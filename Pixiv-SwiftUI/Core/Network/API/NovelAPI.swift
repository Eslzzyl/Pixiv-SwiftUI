import Foundation

/// 小说相关 API
final class NovelAPI {
    private let client = NetworkClient.shared
    private let authHeaders: [String: String]
    
    init(authHeaders: [String: String]) {
        self.authHeaders = authHeaders
    }
    
    /// 获取推荐小说
    func getRecommendedNovels(offset: Int = 0) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/recommended")
        components?.queryItems = [
            URLQueryItem(name: "include_privacy_policy", value: "true"),
            URLQueryItem(name: "filter", value: "for_ios"),
            URLQueryItem(name: "include_ranking_novels", value: "true"),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        return try await client.get(from: url, headers: authHeaders, responseType: NovelResponse.self)
    }
    
    /// 获取关注用户的新作
    func getFollowingNovels(restrict: String = "public", offset: Int = 0) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/follow")
        components?.queryItems = [
            URLQueryItem(name: "restrict", value: restrict),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        return try await client.get(from: url, headers: authHeaders, responseType: NovelResponse.self)
    }
    
    /// 获取用户收藏的小说
    func getUserBookmarkNovels(userId: Int, restrict: String = "public", offset: Int = 0) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/user/bookmarks/novel")
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: String(userId)),
            URLQueryItem(name: "restrict", value: restrict),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        return try await client.get(from: url, headers: authHeaders, responseType: NovelResponse.self)
    }
    
    /// 获取小说详情
    func getNovelDetail(novelId: Int) async throws -> Novel {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/novel/detail")
        components?.queryItems = [
            URLQueryItem(name: "novel_id", value: String(novelId)),
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        struct Response: Decodable {
            let novel: Novel
        }
        
        let response = try await client.get(from: url, headers: authHeaders, responseType: Response.self)
        return response.novel
    }
    
    /// 收藏小说
    func bookmarkNovel(novelId: Int, restrict: String = "public") async throws {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/novel/bookmark/add")
        let body = "novel_id=\(novelId)&restrict=\(restrict)"
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        
        _ = try await client.post(
            to: url,
            body: body.data(using: .utf8),
            headers: headers,
            responseType: EmptyResponse.self
        )
    }
    
    /// 取消收藏
    func unbookmarkNovel(novelId: Int) async throws {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/bookmark/delete")
        let body = "novel_id=\(novelId)"
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"
        
        _ = try await client.post(
            to: url,
            body: body.data(using: .utf8),
            headers: headers,
            responseType: EmptyResponse.self
        )
    }
    
    /// 通过 URL 获取小说列表（用于分页）
    func getNovelsByURL(_ urlString: String) async throws -> NovelResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }
        
        return try await client.get(from: url, headers: authHeaders, responseType: NovelResponse.self)
    }
    
    /// 获取小说评论
    func getNovelComments(novelId: Int) async throws -> CommentResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v3/novel/comments")
        components?.queryItems = [
            URLQueryItem(name: "novel_id", value: String(novelId)),
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        return try await client.get(from: url, headers: authHeaders, responseType: CommentResponse.self)
    }
}

/// 空响应（用于不需要返回内容的请求）
private struct EmptyResponse: Decodable {}
