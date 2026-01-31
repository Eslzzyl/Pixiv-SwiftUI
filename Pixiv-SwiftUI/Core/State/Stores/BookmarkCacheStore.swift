import Foundation
import Observation
import SwiftData

/// 收藏缓存过滤类型
enum BookmarkCacheFilter: String, CaseIterable {
    case all = "全部"
    case normal = "正常"
    case deleted = "已删除"
}

/// 全量同步状态
enum FullSyncState: Equatable {
    case idle
    case fetching(current: Int, total: Int?)
    case detecting
    case preloading(current: Int, total: Int)
    case completed
    case failed(String)

    var isRunning: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}

/// 收藏缓存状态管理
@MainActor
@Observable
final class BookmarkCacheStore {
    static let shared = BookmarkCacheStore()

    private let dataContainer = DataContainer.shared
    private let api = PixivAPI.shared

    /// 缓存列表
    var cachedBookmarks: [BookmarkCache] = []

    /// 当前过滤器
    var filter: BookmarkCacheFilter = .all

    /// 是否正在加载
    var isLoading = false

    /// 全量同步状态
    var syncState: FullSyncState = .idle

    /// 缓存总大小（字节）
    var cacheSizeBytes: Int64 = 0

    /// 已删除作品数量
    var deletedCount: Int {
        cachedBookmarks.filter { $0.isDeleted }.count
    }

    /// 正常作品数量
    var normalCount: Int {
        cachedBookmarks.filter { !$0.isDeleted }.count
    }

    /// 已缓存图片的作品数量
    var cachedImageCount: Int {
        cachedBookmarks.filter { $0.imagePreloaded }.count
    }

    private init() {}

    // MARK: - 查询方法

    /// 加载指定用户的缓存记录
    func loadCachedBookmarks(for ownerId: String) {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BookmarkCache>(
            predicate: #Predicate { $0.ownerId == ownerId },
            sortBy: [SortDescriptor(\.cachedAt, order: .reverse)]
        )

        do {
            cachedBookmarks = try context.fetch(descriptor)
            #if DEBUG
            print("[BookmarkCacheStore] 加载缓存记录: \(cachedBookmarks.count) 条")
            #endif
        } catch {
            print("[BookmarkCacheStore] 加载缓存失败: \(error)")
            cachedBookmarks = []
        }
    }

    /// 获取过滤后的缓存列表
    func filteredBookmarks() -> [BookmarkCache] {
        switch filter {
        case .all:
            return cachedBookmarks
        case .normal:
            return cachedBookmarks.filter { !$0.isDeleted }
        case .deleted:
            return cachedBookmarks.filter { $0.isDeleted }
        }
    }

    /// 检查作品是否在缓存中
    func isCached(illustId: Int) -> Bool {
        cachedBookmarks.contains { $0.illustId == illustId }
    }

    /// 获取指定作品的缓存记录
    func getCacheRecord(illustId: Int) -> BookmarkCache? {
        cachedBookmarks.first { $0.illustId == illustId }
    }

    /// 检查作品是否已标记为删除
    func isDeleted(illustId: Int) -> Bool {
        cachedBookmarks.first { $0.illustId == illustId }?.isDeleted ?? false
    }

    // MARK: - 缓存操作

    /// 添加或更新缓存记录
    func addOrUpdateCache(illust: Illusts, ownerId: String, bookmarkRestrict: String) {
        let context = dataContainer.mainContext
        let targetId = illust.id

        let descriptor = FetchDescriptor<BookmarkCache>(
            predicate: #Predicate { $0.illustId == targetId && $0.ownerId == ownerId }
        )

        do {
            if let existing = try context.fetch(descriptor).first {
                existing.updateIllustData(illust)
                existing.bookmarkRestrict = bookmarkRestrict
                existing.isDeleted = false
            } else {
                let cache = BookmarkCache.from(illust, ownerId: ownerId, bookmarkRestrict: bookmarkRestrict)
                context.insert(cache)
            }
            try context.save()
            loadCachedBookmarks(for: ownerId)
        } catch {
            print("[BookmarkCacheStore] 添加/更新缓存失败: \(error)")
        }
    }

    /// 批量添加或更新缓存记录
    func batchAddOrUpdateCache(illusts: [Illusts], ownerId: String, bookmarkRestrict: String) {
        let context = dataContainer.mainContext

        do {
            for illust in illusts {
                let targetId = illust.id
                let descriptor = FetchDescriptor<BookmarkCache>(
                    predicate: #Predicate { $0.illustId == targetId && $0.ownerId == ownerId }
                )

                if let existing = try context.fetch(descriptor).first {
                    existing.updateIllustData(illust)
                    existing.bookmarkRestrict = bookmarkRestrict
                    existing.isDeleted = false
                } else {
                    let cache = BookmarkCache.from(illust, ownerId: ownerId, bookmarkRestrict: bookmarkRestrict)
                    context.insert(cache)
                }
            }
            try context.save()
            loadCachedBookmarks(for: ownerId)
            #if DEBUG
            print("[BookmarkCacheStore] 批量更新缓存: \(illusts.count) 条")
            #endif
        } catch {
            print("[BookmarkCacheStore] 批量更新缓存失败: \(error)")
        }
    }

    /// 删除缓存记录
    func removeCache(illustId: Int, ownerId: String) {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BookmarkCache>(
            predicate: #Predicate { $0.illustId == illustId && $0.ownerId == ownerId }
        )

        do {
            if let cache = try context.fetch(descriptor).first {
                context.delete(cache)
                try context.save()
                loadCachedBookmarks(for: ownerId)

                Task {
                    await BookmarkCacheService.shared.removeImageCache(for: illustId)
                }
            }
        } catch {
            print("[BookmarkCacheStore] 删除缓存失败: \(error)")
        }
    }

    /// 标记作品为已删除
    func markAsDeleted(illustIds: Set<Int>, ownerId: String) {
        let context = dataContainer.mainContext

        do {
            for illustId in illustIds {
                let targetId = illustId
                let descriptor = FetchDescriptor<BookmarkCache>(
                    predicate: #Predicate { $0.illustId == targetId && $0.ownerId == ownerId }
                )

                if let cache = try context.fetch(descriptor).first {
                    cache.isDeleted = true
                    cache.lastCheckedAt = Date()
                }
            }
            try context.save()
            loadCachedBookmarks(for: ownerId)
            #if DEBUG
            print("[BookmarkCacheStore] 标记 \(illustIds.count) 个作品为已删除")
            #endif
        } catch {
            print("[BookmarkCacheStore] 标记删除失败: \(error)")
        }
    }

    /// 恢复已删除标记（作品恢复时）
    func unmarkDeleted(illustId: Int, ownerId: String) {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BookmarkCache>(
            predicate: #Predicate { $0.illustId == illustId && $0.ownerId == ownerId }
        )

        do {
            if let cache = try context.fetch(descriptor).first {
                cache.isDeleted = false
                cache.lastCheckedAt = Date()
                try context.save()
                loadCachedBookmarks(for: ownerId)
            }
        } catch {
            print("[BookmarkCacheStore] 恢复删除标记失败: \(error)")
        }
    }

    /// 更新图片预取状态
    func updatePreloadStatus(illustId: Int, ownerId: String, preloaded: Bool, quality: BookmarkCacheQuality, allPages: Bool) {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BookmarkCache>(
            predicate: #Predicate { $0.illustId == illustId && $0.ownerId == ownerId }
        )

        do {
            if let cache = try context.fetch(descriptor).first {
                cache.imagePreloaded = preloaded
                cache.cacheQuality = quality.rawValue
                cache.allPagesCached = allPages
                try context.save()
            }
        } catch {
            print("[BookmarkCacheStore] 更新预取状态失败: \(error)")
        }
    }

    // MARK: - 全量同步

    /// 执行全量同步
    func performFullSync(userId: String, ownerId: String, settings: UserSetting) async {
        guard !syncState.isRunning else {
            #if DEBUG
            print("[BookmarkCacheStore] 同步已在进行中")
            #endif
            return
        }

        syncState = .fetching(current: 0, total: nil)
        var allIllusts: [Illusts] = []
        var currentCount = 0

        do {
            var nextUrl: String?

            repeat {
                let illusts: [Illusts]
                if let url = nextUrl {
                    let response: IllustsResponse = try await api.fetchNext(urlString: url)
                    illusts = response.illusts
                    nextUrl = response.nextUrl
                } else {
                    (illusts, nextUrl) = try await api.getUserBookmarksIllusts(userId: userId, restrict: "public")
                }

                allIllusts.append(contentsOf: illusts)
                currentCount += illusts.count

                await MainActor.run {
                    syncState = .fetching(current: currentCount, total: nil)
                }

                if nextUrl != nil {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } while nextUrl != nil

            var privateNextUrl: String?
            repeat {
                let illusts: [Illusts]
                if let url = privateNextUrl {
                    let response: IllustsResponse = try await api.fetchNext(urlString: url)
                    illusts = response.illusts
                    privateNextUrl = response.nextUrl
                } else {
                    (illusts, privateNextUrl) = try await api.getUserBookmarksIllusts(userId: userId, restrict: "private")
                }

                allIllusts.append(contentsOf: illusts)
                currentCount += illusts.count

                await MainActor.run {
                    syncState = .fetching(current: currentCount, total: nil)
                }

                if privateNextUrl != nil {
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            } while privateNextUrl != nil

            #if DEBUG
            print("[BookmarkCacheStore] 获取完成，共 \(allIllusts.count) 个收藏")
            #endif

            await MainActor.run {
                syncState = .detecting
            }

            let apiIllustIds = Set(allIllusts.map { $0.id })
            let cachedIds = Set(cachedBookmarks.map { $0.illustId })
            let deletedIds = cachedIds.subtracting(apiIllustIds)

            if !deletedIds.isEmpty {
                markAsDeleted(illustIds: deletedIds, ownerId: ownerId)
            }

            for illust in allIllusts {
                let restrict = illust.bookmarkRestrict ?? "public"
                addOrUpdateCache(illust: illust, ownerId: ownerId, bookmarkRestrict: restrict)
            }

            if settings.bookmarkAutoPreload {
                await MainActor.run {
                    syncState = .preloading(current: 0, total: allIllusts.count)
                }

                let quality = BookmarkCacheQuality(rawValue: settings.bookmarkCacheQuality) ?? .large
                let allPages = settings.bookmarkCacheAllPages

                for (index, illust) in allIllusts.enumerated() {
                    await BookmarkCacheService.shared.preloadImages(
                        for: illust,
                        quality: quality,
                        allPages: allPages
                    )

                    updatePreloadStatus(
                        illustId: illust.id,
                        ownerId: ownerId,
                        preloaded: true,
                        quality: quality,
                        allPages: allPages
                    )

                    await MainActor.run {
                        syncState = .preloading(current: index + 1, total: allIllusts.count)
                    }

                    // 每10个作品更新一次缓存大小，避免频繁计算影响性能
                    if (index + 1) % 10 == 0 || (index + 1) == allIllusts.count {
                        await calculateCacheSize()
                    }
                }
            }

            await MainActor.run {
                syncState = .completed
            }

            #if DEBUG
            print("[BookmarkCacheStore] 全量同步完成")
            #endif

        } catch {
            await MainActor.run {
                syncState = .failed(error.localizedDescription)
            }
            print("[BookmarkCacheStore] 全量同步失败: \(error)")
        }
    }

    /// 重置同步状态
    func resetSyncState() {
        syncState = .idle
    }

    // MARK: - 存储管理

    /// 计算缓存大小
    func calculateCacheSize() async {
        let size = await BookmarkCacheService.shared.calculateCacheSize()
        await MainActor.run {
            cacheSizeBytes = size
        }
    }

    /// 清理所有图片缓存
    func clearImageCache() async {
        await BookmarkCacheService.shared.clearAllImageCache()
        await calculateCacheSize()

        for cache in cachedBookmarks {
            cache.imagePreloaded = false
        }

        do {
            try dataContainer.mainContext.save()
        } catch {
            print("[BookmarkCacheStore] 更新预取状态失败: \(error)")
        }
    }

    /// 清理所有缓存数据（包括元数据）
    func clearAllCache(ownerId: String) {
        let context = dataContainer.mainContext
        let descriptor = FetchDescriptor<BookmarkCache>(
            predicate: #Predicate { $0.ownerId == ownerId }
        )

        do {
            let caches = try context.fetch(descriptor)
            for cache in caches {
                context.delete(cache)
            }
            try context.save()
            cachedBookmarks = []

            Task {
                await BookmarkCacheService.shared.clearAllImageCache()
                await calculateCacheSize()
            }
        } catch {
            print("[BookmarkCacheStore] 清理缓存失败: \(error)")
        }
    }
}
