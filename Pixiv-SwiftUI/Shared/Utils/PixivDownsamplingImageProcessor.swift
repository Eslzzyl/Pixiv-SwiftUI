import Foundation
import CoreGraphics
import Kingfisher

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PixivDownsamplingImageProcessor: ImageProcessor, Sendable {
    let size: CGSize

    nonisolated init(size: CGSize) {
        self.size = size
    }

    nonisolated var identifier: String {
        DownsamplingImageProcessor(size: size).identifier
    }

    nonisolated func process(
        item: ImageProcessItem,
        options: KingfisherParsedOptionsInfo
    ) -> KFCrossPlatformImage? {
        let fallback = DownsamplingImageProcessor(size: size)

        switch item {
        case .data:
            return fallback.process(item: item, options: options)
        case .image(let image):
            guard (image.kf.imageFrameCount ?? 1) <= 1 else {
                return fallback.process(item: item, options: options)
            }
            #if canImport(UIKit)
            guard image.images == nil || image.images?.count == 1 else {
                return fallback.process(item: item, options: options)
            }
            #endif
            #if canImport(UIKit)
            guard image.cgImage != nil else {
                return fallback.process(item: item, options: options)
            }
            let sourceScale = image.scale
            let sourcePixelSize = CGSize(
                width: image.size.width * sourceScale,
                height: image.size.height * sourceScale
            )
            #else
            guard let sourceCGImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return fallback.process(item: item, options: options)
            }
            let sourceScale: CGFloat = 1
            let sourcePixelSize = CGSize(width: sourceCGImage.width, height: sourceCGImage.height)
            #endif
            let targetLongestEdge = max(size.width, size.height) * options.scaleFactor
            let sourceLongestEdge = max(sourcePixelSize.width, sourcePixelSize.height)
            guard sourceLongestEdge > 0, targetLongestEdge > 0 else {
                return fallback.process(item: item, options: options)
            }

            let scaleFactor = min(1, targetLongestEdge / sourceLongestEdge)
            let outputPixelSize = CGSize(
                width: max(1, sourcePixelSize.width * scaleFactor),
                height: max(1, sourcePixelSize.height * scaleFactor)
            )
            let drawSize = CGSize(
                width: outputPixelSize.width / sourceScale,
                height: outputPixelSize.height / sourceScale
            )
            let resized = image.kf.resize(to: drawSize)
            #if os(macOS)
            let renderedCGImage = resized.cgImage(forProposedRect: nil, context: nil, hints: nil)
            #else
            guard resized.imageOrientation == .up else {
                return fallback.process(item: item, options: options)
            }
            let renderedCGImage = resized.cgImage
            #endif
            guard let renderedCGImage,
                  abs(CGFloat(renderedCGImage.width) - outputPixelSize.width) <= 1,
                  abs(CGFloat(renderedCGImage.height) - outputPixelSize.height) <= 1
            else {
                return fallback.process(item: item, options: options)
            }
            #if os(macOS)
            return NSImage(cgImage: renderedCGImage, size: .zero)
            #else
            return UIImage(cgImage: renderedCGImage, scale: options.scaleFactor, orientation: .up)
            #endif
        }
    }
}
