import Foundation
import Network
import Security
import Gzip

/// 直连网络连接健康度评分管理
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
enum DirectConnectionError: Error, LocalizedError {
    case timeout
    case cancelled
    case emptyResponse
    case incompleteData(expected: Int, received: Int)
    case chunkedDecodeError
    case gzipError
    case allIPsFailed

    var errorDescription: String? {
        switch self {
        case .timeout: return "请求超时"
        case .cancelled: return "请求取消"
        case .emptyResponse: return "响应为空"
        case .incompleteData(let expected, let received): return "数据接收不完整 (期望 \(expected), 实际 \(received))"
        case .chunkedDecodeError: return "分块传输解码失败"
        case .gzipError: return "Gzip 解压失败"
        case .allIPsFailed: return "所有节点尝试失败"
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
actor DirectConnectionHealth {
    static let shared = DirectConnectionHealth()

    private var healthScores: [String: Double] = [:] // 0.0 - 1.0
    private let penalty: Double = 0.2
    private let boost: Double = 0.05

    func reportSuccess(ip: String) {
        let current = healthScores[ip] ?? 1.0
        healthScores[ip] = min(1.0, current + boost)
    }

    func reportFailure(ip: String) {
        let current = healthScores[ip] ?? 1.0
        healthScores[ip] = max(0.1, current - penalty) // 最低保留 0.1 权重
    }

    func rankIPs(_ ips: [String]) -> [String] {
        return ips.sorted { ip1, ip2 in
            let score1 = healthScores[ip1] ?? 1.0
            let score2 = healthScores[ip2] ?? 1.0
            return score1 > score2
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
final class DirectConnection: @unchecked Sendable {
    static let shared = DirectConnection()

    private let defaultTimeout: TimeInterval = 30
    private let limiter = DirectConnectionLimiter.shared
    private let health = DirectConnectionHealth.shared

    private init() {}

    func request(
        endpoint: PixivEndpoint,
        path: String,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval? = nil,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        // 请求并发限制 (32)
        await limiter.wait()
        defer {
            Task {
                await limiter.signal()
            }
        }

        let host = endpoint.host
        let rawIPs = await endpoint.getIPList()
        // 根据健康度对 IP 进行排序
        let ips = await health.rankIPs(rawIPs)
        let requestTimeout = timeout ?? defaultTimeout

        print("[DirectConnection] 请求: \(method) \(host)\(path)")

        var lastError: Error?
        for ip in ips {
            do {
                let result = try await performRequest(
                    ip: ip,
                    port: endpoint.port,
                    host: host,
                    path: path,
                    method: method,
                    headers: headers,
                    body: body,
                    timeout: requestTimeout,
                    onProgress: onProgress
                )
                // 成功则汇报健康
                await health.reportSuccess(ip: ip)
                return result
            } catch {
                print("[DirectConnection] IP \(ip) 失败: \(error)")
                // 失败则降级
                await health.reportFailure(ip: ip)
                lastError = error

                // 如果是证书错误或协议错误，可能不是 IP 的锅，但通常这里是网络连接超时或彻底断开
                if let nwError = error as? NWError {
                    print("[DirectConnection] NWError Details: \(nwError)")
                }
                continue
            }
        }

        // 如果所有 IP 都失败了，且是 image 域名，尝试刷新 IP 缓存
        if endpoint == .image {
            Task {
                await IpCacheManager.shared.refreshAll()
            }
        }

        throw lastError ?? DirectConnectionError.allIPsFailed
    }

    private func performRequest(
        ip: String,
        port: Int,
        host: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let tlsOptions = NWProtocolTLS.Options()

        // 强制使用 HTTP/1.1
        sec_protocol_options_add_tls_application_protocol(tlsOptions.securityProtocolOptions, "http/1.1")

        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { @Sendable (_, trustRef, completionHandler) in
            let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()
            var foundMatch = false

            if let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate] {
                for cert in certificates {
                    if let summary = SecCertificateCopySubjectSummary(cert) as String? {
                        let lowerSummary = summary.lowercased()
                        if lowerSummary.contains("pixiv.net") || lowerSummary.contains("pximg.net") {
                            foundMatch = true
                            break
                        }
                    }
                }
            }

            if foundMatch {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        }, .global())

        let parameters = NWParameters(tls: tlsOptions)
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let connection = NWConnection(to: endpoint, using: parameters)

        let responseBuffer = ResponseBuffer()

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTimer = DispatchSource.makeTimerSource(queue: .global())
            timeoutTimer.schedule(deadline: .now() + timeout)

            let isFinished = AtomicBool(false)
            let finishLock = NSLock()

            @Sendable func finish(with result: Result<(Data, HTTPURLResponse), Error>) {
                if isFinished.compareAndSwap(expected: false, desired: true) {
                    finishLock.lock()
                    timeoutTimer.cancel()

                    // 彻底断开连接，避免复用带来的 POSIX 96 错误
                    connection.stateUpdateHandler = nil
                    connection.cancel()

                    continuation.resume(with: result)
                    finishLock.unlock()
                }
            }

            timeoutTimer.setEventHandler {
                print("[DirectConnection] \(ip) 请求超时")
                finish(with: .failure(DirectConnectionError.timeout))
            }
            timeoutTimer.resume()

            @Sendable func sendRequest() {
                var request = "\(method) \(path) HTTP/1.1\r\n"
                request += "Host: \(host)\r\n"

                var allHeaders = headers
                if allHeaders["User-Agent"] == nil {
                    allHeaders["User-Agent"] = "PixivIOSApp/7.13.3 (iOS 14.6; iPhone12,1)"
                }

                if allHeaders["Accept-Encoding"] == nil {
                    allHeaders["Accept-Encoding"] = "gzip"
                }

                // 暂时禁用 Keep-Alive 以保证稳定性
                allHeaders["Connection"] = "close"

                if allHeaders["Referer"] == nil && (host.contains("pixiv") || host.contains("pximg")) {
                    allHeaders["Referer"] = "https://www.pixiv.net/"
                }

                let bodyLength = body?.count ?? 0
                request += "Content-Length: \(bodyLength)\r\n"

                let excludedHeaders = ["Host", "Content-Length", "Connection"]
                for (key, value) in allHeaders where !excludedHeaders.contains(key) {
                    request += "\(key): \(value)\r\n"
                }
                request += "Connection: close\r\n\r\n"

                var requestData = Data(request.utf8)
                if let body = body {
                    requestData.append(body)
                }

                connection.send(content: requestData, completion: .contentProcessed { sendError in
                    if let error = sendError {
                        print("[DirectConnection] \(ip) 发送失败: \(error)")
                        finish(with: .failure(error))
                    }
                })
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    sendRequest()
                case .failed(let error):
                    finish(with: .failure(error))
                case .cancelled:
                    if !isFinished.isTrue {
                        finish(with: .failure(DirectConnectionError.cancelled))
                    }
                default:
                    break
                }
            }

            @Sendable func receiveNext() {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 512) { data, _, isComplete, error in
                    if let data = data, !data.isEmpty {
                        Task {
                            await responseBuffer.append(data)
                            let progress = await responseBuffer.progress
                            await MainActor.run {
                                onProgress?(progress.received, progress.total)
                            }
                        }
                    }

                    if let error = error {
                        print("[DirectConnection] \(ip) 接收错误: \(error)")
                        finish(with: .failure(error))
                        return
                    }

                    if isComplete {
                        Task {
                            if isFinished.isTrue { return }
                            // 在 isComplete 时，我们要确保之前的 append Task 已经完成。
                            let fullData = await responseBuffer.data
                            if !fullData.isEmpty {
                                do {
                                    let (body, response) = try self.parseHTTPResponse(data: fullData, host: host)
                                    finish(with: .success((body, response)))
                                } catch {
                                    finish(with: .failure(error))
                                }
                            } else {
                                finish(with: .failure(DirectConnectionError.emptyResponse))
                            }
                        }
                        return
                    }

                    if !isFinished.isTrue {
                        receiveNext()
                    }
                }
            }

            receiveNext()
            connection.start(queue: .global())
        }
    }

    nonisolated func parseHTTPResponse(data: Data, host: String) throws -> (body: Data, response: HTTPURLResponse) {
        let separator = Data("\r\n\r\n".utf8)

        guard let range = data.range(of: separator) else {
            throw DirectConnectionError.emptyResponse
        }

        let headerData = data.subdata(in: 0..<range.lowerBound)
        var bodyData = data.subdata(in: range.upperBound..<data.count)

        let headerString = String(data: headerData, encoding: .utf8) ?? ""
        let lines = headerString.components(separatedBy: .newlines)

        var statusCode = 200
        var headers: [String: String] = [:]

        for (index, line) in lines.enumerated() {
            if index == 0 {
                let parts = line.split(separator: " ", maxSplits: 2)
                if parts.count >= 2 {
                    statusCode = Int(parts[1]) ?? 200
                }
            } else {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    headers[key] = value
                }
            }
        }

        let response = HTTPURLResponse(
            // swiftlint:disable:next force_unwrapping
            url: URL(string: "https://\(host)")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) ?? HTTPURLResponse()

        // 校验 Content-Length
        if let contentLengthStr = headers["content-length"], let expectedSize = Int(contentLengthStr) {
            if bodyData.count < expectedSize {
                throw DirectConnectionError.incompleteData(expected: expectedSize, received: bodyData.count)
            }
        }

        // 1. Chunked 解码
        if headers["transfer-encoding"]?.lowercased() == "chunked" {
            bodyData = try decodeChunkedData(bodyData)
        }

        // 2. Gzip 解压
        if headers["content-encoding"]?.lowercased() == "gzip" {
            do {
                if !bodyData.isEmpty {
                    bodyData = try bodyData.gunzipped()
                }
            } catch {
                print("[DirectConnection] Gzip Error: \(error), size: \(bodyData.count)")
                throw DirectConnectionError.gzipError
            }
        }

        return (bodyData, response)
    }

    nonisolated private func decodeChunkedData(_ data: Data) throws -> Data {
        var decoded = Data()
        var offset = 0
        var sawEndMarker = false

        while offset < data.count {
            // 找当前 chunk size 的末尾 \r\n
            var lineEnd = offset
            while lineEnd < data.count - 1 && !(data[lineEnd] == 0x0D && data[lineEnd+1] == 0x0A) {
                lineEnd += 1
            }

            if lineEnd >= data.count - 1 { break }

            let sizeData = data.subdata(in: offset..<lineEnd)
            guard let sizeString = String(data: sizeData, encoding: .utf8) else { break }

            let cleanSizeString = sizeString.trimmingCharacters(in: .whitespaces).split(separator: ";")[0]
            guard let chunkSize = Int(cleanSizeString, radix: 16) else {
                throw DirectConnectionError.chunkedDecodeError
            }

            offset = lineEnd + 2 // 跳过 \r\n

            if chunkSize == 0 {
                sawEndMarker = true
                break
            }

            let chunkEnd = offset + chunkSize
            if chunkEnd <= data.count {
                decoded.append(data.subdata(in: offset..<chunkEnd))
            } else {
                throw DirectConnectionError.incompleteData(expected: chunkEnd, received: data.count)
            }

            offset = chunkEnd + 2 // 跳过 chunk 后的 \r\n
        }

        if !sawEndMarker {
            throw DirectConnectionError.chunkedDecodeError
        }

        return decoded
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
actor ResponseBuffer {
    private var storage = Data()
    private var headerLength: Int?
    private var expectedContentLength: Int64?

    func append(_ newData: Data) {
        storage.append(newData)

        if headerLength == nil {
            let separator = Data("\r\n\r\n".utf8)
            if let range = storage.range(of: separator) {
                headerLength = range.upperBound

                let headerData = storage.subdata(in: 0..<range.lowerBound)
                if let headerString = String(data: headerData, encoding: .utf8) {
                    let lines = headerString.components(separatedBy: .newlines)
                    for line in lines {
                        let parts = line.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            if key == "content-length", let length = Int64(value) {
                                expectedContentLength = length
                                break
                            }
                        }
                    }
                }
            }
        }
    }

    var data: Data { storage }

    var progress: (received: Int64, total: Int64?) {
        let received = Int64(storage.count - (headerLength ?? 0))
        return (max(0, received), expectedContentLength)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
actor DirectConnectionLimiter {
    static let shared = DirectConnectionLimiter()
    private var count = 0
    private let maxConcurrentRequests = 32
    private var continuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if count < maxConcurrentRequests {
            count += 1
            return
        }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func signal() {
        if !continuations.isEmpty {
            let next = continuations.removeFirst()
            next.resume()
        } else {
            count = max(0, count - 1)
        }
    }
}
