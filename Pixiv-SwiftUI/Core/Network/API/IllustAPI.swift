import Foundation

/// 插画相关API
final class IllustAPI {
    private let client = NetworkClient.shared
    private let authHeaders: [String: String]

    init(authHeaders: [String: String]) {
        self.authHeaders = authHeaders
    }

    /// 获取推荐插画
    func getRecommendedIllusts(
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.recommendIllusts)
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "include_ranking_label", value: "true"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
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

        return (response.illusts, response.nextUrl)
    }

    /// 获取排行榜插画
    func getRankingIllusts(
        mode: String = "day",
        date: String? = nil,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
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
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case illusts
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 通过 URL 获取排行榜插画列表（用于分页）
    func getRankingIllustsByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
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
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }

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
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/illust/related")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "filter", value: "for_ios"),
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
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 通过 URL 获取插画列表（用于分页）
    func getIllustsByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
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
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 获取插画评论
    func getIllustComments(illustId: Int) async throws -> CommentResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v3/illust/comments")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: CommentResponse.self
        )

        return response
    }

    /// 获取评论的回复列表
    func getIllustCommentsReplies(commentId: Int) async throws -> CommentResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/illust/comment/replies")
        components?.queryItems = [
            URLQueryItem(name: "comment_id", value: String(commentId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: CommentResponse.self
        )

        return response
    }

    /// 获取动图元数据
    func getUgoiraMetadata(illustId: Int) async throws -> UgoiraMetadataResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/ugoira/metadata")
        components?.queryItems = [
            URLQueryItem(name: "illust_id", value: String(illustId))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: UgoiraMetadataResponse.self
        )

        return response
    }
}
