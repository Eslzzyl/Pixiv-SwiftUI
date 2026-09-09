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
    @State private var transitionPhase: TransitionPhase = .idle
    @State private var transitionProgress: CGFloat = 0
    @State private var transitionScreenSize: CGSize = .zero
    /// Frame saved at entering start — preserved for correct exit animation
    @State private var savedSourceFrame: CGRect = .zero
    @State private var exitDragProgress: CGFloat = 0

    /// Opacity of the detail page content during transitions.
    private var detailContentOpacity: Double {
        guard transitionPhase.isFullscreen || transitionPhase.isTransitioning else { return 1.0 }
        if transitionPhase.isTransitioning {
            switch transitionPhase {
            case .entering:
                return 0.1
            case .exiting:
                return 0.1 + Double(transitionProgress) * 0.9
            default:
                return 0.1
            }
        }
        return 0.1
    }

    private var hidesNavigationChrome: Bool {
        isCurrent && (isFullscreen || transitionPhase != .idle)
    }

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
                                minContainerHeight: proxy.size.height * 0.6,
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
                }
                #else
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
                .scrollDisabled(!isCurrent || isFullscreen || transitionPhase.isTransitioning)
                .opacity(detailContentOpacity)
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
            .onChange(of: isFullscreen) { _, newValue in
                if newValue {
                    startEnteringTransition()
                } else {
                    startExitingTransition()
                }
            }
            .onChange(of: currentPageBinding.wrappedValue) { _, newPage in
                vm.preloadDetailPages(around: newPage)
            }
            .navigationDestination(isPresented: showPagesWaterfallBinding) {
                IllustPagesWaterfallView(illust: illust, currentPage: currentPageBinding)
            }
            #if os(iOS)
            .toolbar {
                if isCurrent {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 8) {
                            if vm.isMultiPage && !vm.isUgoira && !illust.metaPages.isEmpty {
                                Button {
                                    showPagesWaterfallBinding.wrappedValue = true
                                } label: {
                                    Image(systemName: "square.grid.2x2")
                                }
                                .help(String(localized: "多页浏览"))
                            }

                            illustMenuButton
                        }
                    }
                }
            }
            .toolbar(hidesNavigationChrome ? .hidden : .visible, for: .navigationBar)
            .modifier(FullscreenTabBarVisibilityModifier(isHidden: hidesNavigationChrome))
            #endif

            #if os(iOS)
            transitionOverlay()
            #endif
        }
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

    // MARK: - Fullscreen Transition Helpers

    /// Detail-quality image URL for the current illust/page (used for entering ghost image).
    private var enteringTransitionImageURL: String {
        let quality = vm.isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty, currentPage < illust.metaPages.count {
            return ImageURLHelper.getPageImageURL(from: illust, page: currentPage, quality: quality) ?? ""
        }
        return ImageURLHelper.getImageURL(from: illust, quality: quality)
    }

    /// Zoom-quality image URL for the current illust/page (used for exiting ghost image,
    /// since FullscreenImageView has already cached it).
    private var exitingTransitionImageURL: String {
        let quality = vm.isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.zoomQuality
        if !illust.metaPages.isEmpty, currentPage < illust.metaPages.count {
            return ImageURLHelper.getPageImageURL(from: illust, page: currentPage, quality: quality) ?? ""
        }
        return ImageURLHelper.getImageURL(from: illust, quality: quality)
    }

    /// The aspect ratio of the current illust/page to use during transition.
    private var transitionAspectRatio: CGFloat {
        illust.safeAspectRatio
    }

    /// Begin the entering (detail → fullscreen) transition.
    private func startEnteringTransition() {
        let frame = capturedImageFrame

        // Save immediately for correct exit animation (toolbar re-appearance shifts layout)
        savedSourceFrame = frame

        // If frame hasn't been captured yet, retry on next runloop
        guard frame != .zero, frame.width > 0, frame.height > 0 else {
            DispatchQueue.main.async {
                let retryFrame = capturedImageFrame
                guard retryFrame != .zero, retryFrame.width > 0, retryFrame.height > 0 else {
                    transitionPhase = .fullscreen
                    return
                }
                // Retry succeeded — update savedSourceFrame for correct exit animation
                savedSourceFrame = retryFrame
                startEnteringTransitionWithFrame(retryFrame)
            }
            return
        }

        startEnteringTransitionWithFrame(frame)
    }

    private func startEnteringTransitionWithFrame(_ frame: CGRect) {
        let url = enteringTransitionImageURL
        guard !url.isEmpty else {
            transitionPhase = .fullscreen
            return
        }

        // Reset exit drag state from any previous dismissal
        exitDragProgress = 0

        let aspectRatio = transitionAspectRatio
        transitionProgress = 0
        transitionPhase = .entering(sourceFrame: frame, imageURL: url, aspectRatio: aspectRatio)

        // Capture screen size for stable target frame calculation
        #if os(iOS)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let windowSize = windowScene?.windows.first?.bounds.size ?? .zero
        transitionScreenSize = windowSize
        #endif

        if !vm.zoomImageURLs.isEmpty {
            let firstPage = max(0, currentPage - 1)
            let lastPage = min(currentPage + 1, vm.zoomImageURLs.count - 1)
            for page in firstPage...lastPage {
                Task { await vm.preloadImage(urlString: vm.zoomImageURLs[page]) }
            }
        }

        // Animate the ghost image and switch to .fullscreen when the spring settles.
        // 必须在下一个 runloop 执行动画，让 SwiftUI 先渲染 .entering 的初始状态。
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                transitionProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [isFullscreen] in
            guard isFullscreen else { return }
            transitionPhase = .fullscreen
        }
    }

    /// Begin the exiting (fullscreen → detail) transition.
    private func startExitingTransition() {
        // 使用进入时保存的 frame（toolbar 可见时的布局），而不是全屏期间的 capturedImageFrame
        // （toolbar 隐藏时的布局），确保退场幽灵图片直接飞向详情页图片的最终位置。
        let exitFrame = savedSourceFrame

        guard exitFrame != .zero else {
            transitionPhase = .idle
            return
        }

        let url = exitingTransitionImageURL
        let aspectRatio = transitionAspectRatio

        transitionProgress = 0
        transitionPhase = .exiting(sourceFrame: exitFrame, imageURL: url, aspectRatio: aspectRatio)

        // Capture screen size for stable target frame calculation
        #if os(iOS)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let windowSize = windowScene?.windows.first?.bounds.size ?? .zero
        transitionScreenSize = windowSize
        #endif

        // Animate the ghost back and switch to .idle when the spring settles.
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                transitionProgress = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Only transition to .idle if we're still in the exiting phase.
            // This prevents a stale timer from overriding a new entering transition
            // if the user re-taps before the exit animation completes.
            guard case .exiting = transitionPhase else { return }
            transitionPhase = .idle
        }
    }

    /// Compute the target fullscreen frame for a given aspect ratio and screen size.
    private func targetFrame(in screenSize: CGSize, aspectRatio: CGFloat) -> CGRect {
        guard aspectRatio > 0, aspectRatio.isFinite else {
            return CGRect(origin: .zero, size: screenSize)
        }

        let screenW = screenSize.width
        let screenH = screenSize.height

        let imageH = screenW / aspectRatio
        if imageH <= screenH {
            let yOffset = (screenH - imageH) / 2
            return CGRect(x: 0, y: yOffset, width: screenW, height: imageH)
        } else {
            let imageW = screenH * aspectRatio
            let xOffset = (screenW - imageW) / 2
            return CGRect(x: xOffset, y: 0, width: imageW, height: screenH)
        }
    }

    // MARK: - Interpolation Helpers

    private func interpolatedX(from source: CGRect, to target: CGRect) -> CGFloat {
        source.midX + (target.midX - source.midX) * transitionProgress
    }

    private func interpolatedY(from source: CGRect, to target: CGRect) -> CGFloat {
        source.midY + (target.midY - source.midY) * transitionProgress
    }

    private func interpolatedWidth(from source: CGRect, to target: CGRect) -> CGFloat {
        source.width + (target.width - source.width) * transitionProgress
    }

    private func interpolatedHeight(from source: CGRect, to target: CGRect) -> CGFloat {
        source.height + (target.height - source.height) * transitionProgress
    }

    // MARK: - Transition Overlay

    /// The iOS-only fullscreen transition overlay (ghost + pre-warmed FullscreenImageView).
    /// Extracted as a function to help the Swift compiler type-check the body.
    @ViewBuilder
    private func transitionOverlay() -> some View {
        ZStack {
            // Persistent black background to prevent white flash during phase switches
            if transitionPhase != .idle {
                Color.black
                    .ignoresSafeArea()
            }

            // Ghost image for entering/exiting phases
            switch transitionPhase {
            case .entering(let sourceFrame, let imageURL, let aspectRatio):
                enteringGhostView(sourceFrame: sourceFrame, imageURL: imageURL, aspectRatio: aspectRatio)
                    .zIndex(2)

            case .exiting(let sourceFrame, let imageURL, let aspectRatio):
                exitingGhostView(sourceFrame: sourceFrame, imageURL: imageURL, aspectRatio: aspectRatio)
                    .zIndex(2)

            case .fullscreen, .idle:
                EmptyView()
            }

            // Pre-warmed FullscreenImageView — mounted during .entering to give
            // glassEffect and image loading a head start.
            // 始终保持 opacity 1，使玻璃效果从挂载起就正常捕获背景。
            // 幽灵图（zIndex 2）的纯黑背景会完全遮盖它，用户不会看到。
            #if os(iOS)
            if transitionPhase.isEnteringOrFullscreen {
                FullscreenImageView(
                    imageURLs: vm.zoomImageURLs,
                    fallbackImageURLs: vm.detailImageURLs,
                    aspectRatios: vm.zoomImageAspectRatios,
                    initialPage: currentPageBinding,
                    isPresented: $isFullscreen,
                    exitDragProgress: $exitDragProgress,
                    ugoiraStore: vm.isUgoira ? vm.ugoiraStore : nil
                )
                .zIndex(1)
            }
            #endif
        }
    }

    // MARK: - Ghost View Builders

    @ViewBuilder
    private func enteringGhostView(sourceFrame: CGRect, imageURL: String, aspectRatio: CGFloat) -> some View {
        GeometryReader { overlayGeo in
            let origin = overlayGeo.frame(in: .global).origin
            let localSource = CGRect(
                origin: CGPoint(x: sourceFrame.origin.x - origin.x,
                                y: sourceFrame.origin.y - origin.y),
                size: sourceFrame.size
            )
            let localTarget = targetFrame(in: overlayGeo.size, aspectRatio: aspectRatio)
            ZStack {
                // 始终不透明，遮盖下方的 FullscreenImageView（含玻璃按钮）
                // 使玻璃效果有充足时间捕获背景并完成初始化。
                Color.black
                    .ignoresSafeArea()

                KingfisherGhostImage(
                    urlString: imageURL,
                    aspectRatio: aspectRatio
                )
                .frame(
                    width: interpolatedWidth(from: localSource, to: localTarget),
                    height: interpolatedHeight(from: localSource, to: localTarget)
                )
                .position(
                    x: interpolatedX(from: localSource, to: localTarget),
                    y: interpolatedY(from: localSource, to: localTarget)
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func exitingGhostView(sourceFrame: CGRect, imageURL: String, aspectRatio: CGFloat) -> some View {
        GeometryReader { overlayGeo in
            let origin = overlayGeo.frame(in: .global).origin
            let localSource = CGRect(
                origin: CGPoint(x: sourceFrame.origin.x - origin.x,
                                y: sourceFrame.origin.y - origin.y),
                size: sourceFrame.size
            )
            let localTarget = targetFrame(in: overlayGeo.size, aspectRatio: aspectRatio)
            // 调整起始 frame 以匹配用户拖拽关闭时的位置和缩放
            let adjustedScale = 1.0 - exitDragProgress * 0.3
            let adjustedSize = CGSize(
                width: localTarget.width * adjustedScale,
                height: localTarget.height * adjustedScale
            )
            let adjustedCenter = CGPoint(
                x: localTarget.midX,
                y: localTarget.midY + exitDragProgress * overlayGeo.size.height
            )
            let adjustedStart = CGRect(
                origin: CGPoint(
                    x: adjustedCenter.x - adjustedSize.width / 2,
                    y: adjustedCenter.y - adjustedSize.height / 2
                ),
                size: adjustedSize
            )
            ZStack {
                // 始终不透明，遮盖 FullscreenImageView
                Color.black
                    .ignoresSafeArea()

                KingfisherGhostImage(
                    urlString: imageURL,
                    fallbackURLString: enteringTransitionImageURL,
                    aspectRatio: aspectRatio
                )
                .frame(
                    width: interpolatedWidth(from: adjustedStart, to: localSource),
                    height: interpolatedHeight(from: adjustedStart, to: localSource)
                )
                .position(
                    x: interpolatedX(from: adjustedStart, to: localSource),
                    y: interpolatedY(from: adjustedStart, to: localSource)
                )
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
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

private struct FullscreenTabBarVisibilityModifier: ViewModifier {
    let isHidden: Bool

    func body(content: Content) -> some View {
        if isHidden {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}
#endif
