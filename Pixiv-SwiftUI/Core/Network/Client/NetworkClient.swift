import Foundation
import Network

/// 网络请求的基础配置
final class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private var isRefreshing = false
    private var refreshTask: Task<Void, Error>?

    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "PixivIOSApp/6.7.1 (iOS 14.6; iPhone10,3) AppleWebKit/605.1.15",
            "Accept-Language": "zh-CN",
            "Accept-Encoding": "gzip, deflate",
        ]
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)
    }

    /// 是否使用直连模式
    var useDirectConnection: Bool {
        NetworkModeStore.shared.useDirectConnection
    }

    /// 发送 GET 请求
    func get<T: Decodable>(
        from url: URL,
        headers: [String: String] = [:],
        responseType: T.Type,
        isLongContent: Bool = false
    ) async throws -> T {
        if useDirectConnection {
            return try await directGet(from: url, headers: headers, responseType: responseType, isLongContent: isLongContent)
        }
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
        if useDirectConnection {
            return try await directPost(to: url, body: body, headers: headers, responseType: responseType, isLongContent: isLongContent)
        }
        return try await urlSessionPost(to: url, body: body, headers: headers, responseType: responseType, isLongContent: isLongContent)
    }

    /// 下载文件
    func download(
        from url: URL,
        headers: [String: String] = [:],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        if useDirectConnection {
            return try await directDownload(from: url, headers: headers, onProgress: onProgress)
        }
        return try await urlSessionDownload(from: url, headers: headers, onProgress: onProgress)
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
        debugPrintRequest(request)

        let (data, response) = try await Task.detached {
            try await self.session.data(for: request)
        }.value

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if (200...299).contains(httpResponse.statusCode) {
            let decoded = try decodeResponse(data: data, responseType: responseType)
            debugPrintSuccess(request, data: data)
            return decoded
        }

        debugPrintResponse(httpResponse, data: data, isLongContent: isLongContent)

        if httpResponse.statusCode == 400 {
            if let errorMessage = try? decodeErrorMessage(data: data),
               errorMessage.error.message?.contains("OAuth") == true {
                #if DEBUG
                print("[Token] 检测到 OAuth 错误，尝试刷新 token...")
                #endif
                try await refreshTokenIfNeeded()

                #if DEBUG
                print("[Token] Token 刷新成功，重试请求")
                #endif

                if retryCount < 1 {
                    var newRequest = request
                    if let newAccessToken = AccountStore.shared.currentAccount?.accessToken {
                        newRequest.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")
                    }
                    return try await perform(newRequest, responseType: responseType, isLongContent: isLongContent, retryCount: retryCount + 1)
                }
            }
        }

        throw NetworkError.httpError(httpResponse.statusCode)
    }

    // MARK: - 直连实现

    private func directGet<T: Decodable>(
        from url: URL,
        headers: [String: String],
        responseType: T.Type,
        isLongContent: Bool = false,
        retryCount: Int = 0
    ) async throws -> T {
        guard let host = url.host else {
            throw NetworkError.invalidResponse
        }

        let endpoint = endpointForHost(host)
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let fullPath = path + query

        let (data, httpResponse) = try await DirectConnection.shared.request(
            endpoint: endpoint,
            path: fullPath,
            method: "GET",
            headers: headers,
            timeout: isLongContent ? 60 : nil
        )

        if (200...299).contains(httpResponse.statusCode) {
            return try decodeResponse(data: data, responseType: responseType)
        }

        if httpResponse.statusCode == 400 {
            if let errorMessage = try? decodeErrorMessage(data: data),
               errorMessage.error.message?.contains("OAuth") == true {
                #if DEBUG
                print("[Token][直连] 检测到 OAuth 错误，尝试刷新 token...")
                #endif
                try await refreshTokenIfNeeded()

                #if DEBUG
                print("[Token][直连] Token 刷新成功，重试请求")
                #endif

                if retryCount < 1 {
                    var newHeaders = headers
                    if let newAccessToken = AccountStore.shared.currentAccount?.accessToken {
                        newHeaders["Authorization"] = "Bearer \(newAccessToken)"
                    }
                    return try await directGet(from: url, headers: newHeaders, responseType: responseType, isLongContent: isLongContent, retryCount: retryCount + 1)
                }
            }
        }

        throw NetworkError.httpError(httpResponse.statusCode)
    }

    private func directPost<T: Decodable>(
        to url: URL,
        body: Data?,
        headers: [String: String],
        responseType: T.Type,
        isLongContent: Bool = false,
        retryCount: Int = 0
    ) async throws -> T {
        guard let host = url.host else {
            throw NetworkError.invalidResponse
        }

        let endpoint = endpointForHost(host)
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let fullPath = path + query

        var allHeaders = headers
        if body != nil {
            allHeaders["Content-Length"] = String(body?.count ?? 0)
        }

        let (data, httpResponse) = try await DirectConnection.shared.request(
            endpoint: endpoint,
            path: fullPath,
            method: "POST",
            headers: allHeaders,
            body: body,
            timeout: isLongContent ? 60 : nil
        )

        if (200...299).contains(httpResponse.statusCode) {
            return try decodeResponse(data: data, responseType: responseType)
        }

        if httpResponse.statusCode == 400 {
            if let errorMessage = try? decodeErrorMessage(data: data),
               errorMessage.error.message?.contains("OAuth") == true {
                #if DEBUG
                print("[Token][直连] 检测到 OAuth 错误，尝试刷新 token...")
                #endif
                try await refreshTokenIfNeeded()

                #if DEBUG
                print("[Token][直连] Token 刷新成功，重试请求")
                #endif

                if retryCount < 1 {
                    var newHeaders = headers
                    if let newAccessToken = AccountStore.shared.currentAccount?.accessToken {
                        newHeaders["Authorization"] = "Bearer \(newAccessToken)"
                    }
                    return try await directPost(to: url, body: body, headers: newHeaders, responseType: responseType, isLongContent: isLongContent, retryCount: retryCount + 1)
                }
            }
        }

        throw NetworkError.httpError(httpResponse.statusCode)
    }

    private func urlSessionDownload(
        from url: URL,
        headers: [String: String],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // 使用 Task.detached 避免阻塞主线程
        let (data, response) = try await Task.detached {
            try await self.session.data(for: request)
        }.value

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL)

        // 简单模拟进度，因为 data(for:) 不支持进度回调
        onProgress?(1.0)

        return (tempURL, response)
    }

    private func directDownload(
        from url: URL,
        headers: [String: String],
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> (URL, URLResponse) {
        guard let host = url.host else {
            throw NetworkError.invalidResponse
        }

        let endpoint = endpointForHost(host)
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let fullPath = path + query

        let (data, httpResponse) = try await DirectConnection.shared.request(
            endpoint: endpoint,
            path: fullPath,
            method: "GET",
            headers: headers,
            timeout: 120, // 下载文件使用 120 秒超时
            onProgress: { received, total in
                if let total = total, total > 0 {
                    onProgress?(Double(received) / Double(total))
                } else {
                    // 如果无法获取总大小，则显示一个伪进度或每 1MB 增加一点
                    let mb = Double(received) / (1024.0 * 1024.0)
                    let pseudoProgress = (1.0 - exp(-mb/2.0)) * 0.9 // 渐近 0.9
                    onProgress?(pseudoProgress)
                }
            }
        )

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tempURL)

        onProgress?(1.0)

        return (tempURL, httpResponse)
    }

    private func endpointForHost(_ host: String) -> PixivEndpoint {
        if host.contains("oauth.secure.pixiv.net") || host.contains("oauth.pixiv.net") {
            return .oauth
        } else if host.contains("app-api.pixiv.net") || host.contains("api.pixiv.net") {
            return .api
        } else if host.contains("accounts.pixiv.net") {
            return .accounts
        } else {
            return .image
        }
    }

    // MARK: - Token 刷新

    /// 刷新 token（如果需要）
    private func refreshTokenIfNeeded() async throws {
        if isRefreshing {
            if let task = refreshTask {
                try await task.value
            }
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = AccountStore.shared.currentAccount?.refreshToken else {
            #if DEBUG
            print("[Token] 无 refreshToken，无法刷新")
            #endif
            notifyTokenRefreshFailed(message: "无登录凭证，请重新登录")
            return
        }

        refreshTask = Task {
            do {
                let (newAccessToken, newRefreshToken, _) = try await PixivAPI.shared.refreshAccessToken(refreshToken)

                if let currentAccount = AccountStore.shared.currentAccount {
                    currentAccount.accessToken = newAccessToken
                    currentAccount.refreshToken = newRefreshToken
                    try AccountStore.shared.updateAccount(currentAccount)
                }

                PixivAPI.shared.setAccessToken(newAccessToken)

                #if DEBUG
                print("[Token] Token 刷新成功，已更新本地存储")
                #endif
            } catch {
                #if DEBUG
                print("[Token] Token 刷新失败: \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    AccountStore.shared.tokenRefreshErrorMessage = error.localizedDescription
                    AccountStore.shared.showTokenRefreshFailedToast = true
                }
                throw error
            }
        }

        try await refreshTask?.value
    }

    private func notifyTokenRefreshFailed(message: String) {
        Task { @MainActor in
            AccountStore.shared.tokenRefreshErrorMessage = message
            AccountStore.shared.showTokenRefreshFailedToast = true
        }
    }

    // MARK: - 工具方法

    /// 解码错误响应
    private func decodeErrorMessage(data: Data) throws -> ErrorMessageResponse? {
        let decoder = JSONDecoder()
        return try? decoder.decode(ErrorMessageResponse.self, from: data)
    }

    /// 解码正常响应
    private func decodeResponse<T: Decodable>(data: Data, responseType: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(responseType, from: data)
    }

    /// 调试：打印请求信息
    private func debugPrintRequest(_ request: URLRequest) {
        #if DEBUG
            let url = request.url?.absoluteString ?? "未知"
            let method = request.httpMethod ?? "GET"
            let mode = useDirectConnection ? "[直连]" : "[标准]"
            print("\(mode) [Network] \(method) \(url)")
        #endif
    }

    /// 调试：打印成功信息
    private func debugPrintSuccess(_ request: URLRequest, data: Data) {
        #if DEBUG
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    if let illusts = json["illusts"] as? [Any] {
                        print("[Network] 成功获取 \(illusts.count) 个插画")
                    } else if let userPreviews = json["user_previews"] as? [Any] {
                        print("[Network] 成功获取 \(userPreviews.count) 个用户预览")
                    } else {
                        print("[Network] 请求成功")
                    }
                } else {
                    print("[Network] 请求成功")
                }
            } catch {
                print("[Network] 请求成功")
            }
        #endif
    }

    /// 调试：打印响应信息（仅失败时）
    private func debugPrintResponse(_ response: HTTPURLResponse, data: Data, isLongContent: Bool = false) {
        #if DEBUG
            print("[Network] 请求失败，状态码: \(response.statusCode)")
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("[Network] 错误详情: \(responseString)")
            }
        #endif
    }

    /// 获取原始响应文本（用于 HTML 响应）
    func getRaw(url: URL, headers: [String: String] = [:]) async throws -> String {
        if useDirectConnection {
            return try await directGetRaw(url: url, headers: headers)
        }
        return try await urlSessionGetRaw(url: url, headers: headers)
    }

    /// 直连模式获取原始响应文本
    private func directGetRaw(url: URL, headers: [String: String]) async throws -> String {
        guard let host = url.host else {
            throw NetworkError.invalidResponse
        }

        let endpoint = endpointForHost(host)
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let fullPath = path + query

        let (data, httpResponse) = try await DirectConnection.shared.request(
            endpoint: endpoint,
            path: fullPath,
            method: "GET",
            headers: headers
        )

        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("[Network][直连] 请求失败，状态码: \(httpResponse.statusCode)")
            #endif
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }

        return text
    }

    /// URLSession 模式获取原始响应文本
    private func urlSessionGetRaw(url: URL, headers: [String: String]) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        print("[Network] GET \(url.absoluteString)")
        #endif

        let (data, response) = try await Task.detached {
            try await self.session.data(for: request)
        }.value

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            #if DEBUG
            print("[Network] 请求失败，状态码: \(httpResponse.statusCode)")
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
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case connectionError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "无效的服务器响应"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .connectionError(let message):
            return "连接错误: \(message)"
        }
    }
}

/// API 端点定义
enum APIEndpoint {
    static let baseURL = "https://app-api.pixiv.net"
    static let webBaseURL = "https://www.pixiv.net"
    static let oauthURL = "https://oauth.secure.pixiv.net"

    // 认证相关
    static let login = "/auth/token"
    static let authToken = "/auth/token"
    static let refreshToken = "/auth/token"

    // 推荐相关
    static let recommendIllusts = "/v1/illust/recommended"
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
