import Foundation

/// 搜索相关API
final class SearchAPI {
    private let client = NetworkClient.shared
    private let authHeaders: [String: String]

    init(authHeaders: [String: String]) {
        self.authHeaders = authHeaders
    }

    /// 获取搜索建议
    func getSearchAutoCompleteKeywords(word: String) async throws -> [SearchTag] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/search/autocomplete")
        components?.queryItems = [
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "word", value: word)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: SearchAutoCompleteResponse.self
        )

        return response.tags
    }

    /// 搜索插画
    func getSearchIllust(
        word: String,
        sort: String = "date_desc",
        searchTarget: String = "partial_match_for_tags",
        offset: Int = 0
    ) async throws -> [Illusts] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/illust")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "search_target", value: searchTarget),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: IllustsResponse.self
        )

        return response.illusts
    }

    /// 搜索用户
    func getSearchUser(word: String, offset: Int = 0) async throws -> [UserPreviews] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/user")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "offset", value: String(offset))
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: UserPreviewsResponse.self
        )

        return response.userPreviews
    }

    /// 获取热门标签
    func getIllustTrendTags() async throws -> [TrendTag] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/trending-tags/illust")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android")
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: TrendingTagsResponse.self
        )

        return response.trendTags
    }

    /// 搜索插画（新版本）
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
                let tagName: String

                enum CodingKeys: String, CodingKey {
                    case tagName = "tag_name"
                }
            }
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.candidates.map { $0.tagName }
    }

    /// 搜索小说
    func searchNovels(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Novel] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/search/novel")
        components?.queryItems = [
            URLQueryItem(name: "word", value: word),
            URLQueryItem(name: "search_target", value: searchTarget),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "merge_plain_keyword_results", value: "true"),
            URLQueryItem(name: "include_translated_tag_results", value: "true"),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let novels: [Novel]
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return response.novels
    }
}
