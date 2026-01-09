import Foundation
import SwiftUI
import Combine
import SwiftData

@MainActor
final class NovelStore: ObservableObject {
    @Published var recomNovels: [Novel] = []
    @Published var followingNovels: [Novel] = []
    @Published var bookmarkNovels: [Novel] = []

    @Published var dailyRankingNovels: [Novel] = []
    @Published var dailyMaleRankingNovels: [Novel] = []
    @Published var dailyFemaleRankingNovels: [Novel] = []
    @Published var weeklyRankingNovels: [Novel] = []

    @Published var isLoadingRecom = false
    @Published var isLoadingFollowing = false
    @Published var isLoadingBookmark = false
    @Published var isLoadingRanking = false

    var nextUrlRecom: String?
    var nextUrlFollowing: String?
    var nextUrlBookmark: String?
    var nextUrlDailyRanking: String?
    var nextUrlDailyMaleRanking: String?
    var nextUrlDailyFemaleRanking: String?
    var nextUrlWeeklyRanking: String?

    private var loadingNextUrlRecom: String?
    private var loadingNextUrlFollowing: String?
    private var loadingNextUrlBookmark: String?
    private var loadingNextUrlDailyRanking: String?
    private var loadingNextUrlDailyMaleRanking: String?
    private var loadingNextUrlDailyFemaleRanking: String?
    private var loadingNextUrlWeeklyRanking: String?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared
    private let dataContainer = DataContainer.shared
    private let expiration: CacheExpiration = .minutes(5)
    
    private let maxGlanceHistoryCount = 100

    var cacheKeyRecom: String { "novel_recom" }
    var cacheKeyDailyRanking: String { "novel_ranking_daily" }
    var cacheKeyDailyMaleRanking: String { "novel_ranking_daily_male" }
    var cacheKeyDailyFemaleRanking: String { "novel_ranking_daily_female" }
    var cacheKeyWeeklyRanking: String { "novel_ranking_weekly" }
    
    func loadAll(userId: String, forceRefresh: Bool = false) async {
        await loadRecommended(forceRefresh: forceRefresh)
        await loadFollowing(userId: userId, forceRefresh: forceRefresh)
        await loadBookmarks(userId: userId, forceRefresh: forceRefresh)
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

    // MARK: - 排行榜

    func loadDailyRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: NovelRankingResponse = cache.get(forKey: cacheKeyDailyRanking) {
            self.dailyRankingNovels = cached.novels
            self.nextUrlDailyRanking = cached.nextUrl
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getNovelRanking(mode: NovelRankingMode.day.rawValue)
            self.dailyRankingNovels = result.novels
            self.nextUrlDailyRanking = result.nextUrl
            cache.set(NovelRankingResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKeyDailyRanking, expiration: expiration)
        } catch {
            print("Failed to load daily ranking novels: \(error)")
        }
    }

    func loadDailyMaleRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: NovelRankingResponse = cache.get(forKey: cacheKeyDailyMaleRanking) {
            self.dailyMaleRankingNovels = cached.novels
            self.nextUrlDailyMaleRanking = cached.nextUrl
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getNovelRanking(mode: NovelRankingMode.dayMale.rawValue)
            self.dailyMaleRankingNovels = result.novels
            self.nextUrlDailyMaleRanking = result.nextUrl
            cache.set(NovelRankingResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKeyDailyMaleRanking, expiration: expiration)
        } catch {
            print("Failed to load daily male ranking novels: \(error)")
        }
    }

    func loadDailyFemaleRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: NovelRankingResponse = cache.get(forKey: cacheKeyDailyFemaleRanking) {
            self.dailyFemaleRankingNovels = cached.novels
            self.nextUrlDailyFemaleRanking = cached.nextUrl
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getNovelRanking(mode: NovelRankingMode.dayFemale.rawValue)
            self.dailyFemaleRankingNovels = result.novels
            self.nextUrlDailyFemaleRanking = result.nextUrl
            cache.set(NovelRankingResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKeyDailyFemaleRanking, expiration: expiration)
        } catch {
            print("Failed to load daily female ranking novels: \(error)")
        }
    }

    func loadWeeklyRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: NovelRankingResponse = cache.get(forKey: cacheKeyWeeklyRanking) {
            self.weeklyRankingNovels = cached.novels
            self.nextUrlWeeklyRanking = cached.nextUrl
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getNovelRanking(mode: NovelRankingMode.week.rawValue)
            self.weeklyRankingNovels = result.novels
            self.nextUrlWeeklyRanking = result.nextUrl
            cache.set(NovelRankingResponse(novels: result.novels, nextUrl: result.nextUrl), forKey: cacheKeyWeeklyRanking, expiration: expiration)
        } catch {
            print("Failed to load weekly ranking novels: \(error)")
        }
    }

    func loadAllRankings(forceRefresh: Bool = false) async {
        await loadDailyRanking(forceRefresh: forceRefresh)
        await loadDailyMaleRanking(forceRefresh: forceRefresh)
        await loadDailyFemaleRanking(forceRefresh: forceRefresh)
        await loadWeeklyRanking(forceRefresh: forceRefresh)
    }

    func loadMoreRanking(mode: NovelRankingMode) async {
        var nextUrl: String?
        var novelsKey: KeyPath<NovelStore, [Novel]>
        var nextUrlKey: KeyPath<NovelStore, String?>

        switch mode {
        case .day:
            nextUrl = nextUrlDailyRanking
            novelsKey = \.dailyRankingNovels
            nextUrlKey = \.nextUrlDailyRanking
        case .dayMale:
            nextUrl = nextUrlDailyMaleRanking
            novelsKey = \.dailyMaleRankingNovels
            nextUrlKey = \.nextUrlDailyMaleRanking
        case .dayFemale:
            nextUrl = nextUrlDailyFemaleRanking
            novelsKey = \.dailyFemaleRankingNovels
            nextUrlKey = \.nextUrlDailyFemaleRanking
        case .week:
            nextUrl = nextUrlWeeklyRanking
            novelsKey = \.weeklyRankingNovels
            nextUrlKey = \.nextUrlWeeklyRanking
        }

        guard let url = nextUrl, !isLoadingRanking else { return }

        switch mode {
        case .day:
            if url == loadingNextUrlDailyRanking { return }
            loadingNextUrlDailyRanking = url
        case .dayMale:
            if url == loadingNextUrlDailyMaleRanking { return }
            loadingNextUrlDailyMaleRanking = url
        case .dayFemale:
            if url == loadingNextUrlDailyFemaleRanking { return }
            loadingNextUrlDailyFemaleRanking = url
        case .week:
            if url == loadingNextUrlWeeklyRanking { return }
            loadingNextUrlWeeklyRanking = url
        }

        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getNovelRankingByURL(url)
            switch mode {
            case .day:
                self.dailyRankingNovels.append(contentsOf: result.novels)
                self.nextUrlDailyRanking = result.nextUrl
                loadingNextUrlDailyRanking = nil
            case .dayMale:
                self.dailyMaleRankingNovels.append(contentsOf: result.novels)
                self.nextUrlDailyMaleRanking = result.nextUrl
                loadingNextUrlDailyMaleRanking = nil
            case .dayFemale:
                self.dailyFemaleRankingNovels.append(contentsOf: result.novels)
                self.nextUrlDailyFemaleRanking = result.nextUrl
                loadingNextUrlDailyFemaleRanking = nil
            case .week:
                self.weeklyRankingNovels.append(contentsOf: result.novels)
                self.nextUrlWeeklyRanking = result.nextUrl
                loadingNextUrlWeeklyRanking = nil
            }
        } catch {
            switch mode {
            case .day:
                loadingNextUrlDailyRanking = nil
            case .dayMale:
                loadingNextUrlDailyMaleRanking = nil
            case .dayFemale:
                loadingNextUrlDailyFemaleRanking = nil
            case .week:
                loadingNextUrlWeeklyRanking = nil
            }
        }
    }

    func novels(for mode: NovelRankingMode) -> [Novel] {
        switch mode {
        case .day:
            return dailyRankingNovels
        case .dayMale:
            return dailyMaleRankingNovels
        case .dayFemale:
            return dailyFemaleRankingNovels
        case .week:
            return weeklyRankingNovels
        }
    }

    // MARK: - 浏览历史

    func recordGlance(_ novelId: Int, novel: Novel? = nil) throws {
        print("[NovelStore] recordGlance: novelId=\(novelId)")
        let context = dataContainer.mainContext

        let descriptor = FetchDescriptor<GlanceNovelPersist>(
            predicate: #Predicate { $0.novelId == novelId }
        )
        if let existing = try context.fetch(descriptor).first {
            print("[NovelStore] recordGlance: found existing, deleting")
            context.delete(existing)
            try context.save()
        }

        let glance = GlanceNovelPersist(novelId: novelId)
        context.insert(glance)

        if let novel = novel {
            try? saveNovelToCache(novel)
        }

        try enforceGlanceHistoryLimit(context: context)
        try context.save()
        print("[NovelStore] recordGlance: success")
    }

    private func saveNovelToCache(_ novel: Novel) throws {
        let context = dataContainer.mainContext
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(novel) else { return }

        let descriptor = FetchDescriptor<CachedNovel>(
            predicate: #Predicate { $0.id == novel.id }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.data = data
        } else {
            let cached = CachedNovel(id: novel.id)
            cached.data = data
            context.insert(cached)
        }
        try context.save()
    }

    func getNovel(_ id: Int) throws -> Novel? {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<CachedNovel>(
            predicate: #Predicate { $0.id == id }
        )
        guard let cached = try context.fetch(descriptor).first,
              let data = cached.data else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(Novel.self, from: data)
    }

    func getNovels(_ ids: [Int]) throws -> [Novel] {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<CachedNovel>(
            predicate: #Predicate { ids.contains($0.id) }
        )
        let cachedNovels = try context.fetch(descriptor)
        let decoder = JSONDecoder()
        return cachedNovels.compactMap { cached in
            guard let data = cached.data else { return nil }
            return try? decoder.decode(Novel.self, from: data)
        }
    }

    private func enforceGlanceHistoryLimit(context: ModelContext) throws {
        var descriptor = FetchDescriptor<GlanceNovelPersist>()
        descriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        let allHistory = try context.fetch(descriptor)

        if allHistory.count > maxGlanceHistoryCount {
            let toDelete = Array(allHistory.dropFirst(maxGlanceHistoryCount))
            for item in toDelete {
                context.delete(item)
            }
        }
    }

    func getGlanceHistoryIds(limit: Int = 100) throws -> [Int] {
        let history = try getGlanceHistory(limit: limit)
        print("[NovelStore] getGlanceHistoryIds: count=\(history.count), ids=\(history.map { $0.novelId })")
        return history.map { $0.novelId }
    }

    func getGlanceHistory(limit: Int = 100) throws -> [GlanceNovelPersist] {
        let context = dataContainer.mainContext
        var descriptor = FetchDescriptor<GlanceNovelPersist>()
        descriptor.fetchLimit = limit
        descriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        let result = try context.fetch(descriptor)
        print("[NovelStore] getGlanceHistory: fetched \(result.count) items")
        return result
    }

    func clearGlanceHistory() throws {
        let context = dataContainer.mainContext
        try context.delete(model: GlanceNovelPersist.self)
        try context.save()
    }
}
