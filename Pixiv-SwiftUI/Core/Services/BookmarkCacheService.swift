import Foundation
import Kingfisher
import os.log

/// 收藏缓存图片服务
actor BookmarkCacheService {
    static let shared = BookmarkCacheService()

    /// 独立的图片缓存命名空间，nil 时回退到 Kingfisher 默认缓存
    private let bookmarkCache: ImageCache?

    /// 缓存目录名称
    private let cacheName = "BookmarkImageCache"

    private init() {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let cacheDirectory {
            let bookmarkCacheDirectory = cacheDirectory.appendingPathComponent(cacheName)
            try? FileManager.default.createDirectory(at: bookmarkCacheDirectory, withIntermediateDirectories: true)

            if let cache = try? ImageCache(name: cacheName, cacheDirectoryURL: bookmarkCacheDirectory) {
                cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024
                cache.diskStorage.config.sizeLimit = 0
                cache.diskStorage.config.expiration = .never
                self.bookmarkCache = cache
                return
            }
            Logger.cache.error("无法创建图片缓存目录: \(bookmarkCacheDirectory.path)")
        } else {
            Logger.cache.error("无法获取缓存目录")
        }

        // 回退到 Kingfisher 默认缓存，避免 fatalError 导致崩溃
        self.bookmarkCache = nil
    }

    // MARK: - 预取图片

    /// 预取作品图片
    func preloadImages(urls: [String]) async throws {
        for urlString in urls {
            try await preloadSingleImage(urlString: urlString)
        }
    }

    /// 预取单张图片
    private func preloadSingleImage(urlString: String) async throws {
        guard let url = URL(string: urlString) else { return }

        let resource = KF.ImageResource(downloadURL: url)
        let key = resource.cacheKey

        // 检查是否已缓存
        if let cache = bookmarkCache, cache.isCached(forKey: key) {
            Logger.cache.debug("已缓存，跳过: \(urlString.suffix(50))")
            return
        }

        var options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageRequestModifier()),
            .cacheOriginalImage,
            .diskCacheExpiration(.never),
            .memoryCacheExpiration(.never),
        ]
        if let cache = bookmarkCache {
            options.append(.targetCache(cache))
        }

        let source: Source
        if await shouldUseDirectConnection(url: url) {
            source = await MainActor.run { .directNetwork(url) }
        } else {
            source = .network(resource)
        }

        do {
            _ = try await KingfisherManager.shared.retrieveImage(
                with: source,
                options: options
            )
            Logger.cache.info("预取成功: \(urlString.suffix(50))")
        } catch {
            Logger.cache.error("预取失败: \(error.localizedDescription)")
            throw error
        }
    }

    private func shouldUseDirectConnection(url: URL) async -> Bool {
        guard let host = url.host else { return false }
        let useDirect = await MainActor.run { NetworkModeStore.shared.useDirectConnection }
        return useDirect &&
               PixivNetworkConfiguration.isPixivImageHost(host)
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
        guard let cache = bookmarkCache, let url = URL(string: urlString) else { return false }
        let key = url.cacheKey
        return cache.isCached(forKey: key)
    }

    /// 获取缓存的图片
    func getCachedImage(urlString: String) async -> KFCrossPlatformImage? {
        guard let cache = bookmarkCache, let url = URL(string: urlString) else { return nil }
        let key = url.cacheKey

        return await withCheckedContinuation { continuation in
            cache.retrieveImage(forKey: key) { result in
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
        var options: KingfisherOptionsInfo = [
            .cacheOriginalImage,
            .diskCacheExpiration(.never),
            .memoryCacheExpiration(.never),
            .requestModifier(PixivImageRequestModifier()),
        ]
        if let cache = bookmarkCache {
            options.append(.targetCache(cache))
        }
        return options
    }

    // MARK: - 缓存管理

    /// 删除指定作品的图片缓存
    func removeImageCache(for illustId: Int) async {
        Logger.cache.debug("删除作品 \(illustId) 的图片缓存")
    }

    /// 计算缓存大小
    func calculateCacheSize() async -> Int64 {
        guard let cache = bookmarkCache else { return 0 }
        return await withCheckedContinuation { continuation in
            cache.calculateDiskStorageSize { result in
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
        if let cache = bookmarkCache {
            cache.clearMemoryCache()
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                cache.clearDiskCache {
                    continuation.resume()
                }
            }
        }
        Logger.cache.debug("已清理所有图片缓存")
    }

    /// 获取缓存实例（用于 CachedAsyncImage）
    nonisolated func getCache() -> ImageCache? {
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
