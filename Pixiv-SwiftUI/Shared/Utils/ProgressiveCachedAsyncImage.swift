import Foundation
import SwiftUI
import Kingfisher

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProgressiveCachedAsyncImage: View {
    let targetURL: String
    let fallbackURLs: [String]
    let aspectRatio: CGFloat?
    let contentMode: SwiftUI.ContentMode
    let idealWidth: CGFloat?
    let expiration: CacheExpiration
    let onSizeChange: ((CGSize) -> Void)?

    @State private var displayedURL: String?
    @State private var animateDisplayedImage = true
    @State private var loadedImage: KFCrossPlatformImage?
    @State private var loadedImageURL: String?
    @Environment(\.displayScale) private var displayScale

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
        let cachedURL = Self.cachedCandidateURL(targetURL: targetURL, fallbackURLs: fallbackURLs)
        _displayedURL = State(initialValue: cachedURL)
    }

    var body: some View {
        ZStack {
            if let loadedImage {
                #if canImport(UIKit)
                Image(uiImage: loadedImage)
                    .resizable()
                    .transition(animateDisplayedImage ? .opacity : .identity)
                #elseif canImport(AppKit)
                Image(nsImage: loadedImage)
                    .resizable()
                    .transition(animateDisplayedImage ? .opacity : .identity)
                #endif
            } else {
                placeholderView
            }
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .clipped()
        .task(id: targetURL) {
            let isSameImage: Bool
            if let displayedURL {
                isSameImage = imageCandidates.contains(displayedURL)
            } else {
                isSameImage = false
            }
            if !isSameImage {
                displayedURL = Self.cachedCandidateURL(
                    targetURL: targetURL,
                    fallbackURLs: fallbackURLs
                )
            }
            let hasDisplayedImage = displayedURL != nil
            animateDisplayedImage = !hasDisplayedImage
            await loadBestAvailableImage()
        }
    }

    private var downsamplingProcessor: DownsamplingImageProcessor? {
        guard let idealWidth, idealWidth > 0 else { return nil }

        let scale = displayScale > 0 ? displayScale : 2.0

        let targetWidth = idealWidth * scale
        let safeAspectRatio = aspectRatio.flatMap { $0 > 0 && $0.isFinite ? $0 : nil } ?? 1
        let targetHeight = targetWidth / safeAspectRatio
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        guard targetSize.width >= 50, targetSize.height >= 50 else { return nil }
        return DownsamplingImageProcessor(size: targetSize)
    }

    private var imageCandidates: [String] {
        var seenURLs = Set<String>()
        return ([targetURL] + fallbackURLs).filter { url in
            guard !url.isEmpty, URL(string: url) != nil else { return false }
            return seenURLs.insert(url).inserted
        }
    }

    private static func cachedCandidateURL(targetURL: String, fallbackURLs: [String]) -> String? {
        var seenURLs = Set<String>()

        for url in [targetURL] + fallbackURLs {
            guard !url.isEmpty,
                  let validURL = URL(string: url),
                  seenURLs.insert(url).inserted,
                  ImageCache.default.isCached(forKey: validURL.absoluteString) else {
                continue
            }
            return url
        }

        return nil
    }

    @ViewBuilder
    private var placeholderView: some View {
        let safeAspectRatio = (aspectRatio ?? 0) > 0 ? (aspectRatio ?? 1.0) : 1.0
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .aspectRatio(safeAspectRatio, contentMode: .fill)
    }

    private func loadBestAvailableImage() async {
        let candidates = imageCandidates
        guard !candidates.isEmpty else { return }
        let hasDisplayedImage = loadedImage != nil

        if hasDisplayedImage {
            guard displayedURL != targetURL || loadedImageURL != targetURL else {
                return
            }

            await loadFirstAvailableImage(from: candidates[...])
            return
        }

        if let cachedIndex = candidates.firstIndex(where: { isCached(url: $0) }) {
            let cachedURL = candidates[cachedIndex]
            guard let image = await loadImage(urlString: cachedURL) else {
                await loadFirstAvailableImage(from: candidates[...])
                return
            }
            guard !Task.isCancelled else { return }

            animateDisplayedImage = true
            applyLoadedImage(image, url: cachedURL)
            displayedURL = cachedURL

            guard cachedIndex > 0 else {
                return
            }

            await loadFirstAvailableImage(from: candidates[..<cachedIndex])
            return
        }

        guard !Task.isCancelled else { return }
        animateDisplayedImage = true
        await loadFirstAvailableImage(from: candidates[...])
    }

    private func isCached(url: String) -> Bool {
        guard let validURL = URL(string: url), !url.isEmpty else { return false }
        let cacheKey = validURL.absoluteString
        return ImageCache.default.isCached(forKey: cacheKey)
    }

    private func applyLoadedImage(_ image: KFCrossPlatformImage, url: String) {
        let shouldReportSize = loadedImage == nil || url == targetURL
        loadedImage = image
        loadedImageURL = url
        if shouldReportSize {
            onSizeChange?(CGSize(width: image.size.width, height: image.size.height))
        }
    }

    private func loadFirstAvailableImage(from candidates: ArraySlice<String>) async {
        for url in candidates {
            guard !Task.isCancelled else { return }

            if let image = await loadImage(urlString: url) {
                guard !Task.isCancelled else { return }
                animateDisplayedImage = false
                applyLoadedImage(image, url: url)
                displayedURL = url
                return
            }
        }

    }

    private func loadImage(urlString: String) async -> KFCrossPlatformImage? {
        guard let url = URL(string: urlString), !urlString.isEmpty else { return nil }

        do {
            let source = imageSource(for: url)
            let cacheKey = source.cacheKey
            await MainActor.run {
                ImagePrefetchCoordinator.shared.removePending(cacheKey: cacheKey)
            }
            let result = try await KingfisherManager.shared.retrieveImage(
                with: source,
                options: imageLoadingOptions
            )
            return result.image
        } catch {
            return nil
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
        .pixivNetwork(url, priority: ImageRequestPriority.visible)
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
