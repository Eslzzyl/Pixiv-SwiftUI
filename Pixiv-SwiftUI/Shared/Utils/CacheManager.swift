import Foundation

/// 统一缓存管理
@MainActor
final class CacheManager {
    static let shared = CacheManager()

    private var cacheMap: [String: CacheEntry] = [:]
    private let maxEntries = 100

    private struct CacheEntry {
        let data: Any
        let timestamp: Date
        let expiration: CacheExpiration
    }

    private init() {}

    /// 缓存数据
    func set<T>(_ data: T, forKey key: String, expiration: CacheExpiration = .default) {
        let entry = CacheEntry(data: data, timestamp: Date(), expiration: expiration)
        cacheMap[key] = entry

        if cacheMap.count > maxEntries {
            cleanExpiredEntries()
        }
    }

    /// 获取缓存数据
    func get<T>(forKey key: String) -> T? {
        guard let entry = cacheMap[key] else { return nil }

        if isExpired(entry) {
            cacheMap.removeValue(forKey: key)
            return nil
        }

        return entry.data as? T
    }

    /// 检查缓存是否有效
    func isValid(forKey key: String) -> Bool {
        guard let entry = cacheMap[key] else { return false }
        return !isExpired(entry)
    }

    /// 获取缓存时间戳
    func timestamp(forKey key: String) -> Date? {
        guard let entry = cacheMap[key], !isExpired(entry) else { return nil }
        return entry.timestamp
    }

    /// 清除指定缓存
    func remove(forKey key: String) {
        cacheMap.removeValue(forKey: key)
    }

    /// 清除所有缓存
    func clearAll() {
        cacheMap.removeAll()
    }

    /// 清除过期缓存
    func cleanExpiredEntries() {
        cacheMap = cacheMap.filter { !isExpired($0.value) }
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

    static func userDetailKey(userId: String) -> String {
        "userDetail_\(userId)"
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
}
