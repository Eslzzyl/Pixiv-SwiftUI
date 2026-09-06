// swiftlint:disable file_length
import Foundation
import Network
import os.log
import Security
import Gzip

/// 直连网络连接健康度评分管理
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
enum DirectConnectionError: Error, LocalizedError, Equatable {
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
final class DirectConnection: Sendable {
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
        priority: Float = URLSessionTask.defaultPriority,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        try await limiter.withPermit(priority: priority) {
            // 请求并发限制 (32)
            try Task.checkCancellation()

            let host = endpoint.host
            let rawIPs = await endpoint.getIPList()
            // 根据健康度对 IP 进行排序
            let ips = await self.health.rankIPs(rawIPs)
            let requestTimeout = timeout ?? self.defaultTimeout
            Logger.network.debug("开始请求: \(method) \(host)\(path)")

            var lastError: Error?
            for ip in ips {
                try Task.checkCancellation()
                do {
                    Logger.network.debug("正在尝试 IP: \(ip, privacy: .public)")
                    let result = try await self.performRequest(
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
                    await self.health.reportSuccess(ip: ip)
                    Logger.network.info("IP \(ip, privacy: .public) 请求成功")
                    return result
                } catch {
                    if error is CancellationError || (error as? DirectConnectionError) == .cancelled {
                        throw error
                    }

                    Logger.network.warning("IP \(ip, privacy: .public) 失败，错误: \(error.localizedDescription, privacy: .public)")
                    // 失败则降级
                    await self.health.reportFailure(ip: ip)
                    lastError = error

                    if let dcError = error as? DirectConnectionError {
                        Logger.network.warning("DirectConnectionError: \(dcError)")
                    }

                    // 如果是证书错误或协议错误，可能不是 IP 的锅，但通常这里是网络连接超时或彻底断开
                    if let nwError = error as? NWError {
                        Logger.network.warning("NWError Details: \(nwError)")
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
    }

    func download(
        endpoint: PixivEndpoint,
        path: String,
        headers: [String: String] = [:],
        destinationURL: URL,
        existingBytes: Int64 = 0,
        timeout: TimeInterval? = nil,
        priority: Float = URLSessionTask.defaultPriority,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> HTTPURLResponse {
        try await limiter.withPermit(priority: priority) {
            try Task.checkCancellation()

            let host = endpoint.host
            let rawIPs = await endpoint.getIPList()
            let ips = await self.health.rankIPs(rawIPs)
            let requestTimeout = timeout ?? self.defaultTimeout
            Logger.network.debug("开始下载: \(host)\(path)")

            var lastError: Error?
            for ip in ips {
                try Task.checkCancellation()
                do {
                    Logger.network.debug("正在尝试下载 IP: \(ip, privacy: .public)")
                    let response = try await self.performDownload(
                        ip: ip,
                        port: endpoint.port,
                        host: host,
                        path: path,
                        headers: headers,
                        destinationURL: destinationURL,
                        existingBytes: existingBytes,
                        timeout: requestTimeout,
                        onProgress: onProgress
                    )
                    await self.health.reportSuccess(ip: ip)
                    Logger.network.info("IP \(ip, privacy: .public) 下载成功")
                    return response
                } catch {
                    if error is CancellationError || (error as? DirectConnectionError) == .cancelled {
                        throw error
                    }

                    Logger.network.warning("IP \(ip, privacy: .public) 下载失败，错误: \(error.localizedDescription, privacy: .public)")
                    await self.health.reportFailure(ip: ip)
                    lastError = error

                    if let dcError = error as? DirectConnectionError {
                        Logger.network.warning("DirectConnectionError: \(dcError)")
                    }

                    if let nwError = error as? NWError {
                        Logger.network.warning("NWError Details: \(nwError)")
                    }
                    continue
                }
            }

            if endpoint == .image {
                Task {
                    await IpCacheManager.shared.refreshAll()
                }
            }

            throw lastError ?? DirectConnectionError.allIPsFailed
        }
    }

    nonisolated private func performRequest(
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
        let connectionKey = DirectConnectionKey(ip: ip, port: port, host: host)
        let pooledConnection = await DirectConnectionPool.shared.checkout(for: connectionKey)
        let initialConnection = pooledConnection ?? makeRequestConnection(ip: ip, port: port)
        let isReused = pooledConnection != nil

        do {
            return try await executeSingleRequest(
                connection: initialConnection,
                key: connectionKey,
                host: host,
                path: path,
                method: method,
                headers: headers,
                body: body,
                timeout: timeout,
                onProgress: onProgress
            )
        } catch {
            // 如果复用的空闲连接发生网络断开错误（服务端超时断开竞争、对端 FIN/RST 等），
            // 绝不直接向外报错或惩罚 IP 分数，而是静默丢弃该死连接并立即使用全新连接重试一次。
            if isReused, !(error is CancellationError), (error as? DirectConnectionError) != .cancelled {
                Logger.network.info("复用连接失效（\(ip, privacy: .public)），立即使用新建连接重试...")
                let freshConnection = makeRequestConnection(ip: ip, port: port)
                return try await executeSingleRequest(
                    connection: freshConnection,
                    key: connectionKey,
                    host: host,
                    path: path,
                    method: method,
                    headers: headers,
                    body: body,
                    timeout: timeout,
                    onProgress: onProgress
                )
            }
            throw error
        }
    }

    nonisolated private func executeSingleRequest(
        connection reusableConnection: ReusableDirectConnection,
        key connectionKey: DirectConnectionKey,
        host: String,
        path: String,
        method: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let connection = reusableConnection.connection
        let connectionQueue = reusableConnection.queue

        let responseBuffer = ResponseBuffer(expectsNoBody: method.uppercased() == "HEAD")

        let operation = DirectConnectionOperation<(Data, HTTPURLResponse)>(
            connection: connection,
            queue: connectionQueue,
            timeout: timeout,
            onTimeout: {
                Logger.network.warning("连接请求超时: \(connectionKey.ip, privacy: .public)")
            },
            shouldKeepConnection: {
                responseBuffer.isReusable
            }
        )

        do {
            let result = try await operation.run { operation in
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

                    allHeaders["Connection"] = "keep-alive"

                    if allHeaders["Referer"] == nil && (host.contains("pixiv") || host.contains("pximg")) {
                        allHeaders["Referer"] = "https://www.pixiv.net/"
                    }

                    let bodyLength = body?.count ?? 0
                    request += "Content-Length: \(bodyLength)\r\n"

                    let excludedHeaders = ["Host", "Content-Length", "Connection"]
                    for (key, value) in allHeaders where !excludedHeaders.contains(key) {
                        request += "\(key): \(value)\r\n"
                    }
                    request += "Connection: keep-alive\r\n\r\n"

                    var requestData = Data(request.utf8)
                    if let body = body {
                        requestData.append(body)
                    }

                    connection.send(content: requestData, completion: .contentProcessed { sendError in
                        if let error = sendError {
                            Logger.network.warning("发送失败: \(error)")
                            operation.fail(error)
                        }
                    })
                }

                @Sendable func receiveNext() {
                    guard !operation.isFinished else { return }

                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 512) { data, _, isComplete, error in
                        if let data = data, !data.isEmpty {
                            responseBuffer.append(data)
                            let progress = responseBuffer.progress
                            onProgress?(progress.received, progress.total)
                        }

                        if isComplete {
                            responseBuffer.markTransportComplete()
                        }

                        if responseBuffer.isComplete {
                            guard !operation.isFinished else { return }
                            do {
                                let (body, response) = try self.parseHTTPResponse(data: responseBuffer.data, host: host)
                                operation.succeed((body, response))
                            } catch {
                                operation.fail(error)
                            }
                            return
                        }

                        if let error = error {
                            Logger.network.warning("接收错误: \(error)")
                            operation.fail(error)
                            return
                        }

                        if isComplete {
                            guard !operation.isFinished else { return }
                            let fullData = responseBuffer.data
                            if !fullData.isEmpty {
                                do {
                                    let (body, response) = try self.parseHTTPResponse(data: fullData, host: host)
                                    operation.succeed((body, response))
                                } catch {
                                    operation.fail(error)
                                }
                            } else {
                                operation.fail(DirectConnectionError.emptyResponse)
                            }
                            return
                        }

                        receiveNext()
                    }
                }

                @Sendable func startRequest() {
                    guard operation.beginReceiving() else { return }
                    sendRequest()
                    receiveNext()
                }

                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        startRequest()
                    case .failed(let error):
                        operation.fail(error)
                    case .cancelled:
                        operation.fail(DirectConnectionError.cancelled)
                    default:
                        break
                    }
                }

                if reusableConnection.isReady {
                    startRequest()
                } else {
                    connection.start(queue: connectionQueue)
                }
            }

            if responseBuffer.isReusable {
                await DirectConnectionPool.shared.checkin(reusableConnection, for: connectionKey)
            } else {
                reusableConnection.close()
            }
            return result
        } catch {
            reusableConnection.close()
            throw error
        }
    }

    nonisolated private func makeRequestConnection(ip: String, port: Int) -> ReusableDirectConnection {
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

            completionHandler(foundMatch)
        }, .global())

        let parameters = NWParameters(tls: tlsOptions)
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let connection = NWConnection(to: endpoint, using: parameters)
        let connectionQueue = DispatchQueue(label: "com.pixiv.direct.request.\(ip)", qos: .default)
        return ReusableDirectConnection(connection: connection, queue: connectionQueue)
    }

    nonisolated private func performDownload(
        ip: String,
        port: Int,
        host: String,
        path: String,
        headers: [String: String],
        destinationURL: URL,
        existingBytes: Int64,
        timeout: TimeInterval,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> HTTPURLResponse {
        let tlsOptions = NWProtocolTLS.Options()

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

            completionHandler(foundMatch)
        }, .global())

        let parameters = NWParameters(tls: tlsOptions)
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let connection = NWConnection(to: endpoint, using: parameters)
        let connectionQueue = DispatchQueue(label: "com.pixiv.direct.download.\(ip)", qos: .default)
        let streamHandler = try DirectDownloadStreamHandler(
            destinationURL: destinationURL,
            host: host,
            existingBytes: existingBytes,
            onProgress: onProgress
        )

        let operation = DirectConnectionOperation<HTTPURLResponse>(
            connection: connection,
            queue: connectionQueue,
            timeout: timeout,
            onTimeout: {
                Logger.network.warning("\(ip, privacy: .public) 下载超时")
            },
            cleanup: {
                streamHandler.close()
            }
        )

        return try await operation.run { operation in
            @Sendable func sendRequest() {
                var request = "GET \(path) HTTP/1.1\r\n"
                request += "Host: \(host)\r\n"

                var allHeaders = headers
                if allHeaders["User-Agent"] == nil {
                    allHeaders["User-Agent"] = "PixivIOSApp/7.13.3 (iOS 14.6; iPhone12,1)"
                }

                if allHeaders["Accept-Encoding"] == nil {
                    allHeaders["Accept-Encoding"] = "identity"
                }

                allHeaders["Connection"] = "close"

                if allHeaders["Referer"] == nil && (host.contains("pixiv") || host.contains("pximg")) {
                    allHeaders["Referer"] = "https://www.pixiv.net/"
                }

                request += "Content-Length: 0\r\n"

                let excludedHeaders = ["Host", "Content-Length", "Connection"]
                for (key, value) in allHeaders where !excludedHeaders.contains(key) {
                    request += "\(key): \(value)\r\n"
                }
                request += "Connection: close\r\n\r\n"

                let requestData = Data(request.utf8)
                connection.send(content: requestData, completion: .contentProcessed { sendError in
                    if let error = sendError {
                        Logger.network.warning("下载请求发送失败: \(error)")
                        operation.fail(error)
                    }
                })
            }

            @Sendable func receiveNext() {
                guard !operation.isFinished else { return }

                connection.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 512) { data, _, isComplete, error in
                    if let data = data, !data.isEmpty {
                        do {
                            try streamHandler.append(data)
                        } catch {
                            operation.fail(error)
                            return
                        }
                    }

                    if let error = error {
                        Logger.network.warning("下载接收错误: \(error)")
                        operation.fail(error)
                        return
                    }

                    if isComplete {
                        guard !operation.isFinished else { return }
                        do {
                            let response = try streamHandler.complete()
                            operation.succeed(response)
                        } catch {
                            operation.fail(error)
                        }
                        return
                    }

                    receiveNext()
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard operation.beginReceiving() else { return }
                    sendRequest()
                    receiveNext()
                case .failed(let error):
                    operation.fail(error)
                case .cancelled:
                    operation.fail(DirectConnectionError.cancelled)
                default:
                    break
                }
            }

            connection.start(queue: connectionQueue)
        }
    }

    nonisolated private func parseHTTPHeader(data: Data, host: String) throws -> (response: HTTPURLResponse, headers: [String: String]) {
        let headerString = String(data: data, encoding: .utf8) ?? ""
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

        return (response, headers)
    }

    nonisolated func parseHTTPResponse(data: Data, host: String) throws -> (body: Data, response: HTTPURLResponse) {
        let separator = Data("\r\n\r\n".utf8)

        guard let range = data.range(of: separator) else {
            throw DirectConnectionError.emptyResponse
        }

        let headerData = data.subdata(in: 0..<range.lowerBound)
        var bodyData = data.subdata(in: range.upperBound..<data.count)
        let parsedHeader = try parseHTTPHeader(data: headerData, host: host)
        let response = parsedHeader.response
        let headers = parsedHeader.headers

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
                Logger.network.error("Gzip Error: \(error), size: \(bodyData.count)")
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
private final class DirectConnectionOperation<Output>: @unchecked Sendable {
    private enum State {
        case created
        case connecting
        case receiving
        case finishing
        case finished
    }

    fileprivate typealias StartHandler = @Sendable (DirectConnectionOperation<Output>) -> Void

    private let connection: NWConnection
    private let queue: DispatchQueue
    private let timeout: TimeInterval
    private let onTimeout: @Sendable () -> Void
    private let cleanup: @Sendable () -> Void
    private let shouldKeepConnection: @Sendable () -> Bool
    private let lock = NSLock()

    nonisolated(unsafe) private var state = State.created
    nonisolated(unsafe) private var continuation: CheckedContinuation<Output, Error>?
    nonisolated(unsafe) private var pendingResult: Result<Output, Error>?
    nonisolated(unsafe) private var timeoutTimer: DispatchSourceTimer?

    nonisolated init(
        connection: NWConnection,
        queue: DispatchQueue,
        timeout: TimeInterval,
        onTimeout: @escaping @Sendable () -> Void = {},
        cleanup: @escaping @Sendable () -> Void = {},
        shouldKeepConnection: @escaping @Sendable () -> Bool = { false }
    ) {
        self.connection = connection
        self.queue = queue
        self.timeout = timeout
        self.onTimeout = onTimeout
        self.cleanup = cleanup
        self.shouldKeepConnection = shouldKeepConnection
    }

    nonisolated fileprivate func run(_ start: @escaping StartHandler) async throws -> Output {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation(isolation: nil) { (continuation: CheckedContinuation<Output, Error>) in
                install(continuation: continuation, start: start)
            }
        } onCancel: {
            cancel()
        }
    }

    nonisolated var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        switch state {
        case .finishing, .finished:
            return true
        default:
            return false
        }
    }

    nonisolated func beginReceiving() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard case .connecting = state else { return false }
        state = .receiving
        return true
    }

    nonisolated func succeed(_ output: Output) {
        requestFinish(with: .success(output))
    }

    nonisolated func fail(_ error: Error) {
        requestFinish(with: .failure(error))
    }

    nonisolated func cancel() {
        requestFinish(with: .failure(DirectConnectionError.cancelled))
    }

    nonisolated private func install(continuation: CheckedContinuation<Output, Error>, start: @escaping StartHandler) {
        var resultToResume: Result<Output, Error>?
        var shouldStart = false

        lock.lock()
        self.continuation = continuation

        if case .finished = state {
            resultToResume = pendingResult
            pendingResult = nil
            self.continuation = nil
        } else if case .created = state {
            shouldStart = true
        }
        lock.unlock()

        if let resultToResume {
            continuation.resume(with: resultToResume)
        } else if shouldStart {
            queue.async { [weak self] in
                self?.startIfNeeded(start)
            }
        }
    }

    nonisolated private func startIfNeeded(_ start: @escaping StartHandler) {
        lock.lock()
        guard case .created = state else {
            lock.unlock()
            return
        }
        state = .connecting
        lock.unlock()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler { [weak self] in
            self?.onTimeout()
            self?.fail(DirectConnectionError.timeout)
        }

        lock.lock()
        timeoutTimer = timer
        lock.unlock()

        timer.resume()
        start(self)
    }

    nonisolated private func requestFinish(with result: Result<Output, Error>) {
        lock.lock()
        switch state {
        case .finishing, .finished:
            lock.unlock()
            return
        default:
            break
        }
        state = .finishing
        pendingResult = result
        lock.unlock()

        queue.async { [weak self] in
            self?.completeOnQueue()
        }
    }

    nonisolated private func completeOnQueue() {
        lock.lock()
        guard case .finishing = state else {
            lock.unlock()
            return
        }

        state = .finished
        let result = pendingResult
        let continuation = self.continuation
        if continuation != nil {
            pendingResult = nil
            self.continuation = nil
        }
        let timer = timeoutTimer
        timeoutTimer = nil
        lock.unlock()

        timer?.cancel()
        connection.stateUpdateHandler = nil

        let keepConnection: Bool
        if case .success? = result {
            keepConnection = shouldKeepConnection()
        } else {
            keepConnection = false
        }

        if !keepConnection {
            connection.cancel()
            cleanup()
        }

        if let continuation, let result {
            continuation.resume(with: result)
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private final class DirectDownloadStreamHandler: @unchecked Sendable {
    private let host: String
    private let initialBytes: Int64
    private let onProgress: (@Sendable (Int64, Int64?) -> Void)?
    private let lock = NSLock()
    private let fileHandle: FileHandle
    private let chunkedDecoder = HTTPChunkedStreamDecoder()

    nonisolated(unsafe) private var headerBuffer = Data()
    nonisolated(unsafe) private var response: HTTPURLResponse?
    nonisolated(unsafe) private var responseHeaders: [String: String] = [:]
    nonisolated(unsafe) private var receivedBodyBytes: Int64 = 0
    nonisolated(unsafe) private var totalBytes: Int64?
    nonisolated(unsafe) private var effectiveExistingBytes: Int64
    nonisolated(unsafe) private var isChunked = false

    nonisolated init(
        destinationURL: URL,
        host: String,
        existingBytes: Int64,
        onProgress: (@Sendable (Int64, Int64?) -> Void)?
    ) throws {
        self.host = host
        self.initialBytes = existingBytes
        self.effectiveExistingBytes = existingBytes
        self.onProgress = onProgress

        if !FileManager.default.fileExists(atPath: destinationURL.path(percentEncoded: false)) {
            FileManager.default.createFile(atPath: destinationURL.path(percentEncoded: false), contents: nil)
        }

        self.fileHandle = try FileHandle(forWritingTo: destinationURL)
    }

    nonisolated func append(_ data: Data) throws {
        lock.lock()
        defer { lock.unlock() }

        if response == nil {
            headerBuffer.append(data)
            let separator = Data("\r\n\r\n".utf8)
            guard let range = headerBuffer.range(of: separator) else {
                return
            }

            let headerData = headerBuffer.subdata(in: 0..<range.lowerBound)
            let parsedHeader = try Self.parseHTTPHeader(data: headerData, host: host)
            response = parsedHeader.response
            responseHeaders = parsedHeader.headers
            isChunked = responseHeaders["transfer-encoding"]?.lowercased().contains("chunked") == true

            if responseHeaders["content-encoding"]?.lowercased() == "gzip" {
                throw DirectConnectionError.gzipError
            }

            if response?.statusCode == 206 && initialBytes > 0 {
                try fileHandle.seekToEnd()
            } else {
                try fileHandle.truncate(atOffset: 0)
                effectiveExistingBytes = 0
            }

            if let contentLength = responseHeaders["content-length"].flatMap(Int64.init) {
                totalBytes = contentLength + effectiveExistingBytes
            }

            onProgress?(effectiveExistingBytes, totalBytes)

            let bodyStart = range.upperBound
            let bodyData = headerBuffer.subdata(in: bodyStart..<headerBuffer.count)
            headerBuffer.removeAll(keepingCapacity: false)
            try processBody(bodyData)
            return
        }

        try processBody(data)
    }

    nonisolated func complete() throws -> HTTPURLResponse {
        lock.lock()
        defer { lock.unlock() }

        guard let response else {
            throw DirectConnectionError.emptyResponse
        }

        if isChunked {
            try chunkedDecoder.finalize()
        } else if let expectedSize = responseHeaders["content-length"].flatMap(Int.init), receivedBodyBytes < Int64(expectedSize) {
            throw DirectConnectionError.incompleteData(expected: expectedSize, received: Int(receivedBodyBytes))
        }

        return response
    }

    nonisolated func close() {
        lock.lock()
        defer { lock.unlock() }
        try? fileHandle.close()
    }

    nonisolated private func processBody(_ data: Data) throws {
        guard !data.isEmpty else { return }

        if isChunked {
            let chunks = try chunkedDecoder.append(data)
            for chunk in chunks {
                try write(chunk)
            }
        } else {
            try write(data)
        }
    }

    nonisolated private func write(_ data: Data) throws {
        guard !data.isEmpty else { return }
        try fileHandle.write(contentsOf: data)
        receivedBodyBytes += Int64(data.count)
        onProgress?(effectiveExistingBytes + receivedBodyBytes, totalBytes)
    }

    nonisolated private static func parseHTTPHeader(data: Data, host: String) throws -> (response: HTTPURLResponse, headers: [String: String]) {
        let headerString = String(data: data, encoding: .utf8) ?? ""
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

        return (response, headers)
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
private final class HTTPChunkedStreamDecoder: @unchecked Sendable {
    nonisolated(unsafe) private var buffer = Data()
    nonisolated(unsafe) private var sawEndMarker = false

    nonisolated func append(_ data: Data) throws -> [Data] {
        guard !sawEndMarker else { return [] }

        buffer.append(data)
        var decodedChunks: [Data] = []

        while true {
            var lineEnd = 0
            while lineEnd < buffer.count - 1 && !(buffer[lineEnd] == 0x0D && buffer[lineEnd + 1] == 0x0A) {
                lineEnd += 1
            }

            if buffer.count < 2 || lineEnd >= buffer.count - 1 {
                break
            }

            let sizeData = buffer.subdata(in: 0..<lineEnd)
            guard let sizeString = String(data: sizeData, encoding: .utf8) else {
                throw DirectConnectionError.chunkedDecodeError
            }

            let cleanSizeString = sizeString.trimmingCharacters(in: .whitespaces).split(separator: ";")[0]
            guard let chunkSize = Int(cleanSizeString, radix: 16) else {
                throw DirectConnectionError.chunkedDecodeError
            }

            let chunkStart = lineEnd + 2

            if chunkSize == 0 {
                if buffer.count < chunkStart + 2 {
                    break
                }
                sawEndMarker = true
                buffer.removeAll(keepingCapacity: false)
                break
            }

            let chunkEnd = chunkStart + chunkSize
            if buffer.count < chunkEnd + 2 {
                break
            }

            decodedChunks.append(buffer.subdata(in: chunkStart..<chunkEnd))
            buffer.removeSubrange(0..<(chunkEnd + 2))
        }

        return decodedChunks
    }

    nonisolated func finalize() throws {
        guard sawEndMarker else {
            throw DirectConnectionError.chunkedDecodeError
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
nonisolated final class ResponseBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let expectsNoBody: Bool
    nonisolated(unsafe) private var storage = Data()
    nonisolated(unsafe) private var headerLength: Int?
    nonisolated(unsafe) private var expectedContentLength: Int64?
    nonisolated(unsafe) private var responseStatusCode: Int?
    nonisolated(unsafe) private var isChunked = false
    nonisolated(unsafe) private var serverWantsClose = false
    nonisolated(unsafe) private var transportDidComplete = false

    nonisolated init(expectsNoBody: Bool = false) {
        self.expectsNoBody = expectsNoBody
    }

    nonisolated func markTransportComplete() {
        lock.lock()
        defer { lock.unlock() }
        transportDidComplete = true
    }

    nonisolated func append(_ newData: Data) {
        lock.lock()
        defer { lock.unlock() }

        storage.append(newData)

        if headerLength == nil {
            let separator = Data("\r\n\r\n".utf8)
            if let range = storage.range(of: separator) {
                headerLength = range.upperBound

                let headerData = storage.subdata(in: 0..<range.lowerBound)
                if let headerString = String(data: headerData, encoding: .utf8) {
                    let lines = headerString.components(separatedBy: .newlines)
                    if let statusLine = lines.first {
                        let parts = statusLine.split(separator: " ", maxSplits: 2)
                        if parts.count >= 2 {
                            responseStatusCode = Int(parts[1])
                        }
                    }

                    for line in lines {
                        let parts = line.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                            let value = parts[1].trimmingCharacters(in: .whitespaces)
                            if key == "content-length", let length = Int64(value) {
                                expectedContentLength = length
                            } else if key == "transfer-encoding" {
                                isChunked = value.lowercased().split(separator: ";").contains { $0.trimmingCharacters(in: .whitespaces) == "chunked" }
                            } else if key == "connection" {
                                serverWantsClose = value.lowercased().split(separator: ",").contains { $0.trimmingCharacters(in: .whitespaces) == "close" }
                            }
                        }
                    }
                }
            }
        }
    }

    nonisolated var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let headerLength else { return false }
        if expectsNoBody || responseStatusCode == 204 || responseStatusCode == 304 {
            return true
        }

        let body = storage.subdata(in: headerLength..<storage.count)
        if let expectedContentLength {
            return Int64(body.count) >= expectedContentLength
        }
        if isChunked {
            return Self.hasCompleteChunkedBody(body)
        }
        return false
    }

    nonisolated var isReusable: Bool {
        lock.lock()
        defer { lock.unlock() }

        guard let headerLength, !serverWantsClose, !transportDidComplete else { return false }
        guard let responseStatusCode, (200...399).contains(responseStatusCode) else { return false }

        if expectsNoBody || responseStatusCode == 204 || responseStatusCode == 304 {
            return true
        }

        let bodyCount = Int64(storage.count - headerLength)
        if let expectedContentLength {
            return bodyCount == expectedContentLength
        }

        if isChunked {
            let body = storage.subdata(in: headerLength..<storage.count)
            return Self.hasCompleteChunkedBody(body)
        }

        return false
    }

    nonisolated var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    nonisolated var progress: (received: Int64, total: Int64?) {
        lock.lock()
        defer { lock.unlock() }
        let received = Int64(storage.count - (headerLength ?? 0))
        return (max(0, received), expectedContentLength)
    }

    private static func hasCompleteChunkedBody(_ body: Data) -> Bool {
        let lineSeparator = Data([0x0D, 0x0A])
        let trailerSeparator = Data([0x0D, 0x0A, 0x0D, 0x0A])
        var offset = 0

        while offset < body.count {
            guard let lineRange = body.range(of: lineSeparator, in: offset..<body.count) else {
                return false
            }

            let sizeData = body.subdata(in: offset..<lineRange.lowerBound)
            guard let sizeString = String(data: sizeData, encoding: .utf8),
                  let sizeToken = sizeString.split(separator: ";", maxSplits: 1).first,
                  let chunkSize = Int(sizeToken.trimmingCharacters(in: .whitespaces), radix: 16) else {
                return false
            }

            let chunkStart = lineRange.upperBound
            if chunkSize == 0 {
                if body.count >= chunkStart + 2,
                   body[chunkStart] == 0x0D,
                   body[chunkStart + 1] == 0x0A {
                    return true
                }
                return body.range(of: trailerSeparator, in: chunkStart..<body.count) != nil
            }

            let chunkEnd = chunkStart + chunkSize
            guard body.count >= chunkEnd + 2,
                  body[chunkEnd] == 0x0D,
                  body[chunkEnd + 1] == 0x0A else {
                return false
            }
            offset = chunkEnd + 2
        }

        return false
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
actor DirectConnectionLimiter {
    static let shared = DirectConnectionLimiter()
    private var count = 0
    private let maxConcurrentRequests = 32
    private var waitingTasks: [UUID: CheckedContinuation<Void, any Error>] = [:]
    private var waitingPriorities: [UUID: Float] = [:]
    private var waitOrder: [UUID] = []

    func wait(priority: Float) async throws {
        if count < maxConcurrentRequests {
            count += 1
            return
        }
        let id = UUID()
        let clampedPriority = min(max(priority, URLSessionTask.lowPriority), URLSessionTask.highPriority)
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waitingTasks[id] = continuation
                waitingPriorities[id] = clampedPriority
                let insertionIndex = waitOrder.firstIndex {
                    (waitingPriorities[$0] ?? URLSessionTask.lowPriority) < clampedPriority
                } ?? waitOrder.endIndex
                waitOrder.insert(id, at: insertionIndex)
            }
        } onCancel: {
            Task {
                await self.cancelWait(id: id)
            }
        }
    }

    func cancelWait(id: UUID) {
        if let continuation = waitingTasks.removeValue(forKey: id) {
            waitingPriorities.removeValue(forKey: id)
            waitOrder.removeAll { $0 == id }
            continuation.resume(throwing: CancellationError())
        }
    }

    func withPermit<Output: Sendable>(
        priority: Float,
        _ operation: @escaping @Sendable () async throws -> Output
    ) async throws -> Output {
        try await wait(priority: priority)
        do {
            let output = try await operation()
            signal()
            return output
        } catch {
            signal()
            throw error
        }
    }

    func signal() {
        while !waitOrder.isEmpty {
            let id = waitOrder.removeFirst()
            if let continuation = waitingTasks.removeValue(forKey: id) {
                waitingPriorities.removeValue(forKey: id)
                continuation.resume()
                return
            }
        }
        count = max(0, count - 1)
    }
}
