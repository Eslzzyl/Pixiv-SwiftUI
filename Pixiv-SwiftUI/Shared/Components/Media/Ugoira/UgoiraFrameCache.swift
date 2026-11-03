import CoreGraphics
import Foundation
import ImageIO
import Kingfisher

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
final class UgoiraFrameCache {
    static let shared = UgoiraFrameCache()
    private let cache = NSCache<NSString, NSArray>()

    private init() {
        cache.countLimit = 5
    }

    func load(
        frameURLs: [URL],
        targetSize: CGSize,
        displayScale: CGFloat,
        expiration: CacheExpiration
    ) async -> [KFCrossPlatformImage]? {
        guard !frameURLs.isEmpty, targetSize.width > 0, targetSize.height > 0 else {
            return []
        }

        let maxDim = max(targetSize.width, targetSize.height) * max(displayScale, 1)
        let pixelBucket = max(1, Int((maxDim / 32.0).rounded(.up)) * 32)
        let cacheKey = "\(frameURLs.first?.path ?? "")_\(pixelBucket)" as NSString

        if let cached = cache.object(forKey: cacheKey) as? [KFCrossPlatformImage],
           cached.count == frameURLs.count {
            return cached
        }

        let options: KingfisherOptionsInfo = [
            .processor(PixivDownsamplingImageProcessor(size: targetSize)),
            .scaleFactor(max(displayScale, 1)),
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration)
        ]

        let frames = await withTaskGroup(
            of: (Int, KFCrossPlatformImage?).self,
            returning: [KFCrossPlatformImage]?.self
        ) { group in
            for (index, url) in frameURLs.enumerated() {
                group.addTask {
                    if Task.isCancelled { return (index, nil) }

                    if url.isFileURL {
                        let image = Self.loadLocalFrame(
                            from: url,
                            maxPixelSize: CGFloat(pixelBucket),
                            displayScale: displayScale
                        )
                        return (index, image)
                    }

                    let source = Source.pixivNetwork(url)
                    let result = try? await KingfisherManager.shared.retrieveImage(
                        with: source,
                        options: options
                    )
                    return (index, result?.image)
                }
            }

            var indexedFrames: [(Int, KFCrossPlatformImage)] = []
            indexedFrames.reserveCapacity(frameURLs.count)

            for await (index, image) in group {
                guard let image else { return nil }
                indexedFrames.append((index, image))
            }

            guard indexedFrames.count == frameURLs.count else { return nil }
            return indexedFrames.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        if let frames, frames.count == frameURLs.count {
            cache.setObject(frames as NSArray, forKey: cacheKey)
            return frames
        }

        return nil
    }

    private static nonisolated func loadLocalFrame(
        from url: URL,
        maxPixelSize: CGFloat,
        displayScale: CGFloat
    ) -> KFCrossPlatformImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            sourceOptions as CFDictionary
        ) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixelSize.rounded(.up))),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            return nil
        }

        #if os(iOS)
        return UIImage(cgImage: cgImage, scale: max(displayScale, 1), orientation: .up)
        #else
        return NSImage(
            cgImage: cgImage,
            size: NSSize(
                width: maxPixelSize / max(displayScale, 1),
                height: maxPixelSize / max(displayScale, 1)
            )
        )
        #endif
    }
}
