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
    var containerWidth: CGFloat? = nil
    var minContainerHeight: CGFloat? = nil
    var currentAspectRatio: Binding<CGFloat>? = nil
    var disableAspectRatioAnimation: Bool = false
    @State private var scrollPosition: Int? = 0
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
                        withAnimation(.spring()) {
                            isFullscreen = true
                        }
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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        pageImage(url: url, index: index, containerHeight: containerHeight)
                            .frame(width: containerWidth)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
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
        .onChange(of: scrollPosition) { _, newValue in
            if let newValue, currentPage != newValue {
                currentPage = newValue
            }
        }
        .onChange(of: currentPage) { _, newValue in
            if scrollPosition != newValue {
                scrollPosition = newValue
            }
        }
        #endif
        .frame(maxWidth: .infinity)
        .frame(width: containerWidth, height: fixedContainerHeight)
        .aspectRatio(containerWidth == nil ? effectiveAspectRatio : nil, contentMode: .fit)
        .onAppear {
            currentAspectRatioValue = illust.safeAspectRatio
            currentAspectRatio?.wrappedValue = illust.safeAspectRatio
            #if os(macOS)
            scrollPosition = currentPage
            #endif
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
            withAnimation(.spring()) {
                isFullscreen = true
            }
        }
    }

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
