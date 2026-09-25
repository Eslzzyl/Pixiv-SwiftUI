针对目前的 git 修改，从**协议正确性、抗网络封锁可用性、性能与资源开销、以及架构设计**四个维度深入检查后，发现虽然基础功能“跑通了”，但存在若干严重的 Bug 和隐患，强烈建议修补：

---

### 一、协议与解码逻辑 Bug（高优先级，会直接引发偶发失败）

#### 1. `NetworkClient` 无法对 `PixivDirectConnectionError` 执行自动重试
* **位置**：[`NetworkClient.swift` 第 710 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L710)
* **代码**：`guard let urlError = error as? URLError else { return false }`
* **问题**：直连抛出的自定义错误类型为 `PixivDirectConnectionError`（如 `.timedOut`, `.allEndpointsFailed`），不属于 `URLError`，导致自动重试机制直接跳过，偶发超时立刻报错。

---

### 二、网络抗封锁与可用性缺陷（中高优先级）

#### 1. 硬编码 2 个 Cloudflare Anycast IP，且删除了 DoH / 动态 DNS
* **位置**：[`PixivDirectEndpointCatalog.cloudflareAddresses`](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L42-L45)
* **问题**：去掉了原有的 DoH 动态解析与 IP 缓存机制，仅硬编码了 `104.18.42.239` 和 `172.64.145.17` 两个 IP。
* **风险**：国内运营商经常对 Cloudflare 节点实施 IP 丢包、限速或黑洞阻断。一旦这两个 IP 被墙或路由劣化，整套直连模式将彻底瘫痪。建议保留或恢复 DoH 兜底解析机制，或者提供更多候选 IP 池。

#### 2. 缺乏向 TCP / HTTP/1.1 或普通代理的自动降级（Fallback）
* **问题**：在不少国内网络环境下（尤其是移动蜂窝网络或某些省份宽带），UDP 443（QUIC）会遭遇极为严厉的 QoS 限速或 UDP 阻断（丢包率 50%~90%）。当前逻辑在 HTTP/3 连续失败后直接报错，没有像标准 Happy Eyeballs 那样在 QUIC 不通时平滑降级到 TCP 传统通道。

#### 3. QUIC 握手中仍携带明文 SNI
* **位置**：[`PixivDirectConnection.swift` 第 318 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L318)
* **代码**：`sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, serverName)`
* **风险**：虽然 QUIC 在 UDP 上传输，但 QUIC Initial 报文中的 ClientHello 依然明文包含 `app-api.pixiv.net` 的 SNI。现代 GFW 针对 UDP ClientHello 的 DPI 检查已经在部分地区部署，可能随时被精准掐断。

#### 4. 超时时间过长引发 UI 假死
* **位置**：[`PixivDirectConnection.swift` 第 125 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L125)
* **代码**：`let timeout = min(max(request.timeoutInterval, 15), 60)`
* **问题**：每个 IP 的连接与响应等待下限被设为 15 秒。如果第一个 IP 不通，界面需要死等 15 秒才会尝试第二个 IP，两个都挂需要 30 秒才报错，严重影响交互流畅度。

---

### 三、性能与资源利用缺陷（中优先级）

#### 1. 一次性短连接，无连接复用池（Connection Pool）
* **问题**：HTTP/3 与 QUIC 的核心优势是 0-RTT/1-RTT 复用与多路复用。当前实现为每个 HTTP 请求都新建一个 `NWConnectionGroup` 并开启 4 个流，请求一完成就全部 `cancel()` 销毁。
* **后果**：用户滑动列表或连续发起 API 时，频繁的 QUIC 握手不仅消耗大量客户端 CPU/电量，增加每次请求的延迟，还极易触发 Cloudflare 的异常流量防御或限流机制。

#### 2. 强制使用 `identity` 传输（无 Gzip/Brotli 数据压缩）
* **位置**：[`PixivDirectConnection.swift` 第 177 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L177)
* **代码**：`headers["accept-encoding"] = "identity"`
* **问题**：因为删除了 `GzipSwift`，请求强制声明不接受压缩。Pixiv 的各种 Feed、插画列表 JSON 动辄数十上百 KB，未压缩传输会带来 3~5 倍的网络传输量，在弱网下明显变慢。

#### 3. Task 取消时存在可能的 Connection Group 泄露（Race Condition）
* **位置**：[`PixivDirectConnection.swift` 第 282-304 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L282-L304)
* **问题**：在 `start()` 中，`makeGroup()` 在未加锁的状态下创建。如果在 `makeGroup()` 执行期间外部 Task 取消触发了 `finish()`，此时 `self.group` 仍为 `nil`，后续 `start()` 恢复后依然会调用 `group.start()`，导致该连接组脱离管理、持续在后台运行。

---

### 四、图片与多媒体处理的遗留死代码

1. **`PixivDirectEndpointCatalog.pximgAddresses` 是死代码**：
   * 在 [`NetworkClient.swift`](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L670-L675) 中，所有 pximg 图片请求都被 `shouldUseDirectImageSession` 拦截，重写为 `s.pximg.net` 走系统的 TCP `URLSession`，且显式指定 `assumesHTTP3Capable = false`。
   * 因此 `PixivDirectConnection` 里的 `pximgAddresses`（`210.140.139.x`）永远不会被用于图片。退一步讲，即使真的给图片用了，Pixiv 东京机房的原始 IP 根本不支持 QUIC/HTTP/3，同样会报错。
2. **`PixivDirectConnection.swift` 仍是未跟踪文件（Untracked）**：
   * 需注意将其加入版本控制，避免在切换分支或进行 CI 构建时丢失。

---

### 五、Additional Static-Review Findings

Review scope: static source inspection, macOS build, and live-server validation completed.

#### 1. Direct downloads buffer the full response before writing to disk
* **位置**：[`NetworkClient.swift` 第 542-575 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L542)
* **问题**：`PixivDirectConnection.data(for:)` returns the full body in memory; the subsequent 64 KiB loop only chunks file writes. The response parser also caps the body at 128 MiB. Progress callbacks begin after the entire response has arrived, so large direct downloads incur a full-response memory allocation and delayed progress.

#### 2. The implementation scope is an HTTP/3 client subset over system QUIC
* **位置**：[`PixivDirectConnection.swift` 第 306-342 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L306)
* **观察**：`NWProtocolQUIC.Options(alpn: ["h3"])` and `NWConnectionGroup` provide the QUIC transport through Apple's Network framework. Application code builds HTTP/3 streams and frames, advertises QPACK table capacity and blocked-stream limits as zero, and implements a constrained QPACK encoder/decoder. The image-host branch in [`NetworkClient.swift` 第 673-677 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L673) selects the `URLSession` route; URLSession task metrics report its negotiated protocol. The source describes a “Pixiv-specific HTTP/3 subset over system QUIC”; the macOS direct-mode check returned status 200 with protocol h3 for Pixiv API responses, while artwork images rendered through URLSession with protocol h2. See [Apple `NWProtocolQUIC.Options`](https://developer.apple.com/documentation/network/nwprotocolquic/options), [RFC 9114](https://www.rfc-editor.org/rfc/rfc9114.html), and [RFC 9204](https://www.rfc-editor.org/rfc/rfc9204.html).
