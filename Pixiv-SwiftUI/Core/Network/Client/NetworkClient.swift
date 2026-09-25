import Foundation
import Network
import os.log

enum PixivNetworkConfiguration {
    nonisolated static var isDirectMode: Bool {
        let rawValue = UserDefaults.standard.string(forKey: "networkMode") ?? NetworkMode.direct.rawValue
        return rawValue == NetworkMode.direct.rawValue
    }

    nonisolated static func makeNoProxyConfiguration() -> ProxyConfiguration {
        var configuration = ProxyConfiguration(
            httpCONNECTProxy: NWEndpoint.hostPort(
                host: "127.0.0.1",
                port: NWEndpoint.Port(integerLiteral: 1)
            )
        )
        configuration.excludedDomains = ["*"]
        configuration.allowFailover = false
        return configuration
    }

    nonisolated static func applyDirectSessionConfiguration(to configuration: URLSessionConfiguration) {
        configuration.connectionProxyDictionary = [:]
        configuration.proxyConfigurations = [makeNoProxyConfiguration()]
    }

    nonisolated static func isPixivHost(_ host: String) -> Bool {
        hostMatchesDomain(host, domain: "pixiv.net")
            || hostMatchesDomain(host, domain: "pximg.net")
            || hostMatchesDomain(host, domain: "pixivision.net")
    }

    nonisolated static func isPixivImageHost(_ host: String) -> Bool {
        hostMatchesDomain(host, domain: "pximg.net")
            || hostMatchesDomain(host, domain: "img-master.pixiv.net")
    }

    private nonisolated static func hostMatchesDomain(_ host: String, domain: String) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)")
    }
}

private final class PixivURLSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        guard let host = task.originalRequest?.url?.host else { return }

        let protocols = metrics.transactionMetrics.compactMap(\.networkProtocolName)
        let protocolDescription = protocols.isEmpty ? "unavailable" : protocols.joined(separator: ",")
        let statusCode = (task.response as? HTTPURLResponse)?.statusCode ?? -1
        let didUseHTTP3 = protocols.contains("h3")
        let didUseProxy = metrics.transactionMetrics.contains(where: \.isProxyConnection)
        Logger.network.debug(
            "URLSession metrics host=\(host, privacy: .public) status=\(statusCode) protocols=\(protocolDescription, privacy: .public) h3=\(didUseHTTP3) proxy=\(didUseProxy)"
        )
    }
}

/// 网络请求的基础配置
final class NetworkClient {
    static let shared = NetworkClient()

    private let sessionDelegate: PixivURLSessionDelegate
    private var session: URLSession
    private var directImageSession: URLSession
    private let maxAutomaticRetryCount = 1

    private init() {
        let sessionDelegate = PixivURLSessionDelegate()
        self.sessionDelegate = sessionDelegate
        self.session = Self.makeSession(delegate: sessionDelegate)
        self.directImageSession = Self.makeDirectImageSession(delegate: sessionDelegate)

        NotificationCenter.default.addObserver(
            forName: .networkModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.recreateSession()
            }
        }
    }

    private static func makeSession(delegate: PixivURLSessionDelegate) -> URLSession {
        let networkMode = NetworkModeStore.shared.currentMode

        let config = URLSessionConfiguration.default
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let acceptLanguage = (langCode == "zh" || langCode.hasPrefix("zh-")) ? "zh-CN" : "en-US"
        config.httpAdditionalHeaders = [
            "User-Agent": "PixivIOSApp/6.7.1 (iOS 14.6; iPhone10,3) AppleWebKit/605.1.15",
            "Accept-Language": acceptLanguage,
            "Accept-Encoding": "gzip, deflate",
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true

        if #available(macOS 15.4, iOS 18.4, *) {
            config.usesClassicLoadingMode = false
        }

        if networkMode == .direct {
            PixivNetworkConfiguration.applyDirectSessionConfiguration(to: config)
            config.waitsForConnectivity = false
        } else {
            PixivProxySessionConfiguration.apply(NetworkModeStore.shared.activeCustomProxy, to: config)
        }

        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    private static func makeDirectImageSession(delegate: PixivURLSessionDelegate) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = [
            "User-Agent": "PixivIOSApp/6.7.1 (iOS 14.6; iPhone10,3) AppleWebKit/605.1.15",
            "Accept-Language": "zh-CN",
            "Accept-Encoding": "gzip, deflate",
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = false
        if #available(macOS 15.4, iOS 18.4, *) {
            config.usesClassicLoadingMode = true
        }
        PixivNetworkConfiguration.applyDirectSessionConfiguration(to: config)
        return URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    private func recreateSession() {
        let previousSession = session
        let previousDirectImageSession = directImageSession
        session = Self.makeSession(delegate: sessionDelegate)
        directImageSession = Self.makeDirectImageSession(delegate: sessionDelegate)
        cancelInFlightRequests(in: previousSession)
        cancelInFlightRequests(in: previousDirectImageSession)
    }

    /// 是否启用 HTTP/3 优先网络路径
    var useDirectConnection: Bool {
        NetworkModeStore.shared.useDirectConnection
    }

    /// 取消所有进行中的 URLSession 请求（网络模式切换时调用）
    private func cancelInFlightRequests(in session: URLSession) {
        Task {
            let (dataTasks, uploadTasks, downloadTasks) = await session.tasks
            let allTasks = dataTasks + uploadTasks + downloadTasks
            allTasks.forEach { $0.cancel() }
            session.invalidateAndCancel()
            Logger.network.debug("网络模式切换: 已取消 \(allTasks.count) 个进行中的请求")
        }
    }

    private func supportsDirectConnection(host: String) -> Bool {
        // HTTP/3 优先网络路径仅用于 Pixiv 相关域名；对其他域名不应启用 HTTP/3。
        PixivNetworkConfiguration.isPixivHost(host)
    }

    private func applyDirectRequestOptions(to request: inout URLRequest) {
        guard useDirectConnection,
              let host = request.url?.host,
              supportsDirectConnection(host: host) else {
            return
        }

        request.assumesHTTP3Capable = true
    }

    private func shouldUseDirectTransport(for request: URLRequest) -> Bool {
        guard useDirectConnection,
              let url = request.url,
              url.scheme?.lowercased() == "https",
              let host = url.host else {
            return false
        }

        return supportsDirectConnection(host: host)
    }

    private func shouldUseDirectImageSession(for request: URLRequest) -> Bool {
        guard useDirectConnection,
              let host = request.url?.host else {
            return false
        }

        return PixivNetworkConfiguration.isPixivImageHost(host)
    }

    private func makeDirectImageSessionRequest(_ request: URLRequest) -> URLRequest {
        guard let url = request.url,
              let originalHost = url.host,
              PixivNetworkConfiguration.isPixivImageHost(originalHost) else {
            return request
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = "s.pximg.net"

        var rewrittenRequest = request
        if let rewrittenURL = components?.url {
            rewrittenRequest.url = rewrittenURL
        }
        rewrittenRequest.setValue(originalHost, forHTTPHeaderField: "Host")
        rewrittenRequest.assumesHTTP3Capable = false
        return rewrittenRequest
    }

    /// 发送 GET 请求
    func get<T: Decodable>(
        from url: URL,
        headers: [String: String] = [:],
        responseType: T.Type,
        isLongContent: Bool = false
    ) async throws -> T {
        return try await urlSessionGet(from: url, headers: headers, responseType: responseType, isLongContent: isLongContent)
    }

    /// 发送 POST 请求
    func post<T: Decodable>(
        to url: URL,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type,
        isLongContent: Bool = false
    ) async throws -> T {
        return try await urlSessionPost(to: url, body: body, headers: headers, responseType: responseType, isLongContent: isLongContent)
    }

    /// 下载文件
    func download(
        from url: URL,
        headers: [String: String] = [:],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        try await downloadWithByteProgress(from: url, headers: headers) { received, total in
            guard let onProgress else { return }

            if let total, total > 0 {
                onProgress(Double(received) / Double(total))
            } else {
                let mb = Double(received) / (1024.0 * 1024.0)
                let pseudoProgress = (1.0 - exp(-mb / 2.0)) * 0.9
                onProgress(pseudoProgress)
            }
        }
    }

    /// 下载文件（字节级进度）
    func downloadWithByteProgress(
        from url: URL,
        headers: [String: String] = [:],
        destinationURL: URL? = nil,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        return try await urlSessionDownloadWithByteProgress(from: url, headers: headers, destinationURL: destinationURL, onProgress: onProgress)
    }

    /// 分片并发下载文件
    func concurrentDownload(
        from url: URL,
        headers: [String: String] = [:],
        destinationURL: URL? = nil,
        concurrency: Int = 4,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        let tempURL = destinationURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")

        // 1. 获取文件大小
        var headHeaders = headers
        headHeaders["Range"] = "bytes=0-0" // 通过请求第一个字节获取 Content-Range

        let (_, initialResponse): (Data, HTTPURLResponse)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        let (data, response) = try await urlSessionData(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        (_, initialResponse) = (data, httpResponse)

        // 解析文件总长度
        var totalLength: Int64 = -1
        if let contentRange = initialResponse.value(forHTTPHeaderField: "Content-Range"),
           let totalStr = contentRange.split(separator: "/").last {
            totalLength = Int64(totalStr) ?? -1
        }

        // 如果无法获取长度或长度过小，退化为普通下载
        guard totalLength > 1024 * 1024 else {
            return try await downloadWithByteProgress(from: url, headers: headers, destinationURL: tempURL, onProgress: onProgress)
        }

        // 2. 准备基础文件
        if !FileManager.default.fileExists(atPath: tempURL.path(percentEncoded: false)) {
            FileManager.default.createFile(atPath: tempURL.path(percentEncoded: false), contents: nil)
        }
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        try fileHandle.truncate(atOffset: UInt64(totalLength))
        try fileHandle.close()

        // 3. 分片下载
        let chunkSize = Int64(ceil(Double(totalLength) / Double(concurrency)))
        let finalTotalLength = totalLength
        let sharedProgress = OSAllocatedUnfairLock(initialState: Int64(0))

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<concurrency {
                    let start = Int64(i) * chunkSize
                    let end = min(start + chunkSize - 1, finalTotalLength - 1)
                    guard start < finalTotalLength else { break }

                    group.addTask {
                        var chunkHeaders = headers
                        chunkHeaders["Range"] = "bytes=\(start)-\(end)"

                        let chunkTempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".part")
                        defer { try? FileManager.default.removeItem(at: chunkTempURL) }

                        let chunkProgress = OSAllocatedUnfairLock(initialState: Int64(0))
                        let (downloadedURL, chunkResponse) = try await self.downloadWithByteProgress(from: url, headers: chunkHeaders, destinationURL: chunkTempURL) { receivedInChunk, _ in
                            let delta = chunkProgress.withLock {
                                let delta = receivedInChunk - $0
                                $0 = receivedInChunk
                                return delta
                            }
                            sharedProgress.withLock {
                                $0 += delta
                                onProgress?($0, finalTotalLength)
                            }
                        }

                        guard let httpResponse = chunkResponse as? HTTPURLResponse, httpResponse.statusCode == 206 else {
                            throw NetworkError.rangeNotSupported
                        }

                        let data = try Data(contentsOf: downloadedURL, options: .mappedIfSafe)
                        let handle = try FileHandle(forWritingTo: tempURL)
                        try handle.seek(toOffset: UInt64(start))
                        try handle.write(contentsOf: data)
                        try handle.close()
                    }
                }
                try await group.waitForAll()
            }

            // 4. 校验最终文件完整性：实际大小必须等于预期总长度
            let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path(percentEncoded: false))
            guard let actualSize = attributes[.size] as? Int64, actualSize == finalTotalLength else {
                throw NetworkError.rangeNotSupported
            }
        } catch is CancellationError {
            if destinationURL == nil {
                try? FileManager.default.removeItem(at: tempURL)
            }
            throw CancellationError()
        } catch {
            Logger.network.warning("分段并发下载失败，退化为单线程下载: \(error.localizedDescription, privacy: .public)")
            if FileManager.default.fileExists(atPath: tempURL.path(percentEncoded: false)) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            return try await downloadWithByteProgress(from: url, headers: headers, destinationURL: tempURL, onProgress: onProgress)
        }

        return (tempURL, initialResponse)
    }

    // MARK: - URLSession 实现

    private func urlSessionGet<T: Decodable>(
        from url: URL,
        headers: [String: String],
        responseType: T.Type,
        isLongContent: Bool
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await perform(request, responseType: responseType, isLongContent: isLongContent)
    }

    private func urlSessionPost<T: Decodable>(
        to url: URL,
        body: Data?,
        headers: [String: String],
        responseType: T.Type,
        isLongContent: Bool
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let body = body {
            request.httpBody = body
        }

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await perform(request, responseType: responseType, isLongContent: isLongContent)
    }

    /// 执行请求
    private func perform<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        isLongContent: Bool,
        retryCount: Int = 0
    ) async throws -> T {
        var request = request
        applyDirectRequestOptions(to: &request)
        debugPrintRequest(request)

        let (data, response) = try await urlSessionData(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            let decoded = try decodeResponse(data: data, responseType: responseType)
            debugPrintSuccess(request, data: data)
            return decoded
        }

        debugPrintResponse(httpResponse, data: data, isLongContent: isLongContent)

        if shouldRefreshToken(
            statusCode: httpResponse.statusCode,
            headers: request.allHTTPHeaderFields ?? [:],
            data: data
        ) {
            #if DEBUG
            Logger.token.debug("检测到 OAuth 错误，尝试刷新 token...")
            #endif
            try await SessionManager.shared.refreshTokenIfNeeded()

            #if DEBUG
            Logger.token.info("Token 刷新成功，重试请求")
            #endif

            if retryCount < 1 {
                var newRequest = request
                if let newToken = SessionManager.shared.currentAccessToken {
                    newRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                }
                return try await perform(newRequest, responseType: responseType, isLongContent: isLongContent, retryCount: retryCount + 1)
            }
        }

        throw NetworkError.httpError(httpResponse.statusCode)
    }

    private func urlSessionDownloadWithByteProgress(
        from url: URL,
        headers: [String: String],
        destinationURL: URL? = nil,
        onProgress: (@Sendable (Int64, Int64?) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        let tempURL = destinationURL ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        if !FileManager.default.fileExists(atPath: tempURL.path(percentEncoded: false)) {
            FileManager.default.createFile(atPath: tempURL.path(percentEncoded: false), contents: nil)
        }

        var shouldCleanupTemporaryFile = destinationURL == nil
        defer {
            if shouldCleanupTemporaryFile {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        var retryCount = 0
        while true {
            do {
                let result = try await urlSessionDownloadAttempt(
                    from: url,
                    headers: headers,
                    destinationURL: tempURL,
                    onProgress: onProgress
                )
                shouldCleanupTemporaryFile = false
                return result
            } catch let error as URLSessionHTTPError {
                guard retryCount < maxAutomaticRetryCount, isRetryableHTTPStatus(error.statusCode) else {
                    throw NetworkError.httpError(error.statusCode)
                }

                retryCount += 1
                try await waitBeforeRetry(milliseconds: error.retryDelayMilliseconds)
            } catch {
                guard retryCount < maxAutomaticRetryCount,
                      isRetryableNetworkError(error) else {
                    throw error
                }

                retryCount += 1
                try await waitBeforeRetry()
            }
        }
    }

    private func urlSessionDownloadAttempt(
        from url: URL,
        headers: [String: String],
        destinationURL: URL,
        onProgress: (@Sendable (Int64, Int64?) -> Void)?
    ) async throws -> (URL, URLResponse) {
        var request = URLRequest(url: url)
        applyDirectRequestOptions(to: &request)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        var downloadedBytes: Int64 = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: destinationURL.path(percentEncoded: false)),
           let fileSize = attributes[.size] as? NSNumber {
            downloadedBytes = fileSize.int64Value
            if downloadedBytes > 0 {
                request.setValue(
                    resumedRangeHeader(
                        originalRange: request.value(forHTTPHeaderField: "Range"),
                        downloadedBytes: downloadedBytes
                    ),
                    forHTTPHeaderField: "Range"
                )
            }
        }

        let usesDirectImageSession = shouldUseDirectImageSession(for: request)
        if shouldUseDirectTransport(for: request), !usesDirectImageSession {
            let (data, response) = try await PixivDirectConnection.shared.data(for: request)
            let httpResponse = response
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLSessionHTTPError(
                    statusCode: httpResponse.statusCode,
                    retryDelayMilliseconds: retryDelayMilliseconds(for: httpResponse)
                )
            }

            let isPartial = httpResponse.statusCode == 206 && downloadedBytes > 0
            let fileHandle = try FileHandle(forWritingTo: destinationURL)
            defer { try? fileHandle.close() }

            if isPartial {
                try fileHandle.seekToEnd()
            } else {
                downloadedBytes = 0
                try fileHandle.truncate(atOffset: 0)
            }

            let totalBytes = response.expectedContentLength > 0
                ? response.expectedContentLength + downloadedBytes
                : nil
            var receivedBytes = downloadedBytes
            let chunkSize = 64 * 1024
            var offset = 0
            while offset < data.count {
                try Task.checkCancellation()
                let end = min(offset + chunkSize, data.count)
                try fileHandle.write(contentsOf: data.subdata(in: offset..<end))
                receivedBytes += Int64(end - offset)
                onProgress?(receivedBytes, totalBytes)
                offset = end
            }

            return (destinationURL, response)
        }

        if usesDirectImageSession {
            request = makeDirectImageSessionRequest(request)
        }

        let fileHandle = try FileHandle(forWritingTo: destinationURL)
        defer {
            try? fileHandle.close()
        }

        let imageSession = usesDirectImageSession ? directImageSession : session
        let (bytes, response) = try await imageSession.bytes(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLSessionHTTPError(
                statusCode: httpResponse.statusCode,
                retryDelayMilliseconds: retryDelayMilliseconds(for: httpResponse)
            )
        }

        let httpResponse = response as? HTTPURLResponse
        let isPartial = httpResponse?.statusCode == 206

        if !isPartial {
            downloadedBytes = 0
            try fileHandle.truncate(atOffset: 0)
        } else {
            try fileHandle.seekToEnd()
        }

        let totalBytes = response.expectedContentLength > 0 ? response.expectedContentLength + downloadedBytes : nil

        var receivedBytes: Int64 = downloadedBytes
        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= 64 * 1024 {
                try Task.checkCancellation()
                try fileHandle.write(contentsOf: buffer)
                receivedBytes += Int64(buffer.count)
                onProgress?(receivedBytes, totalBytes)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            try Task.checkCancellation()
            try fileHandle.write(contentsOf: buffer)
            receivedBytes += Int64(buffer.count)
            onProgress?(receivedBytes, totalBytes)
        }

        return (destinationURL, response)
    }

    // MARK: - 工具方法

    /// 判断是否应将请求视为令牌失效。只对携带 Authorization 的业务请求刷新，
    /// 避免登录/刷新接口本身失败时误刷新旧账号。
    private func shouldRefreshToken(statusCode: Int, headers: [String: String], data: Data) -> Bool {
        let hasAuthorization = headers.contains { key, value in
            key.caseInsensitiveCompare("Authorization") == .orderedSame && !value.isEmpty
        }
        guard hasAuthorization else { return false }

        if statusCode == 401 {
            return true
        }

        guard statusCode == 400,
              let errorResponse = try? decodeErrorMessage(data: data) else {
            return false
        }

        let error = errorResponse.error
        let details = [error.message ?? "", error.userMessage ?? "", error.reason ?? ""]
            .map { $0.lowercased() }
            .joined(separator: " ")
        return details.contains("oauth")
            || details.contains("token")
            || details.contains("authorization")
    }

    private func urlSessionData(
        for request: URLRequest,
        retryCount: Int = 0
    ) async throws -> (Data, URLResponse) {
        var request = request
        applyDirectRequestOptions(to: &request)
        let retryRequest = request
        let result: (Data, URLResponse)
        do {
            if shouldUseDirectImageSession(for: request) {
                request = makeDirectImageSessionRequest(request)
                result = try await directImageSession.data(for: request)
            } else if shouldUseDirectTransport(for: request) {
                result = try await PixivDirectConnection.shared.data(for: request)
            } else {
                result = try await session.data(for: request)
            }
        } catch {
            guard retryCount < maxAutomaticRetryCount,
                  isRetryableURLSessionRequest(retryRequest),
                  isRetryableNetworkError(error) else {
                throw error
            }

            try await waitBeforeRetry()
            return try await urlSessionData(for: retryRequest, retryCount: retryCount + 1)
        }

        guard retryCount < maxAutomaticRetryCount,
              isRetryableURLSessionRequest(retryRequest),
              let httpResponse = result.1 as? HTTPURLResponse,
              isRetryableHTTPStatus(httpResponse.statusCode) else {
            return result
        }

        try await waitBeforeRetry(after: httpResponse)
        return try await urlSessionData(for: retryRequest, retryCount: retryCount + 1)
    }

    private func isRetryableURLSessionRequest(_ request: URLRequest) -> Bool {
        let method = request.httpMethod?.uppercased() ?? "GET"
        return method == "GET" || method == "HEAD"
    }

    private func isRetryableNetworkError(_ error: Error) -> Bool {
        guard !(error is CancellationError),
              let urlError = error as? URLError else {
            return false
        }

        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    private func isRetryableHTTPStatus(_ statusCode: Int) -> Bool {
        switch statusCode {
        case 408, 429, 500, 502, 503, 504:
            return true
        default:
            return false
        }
    }

    private func resumedRangeHeader(originalRange: String?, downloadedBytes: Int64) -> String {
        guard let originalRange,
              let rangeValue = originalRange.split(separator: "=", maxSplits: 1).last else {
            return "bytes=\(downloadedBytes)-"
        }

        let rangeParts = rangeValue.split(separator: "-", maxSplits: 1).map(String.init)
        guard let originalStart = rangeParts.first.flatMap(Int64.init) else {
            return "bytes=\(downloadedBytes)-"
        }

        let resumedStart = originalStart + downloadedBytes
        if rangeParts.count > 1,
           let originalEnd = Int64(rangeParts[1]),
           resumedStart <= originalEnd {
            return "bytes=\(resumedStart)-\(originalEnd)"
        }

        return "bytes=\(resumedStart)-"
    }

    private func retryDelayMilliseconds(for response: HTTPURLResponse?) -> Int {
        guard let retryAfter = response?.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Double(retryAfter.trimmingCharacters(in: .whitespacesAndNewlines)),
              seconds.isFinite else {
            return 500
        }

        return Int(min(max(seconds, 0), 10) * 1000)
    }

    private func waitBeforeRetry(after response: HTTPURLResponse? = nil, milliseconds: Int? = nil) async throws {
        let delay = milliseconds ?? retryDelayMilliseconds(for: response)
        Logger.network.debug("请求将在 \(delay)ms 后自动重试")
        try await Task.sleep(for: .milliseconds(delay))
    }

    /// 解码错误响应
    private func decodeErrorMessage(data: Data) throws -> ErrorMessageResponse? {
        let decoder = JSONDecoder()
        return try? decoder.decode(ErrorMessageResponse.self, from: data)
    }

    /// 解码正常响应
    private func decodeResponse<T: Decodable>(data: Data, responseType: T.Type) throws -> T {
        // 如果请求者期望原始 Data，直接返回
        if T.self == Data.self, let rawData = data as? T {
            return rawData
        }
        // 如果期望 String，尝试转换
        if T.self == String.self, let string = String(data: data, encoding: .utf8) as? T {
            return string
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    /// 调试：打印请求信息
    private func debugPrintRequest(_ request: URLRequest) {
        #if DEBUG
            let url = request.url?.absoluteString ?? "未知"
            let method = request.httpMethod ?? "GET"
            let mode = useDirectConnection ? "[HTTP/3直连]" : "[标准]"
            Logger.network.debug("\(mode) \(method) \(url, privacy: .public)")
        #endif
    }

    /// 调试：打印成功信息
    private func debugPrintSuccess(_ request: URLRequest, data: Data) {
        #if DEBUG
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let illusts = json["illusts"] as? [Any] {
                        Logger.network.info("成功获取 \(illusts.count) 个插画")
                    } else if let userPreviews = json["user_previews"] as? [Any] {
                        Logger.network.debug("成功获取 \(userPreviews.count) 个用户预览")
                    } else {
                        Logger.network.info("请求成功")
                    }
                } else {
                    Logger.network.info("请求成功")
                }
            } catch {
                Logger.network.info("请求成功")
            }
        #endif
    }

    /// 调试：打印响应信息（仅失败时）
    private func debugPrintResponse(_ response: HTTPURLResponse, data: Data, isLongContent: Bool = false) {
        #if DEBUG
            Logger.network.debug("请求失败，状态码: \(response.statusCode)")
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                Logger.network.debug("错误详情: \(responseString)")
            }
        #endif
    }

    /// 获取原始响应文本（用于 HTML 响应）
    func getRaw(url: URL, headers: [String: String] = [:]) async throws -> String {
        return try await urlSessionGetRaw(url: url, headers: headers)
    }

    /// URLSession 模式获取原始响应文本
    private func urlSessionGetRaw(url: URL, headers: [String: String]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        Logger.network.debug("GET \(url.absoluteString, privacy: .public)")
        #endif

        let (data, response) = try await urlSessionData(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            Logger.network.debug("请求失败，状态码: \(httpResponse.statusCode)")
            #endif
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }

        return text
    }
}

/// 网络请求错误
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case connectionError(String)
    case rangeNotSupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .connectionError(let message):
            return "连接错误: \(message)"
        case .rangeNotSupported:
            return "服务器不支持分段下载"
        }
    }
}

private struct URLSessionHTTPError: Error {
    let statusCode: Int
    let retryDelayMilliseconds: Int
}

/// API 端点定义
enum APIEndpoint {
    static let baseURL = "https://app-api.pixiv.net"
    static let webBaseURL = "https://www.pixiv.net"
    static let ajaxBaseURL = "https://www.pixiv.net/ajax"
    static let oauthURL = "https://oauth.secure.pixiv.net"

    // 认证相关
    static let login = "/auth/token"
    static let authToken = "/auth/token"
    static let refreshToken = "/auth/token"

    // 推荐相关
    static let recommendIllusts = "/v1/illust/recommended"
    static let recommendManga = "/v1/manga/recommended"
    static let recommendNovels = "/v1/novel/recommended"

    // 用户相关
    static let userDetail = "/v1/user/detail"
    static let userIllusts = "/v1/user/illusts"
    static let userNovels = "/v1/user/novels"
    static let userRecommended = "/v1/user/recommended"

    // 插画相关
    static let illustDetail = "/v1/illust/detail"
    static let illustComments = "/v1/illust/comments"

    // 关注相关
    static let followIllusts = "/v2/illust/follow"
    static let userBookmarksIllust = "/v1/user/bookmarks/illust"
    static let userFollowing = "/v1/user/following"
    static let illustBookmarkDetail = "/v1/illust/bookmark/detail"

    // 搜索相关
    static let searchIllust = "/v1/search/illust"
    static let autoWords = "/v1/search/autocomplete"

    // 收藏相关
    static let bookmarkAdd = "/v2/illust/bookmark/add"
    static let bookmarkDelete = "/v1/illust/bookmark/delete"
}

/// 错误响应模型（用于解析 400 错误）
struct ErrorMessageResponse: Decodable {
    let error: ErrorResponse

    struct ErrorResponse: Decodable {
        let message: String?
        let userMessage: String?
        let reason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case userMessage = "user_message"
            case reason
        }
    }
}
