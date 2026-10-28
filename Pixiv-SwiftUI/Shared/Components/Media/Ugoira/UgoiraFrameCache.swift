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
enum UgoiraFrameCache {
    static func load(
        frameURLs: [URL],
        targetSize: CGSize,
        displayScale: CGFloat,
        expiration: CacheExpiration
    ) async -> [KFCrossPlatformImage]? {
        guard !frameURLs.isEmpty, targetSize.width > 0, targetSize.height > 0 else {
            return []
        }

        let options: KingfisherOptionsInfo = [
            .processor(PixivDownsamplingImageProcessor(size: targetSize)),
            .scaleFactor(max(displayScale, 1)),
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration)
        ]

        var frames: [KFCrossPlatformImage] = []
        frames.reserveCapacity(frameURLs.count)

        for url in frameURLs {
            guard !Task.isCancelled else { return nil }

            if url.isFileURL {
                guard let image = loadLocalFrame(
                    from: url,
                    targetSize: targetSize,
                    displayScale: displayScale
                ) else {
                    return nil
                }
                frames.append(image)
                continue
            }

            let source = Source.pixivNetwork(url)
            guard let result = try? await KingfisherManager.shared.retrieveImage(
                with: source,
                options: options
            ) else {
                return nil
            }
            frames.append(result.image)
        }

        return frames
    }

    private static func loadLocalFrame(
        from url: URL,
        targetSize: CGSize,
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

        let maxPixelSize = max(targetSize.width, targetSize.height) * max(displayScale, 1)
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
                width: targetSize.width,
                height: targetSize.height
            )
        )
        #endif
    }
}
