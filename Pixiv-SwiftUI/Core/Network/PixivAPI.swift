import Foundation
import CryptoKit

/// Pixiv API 服务 - 重构后的协调器类
final class PixivAPI {
    static let shared = PixivAPI()

    private let authAPI = AuthAPI()
    private var searchAPI: SearchAPI?
    private var illustAPI: IllustAPI?
    private var userAPI: UserAPI?
    private var bookmarkAPI: BookmarkAPI?
    // MARK: - Public Properties
    
    private(set) var novelAPI: NovelAPI?
    
    /// 设置访问令牌并初始化其他API类
    func setAccessToken(_ token: String) {
        authAPI.setAccessToken(token)
        
        // 有了token后初始化其他API类
        let headers = getAuthHeaders(for: token)
        searchAPI = SearchAPI(authHeaders: headers)
        illustAPI = IllustAPI(authHeaders: headers)
        userAPI = UserAPI(authHeaders: headers)
        bookmarkAPI = BookmarkAPI(authHeaders: headers)
        novelAPI = NovelAPI(authHeaders: headers)
    }

    // MARK: - Private Helper Methods

    private let hashSalt = "28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c"

    private var baseHeaders: [String: String] {
        var headers = [String: String]()
        let time = getIsoDate()
        headers["X-Client-Time"] = time
        headers["X-Client-Hash"] = getHash(time + hashSalt)
        headers["App-OS"] = "ios"
        headers["App-OS-Version"] = "14.6"
        headers["App-Version"] = "7.13.3"
        headers["Accept-Language"] = "zh-CN"
        return headers
    }

    private func getAuthHeaders(for token: String) -> [String: String] {
        var headers = baseHeaders
        headers["Authorization"] = "Bearer \(token)"
        headers["Accept"] = "application/json"
        headers["Content-Type"] = "application/json"
        return headers
    }
    
    private func getIsoDate() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
    
    private func getHash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02hhx", $0) }.joined()
    }

    // MARK: - 认证相关
    
    /// 使用 code 登录
    func loginWithCode(_ code: String, codeVerifier: String) async throws -> (
        accessToken: String, refreshToken: String, user: User
    ) {
        return try await authAPI.loginWithCode(code, codeVerifier: codeVerifier)
    }

    /// 使用 refresh_token 登录
    func loginWithRefreshToken(_ refreshToken: String) async throws -> (
        accessToken: String, user: User
    ) {
        return try await authAPI.loginWithRefreshToken(refreshToken)
    }

    /// 刷新 accessToken
    func refreshAccessToken(_ refreshToken: String) async throws -> (
        accessToken: String, refreshToken: String, user: User
    ) {
        return try await authAPI.refreshAccessToken(refreshToken)
    }

    // MARK: - 搜索相关
    
    /// 获取搜索建议
    func getSearchAutoCompleteKeywords(word: String) async throws -> [SearchTag] {
        guard let api = searchAPI else { throw NetworkError.invalidResponse }
        return try await api.getSearchAutoCompleteKeywords(word: word)
    }
    
    /// 搜索插画
    func getSearchIllust(
        word: String,
        sort: String = "date_desc",
        searchTarget: String = "partial_match_for_tags",
        offset: Int = 0
    ) async throws -> [Illusts] {
        guard let api = searchAPI else { throw NetworkError.invalidResponse }
        return try await api.getSearchIllust(word: word, sort: sort, searchTarget: searchTarget, offset: offset)
    }
    
    /// 搜索用户
    func getSearchUser(word: String, offset: Int = 0) async throws -> [UserPreviews] {
        guard let api = searchAPI else { throw NetworkError.invalidResponse }
        return try await api.getSearchUser(word: word, offset: offset)
    }
    
    /// 获取热门标签
    func getIllustTrendTags() async throws -> [TrendTag] {
        guard let api = searchAPI else { throw NetworkError.invalidResponse }
        return try await api.getIllustTrendTags()
    }

    /// 搜索插画
    func searchIllusts(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Illusts] {
        guard let api = searchAPI else { throw NetworkError.invalidResponse }
        return try await api.searchIllusts(
            word: word,
            searchTarget: searchTarget,
            sort: sort,
            offset: offset,
            limit: limit
        )
    }

    // MARK: - 插画相关
    
    /// 获取推荐插画
    func getRecommendedIllusts(
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getRecommendedIllusts(offset: offset, limit: limit)
    }

    /// 获取插画详情
    func getIllustDetail(illustId: Int) async throws -> Illusts {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getIllustDetail(illustId: illustId)
    }

    /// 获取相关插画
    func getRelatedIllusts(
        illustId: Int,
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getRelatedIllusts(illustId: illustId, offset: offset, limit: limit)
    }

    /// 通过 URL 获取插画列表（用于分页）
    func getIllustsByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getIllustsByURL(urlString)
    }

    /// 获取插画评论
    func getIllustComments(illustId: Int) async throws -> CommentResponse {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getIllustComments(illustId: illustId)
    }

    /// 获取评论的回复列表
    func getIllustCommentsReplies(commentId: Int) async throws -> CommentResponse {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getIllustCommentsReplies(commentId: commentId)
    }

    /// 获取动图元数据
    func getUgoiraMetadata(illustId: Int) async throws -> UgoiraMetadataResponse {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getUgoiraMetadata(illustId: illustId)
    }

    /// 获取插画排行榜
    func getIllustRanking(mode: String, date: String? = nil, offset: Int = 0) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getRankingIllusts(mode: mode, date: date, offset: offset)
    }

    /// 通过 URL 获取排行榜插画列表（用于分页）
    func getIllustRankingByURL(_ urlString: String) async throws -> (illusts: [Illusts], nextUrl: String?) {
        guard let api = illustAPI else { throw NetworkError.invalidResponse }
        return try await api.getRankingIllustsByURL(urlString)
    }

    // MARK: - 用户相关
    
    /// 获取用户作品列表
    func getUserIllusts(
        userId: String,
        type: String = "illust",
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> ([Illusts], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getUserIllusts(userId: userId, type: type, offset: offset, limit: limit)
    }

    /// 通过 URL 加载更多插画（分页）
    func loadMoreIllusts(urlString: String) async throws -> ([Illusts], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.loadMoreIllusts(urlString: urlString)
    }

    /// 获取用户详情
    func getUserDetail(userId: String) async throws -> UserDetailResponse {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getUserDetail(userId: userId)
    }
    
    /// 关注用户
    func followUser(userId: String, restrict: String = "public") async throws {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        try await api.followUser(userId: userId, restrict: restrict)
    }
    
    /// 取消关注用户
    func unfollowUser(userId: String) async throws {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        try await api.unfollowUser(userId: userId)
    }

    /// 获取关注者新作
    func getFollowIllusts(restrict: String = "public") async throws -> ([Illusts], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getFollowIllusts(restrict: restrict)
    }

    /// 获取用户收藏
    func getUserBookmarksIllusts(userId: String, restrict: String = "public") async throws -> ([Illusts], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getUserBookmarksIllusts(userId: userId, restrict: restrict)
    }

    /// 获取用户小说列表
    func getUserNovels(userId: String, offset: Int = 0) async throws -> ([Novel], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getUserNovels(userId: userId, offset: offset)
    }

    /// 通过 URL 加载更多小说（分页）
    func loadMoreNovels(urlString: String) async throws -> ([Novel], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.loadMoreNovels(urlString: urlString)
    }

    /// 获取用户关注列表
    func getUserFollowing(userId: String, restrict: String = "public") async throws -> ([UserPreviews], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getUserFollowing(userId: userId, restrict: restrict)
    }

    /// 获取推荐画师
    func getRecommendedUsers() async throws -> ([UserPreviews], String?) {
        guard let api = userAPI else { throw NetworkError.invalidResponse }
        return try await api.getRecommendedUsers()
    }

    // MARK: - 收藏相关
    
    /// 添加书签（收藏）
    func addBookmark(
        illustId: Int,
        isPrivate: Bool = false,
        tags: [String]? = nil
    ) async throws {
        guard let api = bookmarkAPI else { throw NetworkError.invalidResponse }
        try await api.addBookmark(illustId: illustId, isPrivate: isPrivate, tags: tags)
    }

    /// 删除书签
    func deleteBookmark(illustId: Int) async throws {
        guard let api = bookmarkAPI else { throw NetworkError.invalidResponse }
        try await api.deleteBookmark(illustId: illustId)
    }
    
    /// 通用：获取下一页数据
    func fetchNext<T: Decodable>(urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidResponse
        }
        
        return try await NetworkClient.shared.get(
            from: url,
            headers: getAuthHeaders(for: UserDefaults.standard.string(forKey: "access_token") ?? ""),
            responseType: T.self
        )
    }

    // MARK: - Private Properties
    
    private var accessToken: String? {
        return UserDefaults.standard.string(forKey: "access_token")
    }
    
    // MARK: - 小说相关
    
    /// 获取推荐小说
    func getRecommendedNovels(offset: Int = 0) async throws -> (novels: [Novel], nextUrl: String?) {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        let response = try await api.getRecommendedNovels(offset: offset)
        return (response.novels, response.nextUrl)
    }
    
    /// 获取关注用户的新作
    /// 注意：首次请求不要传递 offset 参数，否则会返回 400 错误
    func getFollowingNovels(restrict: String = "public", offset: Int? = nil) async throws -> (novels: [Novel], nextUrl: String?) {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        let response = try await api.getFollowingNovels(restrict: restrict, offset: offset)
        return (response.novels, response.nextUrl)
    }
    
    /// 获取用户收藏的小说
    func getUserBookmarkNovels(userId: Int, restrict: String = "public", offset: Int = 0) async throws -> (novels: [Novel], nextUrl: String?) {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        let response = try await api.getUserBookmarkNovels(userId: userId, restrict: restrict, offset: offset)
        return (response.novels, response.nextUrl)
    }
    
    /// 获取小说详情
    func getNovelDetail(novelId: Int) async throws -> Novel {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        return try await api.getNovelDetail(novelId: novelId)
    }
    
    /// 通过 URL 获取小说列表（用于分页）
    func getNovelsByURL(_ urlString: String) async throws -> (novels: [Novel], nextUrl: String?) {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        let response = try await api.getNovelsByURL(urlString)
        return (response.novels, response.nextUrl)
    }
    
    /// 获取小说评论
    func getNovelComments(novelId: Int) async throws -> CommentResponse {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        return try await api.getNovelComments(novelId: novelId)
    }

    /// 搜索小说
    func searchNovels(
        word: String,
        searchTarget: String = "partial_match_for_tags",
        sort: String = "date_desc",
        offset: Int = 0,
        limit: Int = 30
    ) async throws -> [Novel] {
        guard let api = searchAPI else { throw NetworkError.invalidResponse }
        return try await api.searchNovels(
            word: word,
            searchTarget: searchTarget,
            sort: sort,
            offset: offset,
            limit: limit
        )
    }

    /// 获取小说正文内容
    func getNovelContent(novelId: Int) async throws -> NovelReaderContent {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        return try await api.getNovelContent(novelId: novelId)
    }

    /// 获取小说排行榜
    func getNovelRanking(mode: String, date: String? = nil, offset: Int = 0) async throws -> (novels: [Novel], nextUrl: String?) {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        let response = try await api.getNovelRanking(mode: mode, date: date, offset: offset)
        return (response.novels, response.nextUrl)
    }

    /// 通过 URL 获取排行榜小说列表（用于分页）
    func getNovelRankingByURL(_ urlString: String) async throws -> (novels: [Novel], nextUrl: String?) {
        guard let api = novelAPI else { throw NetworkError.invalidResponse }
        let response = try await api.getNovelRankingByURL(urlString)
        return (response.novels, response.nextUrl)
    }
}