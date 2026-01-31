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
    /// 注意：首次请求不要传递 offset 参数，否则会返回 400 错误
    func getFollowingNovels(restrict: String = "public", offset: Int? = nil) async throws -> NovelResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/follow")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "restrict", value: restrict),
        ]
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components?.queryItems = queryItems

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
        let components = URLComponents(string: APIEndpoint.baseURL + "/v2/novel/bookmark/add")
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
        let components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/bookmark/delete")
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

    /// 发送小说评论
    /// - Parameters:
    ///   - novelId: 小说ID
    ///   - comment: 评论内容（最多140字符）
    ///   - parentCommentId: 可选，父评论ID（回复评论时使用）
    func postNovelComment(novelId: Int, comment: String, parentCommentId: Int? = nil) async throws {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/comment/add")

        var bodyItems: [URLQueryItem] = [
            URLQueryItem(name: "novel_id", value: String(novelId)),
            URLQueryItem(name: "comment", value: comment),
        ]
        if let parentId = parentCommentId {
            bodyItems.append(URLQueryItem(name: "parent_comment_id", value: String(parentId)))
        }

        components?.queryItems = bodyItems

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        _ = try await client.post(
            to: url,
            body: components?.query?.data(using: .utf8),
            headers: headers,
            responseType: EmptyResponse.self
        )
    }

    /// 删除小说评论
    /// - Parameter commentId: 评论ID
    func deleteNovelComment(commentId: Int) async throws {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/comment/delete")

        let bodyItems: [URLQueryItem] = [
            URLQueryItem(name: "comment_id", value: String(commentId))
        ]

        components?.queryItems = bodyItems

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        _ = try await client.post(
            to: url,
            body: components?.query?.data(using: .utf8),
            headers: headers,
            responseType: EmptyResponse.self
        )
    }

    /// 获取小说系列详情
    func getNovelSeries(seriesId: Int) async throws -> NovelSeriesResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v2/novel/series")
        components?.queryItems = [
            URLQueryItem(name: "series_id", value: String(seriesId)),
            URLQueryItem(name: "filter", value: "for_ios"),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: authHeaders, responseType: NovelSeriesResponse.self)
    }

    /// 通过 URL 获取小说系列（用于分页）
    func getNovelSeriesByURL(_ urlString: String) async throws -> NovelSeriesResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: authHeaders, responseType: NovelSeriesResponse.self)
    }

    /// 获取小说正文内容（通过 webview API）
    func getNovelContent(novelId: Int) async throws -> NovelReaderContent {
        var components = URLComponents(string: APIEndpoint.baseURL + "/webview/v2/novel")
        components?.queryItems = [
            URLQueryItem(name: "id", value: String(novelId)),
            URLQueryItem(name: "viewer_version", value: "20221031_ai"),
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var headers = authHeaders
        headers["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        headers["Accept-Language"] = "zh-CN,zh;q=0.9,ja;q=0.8,en;q=0.7"

        print("[NovelAPI] 开始请求: \(url.absoluteString)")
        let responseText = try await client.getRaw(url: url, headers: headers)
        print("[NovelAPI] 响应长度: \(responseText.count) 字符")

        guard let novelStartRange = responseText.range(of: "novel:", options: .caseInsensitive) else {
            print("[NovelAPI] 无法找到 novel 标记")
            throw NetworkError.invalidResponse
        }

        let startIndex = novelStartRange.upperBound
        var jsonStartIndex = startIndex

        while jsonStartIndex < responseText.endIndex && responseText[jsonStartIndex].isWhitespace {
            jsonStartIndex = responseText.index(after: jsonStartIndex)
        }

        guard jsonStartIndex < responseText.endIndex && responseText[jsonStartIndex] == "{" else {
            print("[NovelAPI] novel 后面不是 { 字符")
            throw NetworkError.invalidResponse
        }

        var braceCount = 0
        var novelEndIndex: String.Index?

        for index in responseText.indices[jsonStartIndex...] {
            if responseText[index] == "{" {
                braceCount += 1
            } else if responseText[index] == "}" {
                braceCount -= 1
                if braceCount == 0 {
                    novelEndIndex = responseText.index(after: index)
                    break
                }
            }
        }

        guard let actualNovelEndIndex = novelEndIndex else {
            print("[NovelAPI] 无法找到 novel 对象的闭合括号")
            throw NetworkError.invalidResponse
        }

        let novelJsonString = String(responseText[jsonStartIndex..<actualNovelEndIndex])
        print("[NovelAPI] novel JSON 长度: \(novelJsonString.count) 字符")

        guard let novelJsonData = novelJsonString.data(using: .utf8) else {
            print("[NovelAPI] novel JSON 数据转换失败")
            throw NetworkError.invalidResponse
        }

        let decoder = JSONDecoder()
        do {
            let content = try decoder.decode(NovelReaderContent.self, from: novelJsonData)
            print("[NovelAPI] 解码成功, title: \(content.title), text长度: \(content.text.count)")
            return content
        } catch {
            print("[NovelAPI] 解码失败: \(error)")
            throw error
        }
    }

    /// 获取小说排行榜
    /// - Parameters:
    ///   - mode: 排行榜模式 (day/每日, day_male/男性向, day_female/女性向, week/每周)
    ///   - date: 可选日期，格式 yyyy-MM-dd，用于查看历史榜单
    ///   - offset: 分页偏移量
    /// - Returns: 排行榜响应，包含小说列表和下一页 URL
    func getNovelRanking(mode: String, date: String? = nil, offset: Int = 0) async throws -> NovelRankingResponse {
        var components = URLComponents(string: APIEndpoint.baseURL + "/v1/novel/ranking")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "filter", value: "for_ios"),
        ]
        if let date = date {
            queryItems.append(URLQueryItem(name: "date", value: date))
        }
        if offset > 0 {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: authHeaders, responseType: NovelRankingResponse.self)
    }

    /// 通过 URL 获取排行榜小说列表（用于分页）
    func getNovelRankingByURL(_ urlString: String) async throws -> NovelRankingResponse {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }

        return try await client.get(from: url, headers: authHeaders, responseType: NovelRankingResponse.self)
    }

    /// 删除小说
    /// - Parameter novelId: 小说ID
    func deleteNovel(novelId: Int) async throws {
        guard let url = URL(string: APIEndpoint.baseURL + "/v1/novel/delete") else {
            throw NetworkError.invalidResponse
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "novel_id", value: String(novelId))
        ]

        let body = components?.query?.data(using: .utf8)

        var headers = authHeaders
        headers["Content-Type"] = "application/x-www-form-urlencoded"

        _ = try await client.post(
            to: url,
            body: body,
            headers: headers,
            responseType: EmptyResponse.self
        )
    }
}

/// 空响应（用于不需要返回内容的请求）
private struct EmptyResponse: Decodable {}
