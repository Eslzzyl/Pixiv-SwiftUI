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
    var isCurrent: Bool = true
    var containerWidth: CGFloat?
    var minContainerHeight: CGFloat?
    var currentAspectRatio: Binding<CGFloat>?
    var disableAspectRatioAnimation: Bool = false
    var onImageFrameChange: ((CGRect) -> Void)?
    var ugoiraStore: UgoiraStore?
    @State private var pageSizes: [Int: CGSize] = [:]
    @State private var currentAspectRatioValue: CGFloat = 0
    @State private var showTranslation = false
    @State private var translationStore = ImageTranslationStore()

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

    private var isStripMode: Bool {
        userSettingStore.userSetting.multiPageBrowseMode == 1
    }

    private var displayQuality: Int {
        isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
    }

    private var imageURLs: [String] {
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: displayQuality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: displayQuality)]
    }

    var body: some View {
        Group {
            if isMultiPage {
                if isStripMode {
                    multiPageStripSection
                } else {
                    multiPageImageSection
                }
            } else {
                singlePageImageSection
            }
        }
        .contextMenu {
            Button(action: translateCurrentImage) {
                Label("翻译图片", systemImage: "text.bubble")
            }
            if userSettingStore.userSetting.vlmEnabled {
                Button(action: explainCurrentImage) {
                    Label("解释图片", systemImage: "wand.and.stars")
                }
            }
        }
        .sheet(isPresented: $showTranslation) {
            ImageTranslationPanelView(store: translationStore) {
                showTranslation = false
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }

    private var effectiveAspectRatio: CGFloat {
        currentAspectRatioValue > 0 ? currentAspectRatioValue : illust.safeAspectRatio
    }

    private var fixedContainerHeight: CGFloat? {
        guard let containerWidth else { return nil }
        let desiredHeight = containerWidth / max(effectiveAspectRatio, 0.1)
        if let minContainerHeight {
            return max(desiredHeight, minContainerHeight)
        }
        return desiredHeight
    }

    private var singlePageImageSection: some View {
        ZStack {
            Group {
                if isUgoira, let store = ugoiraStore {
                    UgoiraLoader(illust: illust, store: store, isFullscreen: $isFullscreen)
                        #if os(iOS)
                        .reportImageFrame(when: isCurrent)
                        #endif
                } else {
                    Button(action: openSinglePageImage) {
                        #if os(iOS)
                        standardImageSection
                            .reportImageFrame(when: isCurrent)
                        #else
                        standardImageSection
                        #endif
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "查看大图"))
                }
            }
            #if os(iOS)
            .opacity(isFullscreen ? 0 : 1)
            #endif
        }
        .frame(maxWidth: containerWidth ?? .infinity)
        .clipped()
    }

    private var standardImageSection: some View {
        let targetURL = ImageURLHelper.getImageURL(
            from: illust,
            quality: displayQuality,
            isPicture: !isManga
        )
        let fallbackURLs = ImageQualityHelper.getLowerQualityURLs(
            from: illust,
            targetQuality: displayQuality,
            isManga: isManga
        )

        return ProgressiveCachedAsyncImage(
            targetURL: targetURL,
            fallbackURLs: fallbackURLs,
            aspectRatio: illust.safeAspectRatio,
            contentMode: .fit,
            expiration: DefaultCacheExpiration.illustDetail
        )
    }

    private var multiPageImageSection: some View {
        Group {
            let containerHeight = fixedContainerHeight
            ZStack {
                #if os(macOS)
                if imageURLs.indices.contains(currentPage) {
                    pageImage(page: currentPage, containerHeight: containerHeight)
                        .frame(width: containerWidth)
                        .id(currentPage)
                }
                #else
                TabView(selection: $currentPage) {
                    ForEach(0..<imageURLs.count, id: \.self) { index in
                        ZStack {
                            if abs(index - currentPage) <= 2 {
                                pageImage(page: index, containerHeight: nil)
                                    // 只在当前插画的当前页上报告 frame，避免多页或邻近插画同时上报导致 PreferenceKey 取到错误的值
                                    .reportImageFrame(when: isCurrent && index == currentPage)
                            } else {
                                Color.clear
                            }
                        }
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
                }

                #endif
            }
        }
        #if os(macOS)
        .onHover { hovering in
            isHoveringImage = hovering
        }
        #endif
        .frame(maxWidth: containerWidth ?? .infinity)
        .frame(width: containerWidth, height: fixedContainerHeight)
        .aspectRatio(containerWidth == nil ? effectiveAspectRatio : nil, contentMode: .fit)
        .clipped()
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

    private var multiPageStripSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<imageURLs.count, id: \.self) { index in
                stripPageItem(page: index)
                    .id("illust-strip-page-\(index)")
            }
        }
        .frame(maxWidth: containerWidth ?? .infinity)
        .clipped()
    }

    private func stripPageItem(page: Int) -> some View {
        let ratio = aspectRatioForPage(page)
        let pageHeight = containerWidth.map { $0 / max(ratio, 0.1) }

        return Button {
            openPage(page)
        } label: {
            ZStack(alignment: .bottomTrailing) {
                ProgressiveMultiPageAsyncImage(
                    illust: illust,
                    targetQuality: displayQuality,
                    currentPage: page,
                    aspectRatio: ratio,
                    idealWidth: containerWidth,
                    expiration: DefaultCacheExpiration.illustDetail,
                    onSizeChange: { size in
                        handleSizeChange(size: size, for: page)
                    }
                )
                .frame(width: containerWidth, height: pageHeight)
                #if os(iOS)
                .reportImageFrame(when: isCurrent && page == currentPage)
                .opacity(isFullscreen && page == currentPage ? 0 : 1)
                #endif

                stripPageIndicator(page: page, total: imageURLs.count)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String.localizedStringWithFormat(
                String(localized: "第 %lld 页，共 %lld 页"),
                page + 1,
                imageURLs.count
            )
        )
        .accessibilityHint(String(localized: "查看大图"))
        .onAppear {
            if abs(currentPage - page) > 0 {
                currentPage = page
            }
        }
    }

    private func stripPageIndicator(page: Int, total: Int) -> some View {
        Text("\(page + 1) / \(total)")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.45), in: .capsule)
            .padding(8)
    }

    private func pageImage(page: Int, containerHeight: CGFloat?) -> some View {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality

        return Button {
            openPage(page)
        } label: {
            ProgressiveMultiPageAsyncImage(
                illust: illust,
                targetQuality: quality,
                currentPage: page,
                aspectRatio: aspectRatioForPage(page),
                expiration: DefaultCacheExpiration.illustDetail,
                onSizeChange: { size in
                    handleSizeChange(size: size, for: page)
                }
            )
            .frame(height: containerHeight)
            #if os(iOS)
            .opacity(isFullscreen && page == currentPage ? 0 : 1)
            #endif
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "查看大图"))
    }

    private func openSinglePageImage() {
        #if os(macOS)
        let quality = isManga
            ? userSettingStore.userSetting.mangaQuality
            : userSettingStore.userSetting.zoomQuality
        let zoomURL = ImageURLHelper.getImageURL(from: illust, quality: quality)
        ImageViewerWindowManager.shared.showSingleImage(
            illust: illust,
            url: zoomURL,
            title: illust.title,
            aspectRatio: illust.safeAspectRatio
        )
        #else
        isFullscreen = true
        #endif
    }

    private func openPage(_ page: Int) {
        currentPage = page
        #if os(macOS)
        openImageViewerWindow(initialPage: page)
        #else
        isFullscreen = true
        #endif
    }

    #if os(macOS)
    private func openImageViewerWindow(initialPage: Int) {
        let quality = isManga
            ? userSettingStore.userSetting.mangaQuality
            : userSettingStore.userSetting.zoomQuality
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
            .background {
                if #available(iOS 26.0, macOS 26.0, *) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                }
            }
            .padding(8)
    }

    private func translateCurrentImage() {
        let url: String
        if imageURLs.indices.contains(currentPage) {
            url = imageURLs[currentPage]
        } else if let first = imageURLs.first {
            url = first
        } else {
            return
        }
        showTranslation = true
        Task {
            await translationStore.translateImage(urlString: url)
        }
    }

    private func explainCurrentImage() {
        let url: String
        if imageURLs.indices.contains(currentPage) {
            url = imageURLs[currentPage]
        } else if let first = imageURLs.first {
            url = first
        } else {
            return
        }
        showTranslation = true
        Task {
            await translationStore.explainImage(urlString: url)
        }
    }
}
