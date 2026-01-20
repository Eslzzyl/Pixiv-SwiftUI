import SwiftUI
import Kingfisher

#if os(macOS)
import AppKit
#endif

struct IllustDetailImageSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let isFullscreen: Bool
    let animation: Namespace.ID

    @Binding var currentPage: Int
    @State private var scrollPosition: Int? = 0
    @State private var pageSizes: [Int: CGSize] = [:]
    @State private var currentAspectRatio: CGFloat = 0
    
#if os(macOS)
    @State private var isHoveringImage = false
#endif

    private var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    private var isUgoira: Bool {
        illust.type == "ugoira"
    }

    private var imageURLs: [String] {
        let quality = userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.enumerated().compactMap { index, _ in
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

    private var singlePageImageSection: some View {
        Group {
            if isUgoira {
                UgoiraLoader(illust: illust)
            } else {
                standardImageSection
                    .onTapGesture {
                    }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var standardImageSection: some View {
        CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: 2),
            aspectRatio: illust.safeAspectRatio,
            contentMode: .fit,
            expiration: DefaultCacheExpiration.illustDetail
        )
    }

    private var multiPageImageSection: some View {
        ZStack {
            #if os(macOS)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        pageImage(url: url, index: index)
                            .containerRelativeFrame(.horizontal)
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
                    pageImage(url: url, index: index)
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
        .aspectRatio(currentAspectRatio > 0 ? currentAspectRatio : illust.safeAspectRatio, contentMode: .fit)
        .onAppear {
            currentAspectRatio = illust.safeAspectRatio
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

    private func pageImage(url: String, index: Int) -> some View {
        DynamicSizeCachedAsyncImage(
            urlString: url,
            placeholder: nil,
            aspectRatio: aspectRatioForPage(index),
            contentMode: .fit,
            onSizeChange: { size in
                handleSizeChange(size: size, for: index)
            },
            expiration: DefaultCacheExpiration.illustDetail
        )
    }

    private func handleSizeChange(size: CGSize, for index: Int) {
        guard size.width > 0 && size.height > 0 else { return }
        pageSizes[index] = size
        if index == currentPage {
            currentAspectRatio = size.width / size.height
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
        if newRatio != currentAspectRatio {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentAspectRatio = newRatio
            }
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
