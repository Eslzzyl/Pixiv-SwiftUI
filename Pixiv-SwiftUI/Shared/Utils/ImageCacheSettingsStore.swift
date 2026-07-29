import Foundation
import Kingfisher
import Observation

enum ImageCacheDiskLimit: Int, CaseIterable, Identifiable {
    case megabytes256 = 256
    case megabytes512 = 512
    case gigabytes1 = 1024
    case gigabytes2 = 2048

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .megabytes256, .megabytes512:
            return "\(rawValue) MB"
        case .gigabytes1:
            return "1 GB"
        case .gigabytes2:
            return "2 GB"
        }
    }

    var bytes: Int {
        rawValue * 1024 * 1024
    }
}

@MainActor
@Observable
final class ImageCacheSettingsStore {
    static let shared = ImageCacheSettingsStore()

    private static let diskLimitKey = "image_cache_disk_limit_mb"
    private let defaults: UserDefaults

    private(set) var diskLimit: ImageCacheDiskLimit
    private(set) var isApplying = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedLimit = defaults.integer(forKey: Self.diskLimitKey)
        self.diskLimit = ImageCacheDiskLimit(rawValue: storedLimit) ?? .megabytes512
    }

    func apply() async {
        await apply(diskLimit: diskLimit)
    }

    func updateDiskLimit(_ limit: ImageCacheDiskLimit) async {
        guard limit != diskLimit else { return }

        diskLimit = limit
        defaults.set(limit.rawValue, forKey: Self.diskLimitKey)
        await apply(diskLimit: limit)
    }

    private func apply(diskLimit: ImageCacheDiskLimit) async {
        isApplying = true
        defer { isApplying = false }

        CacheConfig.configureKingfisher(diskCacheLimit: diskLimit.bytes)
        await withCheckedContinuation { continuation in
            ImageCache.default.cleanExpiredDiskCache {
                continuation.resume()
            }
        }
    }
}
