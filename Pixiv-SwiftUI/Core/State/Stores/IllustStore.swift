import Foundation
import Observation
import SwiftData
import SwiftUI

/// 插画内容状态管理
@MainActor
@Observable
final class IllustStore {
    static let shared = IllustStore()
    
    var illusts: [Illusts] = []
    var favoriteIllusts: [Illusts] = []

    var dailyRankingIllusts: [Illusts] = []
    var dailyMaleRankingIllusts: [Illusts] = []
    var dailyFemaleRankingIllusts: [Illusts] = []
    var weeklyRankingIllusts: [Illusts] = []
    var monthlyRankingIllusts: [Illusts] = []

    var isLoading: Bool = false
    var isLoadingRanking: Bool = false
    var error: AppError?

    var nextUrlDailyRanking: String?
    var nextUrlDailyMaleRanking: String?
    var nextUrlDailyFemaleRanking: String?
    var nextUrlWeeklyRanking: String?
    var nextUrlMonthlyRanking: String?

    private var loadingNextUrlDailyRanking: String?
    private var loadingNextUrlDailyMaleRanking: String?
    private var loadingNextUrlDailyFemaleRanking: String?
    private var loadingNextUrlWeeklyRanking: String?
    private var loadingNextUrlMonthlyRanking: String?

    private let dataContainer = DataContainer.shared
    private let api = PixivAPI.shared
    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)

    var cacheKeyDailyRanking: String { "illust_ranking_daily" }
    var cacheKeyDailyMaleRanking: String { "illust_ranking_daily_male" }
    var cacheKeyDailyFemaleRanking: String { "illust_ranking_daily_female" }
    var cacheKeyWeeklyRanking: String { "illust_ranking_weekly" }
    var cacheKeyMonthlyRanking: String { "illust_ranking_monthly" }
    
    private var currentUserId: String {
        AccountStore.shared.currentUserId
    }

    /// 清空内存缓存的数据
    func clearMemoryCache() {
        self.illusts = []
        self.favoriteIllusts = []
        self.dailyRankingIllusts = []
        self.dailyMaleRankingIllusts = []
        self.dailyFemaleRankingIllusts = []
        self.weeklyRankingIllusts = []
        self.monthlyRankingIllusts = []
        self.nextUrlDailyRanking = nil
        self.nextUrlDailyMaleRanking = nil
        self.nextUrlDailyFemaleRanking = nil
        self.nextUrlWeeklyRanking = nil
        self.nextUrlMonthlyRanking = nil
    }

    // MARK: - 插画管理

    /// 保存或更新插画
    func saveIllust(_ illust: Illusts) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let illustId = illust.id

        // 检查是否已存在
        let descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { $0.id == illustId && $0.ownerId == uid }
        )
        if try context.fetch(descriptor).isEmpty {
            illust.ownerId = uid
            context.insert(illust)
        }

        try context.save()
    }

    /// 保存多个插画
    func saveIllusts(_ illusts: [Illusts]) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId

        for illust in illusts {
            let illustId = illust.id
            let descriptor = FetchDescriptor<Illusts>(
                predicate: #Predicate { $0.id == illustId && $0.ownerId == uid }
            )
            if try context.fetch(descriptor).isEmpty {
                illust.ownerId = uid
                context.insert(illust)
            }
        }

        try context.save()
    }

    /// 获取所有收藏的插画
    func loadFavorites() throws {
        let context = dataContainer.mainContext
        let uid = currentUserId
        var descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { $0.isBookmarked == true && $0.ownerId == uid }
        )
        descriptor.fetchLimit = 1000
        self.favoriteIllusts = try context.fetch(descriptor)
    }

    /// 获取插画详情
    func getIllust(_ id: Int) throws -> Illusts? {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { $0.id == id && $0.ownerId == uid }
        )
        return try context.fetch(descriptor).first
    }

    /// 批量获取插画
    func getIllusts(_ ids: [Int]) throws -> [Illusts] {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<Illusts>(
            predicate: #Predicate { ids.contains($0.id) && $0.ownerId == uid }
        )
        return try context.fetch(descriptor)
    }

    // MARK: - 禁用管理

    /// 禁用插画
    func banIllust(_ illustId: Int) throws {
        let context = dataContainer.mainContext
        let ban = BanIllustId(illustId: illustId, ownerId: currentUserId)
        context.insert(ban)
        try context.save()
    }

    /// 检查插画是否被禁用
    func isIllustBanned(_ illustId: Int) throws -> Bool {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<BanIllustId>(
            predicate: #Predicate { $0.illustId == illustId && $0.ownerId == uid }
        )
        return try context.fetch(descriptor).count > 0
    }

    /// 取消禁用插画
    func unbanIllust(_ illustId: Int) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<BanIllustId>(
            predicate: #Predicate { $0.illustId == illustId && $0.ownerId == uid }
        )
        if let ban = try context.fetch(descriptor).first {
            context.delete(ban)
            try context.save()
        }
    }

    /// 禁用用户
    func banUser(_ userId: String) throws {
        let context = dataContainer.mainContext
        let ban = BanUserId(userId: userId, ownerId: currentUserId)
        context.insert(ban)
        try context.save()
    }

    /// 检查用户是否被禁用
    func isUserBanned(_ userId: String) throws -> Bool {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<BanUserId>(
            predicate: #Predicate { $0.userId == userId && $0.ownerId == uid }
        )
        return try context.fetch(descriptor).count > 0
    }

    /// 取消禁用用户
    func unbanUser(_ userId: String) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<BanUserId>(
            predicate: #Predicate { $0.userId == userId && $0.ownerId == uid }
        )
        if let ban = try context.fetch(descriptor).first {
            context.delete(ban)
            try context.save()
        }
    }

    /// 禁用标签
    func banTag(_ name: String) throws {
        let context = dataContainer.mainContext
        let ban = BanTag(name: name, ownerId: currentUserId)
        context.insert(ban)
        try context.save()
    }

    /// 检查标签是否被禁用
    func isTagBanned(_ name: String) throws -> Bool {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<BanTag>(
            predicate: #Predicate { $0.name == name && $0.ownerId == uid }
        )
        return try context.fetch(descriptor).count > 0
    }

    /// 取消禁用标签
    func unbanTag(_ name: String) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<BanTag>(
            predicate: #Predicate { $0.name == name && $0.ownerId == uid }
        )
        if let ban = try context.fetch(descriptor).first {
            context.delete(ban)
            try context.save()
        }
    }

    // MARK: - 浏览历史

    private let maxGlanceHistoryCount = 100

    /// 记录浏览历史
    /// - Parameters:
    ///   - illustId: 插画 ID
    ///   - illust: 可选的完整插画数据，用于缓存以避免后续网络请求
    func recordGlance(_ illustId: Int, illust: Illusts? = nil) throws {
        let context = dataContainer.mainContext
        let uid = currentUserId

        let descriptor = FetchDescriptor<GlanceIllustPersist>(
            predicate: #Predicate { $0.illustId == illustId && $0.ownerId == uid }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }

        let glance = GlanceIllustPersist(illustId: illustId, ownerId: uid)
        context.insert(glance)

        if let illust = illust {
            try saveIllustToCache(illust, context: context)
        }

        try enforceGlanceHistoryLimit(context: context)
        try context.save()
    }

    private func saveIllustToCache(_ illust: Illusts, context: ModelContext) throws {
        let uid = currentUserId
        let id = illust.id
        let descriptor = FetchDescriptor<CachedIllust>(
            predicate: #Predicate { $0.id == id && $0.ownerId == uid }
        )
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
        }

        let cached = CachedIllust(illust: illust, ownerId: uid)
        context.insert(cached)
    }

    func getCachedIllusts(_ ids: [Int]) throws -> [Illusts] {
        let context = dataContainer.mainContext
        let uid = currentUserId
        let descriptor = FetchDescriptor<CachedIllust>(
            predicate: #Predicate { ids.contains($0.id) && $0.ownerId == uid }
        )
        let cachedIllusts = try context.fetch(descriptor)
        return cachedIllusts.map { $0.toIllusts() }
    }

    /// 强制执行浏览历史数量限制
    private func enforceGlanceHistoryLimit(context: ModelContext) throws {
        let uid = currentUserId
        var descriptor = FetchDescriptor<GlanceIllustPersist>(
            predicate: #Predicate { $0.ownerId == uid }
        )
        descriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        let allHistory = try context.fetch(descriptor)

        if allHistory.count > maxGlanceHistoryCount {
            let toDelete = Array(allHistory.dropFirst(maxGlanceHistoryCount))
            for item in toDelete {
                context.delete(item)
            }
        }
    }

    /// 获取浏览历史 ID 列表
    func getGlanceHistoryIds(limit: Int = 100) throws -> [Int] {
        let history = try getGlanceHistory(limit: limit)
        return history.map { $0.illustId }
    }

    /// 获取浏览历史
    func getGlanceHistory(limit: Int = 100) throws -> [GlanceIllustPersist] {
        let context = dataContainer.mainContext
        let uid = currentUserId
        var descriptor = FetchDescriptor<GlanceIllustPersist>(
            predicate: #Predicate { $0.ownerId == uid }
        )
        descriptor.fetchLimit = limit
        descriptor.sortBy = [SortDescriptor(\.viewedAt, order: .reverse)]
        return try context.fetch(descriptor)
    }

    /// 清空浏览历史
    func clearGlanceHistory() throws {
        let context = dataContainer.mainContext
        let uid = currentUserId
        try context.delete(model: GlanceIllustPersist.self, where: #Predicate { $0.ownerId == uid })
        try context.save()
    }

    // MARK: - 排行榜

    func loadDailyRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: IllustRankingResponse = cache.get(forKey: cacheKeyDailyRanking) {
            self.dailyRankingIllusts = cached.illusts
            self.nextUrlDailyRanking = cached.nextUrl
            return
        }

        guard AccountStore.shared.isLoggedIn else {
            print("[IllustStore] Skip loading daily ranking in guest mode")
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getIllustRanking(mode: IllustRankingMode.day.rawValue)
            self.dailyRankingIllusts = result.illusts
            self.nextUrlDailyRanking = result.nextUrl
            cache.set(IllustRankingResponse(illusts: result.illusts, nextUrl: result.nextUrl), forKey: cacheKeyDailyRanking, expiration: expiration)
        } catch {
            print("Failed to load daily ranking illusts: \(error)")
        }
    }

    func loadDailyMaleRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: IllustRankingResponse = cache.get(forKey: cacheKeyDailyMaleRanking) {
            self.dailyMaleRankingIllusts = cached.illusts
            self.nextUrlDailyMaleRanking = cached.nextUrl
            return
        }

        guard AccountStore.shared.isLoggedIn else {
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getIllustRanking(mode: IllustRankingMode.dayMale.rawValue)
            self.dailyMaleRankingIllusts = result.illusts
            self.nextUrlDailyMaleRanking = result.nextUrl
            cache.set(IllustRankingResponse(illusts: result.illusts, nextUrl: result.nextUrl), forKey: cacheKeyDailyMaleRanking, expiration: expiration)
        } catch {
            print("Failed to load daily male ranking illusts: \(error)")
        }
    }

    func loadDailyFemaleRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: IllustRankingResponse = cache.get(forKey: cacheKeyDailyFemaleRanking) {
            self.dailyFemaleRankingIllusts = cached.illusts
            self.nextUrlDailyFemaleRanking = cached.nextUrl
            return
        }

        guard AccountStore.shared.isLoggedIn else {
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getIllustRanking(mode: IllustRankingMode.dayFemale.rawValue)
            self.dailyFemaleRankingIllusts = result.illusts
            self.nextUrlDailyFemaleRanking = result.nextUrl
            cache.set(IllustRankingResponse(illusts: result.illusts, nextUrl: result.nextUrl), forKey: cacheKeyDailyFemaleRanking, expiration: expiration)
        } catch {
            print("Failed to load daily female ranking illusts: \(error)")
        }
    }

    func loadWeeklyRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: IllustRankingResponse = cache.get(forKey: cacheKeyWeeklyRanking) {
            self.weeklyRankingIllusts = cached.illusts
            self.nextUrlWeeklyRanking = cached.nextUrl
            return
        }

        guard AccountStore.shared.isLoggedIn else {
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getIllustRanking(mode: IllustRankingMode.week.rawValue)
            self.weeklyRankingIllusts = result.illusts
            self.nextUrlWeeklyRanking = result.nextUrl
            cache.set(IllustRankingResponse(illusts: result.illusts, nextUrl: result.nextUrl), forKey: cacheKeyWeeklyRanking, expiration: expiration)
        } catch {
            print("Failed to load weekly ranking illusts: \(error)")
        }
    }

    func loadMonthlyRanking(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: IllustRankingResponse = cache.get(forKey: cacheKeyMonthlyRanking) {
            self.monthlyRankingIllusts = cached.illusts
            self.nextUrlMonthlyRanking = cached.nextUrl
            return
        }

        guard AccountStore.shared.isLoggedIn else {
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getIllustRanking(mode: IllustRankingMode.month.rawValue)
            self.monthlyRankingIllusts = result.illusts
            self.nextUrlMonthlyRanking = result.nextUrl
            cache.set(IllustRankingResponse(illusts: result.illusts, nextUrl: result.nextUrl), forKey: cacheKeyMonthlyRanking, expiration: expiration)
        } catch {
            print("Failed to load monthly ranking illusts: \(error)")
        }
    }

    func loadAllRankings(forceRefresh: Bool = false) async {
        await loadDailyRanking(forceRefresh: forceRefresh)
        await loadDailyMaleRanking(forceRefresh: forceRefresh)
        await loadDailyFemaleRanking(forceRefresh: forceRefresh)
        await loadWeeklyRanking(forceRefresh: forceRefresh)
        await loadMonthlyRanking(forceRefresh: forceRefresh)
    }

    func loadMoreRanking(mode: IllustRankingMode) async {
        guard AccountStore.shared.isLoggedIn else { return }

        var nextUrl: String?

        switch mode {
        case .day:
            nextUrl = nextUrlDailyRanking
        case .dayMale:
            nextUrl = nextUrlDailyMaleRanking
        case .dayFemale:
            nextUrl = nextUrlDailyFemaleRanking
        case .week:
            nextUrl = nextUrlWeeklyRanking
        case .month:
            nextUrl = nextUrlMonthlyRanking
        case .weekOriginal, .weekRookie:
            return
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
        case .month:
            if url == loadingNextUrlMonthlyRanking { return }
            loadingNextUrlMonthlyRanking = url
        case .weekOriginal, .weekRookie:
            return
        }

        isLoadingRanking = true
        defer { isLoadingRanking = false }

        do {
            let result = try await api.getIllustRankingByURL(url)
            switch mode {
            case .day:
                self.dailyRankingIllusts.append(contentsOf: result.illusts)
                self.nextUrlDailyRanking = result.nextUrl
                loadingNextUrlDailyRanking = nil
            case .dayMale:
                self.dailyMaleRankingIllusts.append(contentsOf: result.illusts)
                self.nextUrlDailyMaleRanking = result.nextUrl
                loadingNextUrlDailyMaleRanking = nil
            case .dayFemale:
                self.dailyFemaleRankingIllusts.append(contentsOf: result.illusts)
                self.nextUrlDailyFemaleRanking = result.nextUrl
                loadingNextUrlDailyFemaleRanking = nil
            case .week:
                self.weeklyRankingIllusts.append(contentsOf: result.illusts)
                self.nextUrlWeeklyRanking = result.nextUrl
                loadingNextUrlWeeklyRanking = nil
            case .month:
                self.monthlyRankingIllusts.append(contentsOf: result.illusts)
                self.nextUrlMonthlyRanking = result.nextUrl
                loadingNextUrlMonthlyRanking = nil
            case .weekOriginal, .weekRookie:
                break
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
            case .month:
                loadingNextUrlMonthlyRanking = nil
            case .weekOriginal, .weekRookie:
                break
            }
        }
    }

    func illusts(for mode: IllustRankingMode) -> [Illusts] {
        switch mode {
        case .day:
            return dailyRankingIllusts
        case .dayMale:
            return dailyMaleRankingIllusts
        case .dayFemale:
            return dailyFemaleRankingIllusts
        case .week:
            return weeklyRankingIllusts
        case .month:
            return monthlyRankingIllusts
        case .weekOriginal, .weekRookie:
            return []
        }
    }
}
