import SwiftUI

#if os(macOS)
import AppKit
#endif

private struct IllustPageDescriptor: Identifiable, Equatable {
    let id: String
    let index: Int
    let previewURL: String
    let fullURL: String
    let fallbackURLs: [String]
    let estimatedAspectRatio: CGFloat
}

struct IllustPagesWaterfallView: View {
    @Environment(UserSettingStore.self) private var userSettingStore

    let illust: Illusts
    @Binding var currentPage: Int

    @State private var pageSizes: [Int: CGSize] = [:]
    @State private var focusedPageID: String?
    @State private var scrollRequestID: String?
    @State private var prefetchTracker = PrefetchTracker()

    #if os(iOS)
    @State private var showFullscreen = false
    @State private var fullscreenPage = 0
    @State private var exitDragProgress: CGFloat = 0
    #endif

    private var previewQuality: Int {
        userSettingStore.userSetting.feedPreviewQuality
    }

    private var fullscreenQuality: Int {
        illust.type == "manga"
            ? userSettingStore.userSetting.mangaQuality
            : userSettingStore.userSetting.zoomQuality
    }

    private var pageDescriptors: [IllustPageDescriptor] {
        guard illust.type != "ugoira" else { return [] }

        return illust.metaPages.enumerated().compactMap { index, page in
            guard page.imageUrls != nil else { return nil }

            guard let previewURL = ImageURLHelper.getPageImageURL(
                from: illust,
                page: index,
                quality: previewQuality
            ),
            !previewURL.isEmpty,
            let fullURL = ImageURLHelper.getPageImageURL(
                from: illust,
                page: index,
                quality: fullscreenQuality
            ),
            !fullURL.isEmpty else {
                return nil
            }

            let fallbackURLs = ImageQualityHelper.getAllQualityPageURLs(from: illust, page: index)
                .sorted { $0.key > $1.key }
                .map(\.value)
                .filter { $0 != fullURL }

            return IllustPageDescriptor(
                id: "\(illust.id)-page-\(index)",
                index: index,
                previewURL: previewURL,
                fullURL: fullURL,
                fallbackURLs: fallbackURLs,
                estimatedAspectRatio: illust.safeAspectRatio
            )
        }
    }

    private var initialPageID: String? {
        pageDescriptors.first { $0.index == currentPage }?.id ?? pageDescriptors.first?.id
    }

    private var activePageID: String? {
        focusedPageID ?? initialPageID
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 12
            let availableWidth = max(geometry.size.width - horizontalPadding * 2, 0)
            let columnCount = ResponsiveGrid.columnCount(
                for: availableWidth,
                userSetting: userSettingStore.userSetting
            )

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 12) {
                        let pages = pageDescriptors

                        if pages.isEmpty {
                            ContentUnavailableView(
                                String(localized: "没有可浏览的页面"),
                                systemImage: "photo.on.rectangle.angled"
                            )
                            .frame(maxWidth: .infinity, minHeight: 300)
                        } else {
                            WaterfallGrid(
                                data: pages,
                                columnCount: columnCount,
                                spacing: 12,
                                width: availableWidth,
                                aspectRatio: { $0.estimatedAspectRatio }
                            ) { page, columnWidth in
                                pageCard(
                                    page,
                                    columnWidth: columnWidth,
                                    totalPages: pages.count
                                )
                            }
                            .padding(.horizontal, horizontalPadding)
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onAppear {
                    guard let initialPageID else { return }
                    Task { @MainActor in
                        await Task.yield()
                        scrollProxy.scrollTo(initialPageID, anchor: .top)
                    }
                }
                .onChange(of: scrollRequestID) { _, requestedID in
                    guard let requestedID else { return }
                    withAnimation(.easeInOut(duration: 0.25)) {
                        scrollProxy.scrollTo(requestedID, anchor: .top)
                    }
                    scrollRequestID = nil
                }
            }
        }
        .navigationTitle(String(localized: "多页浏览"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    scrollRequestID = activePageID
                } label: {
                    Label(String(localized: "回到当前页"), systemImage: "scope")
                }
                .disabled(activePageID == nil)
                .help(String(localized: "回到当前页"))
            }
        }
        .task {
            prefetchPages(startingAt: currentPage)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showFullscreen) {
            fullscreenView
        }
        .onChange(of: showFullscreen) { _, isPresented in
            guard !isPresented,
                  pageDescriptors.indices.contains(fullscreenPage) else {
                return
            }
            let page = pageDescriptors[fullscreenPage]
            currentPage = page.index
            focusedPageID = page.id
            scrollRequestID = focusedPageID
        }
        #endif
    }

    private func pageCard(
        _ page: IllustPageDescriptor,
        columnWidth: CGFloat,
        totalPages: Int
    ) -> some View {
        Button {
            openPage(page)
        } label: {
            ZStack(alignment: .bottomLeading) {
                ProgressiveMultiPageAsyncImage(
                    illust: illust,
                    targetQuality: previewQuality,
                    currentPage: page.index,
                    aspectRatio: aspectRatio(for: page),
                    idealWidth: columnWidth,
                    expiration: DefaultCacheExpiration.illustDetail,
                    onSizeChange: { size in
                        updatePageSize(size, for: page.index)
                    }
                )
                .frame(width: columnWidth)

                Text("\(page.index + 1) / \(totalPages)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: .capsule)
                    .padding(8)
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        activePageID == page.id ? Color.accentColor : .clear,
                        lineWidth: 3
                    )
            }
        }
        .buttonStyle(.plain)
        .id(page.id)
        .onAppear {
            prefetchPages(startingAt: page.index)
        }
        .accessibilityLabel(pageAccessibilityLabel(page, totalPages: totalPages))
        .accessibilityHint(String(localized: "查看大图"))
    }

    private func aspectRatio(for page: IllustPageDescriptor) -> CGFloat {
        guard let size = pageSizes[page.index], size.width > 0, size.height > 0 else {
            return page.estimatedAspectRatio
        }
        let ratio = size.width / size.height
        return ratio.isFinite && ratio > 0 ? ratio : page.estimatedAspectRatio
    }

    private func updatePageSize(_ size: CGSize, for pageIndex: Int) {
        guard size.width > 0, size.height > 0, pageSizes[pageIndex] != size else { return }
        pageSizes[pageIndex] = size
    }

    private func pageAccessibilityLabel(_ page: IllustPageDescriptor, totalPages: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "第 %lld 页，共 %lld 页"),
            page.index + 1,
            totalPages
        )
    }

    private func prefetchPages(startingAt pageIndex: Int) {
        let pageCount = userSettingStore.userSetting.listMultiPagePrefetchCount
        guard pageCount != 0 else { return }

        let startIndex = max(prefetchTracker.nextPrefetchIndex, pageIndex)
        guard startIndex < pageDescriptors.count else { return }

        if pageCount < 0 {
            prefetchTracker.nextPrefetchIndex = pageDescriptors.count
        } else {
            prefetchTracker.nextPrefetchIndex = min(startIndex + pageCount, pageDescriptors.count)
        }

        ImageURLHelper.prefetchPageImages(
            from: illust,
            quality: previewQuality,
            pageCount: pageCount,
            startingAt: startIndex
        )
    }

    private func openPage(_ page: IllustPageDescriptor) {
        guard let pagePosition = pageDescriptors.firstIndex(where: { $0.id == page.id }) else { return }
        currentPage = page.index
        focusedPageID = page.id

        #if os(iOS)
        fullscreenPage = pagePosition
        showFullscreen = true
        #elseif os(macOS)
        let pages = pageDescriptors
        ImageViewerWindowManager.shared.showMultiImages(
            illust: illust,
            urls: pages.map(\.fullURL),
            initialPage: pagePosition,
            title: illust.title,
            aspectRatios: pages.map { aspectRatio(for: $0) },
            fallbackURLs: pages.map(\.fallbackURLs)
        )
        #endif
    }

    #if os(iOS)
    private var fullscreenView: some View {
        let pages = pageDescriptors

        return FullscreenImageView(
            imageURLs: pages.map(\.fullURL),
            fallbackImageURLs: [],
            aspectRatios: pages.map { aspectRatio(for: $0) },
            initialPage: $fullscreenPage,
            isPresented: $showFullscreen,
            exitDragProgress: $exitDragProgress,
            fallbackImageURLChains: pages.map(\.fallbackURLs)
        )
    }
    #endif
}

#Preview("多页插画瀑布流") {
    let illust = Illusts(
        id: 124,
        title: "多页示例插画",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium: "",
            medium: "",
            large: ""
        ),
        caption: "多页示例",
        restrict: 0,
        user: User(
            id: .string("1"),
            name: "示例用户",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 3,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [
            MetaPages(imageUrls: MetaPagesImageUrls(
                squareMedium: "",
                medium: "",
                large: "",
                original: ""
            )),
            MetaPages(imageUrls: MetaPagesImageUrls(
                squareMedium: "",
                medium: "",
                large: "",
                original: ""
            )),
            MetaPages(imageUrls: MetaPagesImageUrls(
                squareMedium: "",
                medium: "",
                large: "",
                original: ""
            ))
        ],
        totalView: 0,
        totalBookmarks: 0,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    NavigationStack {
        IllustPagesWaterfallView(illust: illust, currentPage: .constant(0))
    }
    .environment(UserSettingStore())
}
