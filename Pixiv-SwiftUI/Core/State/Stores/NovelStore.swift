import Foundation
import SwiftUI
import Combine

@MainActor
final class NovelStore: ObservableObject {
    @Published var recomNovels: [Novel] = []
    @Published var followingNovels: [Novel] = []
    @Published var bookmarkNovels: [Novel] = []
    
    @Published var isLoadingRecom = false
    @Published var isLoadingFollowing = false
    @Published var isLoadingBookmark = false
    
    var nextUrlRecom: String?
    var nextUrlFollowing: String?
    var nextUrlBookmark: String?
    
    private var loadingNextUrlRecom: String?
    private var loadingNextUrlFollowing: String?
    private var loadingNextUrlBookmark: String?
    
    private let api = PixivAPI.shared
    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)
    
    var cacheKeyRecom: String { "novel_recom" }
    
    func loadAll(userId: String) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadRecommended() }
            group.addTask { await self.loadFollowing(userId: userId) }
            group.addTask { await self.loadBookmarks(userId: userId) }
        }
    }
    
    // MARK: - 推荐
    
    func loadRecommended(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: NovelResponse = cache.get(forKey: cacheKeyRecom) {
            self.recomNovels = cached.novels
            self.nextUrlRecom = cached.nextUrl
            return
        }
        
        guard !isLoadingRecom else { return }
        isLoadingRecom = true
        defer { isLoadingRecom = false }
        
        do {
            let result = try await api.getRecommendedNovels()
            self.recomNovels = result.novels
            self.nextUrlRecom = result.nextUrl
            cache.set(NovelResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKeyRecom, expiration: expiration)
        } catch {
            print("Failed to load recommended novels: \(error)")
        }
    }
    
    func loadMoreRecom() async {
        guard let nextUrl = nextUrlRecom, !isLoadingRecom else { return }
        if nextUrl == loadingNextUrlRecom { return }
        
        loadingNextUrlRecom = nextUrl
        isLoadingRecom = true
        defer { isLoadingRecom = false }
        
        do {
            let result = try await api.getNovelsByURL(nextUrl)
            self.recomNovels.append(contentsOf: result.novels)
            self.nextUrlRecom = result.nextUrl
            loadingNextUrlRecom = nil
        } catch {
            loadingNextUrlRecom = nil
        }
    }
    
    // MARK: - 关注新作
    
    func loadFollowing(userId: String, forceRefresh: Bool = false) async {
        let cacheKey = "novel_following_\(userId)"
        
        if !forceRefresh, let cached: NovelResponse = cache.get(forKey: cacheKey) {
            self.followingNovels = cached.novels
            self.nextUrlFollowing = cached.nextUrl
            return
        }
        
        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }
        
        do {
            let result = try await api.getFollowingNovels()
            self.followingNovels = result.novels
            self.nextUrlFollowing = result.nextUrl
            cache.set(NovelResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            print("Failed to load following novels: \(error)")
        }
    }
    
    func loadMoreFollowing() async {
        guard let nextUrl = nextUrlFollowing, !isLoadingFollowing else { return }
        if nextUrl == loadingNextUrlFollowing { return }
        
        loadingNextUrlFollowing = nextUrl
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }
        
        do {
            let result = try await api.getNovelsByURL(nextUrl)
            self.followingNovels.append(contentsOf: result.novels)
            self.nextUrlFollowing = result.nextUrl
            loadingNextUrlFollowing = nil
        } catch {
            loadingNextUrlFollowing = nil
        }
    }
    
    // MARK: - 收藏
    
    func loadBookmarks(userId: String, restrict: String = "public", forceRefresh: Bool = false) async {
        let cacheKey = "novel_bookmark_\(userId)_\(restrict)"
        
        if !forceRefresh, let cached: NovelResponse = cache.get(forKey: cacheKey) {
            self.bookmarkNovels = cached.novels
            self.nextUrlBookmark = cached.nextUrl
            return
        }
        
        guard !isLoadingBookmark else { return }
        isLoadingBookmark = true
        defer { isLoadingBookmark = false }
        
        do {
            let result = try await api.getUserBookmarkNovels(userId: Int(userId) ?? 0)
            self.bookmarkNovels = result.novels
            self.nextUrlBookmark = result.nextUrl
            cache.set(NovelResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            print("Failed to load bookmark novels: \(error)")
        }
    }
    
    func loadMoreBookmarks() async {
        guard let nextUrl = nextUrlBookmark, !isLoadingBookmark else { return }
        if nextUrl == loadingNextUrlBookmark { return }
        
        loadingNextUrlBookmark = nextUrl
        isLoadingBookmark = true
        defer { isLoadingBookmark = false }
        
        do {
            let result = try await api.getNovelsByURL(nextUrl)
            self.bookmarkNovels.append(contentsOf: result.novels)
            self.nextUrlBookmark = result.nextUrl
            loadingNextUrlBookmark = nil
        } catch {
            loadingNextUrlBookmark = nil
        }
    }
    
    // MARK: - 收藏操作
    
    func toggleBookmark(_ novel: Novel) async {
        let wasBookmarked = novel.isBookmarked
        let novelId = novel.id
        
        var updatedNovel = novel
        updatedNovel.isBookmarked = !wasBookmarked
        updatedNovel.totalBookmarks = wasBookmarked ? novel.totalBookmarks - 1 : novel.totalBookmarks + 1
        
        updateNovelInLists(updatedNovel)
        
        do {
            if wasBookmarked {
                try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
            } else {
                try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId)
            }
        } catch {
            await MainActor.run {
                var rollbackNovel = novel
                rollbackNovel.isBookmarked = wasBookmarked
                rollbackNovel.totalBookmarks = wasBookmarked ? novel.totalBookmarks + 1 : novel.totalBookmarks - 1
                updateNovelInLists(rollbackNovel)
            }
        }
    }
    
    private func updateNovelInLists(_ novel: Novel) {
        if let index = recomNovels.firstIndex(where: { $0.id == novel.id }) {
            recomNovels[index] = novel
        }
        if let index = followingNovels.firstIndex(where: { $0.id == novel.id }) {
            followingNovels[index] = novel
        }
        if let index = bookmarkNovels.firstIndex(where: { $0.id == novel.id }) {
            bookmarkNovels[index] = novel
        }
    }

    // MARK: - 按类型加载

    struct LoadResult {
        var novels: [Novel]
        var nextUrl: String?
    }

    func load(listType: NovelListType, forceRefresh: Bool = false) async -> LoadResult {
        switch listType {
        case .recommend:
            await loadRecommended(forceRefresh: forceRefresh)
            return LoadResult(novels: recomNovels, nextUrl: nextUrlRecom)
        case .following:
            await loadFollowing(userId: "", forceRefresh: forceRefresh)
            return LoadResult(novels: followingNovels, nextUrl: nextUrlFollowing)
        case .bookmarks(let userId, _):
            await loadBookmarks(userId: userId, forceRefresh: forceRefresh)
            return LoadResult(novels: bookmarkNovels, nextUrl: nextUrlBookmark)
        }
    }

    func loadMore(listType: NovelListType, url: String) async -> LoadResult {
        do {
            let result = try await api.getNovelsByURL(url)
            switch listType {
            case .recommend:
                recomNovels.append(contentsOf: result.novels)
                nextUrlRecom = result.nextUrl
                return LoadResult(novels: result.novels, nextUrl: result.nextUrl)
            case .following:
                followingNovels.append(contentsOf: result.novels)
                nextUrlFollowing = result.nextUrl
                return LoadResult(novels: result.novels, nextUrl: result.nextUrl)
            case .bookmarks:
                bookmarkNovels.append(contentsOf: result.novels)
                nextUrlBookmark = result.nextUrl
                return LoadResult(novels: result.novels, nextUrl: result.nextUrl)
            }
        } catch {
            return LoadResult(novels: [], nextUrl: nil)
        }
    }
}
