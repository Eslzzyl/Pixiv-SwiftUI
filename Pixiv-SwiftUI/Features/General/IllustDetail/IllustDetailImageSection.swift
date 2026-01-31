import SwiftUI
import Kingfisher

#if os(macOS)
import AppKit
#endif

struct IllustDetailImageSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    @Binding var isFullscreen: Bool
    let animation: Namespace.ID

    @Binding var currentPage: Int
    var containerWidth: CGFloat?
    var minContainerHeight: CGFloat?
    var currentAspectRatio: Binding<CGFloat>?
    var disableAspectRatioAnimation: Bool = false
    @State private var pageSizes: [Int: CGSize] = [:]
    @State private var currentAspectRatioValue: CGFloat = 0

#if os(macOS)
    @State private var isHoveringImage = false
#endif

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    private var isUgoira: Bool {
        illust.type == "ugoira"
    }

    private var isManga: Bool {
        illust.type == "manga"
    }

    private var imageURLs: [String] {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    var body: some View {
        if isMultiPage {
            multiPageImageSection
        } else {
            singlePageImageSection
        }
    }

    private var effectiveAspectRatio: CGFloat {
        currentAspectRatioValue > 0 ? currentAspectRatioValue : illust.safeAspectRatio
    }

    private var fixedContainerHeight: CGFloat? {
        guard let containerWidth, let minContainerHeight else { return nil }
        let desiredHeight = containerWidth / max(effectiveAspectRatio, 0.1)
        return max(desiredHeight, minContainerHeight)
    }

    private var singlePageImageSection: some View {
        Group {
            if isUgoira {
                UgoiraLoader(illust: illust)
            } else {
                standardImageSection
                    .onTapGesture {
                        #if os(macOS)
                        let zoomURL = ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.zoomQuality)
                        ImageViewerWindowManager.shared.showSingleImage(
                            illust: illust,
                            url: zoomURL,
                            title: illust.title,
                            aspectRatio: illust.safeAspectRatio
                        )
                        #else
                        withAnimation(.spring()) {
                            isFullscreen = true
                        }
                        #endif
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var standardImageSection: some View {
        CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: 2),
            aspectRatio: illust.safeAspectRatio,
            contentMode: .fill,
            expiration: DefaultCacheExpiration.illustDetail
        )
    }

    private var multiPageImageSection: some View {
        Group {
            let containerHeight = fixedContainerHeight
            ZStack {
            #if os(macOS)
            if imageURLs.indices.contains(currentPage) {
                pageImage(url: imageURLs[currentPage], index: currentPage, containerHeight: containerHeight)
                    .frame(width: containerWidth)
                    .id(currentPage)
            }
            #else
            TabView(selection: $currentPage) {
                ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                    pageImage(url: url, index: index, containerHeight: nil)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif

            #if os(macOS)
            if isMultiPage {
                MacOSPageNavigationOverlay(
                    currentPage: $currentPage,
                    totalPages: imageURLs.count,
                    isHovering: isHoveringImage
                )
                .padding(.horizontal, 16)
            }
            #endif
            }
        }
        #if os(macOS)
        .onHover { hovering in
            isHoveringImage = hovering
        }
        #endif
        .frame(maxWidth: .infinity)
        .frame(width: containerWidth, height: fixedContainerHeight)
        .aspectRatio(containerWidth == nil ? effectiveAspectRatio : nil, contentMode: .fit)
        .onAppear {
            currentAspectRatioValue = illust.safeAspectRatio
            currentAspectRatio?.wrappedValue = illust.safeAspectRatio
        }
        .onChange(of: currentPage) { _, newPage in
            updateAspectRatio(for: newPage)
        }
        .overlay(alignment: .bottomTrailing) {
            pageIndicator
        }
    }

    private func pageImage(url: String, index: Int, containerHeight: CGFloat?) -> some View {
        DynamicSizeCachedAsyncImage(
            urlString: url,
            placeholder: nil,
            aspectRatio: aspectRatioForPage(index),
            contentMode: .fill,
            onSizeChange: { size in
                handleSizeChange(size: size, for: index)
            },
            expiration: DefaultCacheExpiration.illustDetail
        )
        .frame(height: containerHeight)
        .onTapGesture {
            #if os(macOS)
            openImageViewerWindow(initialPage: index)
            #else
            withAnimation(.spring()) {
                isFullscreen = true
            }
            #endif
        }
    }

    #if os(macOS)
    private func openImageViewerWindow(initialPage: Int) {
        let quality = userSettingStore.userSetting.zoomQuality
        let zoomURLs = illust.metaPages.indices.compactMap { pageIndex in
            ImageURLHelper.getPageImageURL(from: illust, page: pageIndex, quality: quality)
        }
        let aspectRatios = illust.metaPages.indices.map { pageIndex in
            if let size = pageSizes[pageIndex], size.width > 0 && size.height > 0 {
                return size.width / size.height
            }
            return illust.safeAspectRatio
        }

        ImageViewerWindowManager.shared.showMultiImages(
            illust: illust,
            urls: zoomURLs,
            initialPage: initialPage,
            title: illust.title,
            aspectRatios: aspectRatios
        )
    }
    #endif

    private func handleSizeChange(size: CGSize, for index: Int) {
        guard size.width > 0 && size.height > 0 else { return }
        pageSizes[index] = size
        if index == currentPage {
            let ratio = size.width / size.height
            currentAspectRatioValue = ratio
            currentAspectRatio?.wrappedValue = ratio
        }
    }

    private func aspectRatioForPage(_ page: Int) -> CGFloat {
        if let size = pageSizes[page], size.width > 0 && size.height > 0 {
            return size.width / size.height
        }
        return illust.safeAspectRatio
    }

    private func updateAspectRatio(for page: Int) {
        let newRatio = aspectRatioForPage(page)
        if newRatio != currentAspectRatioValue {
            if disableAspectRatioAnimation {
                currentAspectRatioValue = newRatio
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentAspectRatioValue = newRatio
                }
            }
            currentAspectRatio?.wrappedValue = newRatio
        }
    }

    private var pageIndicator: some View {
        Text("\(currentPage + 1) / \(imageURLs.count)")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .padding(8)
    }
}
