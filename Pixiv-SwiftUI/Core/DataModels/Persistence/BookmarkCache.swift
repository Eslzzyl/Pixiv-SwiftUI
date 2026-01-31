import Foundation
import SwiftData

/// 缓存画质枚举
enum BookmarkCacheQuality: Int, Codable {
    case medium = 0
    case large = 1
    case original = 2

    var displayName: String {
        switch self {
        case .medium:
            return String(localized: "中等")
        case .large:
            return String(localized: "大图")
        case .original:
            return String(localized: "原图")
        }
    }
}

/// 收藏缓存记录
@Model
final class BookmarkCache {
    /// 作品ID
    @Attribute(.unique) var illustId: Int

    /// 用户ID（账号隔离）
    var ownerId: String

    /// 收藏类型：public/private
    var bookmarkRestrict: String

    /// 缓存时间
    var cachedAt: Date

    /// 最后检查时间
    var lastCheckedAt: Date

    /// 删除标记
    var isDeleted: Bool

    /// 作品数据快照（JSON编码的Illusts）
    var illustData: Data?

    /// 页面数
    var pageCount: Int

    /// 图片预取状态
    var imagePreloaded: Bool

    /// 缓存画质
    var cacheQuality: Int

    /// 是否缓存了所有页面
    var allPagesCached: Bool

    init(
        illustId: Int,
        ownerId: String,
        bookmarkRestrict: String = "public",
        cachedAt: Date = Date(),
        lastCheckedAt: Date = Date(),
        isDeleted: Bool = false,
        illustData: Data? = nil,
        pageCount: Int = 1,
        imagePreloaded: Bool = false,
        cacheQuality: Int = BookmarkCacheQuality.large.rawValue,
        allPagesCached: Bool = false
    ) {
        self.illustId = illustId
        self.ownerId = ownerId
        self.bookmarkRestrict = bookmarkRestrict
        self.cachedAt = cachedAt
        self.lastCheckedAt = lastCheckedAt
        self.isDeleted = isDeleted
        self.illustData = illustData
        self.pageCount = pageCount
        self.imagePreloaded = imagePreloaded
        self.cacheQuality = cacheQuality
        self.allPagesCached = allPagesCached
    }

    /// 从 Illusts 创建缓存记录
    static func from(_ illust: Illusts, ownerId: String, bookmarkRestrict: String) -> BookmarkCache {
        let encoder = JSONEncoder()
        let illustData = try? encoder.encode(illust)

        return BookmarkCache(
            illustId: illust.id,
            ownerId: ownerId,
            bookmarkRestrict: bookmarkRestrict,
            illustData: illustData,
            pageCount: illust.pageCount
        )
    }

    /// 获取解码后的 Illusts 对象
    func getIllust() -> Illusts? {
        guard let data = illustData else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Illusts.self, from: data)
    }

    /// 更新作品数据
    func updateIllustData(_ illust: Illusts) {
        let encoder = JSONEncoder()
        self.illustData = try? encoder.encode(illust)
        self.pageCount = illust.pageCount
        self.lastCheckedAt = Date()
    }

    /// 获取缓存画质枚举
    var quality: BookmarkCacheQuality {
        BookmarkCacheQuality(rawValue: cacheQuality) ?? .large
    }
}
