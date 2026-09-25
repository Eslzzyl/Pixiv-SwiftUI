针对目前的 git 修改，从**协议正确性、抗网络封锁可用性、性能与资源开销、以及架构设计**四个维度深入检查后，发现虽然基础功能“跑通了”，但存在若干严重的 Bug 和隐患，强烈建议修补：

---

### 一、协议与解码逻辑 Bug（高优先级，会直接引发偶发失败）

#### 1. QPACK 解码 `isStatic` 判断位偏移错误
* **位置**：[`PixivDirectConnection.swift` 第 840 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L840)
* **代码**：`let isStatic = first & 0x08 != 0`
* **问题**：在 RFC 9204 4.5.4 规范（Literal Field Line with Name Reference）中，位结构为 `01NT xxxx`，第 4 位（`0x10`）才是 Static Table 标记位 `T`，而 `0x08` 实际上是 4 位 Index 前缀的最高位！
* **后果**：当静态表索引值小于 8 时（例如 `:authority`、`:path`、`date` 等），`isStatic` 会被误判为 `false`，导致无法解析引用的静态头。应修正为 `first & 0x10 != 0`。

#### 2. QPACK 字符串长度与 Huffman 掩码计算错误
* **位置**：[`PixivDirectConnection.swift` 第 893 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L893)
* **代码**：`let huffmanMask = UInt8(1 << (prefixBits - 1))`
* **问题**：
  * 当 `prefixBits = 7` 时，`1 << 6 = 0x40`。但规范中 Huffman 标志位 `H` 位于字节最高位（`0x80`，即 `1 << prefixBits`）。
  * 当 `prefixBits = 3` 时，`1 << 2 = 0x04`，而 `H` 位于第 3 位（`0x08`）。
* **后果**：
  1. 真正的 Huffman 编码（最高位为 1）没有被识别为 Huffman，直接走 UTF-8 解码，导致解码乱码或解析失败；
  2. 只要字符串长度超过 64 字节（第 6 位为 1），就会被错误识别为 Huffman 并直接丢弃（返回 `nil`）！应修正为 `let huffmanMask = UInt8(1 << prefixBits)`。

#### 3. 响应头几乎全被抛弃，仅记录了 `:status`
* **位置**：[`PixivDirectConnection.swift` 第 846-848 行、第 855-857 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L846-L848)
* **代码**：
  ```swift
  if name == ":status", let value {
      record(name: name, value: value)
  }
  ```
* **问题**：解码循环中硬编码了只在 `name == ":status"` 时才记录。服务端返回的诸如 `Content-Type`、`Set-Cookie`、`Location`、`Retry-After` 等字面量响应头全部被抛弃。
* **后果**：重试逻辑中的 [`retryDelayMilliseconds`](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L752) 永远读不到服务端的 `Retry-After`；重定向（301/302）丢失 `Location`；任何需要检查 Header 的上层业务全部失效。

#### 4. 非 200/静态表状态码在遇 Huffman 时直接抛出崩溃式错误
* 在 QPACK 静态表中只有部分状态码（200, 304, 404 等）。如果服务端返回 401（Token 失效）、429（限流被控）、502 等状态码且带 Huffman 压缩时，`decodeString` 解析失败导致 `statusCode` 为 `nil`，最终在 `finish()` 中直接抛出 `invalidResponse`，使业务层无法捕获 401 去自动刷新 Token。

#### 5. `NetworkClient` 无法对 `PixivDirectConnectionError` 执行自动重试
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

Review scope: static source inspection completed; build and live-server validation remain pending.

#### 1. Request QPACK string values use an 8-bit prefix
* **位置**：[`PixivDirectConnection.swift` 第 702、715 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L702)
* **代码**：Both call `appendString(..., prefixBits: 8)`.
* **问题**：QPACK string literals carry a Huffman flag followed by a 7-bit-prefixed length. These calls encode the length with eight prefix bits. Values shorter than 128 bytes happen to share the same leading length byte; values of 128 bytes or more can set the Huffman flag or produce a malformed field value. Long paths, query values, cookies, or authorization values can therefore make the server reject the request. See [RFC 9204 §4.1.2](https://www.rfc-editor.org/rfc/rfc9204.html#section-4.1.2).

#### 2. Response frame handling uses a two-type switch
* **位置**：[`PixivDirectConnection.swift` 第 786-817 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L786)
* **问题**：The parser stores buffered bytes, body bytes, headers, and an optional status code. `parseAvailableFrames()` handles frame types `DATA` and `HEADERS`, then skips the remaining frame types. `DATA` before `HEADERS` is appended to the body; `DATA` after a trailing `HEADERS` frame follows the same path. RFC 9114 classifies these frame-order sequences as errors; see [RFC 9114 §4.1 and §7](https://www.rfc-editor.org/rfc/rfc9114.html#section-4.1).

#### 3. Direct downloads buffer the full response before writing to disk
* **位置**：[`NetworkClient.swift` 第 542-575 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L542)
* **问题**：`PixivDirectConnection.data(for:)` returns the full body in memory; the subsequent 64 KiB loop only chunks file writes. The response parser also caps the body at 128 MiB. Progress callbacks begin after the entire response has arrived, so large direct downloads incur a full-response memory allocation and delayed progress.

#### 4. The implementation scope is an HTTP/3 client subset over system QUIC
* **位置**：[`PixivDirectConnection.swift` 第 306-342 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L306)
* **观察**：`NWProtocolQUIC.Options(alpn: ["h3"])` and `NWConnectionGroup` provide the QUIC transport through Apple's Network framework. Application code builds HTTP/3 streams and frames, advertises QPACK table capacity and blocked-stream limits as zero, and implements a constrained QPACK encoder/decoder. The image-host branch in [`NetworkClient.swift` 第 673-677 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L673) selects the `URLSession` route; URLSession task metrics report its negotiated protocol. The source describes a “Pixiv-specific HTTP/3 subset over system QUIC”; runtime compatibility awaits live-server validation. See [Apple `NWProtocolQUIC.Options`](https://developer.apple.com/documentation/network/nwprotocolquic/options), [RFC 9114](https://www.rfc-editor.org/rfc/rfc9114.html), and [RFC 9204](https://www.rfc-editor.org/rfc/rfc9204.html).
