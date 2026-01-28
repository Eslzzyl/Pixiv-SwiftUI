import Foundation

final class MangaAPI {
    private let client = NetworkClient.shared
    private let authHeaders: [String: String]

    init(authHeaders: [String: String]) {
        self.authHeaders = authHeaders
    }

    func getRecommendedManga(offset: Int = 0, limit: Int = 30) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.recommendManga)
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

    func getRecommendedMangaNoLogin(offset: Int = 0, limit: Int = 30) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/illust/recommended-nologin")
        components?.queryItems = [
            URLQueryItem(name: "content_type", value: "manga"),
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

    func getWatchlistManga() async throws -> (series: [MangaSeries], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/watchlist/manga")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_ios"),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let series: [MangaSeries]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case series
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return (response.series, response.nextUrl)
    }

    func addMangaSeries(seriesId: Int) async throws {
        let components = URLComponents(string: APIEndpoint.baseURL + "/v1/watchlist/manga/add")
        let body = "series_id=\(seriesId)"
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: body.data(using: .utf8),
            headers: headers,
            responseType: EmptyResponse.self
        )
    }

    func removeMangaSeries(seriesId: Int) async throws {
        let components = URLComponents(string: APIEndpoint.baseURL + "/v1/watchlist/manga/delete")
        let body = "series_id=\(seriesId)"
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        struct EmptyResponse: Decodable {}
        _ = try await client.post(
            to: url,
            body: body.data(using: .utf8),
            headers: headers,
            responseType: EmptyResponse.self
        )
    }

    func getMangaSeriesByURL(_ urlString: String) async throws -> (series: [MangaSeries], nextUrl: String?) {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let series: [MangaSeries]
            let nextUrl: String?

            enum CodingKeys: String, CodingKey {
                case series
                case nextUrl = "next_url"
            }
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: Response.self
        )

        return (response.series, response.nextUrl)
    }
}
