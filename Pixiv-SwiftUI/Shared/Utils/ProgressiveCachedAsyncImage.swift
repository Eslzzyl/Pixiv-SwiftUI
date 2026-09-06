import Foundation
import SwiftUI
import Kingfisher

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private typealias KFImage = Kingfisher.KFImage

struct ProgressiveCachedAsyncImage: View {
    let targetURL: String
    let fallbackURLs: [String]
    let aspectRatio: CGFloat?
    let contentMode: SwiftUI.ContentMode
    let idealWidth: CGFloat?
    let expiration: CacheExpiration
    let onSizeChange: ((CGSize) -> Void)?

    @State private var displayedURL: String?
    @State private var isLoadingTarget = false
    @State private var animateDisplayedImage = true

    init(
        targetURL: String,
        fallbackURLs: [String] = [],
        aspectRatio: CGFloat? = nil,
        contentMode: SwiftUI.ContentMode = .fit,
        idealWidth: CGFloat? = nil,
        expiration: CacheExpiration? = nil,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        self.targetURL = targetURL
        self.fallbackURLs = fallbackURLs
        self.aspectRatio = aspectRatio
        self.contentMode = contentMode
        self.idealWidth = idealWidth
        self.expiration = expiration ?? .days(7)
        self.onSizeChange = onSizeChange
    }

    var body: some View {
        Group {
            if let displayedURL = displayedURL {
                cachedImage(url: displayedURL, isTarget: displayedURL == targetURL)
            } else {
                placeholderView
            }
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .clipped()
        .task(id: targetURL) {
            let hasDisplayedImage = displayedURL != nil
            isLoadingTarget = false
            animateDisplayedImage = !hasDisplayedImage
            if !hasDisplayedImage {
                displayedURL = nil
            }
            await loadBestAvailableImage()
        }
    }

    @ViewBuilder
    private func cachedImage(url: String, isTarget: Bool) -> some View {
        if let validURL = URL(string: url), !url.isEmpty {
            buildKFImage(url: validURL)
                .placeholder {
                    if isTarget {
                        placeholderView
                    } else {
                        placeholderView
                            .overlay {
                                if isLoadingTarget {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                    }
                }
                .fade(duration: animateDisplayedImage ? 0.5 : 0)
                .cacheOriginalImage()
                .downloadPriority(ImageRequestPriority.visible)
                .requestModifier(PixivImageLoader.shared)
                .diskCacheExpiration(expiration.kingfisherExpiration)
                .memoryCacheExpiration(expiration.kingfisherExpiration)
                .onSuccess { result in
                    onSizeChange?(CGSize(width: result.image.size.width, height: result.image.size.height))
                    if url == targetURL {
                        isLoadingTarget = false
                    }
                }
                .resizable()
        } else {
            placeholderView
        }
    }

    private func buildKFImage(url: URL) -> KFImage {
        let image: KFImage
        if shouldUseDirectConnection(url: url) {
            image = KFImage.source(.directNetwork(url, priority: ImageRequestPriority.visible))
        } else {
            image = KFImage.source(.network(url))
        }

        if let processor = downsamplingProcessor {
            return image.setProcessor(processor)
        }
        return image
    }

    private var downsamplingProcessor: DownsamplingImageProcessor? {
        guard let idealWidth, idealWidth > 0 else { return nil }

        let scale: CGFloat
#if canImport(UIKit)
        scale = UIScreen.main.scale
#elseif canImport(AppKit)
        scale = NSScreen.main?.backingScaleFactor ?? 2
#else
        scale = 2
#endif

        let targetWidth = idealWidth * scale
        let safeAspectRatio = aspectRatio.flatMap { $0 > 0 && $0.isFinite ? $0 : nil } ?? 1
        let targetHeight = targetWidth / safeAspectRatio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        guard targetSize.width >= 50, targetSize.height >= 50 else { return nil }
        return DownsamplingImageProcessor(size: targetSize)
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    @ViewBuilder
    private var placeholderView: some View {
        let safeAspectRatio = (aspectRatio ?? 0) > 0 ? (aspectRatio ?? 1.0) : 1.0
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(safeAspectRatio, contentMode: .fill)
    }

    private func loadBestAvailableImage() async {
        guard !targetURL.isEmpty else { return }

        if isCached(url: targetURL) {
            animateDisplayedImage = displayedURL == nil
            displayedURL = targetURL
            return
        }

        if let cachedFallbackURL = fallbackURLs.first(where: { isCached(url: $0) }) {
            guard !Task.isCancelled else { return }
            animateDisplayedImage = displayedURL == nil
            displayedURL = cachedFallbackURL
            isLoadingTarget = true
            await loadTargetImage()
            return
        }

        guard !Task.isCancelled else { return }
        if displayedURL == nil {
            animateDisplayedImage = true
            displayedURL = targetURL
        } else {
            isLoadingTarget = true
            await loadTargetImage()
        }
    }

    private func isCached(url: String) -> Bool {
        guard let validURL = URL(string: url), !url.isEmpty else { return false }
        let cacheKey = validURL.absoluteString
        return ImageCache.default.isCached(forKey: cacheKey)
    }

    private func loadTargetImage() async {
        guard !targetURL.isEmpty, URL(string: targetURL) != nil else { return }
        guard !Task.isCancelled else { return }

        guard await loadImage(urlString: targetURL) else {
            guard !Task.isCancelled else { return }
            isLoadingTarget = false
            return
        }

        guard !Task.isCancelled else { return }
        animateDisplayedImage = false
        displayedURL = targetURL
        isLoadingTarget = false
    }

    private func loadImage(urlString: String) async -> Bool {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return false }

        do {
            let source = imageSource(for: url)
            let cacheKey = source.cacheKey
            await MainActor.run {
                ImagePrefetchCoordinator.shared.removePending(cacheKey: cacheKey)
            }
            _ = try await KingfisherManager.shared.retrieveImage(
                with: source,
                options: imageLoadingOptions
            )
            return true
        } catch {
            return false
        }
    }

    private var imageLoadingOptions: KingfisherOptionsInfo {
        var options: KingfisherOptionsInfo = [
            .cacheOriginalImage,
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration),
            .requestModifier(PixivImageLoader.shared),
            .asyncCacheTypeCheck,
            .downloadPriority(ImageRequestPriority.visible)
        ]
        if let processor = downsamplingProcessor {
            options.append(.processor(processor))
        }
        return options
    }

    private func imageSource(for url: URL) -> Kingfisher.Source {
        if shouldUseDirectConnection(url: url) {
            return .directNetwork(url, priority: ImageRequestPriority.visible)
        }
        return .network(KF.ImageResource(downloadURL: url))
    }
}

struct ProgressiveMultiPageAsyncImage: View {
    let illust: Illusts
    let targetQuality: Int
    let currentPage: Int
    let aspectRatio: CGFloat?
    let idealWidth: CGFloat?
    let expiration: CacheExpiration
    let onSizeChange: ((CGSize) -> Void)?

    init(
        illust: Illusts,
        targetQuality: Int,
        currentPage: Int,
        aspectRatio: CGFloat?,
        idealWidth: CGFloat? = nil,
        expiration: CacheExpiration,
        onSizeChange: ((CGSize) -> Void)? = nil
    ) {
        self.illust = illust
        self.targetQuality = targetQuality
        self.currentPage = currentPage
        self.aspectRatio = aspectRatio
        self.idealWidth = idealWidth
        self.expiration = expiration
        self.onSizeChange = onSizeChange
    }

    var body: some View {
        let targetURL = ImageURLHelper.getPageImageURL(from: illust, page: currentPage, quality: targetQuality) ?? ""
        let fallbackURLs = ImageQualityHelper.getLowerQualityPageURLs(
            from: illust,
            targetQuality: targetQuality,
            page: currentPage
        )

        ProgressiveCachedAsyncImage(
            targetURL: targetURL,
            fallbackURLs: fallbackURLs,
            aspectRatio: aspectRatio,
            contentMode: .fit,
            idealWidth: idealWidth,
            expiration: expiration,
            onSizeChange: onSizeChange
        )
    }
}
