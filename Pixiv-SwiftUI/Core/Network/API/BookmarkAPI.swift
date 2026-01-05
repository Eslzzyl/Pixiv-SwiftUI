import Foundation

/// 收藏相关API
final class BookmarkAPI {
    private let client = NetworkClient.shared
    private let authHeaders: [String: String]

    init(authHeaders: [String: String]) {
        self.authHeaders = authHeaders
    }

    /// 添加书签（收藏）
    func addBookmark(
        illustId: Int,
        isPrivate: Bool = false,
        tags: [String]? = nil
    ) async throws {
        let components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.bookmarkAdd)

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var body = [String: String]()
        body["illust_id"] = String(illustId)
        body["restrict"] = isPrivate ? "private" : "public"

        if let tags = tags, !tags.isEmpty {
            body["tags[]"] = tags.joined(separator: " ")
        }

        var formComponents = URLComponents()
        formComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = formComponents.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {}

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: headers,
            responseType: Response.self
        )
    }

    /// 删除书签
    func deleteBookmark(illustId: Int) async throws {
        let components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.bookmarkDelete)

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var body = [String: String]()
        body["illust_id"] = String(illustId)

        var formComponents = URLComponents()
        formComponents.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = formComponents.percentEncodedQuery ?? ""

        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }

        struct Response: Decodable {}

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: headers,
            responseType: Response.self
        )
    }
}