针对目前的 git 修改，从**协议正确性、抗网络封锁可用性、性能与资源开销、以及架构设计**四个维度深入检查后，发现虽然基础功能“跑通了”，但存在若干严重的 Bug 和隐患，强烈建议修补：

---

### 二、网络抗封锁与可用性缺陷（中高优先级）

#### 2. 缺乏向 TCP / HTTP/1.1 或普通代理的自动降级（Fallback）
* **问题**：在不少国内网络环境下（尤其是移动蜂窝网络或某些省份宽带），UDP 443（QUIC）会遭遇极为严厉的 QoS 限速或 UDP 阻断（丢包率 50%~90%）。当前逻辑在 HTTP/3 连续失败后直接报错，没有像标准 Happy Eyeballs 那样在 QUIC 不通时平滑降级到 TCP 传统通道。

#### 3. QUIC 握手中仍携带明文 SNI
* **位置**：[`PixivDirectConnection.swift` 第 437 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L437)
* **代码**：`sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, serverName)`
* **风险**：虽然 QUIC 在 UDP 上传输，但 QUIC Initial 报文中的 ClientHello 依然明文包含 `app-api.pixiv.net` 的 SNI。现代 GFW 针对 UDP ClientHello 的 DPI 检查已经在部分地区部署，可能随时被精准掐断。

---

### 四、图片与多媒体处理的遗留死代码

1. **`PixivDirectEndpointCatalog.pximgAddresses` 是死代码**：
   * 在 [`NetworkClient.swift`](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L676-L680) 中，所有 pximg 图片请求都被 `shouldUseDirectImageSession` 拦截，重写为 `s.pximg.net` 走系统的 TCP `URLSession`，且显式指定 `assumesHTTP3Capable = false`。
   * 因此 `PixivDirectConnection` 里的 `pximgAddresses`（`210.140.139.x`）永远不会被用于图片。退一步讲，即使真的给图片用了，Pixiv 东京机房的原始 IP 根本不支持 QUIC/HTTP/3，同样会报错。

---

### 五、Additional Static-Review Findings

Review scope: static source inspection, macOS build, and live-server validation completed.

#### 1. Direct downloads buffer the full response before writing to disk
* **位置**：[`NetworkClient.swift` 第 542-575 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L542)
* **问题**：`PixivDirectConnection.data(for:)` returns the full body in memory; the subsequent 64 KiB loop only chunks file writes. The response parser also caps the body at 128 MiB. Progress callbacks begin after the entire response has arrived, so large direct downloads incur a full-response memory allocation and delayed progress.

#### 2. The implementation scope is an HTTP/3 client subset over system QUIC
* **位置**：[`PixivDirectConnection.swift` 第 396-460 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/PixivDirectConnection.swift#L396)
* **观察**：`NWProtocolQUIC.Options(alpn: ["h3"])` and `NWConnectionGroup` provide the QUIC transport through Apple's Network framework. Application code builds HTTP/3 streams and frames, advertises QPACK table capacity and blocked-stream limits as zero, and implements a constrained QPACK encoder/decoder. The image-host branch in [`NetworkClient.swift` 第 676-680 行](file:///Users/eslzzyl/WorkSpace/Xcode/Pixiv-SwiftUI/Pixiv-SwiftUI/Core/Network/Client/NetworkClient.swift#L676) selects the `URLSession` route; URLSession task metrics report its negotiated protocol. The source describes a “Pixiv-specific HTTP/3 subset over system QUIC”; the macOS direct-mode check returned status 200 with protocol h3 for Pixiv API responses, while artwork images rendered through URLSession with protocol h2. See [Apple `NWProtocolQUIC.Options`](https://developer.apple.com/documentation/network/nwprotocolquic/options), [RFC 9114](https://www.rfc-editor.org/rfc/rfc9114.html), and [RFC 9204](https://www.rfc-editor.org/rfc/rfc9204.html).
