import Foundation
import Kingfisher

/// 缓存过期时间配置
public enum CacheExpiration {
    case hours(Int)
    case days(Int)
    case never
    case `default`

    public var timeInterval: TimeInterval {
        switch self {
        case .hours(let hours):
            return Double(hours) * 3600
        case .days(let days):
            return Double(days) * 86400
        case .never:
            return -1
        case .default:
            return 7 * 86400
        }
    }

    /// 转换为 Kingfisher 的 StorageExpiration
    public var kingfisherExpiration: StorageExpiration {
        switch self {
        case .hours(let hours):
            return .seconds(Double(hours) * 3600)
        case .days(let days):
            return .days(days)
        case .never:
            return .never
        case .default:
            return .days(7)
        }
    }
}

/// 默认缓存过期时间
public enum DefaultCacheExpiration {
    public static let recommend: CacheExpiration = .hours(1)
    public static let illustDetail: CacheExpiration = .hours(1)
    public static let updates: CacheExpiration = .days(7)
    public static let bookmarks: CacheExpiration = .days(30)
    public static let following: CacheExpiration = .days(7)
    public static let userHeader: CacheExpiration = .days(7)
    public static let userAvatar: CacheExpiration = .days(30)
    public static let myAvatar: CacheExpiration = .days(30)
    public static let `default`: CacheExpiration = .days(7)
}

/// 缓存配置工具
public struct CacheConfig {
    /// 内存缓存上限 (字节)
    public static let memoryCacheLimit: Int = 100 * 1024 * 1024

    /// 磁盘缓存上限 (字节)
    public static let diskCacheLimit: Int = 500 * 1024 * 1024

    /// 配置 Kingfisher 全局缓存设置
    public static func configureKingfisher() {
        let memoryStorage = ImageCache.default.memoryStorage
        memoryStorage.config.totalCostLimit = memoryCacheLimit

        let diskStorage = ImageCache.default.diskStorage
        var diskConfig = diskStorage.config
        diskConfig.sizeLimit = UInt(diskCacheLimit)
        diskConfig.expiration = DefaultCacheExpiration.default.kingfisherExpiration
        diskStorage.config = diskConfig
    }

    /// 获取带有过期时间的 Kingfisher 选项
    public static func options(expiration: CacheExpiration) -> KingfisherOptionsInfo {
        return [
            .pixivModifier,
            .cacheOriginalImage,
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration)
        ]
    }

    /// 获取默认选项（7天过期）
    public static func defaultOptions() -> KingfisherOptionsInfo {
        return options(expiration: .default)
    }
}
