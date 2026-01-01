import Foundation

/// 网络请求的基础配置
final class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession
    private var isRefreshing = false
    private var refreshTask: Task<Void, Never>? = nil

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

    /// 发送 GET 请求
    func get<T: Decodable>(
        from url: URL,
        headers: [String: String] = [:],
        responseType: T.Type,
        isLongContent: Bool = false
    ) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return try await perform(request, responseType: responseType, isLongContent: isLongContent)
    }

    /// 发送 POST 请求
    func post<T: Decodable>(
        to url: URL,
        body: Data? = nil,
        headers: [String: String] = [:],
        responseType: T.Type,
        isLongContent: Bool = false
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
        isLongContent: Bool = false,
        retryCount: Int = 0
    ) async throws -> T {
        debugPrintRequest(request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        debugPrintResponse(httpResponse, data: data, isLongContent: isLongContent)

        if (200...299).contains(httpResponse.statusCode) {
            return try decodeResponse(data: data, responseType: responseType)
        }

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

    /// 刷新 token（如果需要）
    private func refreshTokenIfNeeded() async throws {
        if isRefreshing {
            if let task = refreshTask {
                await task.value
            }
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        guard let refreshToken = AccountStore.shared.currentAccount?.refreshToken else {
            #if DEBUG
            print("[Token] 无 refreshToken，无法刷新")
            #endif
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
            }
        }

        await refreshTask?.value
    }

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
            print("[Network Debug] ==========")
            print("[Network Debug] 请求 URL: \(request.url?.absoluteString ?? "未知")")
            print("[Network Debug] 请求方法: \(request.httpMethod ?? "GET")")
            print("[Network Debug] 请求头: \(request.allHTTPHeaderFields ?? [:])")

            if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
                print("[Network Debug] 请求体: \(bodyString)")
            }
            print("[Network Debug] ==========")
        #endif
    }

    /// 调试：打印响应信息
    private func debugPrintResponse(_ response: HTTPURLResponse, data: Data, isLongContent: Bool = false) {
        #if DEBUG
            print("[Network Debug] ==========")
            print("[Network Debug] 响应状态码: \(response.statusCode)")
            print("[Network Debug] 响应头: \(response.allHeaderFields)")

            if isLongContent {
                print("[Network Debug] 响应体: (内容过长，跳过完整输出)")
                if let preview = String(data: data, encoding: .utf8) {
                    let previewLength = 500
                    let endIndex = min(preview.count, previewLength)
                    let previewString = String(preview.prefix(endIndex))
                    print("[Network Debug] 响应体预览: \(previewString)...")
                }
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[Network Debug] 响应体: \(responseString)")
                } else {
                    print("[Network Debug] 响应体: (二进制数据，大小 \(data.count) 字节)")
                }
            }
            print("[Network Debug] ==========")
        #endif
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
