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
    @State private var targetLoaded = false

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
                    .onAppear {
                        loadBestAvailableImage()
                    }
            }
        }
        .aspectRatio(aspectRatio, contentMode: contentMode)
        .clipped()
        .onChange(of: targetURL) { _, newURL in
            guard newURL != displayedURL else { return }
            targetLoaded = false
            isLoadingTarget = false
            displayedURL = nil
            loadBestAvailableImage()
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
                .fade(duration: targetLoaded ? 0.3 : 0.5)
                .cacheOriginalImage()
                .requestModifier(PixivImageLoader.shared)
                .diskCacheExpiration(expiration.kingfisherExpiration)
                .memoryCacheExpiration(expiration.kingfisherExpiration)
                .onSuccess { result in
                    onSizeChange?(CGSize(width: result.image.size.width, height: result.image.size.height))
                    if url == targetURL {
                        targetLoaded = true
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
            image = KFImage.source(.directNetwork(url))
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

    private func loadBestAvailableImage() {
        if isCached(url: targetURL) {
            displayedURL = targetURL
            targetLoaded = true
            return
        }

        for fallbackURL in fallbackURLs where isCached(url: fallbackURL) {
            displayedURL = fallbackURL
            break
        }

        if displayedURL == nil {
            displayedURL = targetURL
        }

        if displayedURL != targetURL {
            isLoadingTarget = true
            loadTargetImage()
        }
    }

    private func isCached(url: String) -> Bool {
        guard let validURL = URL(string: url), !url.isEmpty else { return false }
        let cacheKey = validURL.absoluteString
        return ImageCache.default.isCached(forKey: cacheKey)
    }

    private func loadTargetImage() {
        guard let validURL = URL(string: targetURL), !targetURL.isEmpty else { return }

        let source: Kingfisher.Source
        if shouldUseDirectConnection(url: validURL) {
            source = .directNetwork(validURL)
        } else {
            source = .network(KF.ImageResource(downloadURL: validURL))
        }

        let options: KingfisherOptionsInfo = [
            .cacheOriginalImage,
            .diskCacheExpiration(expiration.kingfisherExpiration),
            .memoryCacheExpiration(expiration.kingfisherExpiration),
            .requestModifier(PixivImageLoader.shared)
        ]

        KingfisherManager.shared.retrieveImage(with: source, options: options) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    withAnimation(.easeInOut(duration: 0.3)) {
                        displayedURL = targetURL
                        targetLoaded = true
                        isLoadingTarget = false
                    }
                case .failure:
                    isLoadingTarget = false
                }
            }
        }
    }
}

struct ProgressiveMultiPageAsyncImage: View {
    let illust: Illusts
    let targetQuality: Int
    let currentPage: Int
    let aspectRatio: CGFloat?
    let expiration: CacheExpiration
    let onSizeChange: ((CGSize) -> Void)?

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
            expiration: expiration,
            onSizeChange: onSizeChange
        )
    }
}
