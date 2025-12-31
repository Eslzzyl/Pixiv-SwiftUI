import Foundation

/// 网络请求的基础配置
final class NetworkClient {
    static let shared = NetworkClient()

    private let session: URLSession

    private init() {
        // 配置 URLSession，包括自定义请求头和 DNS 配置
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

        // 添加自定义请求头
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
        isLongContent: Bool = false
    ) async throws -> T {
        // 调试：打印请求信息
        debugPrintRequest(request)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // 调试：打印响应信息
        debugPrintResponse(httpResponse, data: data, isLongContent: isLongContent)

        // 检查 HTTP 状态码
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }

        // 解码响应
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(responseType, from: data)
        } catch {
            #if DEBUG
            print("[Network Debug] 解码错误详情:")
            print("[Network Debug] 类型: \(T.self)")
            print("[Network Debug] 错误: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("[Network Debug] 缺失字段: \(key.stringValue)")
                    print("[Network Debug] 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("[Network Debug] 类型不匹配: 期望 \(type), 实际路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    print("[Network Debug] 值为空: 期望 \(type), 路径: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("[Network Debug] 数据损坏: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("[Network Debug] 未知解码错误")
                }
                if let preview = String(data: data, encoding: .utf8) {
                    let previewLength = 1000
                    let endIndex = min(preview.count, previewLength)
                    let previewString = String(preview.prefix(endIndex))
                    print("[Network Debug] 响应体预览: \(previewString)...")
                }
            }
            #endif
            throw NetworkError.decodingError(error)
        }
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
    static let illustBookmarkDetail = "/v1/illust/bookmark/detail"

    // 搜索相关
    static let searchIllust = "/v1/search/illust"
    static let autoWords = "/v1/search/autocomplete"

    // 收藏相关
    static let bookmarkAdd = "/v1/illust/bookmark/add"
    static let bookmarkDelete = "/v1/illust/bookmark/delete"
}
