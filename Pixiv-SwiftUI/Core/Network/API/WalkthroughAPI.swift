import Foundation
import SwiftUI

/// 公共插画 API（无需认证）
struct WalkthroughAPI {
    private let client = NetworkClient.shared

    /// 获取公共插画（用于游客模式首页）
    func getWalkthroughIllusts(
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/walkthrough/illusts")
        components?.queryItems = [
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
            headers: [:],
            responseType: Response.self,
            isLongContent: true
        )

        return (response.illusts, response.nextUrl)
    }

    /// 通过 URL 获取公共插画列表（用于分页）
    func getWalkthroughIllustsByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
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
            headers: [:],
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 获取热门标签（公开 API，无需认证）
    func getIllustTrendTags() async throws -> [TrendTag] {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/trending-tags/illust")
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android")
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {
            let trendTags: [TrendTag]

            enum CodingKeys: String, CodingKey {
                case trendTags = "trend_tags"
            }
        }

        let response = try await client.get(
            from: url,
            headers: [:],
            responseType: Response.self
        )

        return response.trendTags
    }

    /// 获取插画排行榜（公开 API，无需认证）
    func getIllustRanking(
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
            headers: [:],
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 通过 URL 获取排行榜插画列表（用于分页，公开 API，无需认证）
    func getIllustRankingByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
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
            headers: [:],
            responseType: Response.self
        )

        return (response.illusts, response.nextUrl)
    }
}
