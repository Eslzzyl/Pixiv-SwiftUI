import Foundation
import Observation
import SwiftData
import SwiftUI
import os.log

/// 插画内容状态管理
@MainActor
@Observable
final class IllustStore {
    static let shared = IllustStore()

    var illusts: [Illusts] = []
    var favoriteIllusts: [Illusts] = []

    var rankingIllustsByMode: [IllustRankingMode: [Illusts]] = [:]

    var isLoading: Bool = false
    var isLoadingRanking: Bool = false
    var error: AppError?

    var nextUrlsByRankingMode: [IllustRankingMode: String] = [:]

    private var loadingNextUrlsByRankingMode: [IllustRankingMode: String] = [:]

    private let dataContainer = DataContainer.shared
    private let api = PixivAPI.shared
    private let cache: CacheStorageProtocol
    private let authSession: AuthSessionProtocol
    private let expiration: CacheExpiration = .minutes(5)
    private var requestGeneration: UInt = 0

    init(
        authSession: AuthSessionProtocol = AccountStore.shared,
        cache: CacheStorageProtocol = CacheManager.shared
    ) {
        self.authSession = authSession
        self.cache = cache
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clearMemoryCache()
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func cacheKeyPrefix(for mode: IllustRankingMode) -> String {
        switch mode {
        case .day:
            return "illust_ranking_daily"
        case .dayMale:
            return "illust_ranking_daily_male"
        case .dayFemale:
            return "illust_ranking_daily_female"
        case .week:
            return "illust_ranking_weekly"
        case .month:
            return "illust_ranking_monthly"
        case .weekOriginal:
            return "illust_ranking_week_original"
        case .weekRookie:
            return "illust_ranking_week_rookie"
        case .dayAI:
            return "illust_ranking_day_ai"
        case .dayR18AI:
            return "illust_ranking_day_r18_ai"
        case .dayR18:
            return "illust_ranking_day_r18"
        case .weekR18:
            return "illust_ranking_week_r18"
        case .weekR18G:
            return "illust_ranking_week_r18g"
        }
    }

    private func cacheKey(for mode: IllustRankingMode, dateString: String? = nil) -> String {
        let key = cacheKeyPrefix(for: mode)
        if let dateString = dateString { return "\(key)_\(dateString)" }
        return key
    }

    private var currentUserId: String {
        authSession.currentUserId
    }

    /// 清空内存缓存的数据
    func clearMemoryCache() {
        requestGeneration &+= 1
        self.illusts = []
        self.favoriteIllusts = []
        self.rankingIllustsByMode.removeAll()
        self.nextUrlsByRankingMode.removeAll()
        self.loadingNextUrlsByRankingMode.removeAll()
        self.isLoading = false
        self.isLoadingRanking = false
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
        let result = try context.fetch(descriptor)
        return result.isEmpty == false
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
        let result = try context.fetch(descriptor)
        return result.isEmpty == false
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
        let result = try context.fetch(descriptor)
        return result.isEmpty == false
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

    private func rankingModes(from modes: [IllustRankingMode]?) -> [IllustRankingMode] {
        guard let modes else {
            return IllustRankingMode.defaultVisibleModes
        }

        var seenModes = Set<IllustRankingMode>()
        return modes.filter { seenModes.insert($0).inserted }
    }

    func loadRanking(mode: IllustRankingMode, date: Date? = nil, forceRefresh: Bool = false) async {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        let dateString = date.map { dateFormatter.string(from: $0) }
        let cacheKey = cacheKey(for: mode, dateString: dateString)

        if !forceRefresh, let cached: IllustRankingResponseDTO = cache.get(forKey: cacheKey) {
            self.rankingIllustsByMode[mode] = cached.illusts.map { $0.toDomain() }
            self.nextUrlsByRankingMode[mode] = cached.nextUrl
            return
        }

        guard authSession.isLoggedIn else {
            if mode == .day {
                Logger.illust.debug("Skip loading daily ranking in guest mode")
            }
            return
        }

        guard !isLoadingRanking else { return }
        isLoadingRanking = true
        defer {
            if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
                isLoadingRanking = false
            }
        }

        do {
            let result = try await api.illustAPI.getIllustRanking(mode: mode.rawValue, date: dateString)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.rankingIllustsByMode[mode] = result.illusts
            self.nextUrlsByRankingMode[mode] = result.nextUrl
            cache.set(IllustRankingResponseDTO(illusts: result.illusts.map { IllustDTO.fromDomain($0) }, nextUrl: result.nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            Logger.illust.error("Failed to load \(mode.rawValue) ranking illusts: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadDailyRanking(date: Date? = nil, forceRefresh: Bool = false) async {
        await loadRanking(mode: .day, date: date, forceRefresh: forceRefresh)
    }

    func loadDailyMaleRanking(date: Date? = nil, forceRefresh: Bool = false) async {
        await loadRanking(mode: .dayMale, date: date, forceRefresh: forceRefresh)
    }

    func loadDailyFemaleRanking(date: Date? = nil, forceRefresh: Bool = false) async {
        await loadRanking(mode: .dayFemale, date: date, forceRefresh: forceRefresh)
    }

    func loadWeeklyRanking(date: Date? = nil, forceRefresh: Bool = false) async {
        await loadRanking(mode: .week, date: date, forceRefresh: forceRefresh)
    }

    func loadMonthlyRanking(date: Date? = nil, forceRefresh: Bool = false) async {
        await loadRanking(mode: .month, date: date, forceRefresh: forceRefresh)
    }

    func loadAllRankings(date: Date? = nil, forceRefresh: Bool = false, modes: [IllustRankingMode]? = nil) async {
        for mode in rankingModes(from: modes) {
            await loadRanking(mode: mode, date: date, forceRefresh: forceRefresh)
        }
    }

    func loadMoreRanking(mode: IllustRankingMode) async {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        guard authSession.isLoggedIn else { return }
        guard let url = nextUrlsByRankingMode[mode], !isLoadingRanking else { return }
        guard loadingNextUrlsByRankingMode[mode] != url else { return }

        loadingNextUrlsByRankingMode[mode] = url
        isLoadingRanking = true
        defer {
            if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
                isLoadingRanking = false
            }
        }

        do {
            let result = try await api.illustAPI.getIllustRankingByURL(url)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                loadingNextUrlsByRankingMode[mode] = nil
                return
            }
            self.rankingIllustsByMode[mode, default: []].append(contentsOf: result.illusts)
            self.nextUrlsByRankingMode[mode] = result.nextUrl
            loadingNextUrlsByRankingMode[mode] = nil
        } catch {
            loadingNextUrlsByRankingMode[mode] = nil
        }
    }

    func nextUrl(for mode: IllustRankingMode) -> String? {
        nextUrlsByRankingMode[mode]
    }

    func illusts(for mode: IllustRankingMode) -> [Illusts] {
        rankingIllustsByMode[mode] ?? []
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt, userId: String) -> Bool {
        self.requestGeneration == generation &&
            authSession.accountGeneration == accountGeneration &&
            authSession.currentUserId == userId
    }
}
