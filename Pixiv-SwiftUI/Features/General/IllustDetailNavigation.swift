import SwiftUI

enum IllustDetailNavigationDirection {
    case previous
    case next
}

typealias IllustDetailNavigationContextProvider = @MainActor () -> [Illusts]
typealias IllustDetailNavigationLoadMore = @MainActor () async -> Void
typealias IllustDetailNavigationLoadingState = @MainActor () -> Bool

@MainActor
final class IllustDetailNavigationSession: Hashable {
    let id = UUID()
    let initialContext: [Illusts]
    let contextProvider: IllustDetailNavigationContextProvider?
    let hasMore: IllustDetailNavigationLoadingState?
    let loadMore: IllustDetailNavigationLoadMore?

    init(
        context: [Illusts],
        contextProvider: IllustDetailNavigationContextProvider? = nil,
        hasMore: IllustDetailNavigationLoadingState? = nil,
        loadMore: IllustDetailNavigationLoadMore? = nil
    ) {
        var seen = Set<Int>()
        let normalizedContext = context.filter { seen.insert($0.id).inserted }
        self.initialContext = normalizedContext
        self.contextProvider = contextProvider
        self.hasMore = hasMore
        self.loadMore = loadMore
    }

    static func == (lhs: IllustDetailNavigationSession, rhs: IllustDetailNavigationSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct IllustDetailNavigationTarget: Hashable {
    let illust: Illusts
    let session: IllustDetailNavigationSession

    init(
        illust: Illusts,
        context: [Illusts] = [],
        contextProvider: IllustDetailNavigationContextProvider? = nil,
        hasMore: IllustDetailNavigationLoadingState? = nil,
        loadMore: IllustDetailNavigationLoadMore? = nil
    ) {
        self.illust = illust
        var seen = Set<Int>()
        var normalizedContext = context.filter { seen.insert($0.id).inserted }
        if !seen.contains(illust.id) {
            normalizedContext.insert(illust, at: 0)
        }
        self.session = IllustDetailNavigationSession(
            context: normalizedContext,
            contextProvider: contextProvider,
            hasMore: hasMore,
            loadMore: loadMore
        )
    }

    static func == (lhs: IllustDetailNavigationTarget, rhs: IllustDetailNavigationTarget) -> Bool {
        lhs.illust.id == rhs.illust.id && lhs.session == rhs.session
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(illust.id)
        hasher.combine(session)
    }
}

#Preview("插画详情导航") {
    let illust = Illusts(
        id: 123,
        title: "示例插画",
        type: "illust",
        imageUrls: ImageUrls(squareMedium: "", medium: "", large: ""),
        caption: "",
        restrict: 0,
        user: User(id: .string("1"), name: "示例用户", account: "preview"),
        tags: [],
        tools: [],
        createDate: "",
        pageCount: 1,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 0,
        totalBookmarks: 0,
        isBookmarked: false,
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    NavigationStack {
        IllustDetailNavigationLink(illust: illust, context: [illust]) {
            Text("打开示例插画")
                .padding()
        }
    }
}

struct IllustDetailNavigationLink<Label: View>: View {
    private let target: IllustDetailNavigationTarget
    private let label: () -> Label
    @Namespace private var transitionNamespace

    init(
        illust: Illusts,
        context: [Illusts],
        contextProvider: IllustDetailNavigationContextProvider? = nil,
        hasMore: IllustDetailNavigationLoadingState? = nil,
        loadMore: IllustDetailNavigationLoadMore? = nil,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.target = IllustDetailNavigationTarget(
            illust: illust,
            context: context,
            contextProvider: contextProvider,
            hasMore: hasMore,
            loadMore: loadMore
        )
        self.label = label
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            sourceLabel
        }
    }

    @ViewBuilder
    private var sourceLabel: some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            label()
                .matchedTransitionSource(id: target.illust.id, in: transitionNamespace)
        } else {
            label()
        }
        #else
        label()
        #endif
    }

    @ViewBuilder
    private var destination: some View {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            IllustDetailBrowserView(
                target: target
            )
                .navigationTransition(.zoom(sourceID: target.illust.id, in: transitionNamespace))
        } else {
            IllustDetailBrowserView(
                target: target
            )
        }
        #else
        IllustDetailBrowserView(
            target: target
        )
        #endif
    }
}

struct IllustDetailBrowserView: View {
    @State private var context: [Illusts]
    private let contextProvider: IllustDetailNavigationContextProvider?
    private let hasMore: IllustDetailNavigationLoadingState?
    private let loadMore: IllustDetailNavigationLoadMore?
    @Environment(\.dismiss) private var dismiss
    @State private var currentIllustID: Int
    @State private var isLoadingMore = false
    @State private var loadMoreRequestID = 0
    @State private var pendingNavigationDirection: IllustDetailNavigationDirection?
    @State private var horizontalDragOffset: CGFloat = 0
    @State private var isHorizontalGestureActive = false
    @State private var horizontalTransitionToken = 0
    @State private var currentDetailSubpage: Int = 0
    #if os(iOS)
    @State private var currentImageFrame: CGRect = .zero
    #endif
    @State private var measuredWidth: CGFloat = 0

    private let preloadThreshold = 2

    init(illust: Illusts, context: [Illusts] = []) {
        let target = IllustDetailNavigationTarget(illust: illust, context: context)
        self.init(target: target)
    }

    init(
        target: IllustDetailNavigationTarget,
        contextProvider: IllustDetailNavigationContextProvider? = nil,
        hasMore: IllustDetailNavigationLoadingState? = nil,
        loadMore: IllustDetailNavigationLoadMore? = nil
    ) {
        let session = target.session
        let initialContext = session.initialContext
        _context = State(initialValue: initialContext)
        self.contextProvider = contextProvider ?? session.contextProvider
        self.hasMore = hasMore ?? session.hasMore
        self.loadMore = loadMore ?? session.loadMore
        _currentIllustID = State(initialValue: target.illust.id)
    }

    private var currentIndex: Int? {
        context.firstIndex { $0.id == currentIllustID }
    }

    private var currentIllust: Illusts? {
        guard let currentIndex else { return nil }
        return context[currentIndex]
    }

    private var currentIllustTotalPages: Int {
        guard let currentIllust else { return 1 }
        return max(currentIllust.pageCount, currentIllust.metaPages.count, 1)
    }

    private var isCurrentIllustMultiPage: Bool {
        currentIllustTotalPages > 1
    }

    private var isCurrentIllustFirstPage: Bool {
        currentDetailSubpage <= 0
    }

    private var isCurrentIllustLastPage: Bool {
        currentDetailSubpage >= currentIllustTotalPages - 1
    }

    private var hasPreviousIllust: Bool {
        guard let currentIndex else { return false }
        return currentIndex > 0
    }

    private var hasNextIllust: Bool {
        guard let currentIndex else { return false }
        return currentIndex < context.count - 1
    }

    private var pageWidth: CGFloat {
        if measuredWidth > 0 {
            return measuredWidth
        }
        #if os(iOS)
        return UIScreen.main.bounds.width
        #elseif os(macOS)
        return NSScreen.main?.frame.width ?? 800
        #else
        return 390
        #endif
    }

    private var isBrowsingPagingActive: Bool {
        isHorizontalGestureActive || horizontalDragOffset != 0
    }

    var body: some View {
        let providedContextIDs = contextProvider?().map(\.id) ?? []

        browserContent(width: pageWidth)
            #if os(iOS)
            .background {
                IllustDetailRegionSwipeView(
                    excludedFrame: currentImageFrame,
                    fallbackAspectRatio: currentIllust?.safeAspectRatio ?? 1,
                    isMultiPage: isCurrentIllustMultiPage,
                    isFirstPage: isCurrentIllustFirstPage,
                    isLastPage: isCurrentIllustLastPage,
                    onChanged: handleHorizontalDragChanged,
                    onEnded: { translation, velocity in
                        handleHorizontalDragEnded(
                            translation: translation,
                            velocity: velocity,
                            pageWidth: pageWidth
                        )
                    },
                    onCancelled: resetHorizontalDrag
                )
            }
            #endif
            .overlay(alignment: .bottom) {
                loadingIndicator
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: IllustBrowserWidthPreferenceKey.self, value: proxy.size.width)
                }
            }
            .onPreferenceChange(IllustBrowserWidthPreferenceKey.self) { newWidth in
                if newWidth > 0 && abs(newWidth - measuredWidth) > 0.5 {
                    measuredWidth = newWidth
                }
            }
            .navigationTitle(currentIllust?.title ?? "")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #if os(iOS)
            .onPreferenceChange(ImageFramePreferenceKey.self) { frame in
                if frame != .zero {
                    currentImageFrame = frame
                }
            }
            #endif
            .onAppear {
                requestMoreIfNeeded()
            }
            .onChange(of: currentIllustID) { _, _ in
                requestMoreIfNeeded()
                #if os(iOS)
                currentImageFrame = .zero
                #endif
                currentDetailSubpage = 0
            }
            .onChange(of: providedContextIDs, initial: true) { _, _ in
                synchronizeContext()
            }
            .task(id: loadMoreRequestID) {
                guard loadMoreRequestID > 0 else { return }
                await loadMoreContext()
            }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        if isLoadingMore {
            ProgressView()
                .padding(10)
                .background(.ultraThinMaterial, in: .capsule)
                .padding(.bottom, 12)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func browserContent(width: CGFloat) -> some View {
        if let currentIndex {
            ZStack(alignment: .topLeading) {
                if let currentIllust {
                    detailPage(
                        illust: currentIllust,
                        width: width,
                        isCurrent: true
                    )
                    .offset(x: horizontalDragOffset)
                }

                if isBrowsingPagingActive, currentIndex > 0 {
                    detailPage(
                        illust: context[currentIndex - 1],
                        width: width,
                        isCurrent: false
                    )
                    .offset(x: -width + horizontalDragOffset)
                }

                if isBrowsingPagingActive, currentIndex + 1 < context.count {
                    detailPage(
                        illust: context[currentIndex + 1],
                        width: width,
                        isCurrent: false
                    )
                    .offset(x: width + horizontalDragOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView("作品不可用", systemImage: "photo.badge.exclamationmark")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func detailPage(illust: Illusts, width: CGFloat, isCurrent: Bool) -> some View {
        IllustDetailView(
            illust: illust,
            isCurrent: isCurrent,
            currentPage: isCurrent ? $currentDetailSubpage : nil,
            onNavigate: navigate,
            canNavigatePrevious: hasPreviousIllust,
            canNavigateNext: hasNextIllust
        )
        .id(illust.id)
        .frame(width: max(width, 1))
    }

    private func handleHorizontalDragChanged(_ translation: CGFloat) {
        if !isHorizontalGestureActive {
            horizontalTransitionToken += 1
        }
        isHorizontalGestureActive = true
        let hasTarget = translation < 0 ? hasNextIllust : hasPreviousIllust
        horizontalDragOffset = hasTarget ? translation : translation * 0.25
    }

    private func handleHorizontalDragEnded(translation: CGFloat, velocity: CGFloat, pageWidth: CGFloat) {
        guard isHorizontalGestureActive else {
            resetHorizontalDrag()
            return
        }

        isHorizontalGestureActive = false
        let projectedTranslation = translation + velocity * 0.12
        let direction: IllustDetailNavigationDirection = projectedTranslation < 0 ? .next : .previous
        let hasTarget = direction == .next ? hasNextIllust : hasPreviousIllust
        let distanceThreshold = max(pageWidth * 0.25, 80)
        let projectedThreshold = max(pageWidth * 0.5, 160)
        let shouldCommit = abs(translation) >= distanceThreshold
            || abs(projectedTranslation) >= projectedThreshold
            || abs(velocity) >= 900

        guard shouldCommit, hasTarget else {
            if direction == .next, hasMore?() == true {
                pendingNavigationDirection = .next
                requestMoreIfNeeded()
            } else {
                pendingNavigationDirection = nil
            }
            resetHorizontalDrag()
            return
        }

        let targetOffset = direction == .next ? -pageWidth : pageWidth
        horizontalTransitionToken += 1
        let transitionToken = horizontalTransitionToken
        withAnimation(.easeOut(duration: 0.2)) {
            horizontalDragOffset = targetOffset
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard transitionToken == horizontalTransitionToken else { return }
            commitHorizontalNavigation(direction)
        }
    }

    private func resetHorizontalDrag() {
        horizontalTransitionToken += 1
        withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86)) {
            horizontalDragOffset = 0
        }
        isHorizontalGestureActive = false
    }

    private func commitHorizontalNavigation(_ direction: IllustDetailNavigationDirection) {
        guard let currentIndex else {
            resetHorizontalDrag()
            return
        }

        let destinationIndex = direction == .next ? currentIndex + 1 : currentIndex - 1
        guard context.indices.contains(destinationIndex) else {
            resetHorizontalDrag()
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            currentIllustID = context[destinationIndex].id
            horizontalDragOffset = 0
        }
    }

    private func navigate(_ direction: IllustDetailNavigationDirection) {
        guard let currentIndex else { return }

        let destinationIndex: Int
        switch direction {
        case .previous:
            destinationIndex = currentIndex - 1
        case .next:
            destinationIndex = currentIndex + 1
        }

        if context.indices.contains(destinationIndex) {
            move(to: destinationIndex)
            return
        }

        guard direction == .next, hasMore?() == true else { return }
        pendingNavigationDirection = direction
        requestMoreIfNeeded()
    }

    private func move(to index: Int) {
        guard context.indices.contains(index) else { return }
        horizontalTransitionToken += 1
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIllustID = context[index].id
            horizontalDragOffset = 0
        }
    }

    private func requestMoreIfNeeded() {
        guard let currentIndex,
              context.count - 1 - currentIndex <= preloadThreshold,
              hasMore?() == true,
              loadMore != nil
        else { return }

        if isLoadingMore {
            return
        }

        isLoadingMore = true
        loadMoreRequestID += 1
    }

    private func loadMoreContext() async {
        defer { isLoadingMore = false }
        await loadMore?()
        guard !Task.isCancelled else { return }
        synchronizeContext()

        consumePendingNavigationIfPossible()
    }

    private func synchronizeContext() {
        guard let contextProvider else { return }
        let latestContext = contextProvider()
        guard let currentIllust else {
            context = latestContext
            return
        }

        let normalizedContext = normalizedContext(for: currentIllust, in: latestContext)
        if normalizedContext.map(\.id) != context.map(\.id) {
            context = normalizedContext
        }
        consumePendingNavigationIfPossible()
        requestMoreIfNeeded()
    }

    private func consumePendingNavigationIfPossible() {
        guard pendingNavigationDirection == .next else { return }

        guard let currentIndex else {
            pendingNavigationDirection = nil
            return
        }

        if context.indices.contains(currentIndex + 1) {
            pendingNavigationDirection = nil
            move(to: currentIndex + 1)
        } else if hasMore?() != true {
            pendingNavigationDirection = nil
        }
    }

    private func normalizedContext(for illust: Illusts, in context: [Illusts]) -> [Illusts] {
        var seen = Set<Int>()
        var normalizedContext = context.filter { seen.insert($0.id).inserted }
        if !seen.contains(illust.id) {
            normalizedContext.insert(illust, at: 0)
        }
        return normalizedContext
    }
}

private struct IllustBrowserWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}
