import SwiftUI
import Kingfisher

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct IllustDetailView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ToastPresenter.self) var toast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.pixivNavigationRouter) private var navigationRouter
    let illust: Illusts
    let isCurrent: Bool
    @Binding private var externalCurrentPage: Int
    @State private var internalCurrentPage: Int = 0
    private let hasExternalCurrentPage: Bool
    @State private var vm: IllustDetailViewModel
    @State private var illustStore = IllustStore()
    @State private var isCommentsPanelPresented = false
    @State private var isFullscreen = false
    @State private var showRelatedIllustDetail = false
    #if os(macOS)
    @State private var currentImageAspectRatio: CGFloat = 0
    #endif
    @State private var showAuthView = false
    @State private var pendingSaveURL: URL?
    @Namespace private var animation
    @Environment(\.dismiss) private var dismiss

    @Binding private var externalShowPagesWaterfall: Bool
    @State private var internalShowPagesWaterfall = false
    private let hasExternalShowPagesWaterfall: Bool
    private let containerWidth: CGFloat?

    private var currentPageBinding: Binding<Int> {
        Binding(
            get: { hasExternalCurrentPage ? externalCurrentPage : internalCurrentPage },
            set: { newValue in
                if hasExternalCurrentPage {
                    externalCurrentPage = newValue
                } else {
                    internalCurrentPage = newValue
                }
            }
        )
    }

    private var currentPage: Int {
        get { currentPageBinding.wrappedValue }
        nonmutating set { currentPageBinding.wrappedValue = newValue }
    }

    // MARK: - Fullscreen Transition State
    @State private var capturedImageFrame: CGRect = .zero

    init(
        illust: Illusts,
        isCurrent: Bool = true,
        currentPage: Binding<Int>? = nil,
        containerWidth: CGFloat? = nil,
        viewModel: IllustDetailViewModel? = nil,
        showPagesWaterfall: Binding<Bool>? = nil
    ) {
        self.illust = illust
        self.isCurrent = isCurrent
        self.containerWidth = containerWidth
        if let currentPage {
            self._externalCurrentPage = currentPage
            self.hasExternalCurrentPage = true
        } else {
            self._externalCurrentPage = .constant(0)
            self.hasExternalCurrentPage = false
        }
        if let showPagesWaterfall {
            self._externalShowPagesWaterfall = showPagesWaterfall
            self.hasExternalShowPagesWaterfall = true
        } else {
            self._externalShowPagesWaterfall = .constant(false)
            self.hasExternalShowPagesWaterfall = false
        }
        _vm = State(initialValue: viewModel ?? IllustDetailViewModel(illust: illust))
    }

    private var showPagesWaterfallBinding: Binding<Bool> {
        Binding(
            get: { hasExternalShowPagesWaterfall ? externalShowPagesWaterfall : internalShowPagesWaterfall },
            set: { newValue in
                if hasExternalShowPagesWaterfall {
                    externalShowPagesWaterfall = newValue
                } else {
                    internalShowPagesWaterfall = newValue
                }
            }
        )
    }

    var body: some View {
        ZStack {
            Group {
                #if os(macOS)
                GeometryReader { proxy in
                    let scrollBarWidth = NSScroller.scrollerWidth(
                        for: .regular,
                        scrollerStyle: NSScroller.preferredScrollerStyle
                    )
                    let contentWidth = max(0, proxy.size.width - scrollBarWidth)
                    let isStripMode = userSettingStore.userSetting.multiPageBrowseMode == 1

                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                IllustDetailImageSection(
                                    illust: illust,
                                    userSettingStore: userSettingStore,
                                    isFullscreen: $isFullscreen,
                                    animation: animation,
                                    currentPage: currentPageBinding,
                                    isCurrent: isCurrent,
                                    containerWidth: contentWidth,
                                    minContainerHeight: isStripMode ? nil : proxy.size.height * 0.6,
                                    currentAspectRatio: $currentImageAspectRatio,
                                    disableAspectRatioAnimation: true,
                                    ugoiraStore: vm.ugoiraStore
                                )

                                IllustDetailRelatedSection(
                                    illustId: illust.id,
                                    isLoggedIn: vm.isLoggedIn,
                                    relatedIllusts: $vm.relatedIllusts,
                                    isLoadingRelated: $vm.isLoadingRelated,
                                    isFetchingMoreRelated: $vm.isFetchingMoreRelated,
                                    relatedNextUrl: $vm.relatedNextUrl,
                                    hasMoreRelated: $vm.hasMoreRelated,
                                    relatedIllustError: $vm.relatedIllustError,
                                    width: contentWidth
                                )
                                .frame(width: contentWidth, alignment: .leading)
                            }
                            .frame(width: contentWidth, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onChange(of: showPagesWaterfallBinding.wrappedValue) { _, isPresented in
                            if !isPresented && isStripMode {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    scrollProxy.scrollTo("illust-strip-page-\(currentPage)", anchor: .top)
                                }
                            }
                        }
                    }
                }
                #else
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            IllustDetailImageSection(
                                illust: illust,
                                userSettingStore: userSettingStore,
                                isFullscreen: $isFullscreen,
                                animation: animation,
                                currentPage: currentPageBinding,
                                isCurrent: isCurrent,
                                containerWidth: containerWidth,
                                ugoiraStore: vm.ugoiraStore
                            )

                            VStack(alignment: .leading, spacing: 0) {
                                IllustDetailInfoSection(
                                    illust: illust,
                                    userSettingStore: userSettingStore,
                                    accountStore: accountStore,
                                    colorScheme: colorScheme,
                                    authorLatestIllusts: vm.authorLatestIllusts,
                                    isLoadingAuthorLatestIllusts: vm.isLoadingAuthorLatestIllusts,
                                    onFetchAuthorLatestIllusts: vm.fetchAuthorLatestIllustsIfNeeded,
                                    isFollowed: $vm.isFollowed,
                                    isBookmarked: $vm.isBookmarked,
                                    totalComments: $vm.totalComments,
                                    isBlockTriggered: $vm.isBlockTriggered,
                                    isCommentsPanelPresented: $isCommentsPanelPresented
                                )
                                .padding()
                                .frame(width: containerWidth, alignment: .leading)

                                IllustDetailRelatedSection(
                                    illustId: illust.id,
                                    isLoggedIn: vm.isLoggedIn,
                                    relatedIllusts: $vm.relatedIllusts,
                                    isLoadingRelated: $vm.isLoadingRelated,
                                    isFetchingMoreRelated: $vm.isFetchingMoreRelated,
                                    relatedNextUrl: $vm.relatedNextUrl,
                                    hasMoreRelated: $vm.hasMoreRelated,
                                    relatedIllustError: $vm.relatedIllustError,
                                    width: max((containerWidth ?? 1) - 16, 1)
                                )
                                .padding(.trailing, 16)
                            }
                            .frame(width: containerWidth, alignment: .leading)
                        }
                    }
                    .scrollDisabled(!isCurrent)
                    .onChange(of: isFullscreen) { _, isPresented in
                        if !isPresented && userSettingStore.userSetting.multiPageBrowseMode == 1 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scrollProxy.scrollTo("illust-strip-page-\(currentPage)", anchor: .top)
                            }
                        }
                    }
                    .onChange(of: showPagesWaterfallBinding.wrappedValue) { _, isPresented in
                        if !isPresented && userSettingStore.userSetting.multiPageBrowseMode == 1 {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scrollProxy.scrollTo("illust-strip-page-\(currentPage)", anchor: .top)
                            }
                        }
                    }
                }
                #endif
            }
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .sheet(isPresented: $isCommentsPanelPresented) {
                IllustCommentsPanelView(
                    illust: illust,
                    isPresented: $isCommentsPanelPresented,
                    onUserTapped: { userId in
                        isCommentsPanelPresented = false
                        navigationRouter?.push(.user(id: userId))
                    }
                )
            }
            #endif
            .onAppear {
                vm.showToast = { toast.show($0) }
                vm.fetchDetailIfNeeded()
                if vm.isUgoira && vm.ugoiraStore == nil {
                    vm.ugoiraStore = UgoiraStore(illustId: illust.id, expiration: .hours(1))
                }
            }
            .task {
                guard isCurrent else { return }
                try? illustStore.recordGlance(illust.id, illust: illust)
            }
            .task {
                await vm.ugoiraStore?.loadIfNeeded()
            }
            .onChange(of: isCurrent) { _, newValue in
                if newValue {
                    try? illustStore.recordGlance(illust.id, illust: illust)
                }
            }
            #if os(iOS)
            .onPreferenceChange(ImageFramePreferenceKey.self) { frame in
                if isCurrent && frame != .zero {
                    capturedImageFrame = frame
                }
            }
            #endif
            .onChange(of: currentPageBinding.wrappedValue) { _, newPage in
                vm.preloadDetailPages(around: newPage)
            }
            #if os(iOS)
            .navigationDestination(isPresented: showPagesWaterfallBinding) {
                IllustPagesWaterfallView(illust: illust, currentPage: currentPageBinding)
            }
            #endif
            #if os(iOS)
            .toolbar {
                if isCurrent {
                    if vm.isMultiPage && !vm.isUgoira && !illust.metaPages.isEmpty {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showPagesWaterfallBinding.wrappedValue = true
                            } label: {
                                Image(systemName: "square.grid.2x2")
                            }
                            .help(String(localized: "多页浏览"))
                        }

                        if #available(iOS 26.0, *) {
                            ToolbarSpacer(.fixed)
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        illustMenuButton
                    }
                }
            }
            .fullScreenCover(isPresented: $isFullscreen) {
                FullscreenImageView(
                    imageURLs: vm.zoomImageURLs,
                    fallbackImageURLs: vm.detailImageURLs,
                    aspectRatios: vm.zoomImageAspectRatios,
                    initialPage: currentPageBinding,
                    isPresented: $isFullscreen,
                    sourceFrame: capturedImageFrame,
                    ugoiraStore: vm.isUgoira ? vm.ugoiraStore : nil,
                    fallbackImageURLChains: vm.detailImageURLChains
                )
                .presentationBackground(.clear)
            }
            .transaction { transaction in
                transaction.disablesAnimations = true
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.openURL, OpenURLAction { url in
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if url.scheme == "pixiv" {
                    let pathId = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    if components.host == "illusts", let id = Int(pathId) {
                        navigationRouter?.push(.illustLoader(id: id))
                        return .handled
                    } else if components.host == "users" {
                        navigationRouter?.push(.user(id: pathId))
                        return .handled
                    } else if components.host == "novel" || components.host == "novels", let id = Int(pathId) {
                        navigationRouter?.push(.novelLoader(id: id))
                        return .handled
                    }
                } else if url.host?.contains("pixiv.net") == true {
                    // Simple handling for common pixiv web links
                    let pathComponents = components.path.split(separator: "/")
                    if pathComponents.count >= 2 {
                        if pathComponents[0] == "artworks", let id = Int(pathComponents[1]) {
                            navigationRouter?.push(.illustLoader(id: id))
                            return .handled
                        } else if pathComponents[0] == "users" {
                            navigationRouter?.push(.user(id: String(pathComponents[1])))
                            return .handled
                        }
                    }
                    if components.path.contains("novel/show.php"),
                       let idStr = components.queryItems?.first(where: { $0.name == "id" })?.value,
                       let id = Int(idStr) {
                        navigationRouter?.push(.novelLoader(id: id))
                        return .handled
                    }
                }
            }
            return .systemAction
        })
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        toast.show(String(localized: "已复制"))
    }
}

#if os(iOS)
private extension IllustDetailView {
    var illustMenuButton: some View {
        Menu {
            Button(action: { copyToClipboard(String(illust.id)) }) {
                Label(String(localized: "复制 ID"), systemImage: "doc.on.doc")
            }

            if let shareURL = URL(string: "https://www.pixiv.net/artworks/\(illust.id)") {
                ShareLink(item: shareURL) {
                    Label(String(localized: "分享"), systemImage: "square.and.arrow.up")
                }
            }

            if vm.isLoggedIn {
                Button(action: {
                    if vm.isBookmarked {
                        vm.bookmarkIllust(forceUnbookmark: true)
                    } else {
                        vm.bookmarkIllust(isPrivate: userSettingStore.userSetting.defaultPrivateLike)
                    }
                }) {
                    Label(
                        vm.isBookmarked ? String(localized: "取消收藏") : String(localized: "收藏"),
                        systemImage: vm.isBookmarked ? (illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill") : "heart"
                    )
                }

                Divider()

                Button(action: {
                    Task {
                        await vm.saveIllust()
                    }
                }) {
                    Label(String(localized: "保存到相册"), systemImage: "photo.on.rectangle")
                }

                if userSettingStore.userSetting.illustDetailSaveSkipLongPress {
                    Button(action: {
                        Task {
                            await vm.saveIllust()
                        }
                    }) {
                        Label(String(localized: "快速保存"), systemImage: "bolt.fill")
                    }
                }

                Divider()

                Button(role: .destructive, action: {
                    vm.isBlockTriggered = true
                    try? userSettingStore.addBlockedIllustWithInfo(
                        illust.id,
                        title: illust.title,
                        authorId: illust.user.id.stringValue,
                        authorName: illust.user.name,
                        thumbnailUrl: illust.imageUrls.squareMedium
                    )
                    toast.show(String(localized: "已屏蔽作品"))
                    dismiss()
                }) {
                    Label(String(localized: "屏蔽此作品"), systemImage: "eye.slash")
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: vm.isBlockTriggered)

                Button(role: .destructive, action: {
                    vm.isBlockTriggered = true
                    try? userSettingStore.addBlockedUserWithInfo(
                        illust.user.id.stringValue,
                        name: illust.user.name,
                        account: illust.user.account,
                        avatarUrl: illust.user.profileImageUrls?.medium
                    )
                    toast.show(String(localized: "已屏蔽作者"))
                    dismiss()
                }) {
                    Label(String(localized: "屏蔽此作者"), systemImage: "person.slash")
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: vm.isBlockTriggered)

                if vm.isOwnIllust {
                    Divider()

                    Button(role: .destructive, action: {
                        vm.showDeleteConfirmation = true
                    }) {
                        Label(String(localized: "删除作品"), systemImage: "trash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}
#endif
