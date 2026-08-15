import Foundation

/// 统一缓存管理
///
/// 基于 NSCache 实现，系统在内存压力下自动驱逐条目，
/// 无需手动监听内存警告或维护淘汰策略。
///
/// ## 淘汰策略
/// - **容量限制**: 最多 500 个条目
/// - **成本限制**: 总 cost 上限 200MB，Cost 按缓存数据类型估算
/// - **过期淘汰**: 在 `get` / `isValid` 时惰性检查时间戳
/// - **系统淘汰**: NSCache 在内存压力下自动驱逐低优先级条目
@MainActor
final class CacheManager: CacheStorageProtocol {
    static let shared = CacheManager()

    private let cache: NSCache<NSString, CacheEntry>

    /// 最大条目数（NSCache 硬限制）
    private let countLimit = 500

    /// 总成本上限（字节），NSCache 据此优先驱逐高成本条目
    private let totalCostLimit = 200 * 1024 * 1024

    private final class CacheEntry {
        let data: Any
        let timestamp: Date
        let expiration: CacheExpiration

        init(data: Any, timestamp: Date, expiration: CacheExpiration) {
            self.data = data
            self.timestamp = timestamp
            self.expiration = expiration
        }

        /// 估算该条目占用的内存成本（字节）
        var cost: Int {
            CacheManager.estimateCost(of: data)
        }
    }

    private init() {
        cache = NSCache<NSString, CacheEntry>()
        cache.countLimit = countLimit
        cache.totalCostLimit = totalCostLimit
    }

    /// 估算任意值的近似内存占用（用于 NSCache cost 计算）
    private static func estimateCost(of value: Any) -> Int {
        switch value {
        case let array as [Any]:
            return max(array.count * 512, 128)
        case let dict as [AnyHashable: Any]:
            return max(dict.count * 256, 128)
        case let data as Data:
            return max(data.count, 128)
        case let string as String:
            return max(string.utf8.count, 64)
        default:
            return 1024
        }
    }

    // MARK: - 核心接口

    /// 缓存数据
    func set<T>(_ data: T, forKey key: String, expiration: CacheExpiration = .default) {
        let entry = CacheEntry(data: data, timestamp: Date(), expiration: expiration)
        cache.setObject(entry, forKey: key as NSString, cost: entry.cost)
    }

    /// 获取缓存数据（惰性过期检查）
    func get<T>(forKey key: String) -> T? {
        guard let entry = cache.object(forKey: key as NSString) else { return nil }

        if isExpired(entry) {
            cache.removeObject(forKey: key as NSString)
            return nil
        }

        return entry.data as? T
    }

    /// 检查缓存是否有效
    func isValid(forKey key: String) -> Bool {
        guard let entry = cache.object(forKey: key as NSString) else { return false }
        return !isExpired(entry)
    }

    /// 获取缓存时间戳
    func timestamp(forKey key: String) -> Date? {
        guard let entry = cache.object(forKey: key as NSString), !isExpired(entry) else { return nil }
        return entry.timestamp
    }

    /// 清除指定缓存
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    /// 清除所有缓存
    func clearAll() {
        cache.removeAllObjects()
    }

    private func isExpired(_ entry: CacheEntry) -> Bool {
        switch entry.expiration {
        case .never:
            return false
        default:
            return Date().timeIntervalSince(entry.timestamp) > entry.expiration.timeInterval
        }
    }

    // MARK: - 便捷方法

    static func trendTagsKey() -> String {
        "trendTags"
    }

    static func commentsKey(illustId: Int) -> String {
        "comments_\(illustId)"
    }

    static func novelCommentsKey(novelId: Int) -> String {
        "novelComments_\(novelId)"
    }

    static func illustDetailKey(illustId: Int) -> String {
        "illustDetail_\(illustId)"
    }

    static func userDetailKey(userId: String, ownerId: String) -> String {
        "userDetail_\(ownerId)_\(userId)"
    }

    static func userDetailDataKey(userId: String, ownerId: String) -> String {
        "userDetailData_\(ownerId)_\(userId)"
    }

    static func recommendKey(offset: Int) -> String {
        "recommend_\(offset)"
    }

    static func updatesKey(userId: String) -> String {
        "updates_\(userId)"
    }

    static func bookmarksKey(userId: String, restrict: String) -> String {
        "bookmarks_\(userId)_\(restrict)"
    }

    static func recommendedTagsKey(userId: String = "") -> String {
        userId.isEmpty ? "recommendedTags" : "recommendedTags_\(userId)"
    }

    static func recommendByTagGroupsKey(userId: String = "") -> String {
        userId.isEmpty ? "recommendByTagGroups" : "recommendByTagGroups_\(userId)"
    }
}
