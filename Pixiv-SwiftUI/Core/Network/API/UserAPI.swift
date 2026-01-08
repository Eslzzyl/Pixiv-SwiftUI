import Foundation

/// 用户相关API
final class UserAPI {
    private let client = NetworkClient.shared
    private let authHeaders: [String: String]

    init(authHeaders: [String: String]) {
        self.authHeaders = authHeaders
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

    /// 获取用户详情
    func getUserDetail(userId: String) async throws -> UserDetailResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/user/detail")
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "filter", value: "for_ios")
        ]
        
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }
        
        return try await client.get(
            from: url,
            headers: authHeaders,
            responseType: UserDetailResponse.self
        )
    }
    
    /// 关注用户
    func followUser(userId: String, restrict: String = "public") async throws {
        let url = URL(string: APIEndpoint.baseURL + "/v1/user/follow/add")!
        
        var body = [String: String]()
        body["user_id"] = userId
        body["restrict"] = restrict
        
        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = components.percentEncodedQuery ?? ""
        
        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }
        
        struct EmptyResponse: Decodable {}
        
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: authHeaders.merging(["Content-Type": "application/x-www-form-urlencoded"], uniquingKeysWith: { (_, new) in new }),
            responseType: EmptyResponse.self
        )
    }
    
    /// 取消关注用户
    func unfollowUser(userId: String) async throws {
        let url = URL(string: APIEndpoint.baseURL + "/v1/user/follow/delete")!
        
        var body = [String: String]()
        body["user_id"] = userId
        
        var components = URLComponents()
        components.queryItems = body.map { URLQueryItem(name: $0.key, value: $0.value) }
        let formData = components.percentEncodedQuery ?? ""
        
        guard let formEncodedData = formData.data(using: .utf8) else {
            throw NetworkError.invalidResponse
        }
        
        struct EmptyResponse: Decodable {}
        
        _ = try await client.post(
            to: url,
            body: formEncodedData,
            headers: authHeaders.merging(["Content-Type": "application/x-www-form-urlencoded"], uniquingKeysWith: { (_, new) in new }),
            responseType: EmptyResponse.self
        )
    }

    /// 获取关注者新作
    func getFollowIllusts(restrict: String = "public") async throws -> ([Illusts], String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.followIllusts)
        components?.queryItems = [
            URLQueryItem(name: "restrict", value: restrict)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: IllustsResponse.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 获取用户收藏
    func getUserBookmarksIllusts(userId: String, restrict: String = "public") async throws -> ([Illusts], String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.userBookmarksIllust)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "restrict", value: restrict)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: IllustsResponse.self
        )

        return (response.illusts, response.nextUrl)
    }

    /// 获取用户关注列表
    func getUserFollowing(userId: String, restrict: String = "public") async throws -> ([UserPreviews], String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.userFollowing)
        components?.queryItems = [
            URLQueryItem(name: "user_id", value: userId),
            URLQueryItem(name: "restrict", value: restrict)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: UserPreviewsResponse.self
        )

        return (response.userPreviews, response.nextUrl)
    }

    /// 获取推荐画师
    func getRecommendedUsers() async throws -> ([UserPreviews], String?) {
        var components = URLComponents(string: APIEndpoint.baseURL + APIEndpoint.userRecommended)
        components?.queryItems = [
            URLQueryItem(name: "filter", value: "for_android")
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response = try await client.get(
            from: url,
            headers: authHeaders,
            responseType: UserPreviewsResponse.self
        )

        return (response.userPreviews, response.nextUrl)
    }
}