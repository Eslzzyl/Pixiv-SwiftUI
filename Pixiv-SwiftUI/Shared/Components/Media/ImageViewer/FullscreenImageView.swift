#if os(iOS)
import SwiftUI
import UIKit
import Kingfisher

private enum FullscreenTransitionPhase {
    case entering
    case idle
    case exiting
}

struct FullscreenImageView: View {
    let imageURLs: [String]
    let fallbackImageURLChains: [[String]]
    let aspectRatios: [CGFloat]
    @Binding var initialPage: Int
    @Binding var isPresented: Bool
    var sourceFrame: CGRect = .zero
    var ugoiraStore: UgoiraStore?

    @State private var phase: FullscreenTransitionPhase = .entering
    @State private var animProgress: CGFloat = 0.0
    @State private var exitStartFrame: CGRect = .zero
    @State private var exitEndFrame: CGRect = .zero

    @State private var dragOffset: CGSize = .zero
    @State private var dragScale: CGFloat = 1.0
    @State private var isDraggingToDismiss = false
    @State private var backgroundOpacity: Double = 0.0
    @State private var controlsOpacity: Double = 0.0
    @State private var contentOpacity: Double = 1.0
    @State private var isDismissing = false
    @State private var isTargetQualityEnabled = false

    @State private var showTranslation = false
    @State private var translationStore = ImageTranslationStore()

    // Zoom state for the current page
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var lastZoomOffset: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0

    @State private var singleTapTask: Task<Void, Never>?
    @State private var lastTapTime: TimeInterval = 0
    @State private var initialDragTranslation: CGSize?

    private let pages: [FullscreenImagePage]

    init(
        imageURLs: [String],
        fallbackImageURLs: [String] = [],
        aspectRatios: [CGFloat],
        initialPage: Binding<Int>,
        isPresented: Binding<Bool>,
        sourceFrame: CGRect = .zero,
        ugoiraStore: UgoiraStore? = nil,
        fallbackImageURLChains: [[String]]? = nil
    ) {
        self.imageURLs = imageURLs
        let resolvedFallbackImageURLChains = fallbackImageURLChains ?? fallbackImageURLs.map { [$0] }
        self.fallbackImageURLChains = resolvedFallbackImageURLChains
        self.aspectRatios = aspectRatios
        self._initialPage = initialPage
        self._isPresented = isPresented
        self.sourceFrame = sourceFrame
        self.ugoiraStore = ugoiraStore

        let pages = imageURLs.enumerated().map { index, imageURL in
            FullscreenImagePage(
                index: index,
                imageURL: imageURL,
                fallbackImageURLs: resolvedFallbackImageURLChains.indices.contains(index)
                    ? resolvedFallbackImageURLChains[index]
                    : [],
                aspectRatio: aspectRatios.indices.contains(index) ? aspectRatios[index] : 1
            )
        }
        self.pages = pages
    }

    private var currentAspectRatio: CGFloat {
        if aspectRatios.indices.contains(initialPage) {
            let ratio = aspectRatios[initialPage]
            return ratio > 0 && ratio.isFinite ? ratio : 1.0
        }
        return 1.0
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            let targetRect = aspectFitRect(for: currentAspectRatio, in: screenSize)

            ZStack {
                // 背景遮罩：支持点击背景关闭与拖拽交互透过
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if phase == .idle {
                            dismissToSource(targetRect: targetRect)
                        }
                    }

                // 主内容容器
                if phase == .idle || phase == .exiting {
                    interactivePagingView(screenSize: screenSize, targetRect: targetRect)
                        .scaleEffect(dragScale)
                        .offset(dragOffset)
                        .opacity(contentOpacity)
                        .simultaneousGesture(
                            zoomScale <= 1.02 && !isDismissing
                                ? dismissDragGesture(screenHeight: screenSize.height, targetRect: targetRect)
                                : nil
                        )
                } else if phase == .entering {
                    let initialSource = (sourceFrame != .zero && sourceFrame.width > 0 && sourceFrame.height > 0)
                        ? sourceFrame
                        : CGRect(x: targetRect.midX - 20, y: targetRect.midY - 20, width: 40, height: 40)

                    heroImage(for: initialPage)
                        .modifier(HeroFrameModifier(progress: animProgress, source: initialSource, target: targetRect))
                        .opacity(contentOpacity)
                }

                // 覆盖控制栏（分页计数）
                fullscreenOverlay(geometry: geometry)
                    .opacity(controlsOpacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                contentOpacity = 1.0
                guard phase == .entering else { return }
                try? await Task.sleep(for: .milliseconds(12))
                withAnimation(.spring(response: 0.22, dampingFraction: 0.86), completionCriteria: .removed) {
                    animProgress = 1.0
                    backgroundOpacity = 1.0
                } completion: {
                    guard !isDismissing else { return }
                    phase = .idle
                    isTargetQualityEnabled = true
                    withAnimation(.easeIn(duration: 0.1)) {
                        controlsOpacity = 1.0
                    }
                }

                try? await Task.sleep(for: .milliseconds(350))
                if phase == .entering && !isDismissing {
                    phase = .idle
                    isTargetQualityEnabled = true
                    withAnimation(.easeIn(duration: 0.1)) {
                        controlsOpacity = 1.0
                    }
                }
            }
            .onChange(of: initialPage) { _, _ in
                resetZoom(animated: false)
            }
            .sheet(isPresented: $showTranslation) {
                ImageTranslationPanelView(store: translationStore) {
                    showTranslation = false
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Hero Transition Image

    @ViewBuilder
    private func heroImage(for pageIndex: Int) -> some View {
        if pageIndex == 0, let store = ugoiraStore, store.isReady {
            UgoiraView(
                frameURLs: store.frameURLs,
                frameDelays: store.frameDelays,
                aspectRatio: currentAspectRatio,
                expiration: store.expiration,
                shouldAutoPlay: true,
                isPlaying: .constant(true)
            )
            .allowsHitTesting(false)
        } else if pages.indices.contains(pageIndex) {
            singlePageView(pages[pageIndex])
                .allowsHitTesting(false)
        }
    }

    // MARK: - Interactive Paging View

    @ViewBuilder
    private func interactivePagingView(screenSize: CGSize, targetRect: CGRect) -> some View {
        if pages.count > 1 {
            TabView(selection: $initialPage) {
                ForEach(pages, id: \.self) { page in
                    pageContainer(page, screenSize: screenSize, targetRect: targetRect)
                        .ignoresSafeArea()
                        .tag(page.index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
        } else if let firstPage = pages.first {
            pageContainer(firstPage, screenSize: screenSize, targetRect: targetRect)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func pageContainer(_ page: FullscreenImagePage, screenSize: CGSize, targetRect: CGRect) -> some View {
        let isCurrentPage = page.index == initialPage
        let pageTargetRect = aspectFitRect(for: page.aspectRatio, in: screenSize)

        ZStack {
            // 背景点击响应区：点在黑边区域直接 0ms 延迟退出全屏
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if phase == .idle && !isDismissing {
                        singleTapTask?.cancel()
                        singleTapTask = nil
                        if zoomScale > 1.02 {
                            resetZoom(animated: true)
                        } else {
                            dismissToSource(targetRect: pageTargetRect)
                        }
                    }
                }

            singlePageView(page)
                .frame(width: pageTargetRect.width, height: pageTargetRect.height)
                .contentShape(Rectangle())
                .scaleEffect(isCurrentPage ? zoomScale : 1.0)
                .offset(isCurrentPage ? zoomOffset : .zero)
                .gesture(
                    isCurrentPage ? magnifyGesture : nil
                )
                .gesture(
                    isCurrentPage && zoomScale > 1.02 ? panZoomGesture(screenSize: screenSize) : nil
                )
                .onTapGesture {
                    if isCurrentPage {
                        handleImageTap(targetRect: pageTargetRect)
                    }
                }
                .contextMenu {
                    Button(action: translateCurrentImage) {
                        Label(String(localized: "翻译图片"), systemImage: "text.bubble")
                    }
                    if UserSettingStore.shared.userSetting.vlmEnabled {
                        Button(action: explainCurrentImage) {
                            Label(String(localized: "解释图片"), systemImage: "wand.and.stars")
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func singlePageView(_ page: FullscreenImagePage) -> some View {
        if page.index == 0, let store = ugoiraStore, store.isReady {
            UgoiraView(
                frameURLs: store.frameURLs,
                frameDelays: store.frameDelays,
                aspectRatio: page.aspectRatio,
                expiration: store.expiration,
                shouldAutoPlay: true,
                isPlaying: .constant(true)
            )
        } else {
            let detailURLString = page.fallbackImageURLs.first ?? page.imageURL
            let targetURLString = page.imageURL
            let cachedImage = getCachedImage(for: page)

            ZStack {
                // 1. 底层：详情页已缓存的当前画质（优先同步显示已解码的内存/磁盘UIImage，零黑屏延迟）
                if let cachedImage {
                    Image(uiImage: cachedImage)
                        .resizable()
                        .aspectRatio(page.aspectRatio, contentMode: .fit)
                } else if let detailURL = URL(string: detailURLString), !detailURLString.isEmpty {
                    makeKFImage(url: detailURL)
                        .fade(duration: 0.15)
                        .resizable()
                        .aspectRatio(page.aspectRatio, contentMode: .fit)
                }

                // 2. 顶层：目标高画质图（原图）。在进场动画完成后异步加载并淡入覆盖，完成替换
                if isTargetQualityEnabled, targetURLString != detailURLString,
                   let targetURL = URL(string: targetURLString), !targetURLString.isEmpty {
                    makeKFImage(url: targetURL)
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(page.aspectRatio, contentMode: .fit)
                }
            }
        }
    }

    // MARK: - Zoom Gestures

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let delta = value.magnification / lastMagnification
                lastMagnification = value.magnification
                let newScale = zoomScale * delta
                zoomScale = min(max(newScale, 0.85), 5.0)
            }
            .onEnded { _ in
                lastMagnification = 1.0
                if zoomScale < 1.0 {
                    withAnimation(.spring(response: 0.20, dampingFraction: 0.82)) {
                        zoomScale = 1.0
                        zoomOffset = .zero
                        lastZoomOffset = .zero
                    }
                }
            }
    }

    private func panZoomGesture(screenSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let newOffset = CGSize(
                    width: lastZoomOffset.width + value.translation.width,
                    height: lastZoomOffset.height + value.translation.height
                )
                let maxW = max(0, (screenSize.width * zoomScale - screenSize.width) / 2)
                let maxH = max(0, (screenSize.height * zoomScale - screenSize.height) / 2)
                zoomOffset = CGSize(
                    width: min(max(newOffset.width, -maxW), maxW),
                    height: min(max(newOffset.height, -maxH), maxH)
                )
            }
            .onEnded { _ in
                lastZoomOffset = zoomOffset
            }
    }

    private func toggleDoubleTapZoom() {
        withAnimation(.spring(response: 0.20, dampingFraction: 0.82)) {
            if zoomScale > 1.02 {
                zoomScale = 1.0
                zoomOffset = .zero
                lastZoomOffset = .zero
            } else {
                zoomScale = 2.5
            }
        }
    }

    private func resetZoom(animated: Bool) {
        if animated {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.82)) {
                zoomScale = 1.0
                zoomOffset = .zero
                lastZoomOffset = .zero
            }
        } else {
            zoomScale = 1.0
            zoomOffset = .zero
            lastZoomOffset = .zero
        }
    }

    private func handleImageTap(targetRect: CGRect) {
        guard phase == .idle, !isDismissing else { return }

        // 若当前处于放大态，点击意图明确是复位还原，立即执行无需等待消歧义
        if zoomScale > 1.02 {
            singleTapTask?.cancel()
            singleTapTask = nil
            resetZoom(animated: true)
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        if now - lastTapTime < 0.25 {
            // 双击放大：取消待执行的单击退出任务，立即响应放大
            singleTapTask?.cancel()
            singleTapTask = nil
            lastTapTime = 0
            toggleDoubleTapZoom()
        } else {
            // 单击退出：启动 220ms 灵敏倒计时消歧义（大幅缩短系统默认 ~400ms 迟滞）
            lastTapTime = now
            singleTapTask?.cancel()
            singleTapTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                dismissToSource(targetRect: targetRect)
            }
        }
    }

    // MARK: - Overlay Controls

    @ViewBuilder
    private func fullscreenOverlay(geometry: GeometryProxy) -> some View {
        if pages.count > 1 {
            VStack(spacing: 0) {
                Spacer()

                Text("\(initialPage + 1) / \(pages.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background {
                        if #available(iOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.clear)
                                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 16) + 12)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Dismiss Pan Gesture

    private func dismissDragGesture(screenHeight: CGFloat, targetRect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard phase == .idle, !isDismissing else { return }
                let translation = value.translation

                if !isDraggingToDismiss {
                    // 判断垂直拉动主导：垂直位移大于横向，且超过 6pt 起始死区（无论向上还是向下拖拽均可触发）
                    let isVertical = abs(translation.height) > abs(translation.width) * 1.1
                    let hasMovedVertically = abs(translation.height) > 6

                    if isVertical && hasMovedVertically {
                        singleTapTask?.cancel()
                        singleTapTask = nil
                        isDraggingToDismiss = true
                        initialDragTranslation = translation
                        handleDismissPanChanged(translation: .zero, screenHeight: screenHeight)
                    }
                } else {
                    let adjustedTranslation = CGSize(
                        width: translation.width - (initialDragTranslation?.width ?? 0),
                        height: translation.height - (initialDragTranslation?.height ?? 0)
                    )
                    handleDismissPanChanged(translation: adjustedTranslation, screenHeight: screenHeight)
                }
            }
            .onEnded { value in
                guard phase == .idle, !isDismissing else { return }
                if isDraggingToDismiss {
                    isDraggingToDismiss = false
                    let adjustedTranslation = CGSize(
                        width: value.translation.width - (initialDragTranslation?.width ?? 0),
                        height: value.translation.height - (initialDragTranslation?.height ?? 0)
                    )
                    initialDragTranslation = nil
                    handleDismissPanEnded(
                        translation: adjustedTranslation,
                        velocity: value.velocity,
                        screenHeight: screenHeight,
                        targetRect: targetRect
                    )
                }
            }
    }

    private func handleDismissPanChanged(translation: CGSize, screenHeight: CGFloat) {
        // 双向拖拽：1:1 绝对跟手（X/Y 轴均跟随手指真实物理轨迹）
        dragOffset = CGSize(width: translation.width, height: translation.height)

        // 无论向上或向下拖拽，均呈现一致细腻的非线性缩放与背景透出
        let pullDistance = abs(translation.height)
        let progress = min(1.0, max(0.0, pullDistance / max(screenHeight * 0.65, 1)))
        dragScale = max(0.72, 1.0 - pow(progress, 0.9) * 0.28)
        backgroundOpacity = max(0.0, 1.0 - pow(progress, 1.15) * 1.0)
        controlsOpacity = max(0.0, 1.0 - progress * 3.0)
    }

    private func handleDismissPanEnded(
        translation: CGSize,
        velocity: CGSize,
        screenHeight: CGFloat,
        targetRect: CGRect
    ) {
        let dragDistanceY = abs(translation.height)
        let speedY = abs(velocity.height)

        // 无论向上甩还是向下甩，只要速度充沛（>400）或拉拽距离充分（>70pt），即判定为退出
        let isFastFlick = speedY > 400 && dragDistanceY > 20
        let isDraggedSufficiently = dragDistanceY > 70
        let shouldDismiss = isFastFlick || isDraggedSufficiently

        if shouldDismiss {
            // 根据下/上甩释放速度动态适配弹簧响应时长，保留真实物理甩出惯性
            let response = max(0.16, min(0.24, 0.24 - (speedY / 3000.0) * 0.08))
            dismissToSource(targetRect: targetRect, response: response)
        } else {
            resetDismissPan()
        }
    }

    private func resetDismissPan() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.84)) {
            dragOffset = .zero
            dragScale = 1.0
            backgroundOpacity = 1.0
            controlsOpacity = 1.0
        }
    }

    private func dismissToSource(targetRect: CGRect, response: Double = 0.22) {
        guard !isDismissing else { return }
        singleTapTask?.cancel()
        singleTapTask = nil
        isDismissing = true
        phase = .exiting

        let hasValidSource = (sourceFrame != .zero && sourceFrame.width > 0 && sourceFrame.height > 0)
        let finalScale = hasValidSource ? (sourceFrame.width / max(targetRect.width, 1)) : 0.65
        let finalOffset = hasValidSource
            ? CGSize(width: sourceFrame.midX - targetRect.midX, height: sourceFrame.midY - targetRect.midY)
            : CGSize(width: 0, height: targetRect.height * 0.35)

        withAnimation(.spring(response: response, dampingFraction: 0.88), completionCriteria: .removed) {
            dragOffset = finalOffset
            dragScale = finalScale
            backgroundOpacity = 0.0
            controlsOpacity = 0.0
            if !hasValidSource {
                contentOpacity = 0.0
            }
        } completion: {
            finishDismiss()
        }

        // 兜底超时：避免极端场景下 completion 未触发导致全屏状态挂起
        let fallbackTimeout = max(350, Int(response * 2500))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(fallbackTimeout))
            finishDismiss()
        }
    }

    private func finishDismiss() {
        guard isPresented else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            contentOpacity = 0.0
            isPresented = false
        }
    }

    // MARK: - Helpers

    private func aspectFitRect(for aspectRatio: CGFloat, in containerSize: CGSize) -> CGRect {
        guard aspectRatio > 0, aspectRatio.isFinite else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let containerW = containerSize.width
        let containerH = containerSize.height
        guard containerW > 0, containerH > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let heightFromWidth = containerW / aspectRatio
        if heightFromWidth <= containerH {
            let y = (containerH - heightFromWidth) / 2
            return CGRect(x: 0, y: y, width: containerW, height: heightFromWidth)
        } else {
            let widthFromHeight = containerH * aspectRatio
            let x = (containerW - widthFromHeight) / 2
            return CGRect(x: x, y: 0, width: widthFromHeight, height: containerH)
        }
    }

    private func translateCurrentImage() {
        guard pages.indices.contains(initialPage) else { return }
        let page = pages[initialPage]
        showTranslation = true
        Task {
            await translationStore.translateImage(urlString: page.imageURL)
        }
    }

    private func explainCurrentImage() {
        guard pages.indices.contains(initialPage) else { return }
        let page = pages[initialPage]
        showTranslation = true
        Task {
            await translationStore.explainImage(urlString: page.imageURL)
        }
    }

    // MARK: - Direct Connection & Image Cache Helpers

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    private func makeKFImage(url: URL) -> KFImage {
        let source: Kingfisher.Source
        if shouldUseDirectConnection(url: url) {
            source = .directNetwork(url, priority: ImageRequestPriority.visible)
        } else {
            source = .network(KF.ImageResource(downloadURL: url))
        }
        return KFImage.source(source)
            .requestModifier(PixivImageLoader.shared)
            .cacheOriginalImage()
    }

    private func getCachedImage(for urlString: String) -> UIImage? {
        guard !urlString.isEmpty else { return nil }
        return ImageCache.default.retrieveImageInMemoryCache(forKey: urlString)
    }

    private func getCachedImage(for page: FullscreenImagePage) -> UIImage? {
        for url in page.fallbackImageURLs {
            if let image = getCachedImage(for: url) {
                return image
            }
        }
        if let image = getCachedImage(for: page.imageURL) {
            return image
        }
        return nil
    }
}

// MARK: - Hero Transition Animatable Modifier

private struct HeroFrameModifier: AnimatableModifier {
    var progress: CGFloat
    let source: CGRect
    let target: CGRect

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let frameWidth = source.width + (target.width - source.width) * progress
        let frameHeight = source.height + (target.height - source.height) * progress
        let centerX = source.midX + (target.midX - source.midX) * progress
        let centerY = source.midY + (target.midY - source.midY) * progress

        content
            .frame(width: max(1, frameWidth), height: max(1, frameHeight))
            .position(x: centerX, y: centerY)
    }
}

private struct FullscreenImagePage: Hashable {
    let index: Int
    let imageURL: String
    let fallbackImageURLs: [String]
    let aspectRatio: CGFloat
}

#Preview("Fullscreen Pager") {
    FullscreenImageView(
        imageURLs: [
            "preview-image-0",
            "preview-image-1"
        ],
        fallbackImageURLs: [],
        aspectRatios: [0.75, 0.75],
        initialPage: .constant(0),
        isPresented: .constant(true),
        sourceFrame: CGRect(x: 20, y: 120, width: 350, height: 350)
    )
}
#endif
