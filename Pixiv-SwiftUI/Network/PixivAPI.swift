import Foundation

/// Pixiv API 服务
final class PixivAPI {
    static let shared = PixivAPI()

    private let client = NetworkClient.shared
    private var accessToken: String?

    /// 设置访问令牌
    func setAccessToken(_ token: String) {
        self.accessToken = token
    }

    /// 获取授权请求头
    private var authHeaders: [String: String] {
        var headers = [String: String]()
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        headers["Accept"] = "application/json"
        headers["Content-Type"] = "application/json"
        return headers
    }

    // MARK: - 认证相关

    /// 使用刷新令牌登录
    func loginWithRefreshToken(_ refreshToken: String) async throws -> (
        accessToken: String, user: User
    ) {
        // 使用 OAuth 服务器端点
        let url = URL(string: APIEndpoint.oauthURL + "/auth/token")!

        var body = [String: String]()
        // 使用官方 Pixiv Android 客户端的 refresh token 凭证（与 PixEz flutter 项目一致）
        body["client_id"] = "MOBrBDS8blbauoSck0ZfDbtuzpyT"
        body["client_secret"] = "lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj"
        body["grant_type"] = "refresh_token"
        body["refresh_token"] = refreshToken
        body["include_policy"] = "true"

        // 使用 form-urlencoded 格式（不是 JSON）
        // 使用 URLComponents 正确编码，保留下划线不编码
        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = components.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct AuthResponse: Decodable {
            let accessToken: String
            let user: User

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case user
            }
        }

        let response = try await client.post(
            to: url,
            body: formEncodedData,
            headers: ["Content-Type": "application/x-www-form-urlencoded"],
            responseType: AuthResponse.self
        )

        // 设置访问令牌
        self.accessToken = response.accessToken

        return (response.accessToken, response.user)
    }

    // MARK: - 推荐相关

    /// 获取推荐插画
    func getRecommendedIllusts(
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.recommendIllusts)
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "include_ranking_label", value: "true"),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [Illusts]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self,
            isLongContent: true
        )

        return response.illusts
    }

    /// 获取排行榜插画
    func getRankingIllusts(
        mode: String = "day",
        date: String? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/illust/ranking")
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        if let date = date {
            components?.queryItems?.append(URLQueryItem(name: "date", value: date))
        }

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [Illusts]
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.illusts
    }

    // MARK: - 插画相关

    /// 获取插画详情
    func getIllustDetail(illustId: Int) async throws -> Illusts {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.illustDetail)
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illust: Illusts
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.illust
    }

    /// 获取相关插画
    func getRelatedIllusts(
        illustId: Int,
        limit: Int = 30
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/illust/related")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [Illusts]
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.illusts
    }

    // MARK: - 用户相关

    /// 获取用户详情
    func getUserDetail(userId: String) async throws -> User {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.userDetail)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let user: User
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.user
    }

    /// 获取用户作品列表
    func getUserIllusts(
        userId: String,
        type: String = "illust",
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.userIllusts)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [Illusts]
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.illusts
    }

    // MARK: - 收藏相关

    /// 添加书签（收藏）
    func addBookmark(
        illustId: Int,
        isPrivate: Bool = false,
        tags: [String]? = nil
    ) async throws {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.bookmarkAdd)

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var body = [String: Any]()
        body["illust_id"] = illustId
        body["restrict"] = isPrivate ? "private" : "public"

        if let tags = tags {
            body["tags"] = tags
        }

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        struct Response: Decodable {}

        _ = try await client.post(
            to: url,
            body: jsonData,
            headers: authHeaders,
            responseType: Response.self
        )
    }

    /// 删除书签
    func deleteBookmark(illustId: Int) async throws {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.bookmarkAdd)
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {}

        _ = try await client.post(
            to: url,
            headers: authHeaders,
            responseType: Response.self
        )
    }

    // MARK: - 搜索相关

    /// 搜索插画
    func searchIllusts(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.searchIllust)
        components?.queryItems = [
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "search_target", value: searchTarget),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let illusts: [Illusts]
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.illusts
    }

    /// 获取搜索建议
    func getSearchAutocomplete(word: String) async throws -> [String] {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.autoWords)
        components?.queryItems = [
            URLQueryItem(name: "word", value: word)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let candidates: [Candidate]

            struct Candidate: Decodable {
                let tag_name: String
            }
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.candidates.map { $0.tag_name }
    }
}
