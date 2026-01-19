import SwiftUI
import Kingfisher

struct IllustDetailImageSection: View {
    let illust: Illusts
    let userSettingStore: UserSettingStore
    let isFullscreen: Bool
    let animation: Namespace.ID

    @Binding var currentPage: Int
    @State private var pageSizes: [Int: CGSize] = [:]
    @State private var currentAspectRatio: CGFloat = 0

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
        ZStack(alignment: .bottomTrailing) {
            if isMultiPage {
                multiPageImageSection
            } else {
                singlePageImageSection
            }
        }
        .overlay(alignment: .top) {
            scrimOverlay
        }
    }

    @ViewBuilder
    private var scrimOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.white.opacity(0.1), .clear]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 100)
        .allowsHitTesting(false)
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
        TabView(selection: $currentPage) {
            ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                pageImage(url: url, index: index)
                    .tag(index)
            }
        }
        #if canImport(UIKit)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .frame(maxWidth: .infinity)
        .aspectRatio(aspectRatioForPage(currentPage), contentMode: .fit)
        .onAppear {
            currentAspectRatio = illust.safeAspectRatio
        }
        .onChange(of: currentPage) { _, newPage in
            updateAspectRatio(for: newPage)
        }
        .onTapGesture {
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
