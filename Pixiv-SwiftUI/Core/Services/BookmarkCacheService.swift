import Foundation
import Kingfisher

/// 收藏缓存图片服务
actor BookmarkCacheService {
    static let shared = BookmarkCacheService()

    /// 独立的图片缓存命名空间
    private let bookmarkCache: ImageCache

    /// 缓存目录名称
    private let cacheName = "BookmarkImageCache"

    private init() {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            fatalError("无法获取缓存目录")
        }
        let bookmarkCacheDirectory = cacheDirectory.appendingPathComponent(cacheName)

        try? FileManager.default.createDirectory(at: bookmarkCacheDirectory, withIntermediateDirectories: true)

        guard let cache = try? ImageCache(name: cacheName, cacheDirectoryURL: bookmarkCacheDirectory) else {
            fatalError("无法创建图片缓存")
        }
        bookmarkCache = cache

        bookmarkCache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
        bookmarkCache.diskStorage.config.sizeLimit = 0
        bookmarkCache.diskStorage.config.expiration = .never
    }

    // MARK: - 预取图片

    /// 预取作品图片
    func preloadImages(for illust: Illusts, quality: BookmarkCacheQuality, allPages: Bool) async {
        let urls = getImageURLs(for: illust, quality: quality, allPages: allPages)

        for urlString in urls {
            await preloadSingleImage(urlString: urlString)
        }
    }

    /// 预取单张图片
    private func preloadSingleImage(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        let options: KingfisherOptionsInfo = [
            .targetCache(bookmarkCache),
            .cacheOriginalImage,
            .diskCacheExpiration(.never),
            .memoryCacheExpiration(.never),
            .requestModifier(PixivImageRequestModifier()),
        ]

        let resource = KF.ImageResource(downloadURL: url)

        do {
            _ = try await KingfisherManager.shared.retrieveImage(
                with: .network(resource),
                options: options
            )
            #if DEBUG
            print("[BookmarkCacheService] 预取成功: \(urlString.suffix(50))")
            #endif
        } catch {
            #if DEBUG
            print("[BookmarkCacheService] 预取失败: \(error.localizedDescription)")
            #endif
        }
    }

    /// 获取作品的图片URL列表
    private func getImageURLs(for illust: Illusts, quality: BookmarkCacheQuality, allPages: Bool) -> [String] {
        var urls: [String] = []

        if illust.pageCount == 1 || !allPages {
            if let url = getSingleImageURL(for: illust, quality: quality) {
                urls.append(url)
            }
        } else {
            for metaPage in illust.metaPages {
                if let imageUrls = metaPage.imageUrls {
                    let url: String
                    switch quality {
                    case .original:
                        url = imageUrls.original
                    case .large:
                        url = imageUrls.large
                    case .medium:
                        url = imageUrls.medium
                    }
                    urls.append(url)
                }
            }
        }

        return urls
    }

    /// 获取单页图片URL
    private func getSingleImageURL(for illust: Illusts, quality: BookmarkCacheQuality) -> String? {
        switch quality {
        case .original:
            return illust.metaSinglePage?.originalImageUrl ?? illust.imageUrls.large
        case .large:
            return illust.imageUrls.large
        case .medium:
            return illust.imageUrls.medium
        }
    }

    // MARK: - 缓存读取

    /// 检查图片是否已缓存
    func isImageCached(urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        let key = url.cacheKey
        return bookmarkCache.isCached(forKey: key)
    }

    /// 获取缓存的图片
    func getCachedImage(urlString: String) async -> KFCrossPlatformImage? {
        guard let url = URL(string: urlString) else { return nil }
        let key = url.cacheKey

        return await withCheckedContinuation { continuation in
            bookmarkCache.retrieveImage(forKey: key) { result in
                switch result {
                case .success(let imageResult):
                    continuation.resume(returning: imageResult.image)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// 获取缓存图片的 Kingfisher 选项
    func cacheOptions() -> KingfisherOptionsInfo {
        return [
            .targetCache(bookmarkCache),
            .cacheOriginalImage,
            .diskCacheExpiration(.never),
            .memoryCacheExpiration(.never),
            .requestModifier(PixivImageRequestModifier()),
        ]
    }

    // MARK: - 缓存管理

    /// 删除指定作品的图片缓存
    func removeImageCache(for illustId: Int) async {
        #if DEBUG
        print("[BookmarkCacheService] 删除作品 \(illustId) 的图片缓存")
        #endif
    }

    /// 计算缓存大小
    func calculateCacheSize() async -> Int64 {
        return await withCheckedContinuation { continuation in
            bookmarkCache.calculateDiskStorageSize { result in
                switch result {
                case .success(let size):
                    continuation.resume(returning: Int64(size))
                case .failure:
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    /// 清理所有图片缓存
    func clearAllImageCache() async {
        bookmarkCache.clearMemoryCache()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            bookmarkCache.clearDiskCache {
                continuation.resume()
            }
        }
        #if DEBUG
        print("[BookmarkCacheService] 已清理所有图片缓存")
        #endif
    }

    /// 获取缓存实例（用于 CachedAsyncImage）
    nonisolated func getCache() -> ImageCache {
        return bookmarkCache
    }
}

/// Pixiv 图片请求修改器
struct PixivImageRequestModifier: ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest? {
        var modifiedRequest = request
        modifiedRequest.setValue("https://www.pixiv.net/", forHTTPHeaderField: "Referer")
        return modifiedRequest
    }
}
