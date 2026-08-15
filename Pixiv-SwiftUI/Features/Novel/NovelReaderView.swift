import SwiftUI
import Kingfisher

struct NovelReaderView: View {
    let novelId: Int
    @State private var store: NovelReaderStore
    @Environment(UserSettingStore.self) private var userSettingStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSettings = false
    @State private var navigateToIllust: Int?
    @State private var navigateToNovel: Int?
    @State private var showSeriesNavigation = false
    @State private var selectedTab = 0
    @State private var scrollProxy: ScrollViewProxy?
    @State private var scrollPositionID: Int?

    init(novelId: Int) {
        self.novelId = novelId
        let initialStore = NovelReaderStore(novelId: novelId)
        _store = State(initialValue: initialStore)
        _scrollPositionID = State(initialValue: initialStore.savedIndex)
    }

    var body: some View {
        @Bindable var store = store
        ZStack {
            readerBackground
            contentView
        }
        .animation(.easeInOut(duration: 0.25), value: store.isLoading)
        .navigationTitle(store.novel?.title ?? "加载中...")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(iOS)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: {
                        Task {
                            await store.toggleBookmark()
                        }
                    }) {
                        Label(
                            store.isBookmarked ? "取消收藏" : "点赞收藏",
                            systemImage: store.isBookmarked ? "heart.fill" : "heart"
                        )
                    }

                    Divider()

                    #if os(macOS)
                    Button(action: {
                        // 延迟一帧开启，避免与 Menu 动画冲突导致 task_name_port 警告
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showSettings = true
                        }
                    }) {
                        Label("阅读设置", systemImage: "textformat.size")
                    }
                    #else
                    Button(action: { showSettings = true }) {
                        Label("阅读设置", systemImage: "textformat.size")
                    }
                    #endif

                    if store.hasSeriesNavigation {
                        Divider()

                        Button(action: { showSeriesNavigation = true }) {
                            Label("系列导航", systemImage: "list.bullet")
                        }
                    }

                    Button(action: {
                        Task { @MainActor in
                            if store.settings.translationDisplayMode == .translationOnly {
                                await store.toggleTranslationForTranslationOnly()
                            } else {
                                await store.toggleTranslation()
                            }
                        }
                    }) {
                        Label(
                            store.isTranslationEnabled ? "显示原文" : "全文翻译",
                            systemImage: "globe"
                        )
                    }

                    Divider()

                    ShareLink(item: "https://www.pixiv.net/novel/show.php?id=\(novelId)") {
                        Label("分享链接", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        #if os(macOS)
        .popover(isPresented: $showSettings) {
            NovelReaderSettingsView(store: store)
                .frame(width: 320, height: 420)
                .popoverCompactify()
        }
        #else
        .sheet(isPresented: $showSettings) {
            NovelReaderSettingsView(store: store)
        }
        #endif
        .sheet(isPresented: $showSeriesNavigation) {
            if let navigation = store.seriesNavigation {
                SeriesNavigationView(navigation: navigation) { selectedNovelId in
                    showSeriesNavigation = false
                    DispatchQueue.main.async {
                        openSeriesNovel(selectedNovelId)
                    }
                }
            }
        }
        .navigationDestination(item: $navigateToNovel) { novelId in
            NovelReaderView(novelId: novelId)
        }
        .navigationDestination(item: $navigateToIllust) { illustId in
            IllustDetailView(illust: Illusts(
                id: illustId,
                title: "",
                type: "illust",
                imageUrls: ImageUrls(squareMedium: "", medium: "", large: ""),
                caption: "",
                restrict: 0,
                user: User(profileImageUrls: nil, id: StringIntValue.string("0"), name: "", account: ""),
                tags: [],
                tools: [],
                createDate: "",
                pageCount: 1,
                width: 0,
                height: 0,
                sanityLevel: 0,
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
            ))
        }
        .task {
            await store.fetch()
        }
        .onDisappear {
            if let firstVisible = scrollPositionID {
                store.savePositionOnDisappear(firstVisible: firstVisible)
            }
        }
    }

    @ViewBuilder
    private var readerBackground: some View {
        Color(store.settings.theme.backgroundColor)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var contentView: some View {
        if store.isLoading {
            novelReaderSkeleton
                .transition(.opacity)
        } else if let error = store.error {
            ErrorStateView(message: error.localizedDescription ?? "未知错误", retryAction: {
                Task {
                    await store.fetch()
                }
            })
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 20)

                        if let translationError = store.translationError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(translationError)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.bottom, 12)
                        }

                        contentSection

                        if store.hasSeriesNavigation {
                            Divider()
                                .padding(.vertical, 20)

                            seriesNavigationSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, store.settings.horizontalPadding)
                    .scrollTargetLayout()
                }
                .scrollPositionCompat(id: $scrollPositionID)
                .onChange(of: scrollPositionID) { _, newValue in
                    if let index = newValue {
                        store.saveProgress(index: index)
                    }
                }
                .onAppear {
                    scrollProxy = proxy
                    performRestorePosition()
                }
                .onChange(of: store.isLoading) { _, loading in
                    if !loading {
                        performRestorePosition()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .novelReaderShouldRestorePosition)) { _ in
                    performRestorePosition()
                }
                .overlay(alignment: .bottomLeading) {
                    if !store.spans.isEmpty {
                        ReadingProgressTag(percentage: progressPercentage)
                            .padding(.leading, store.settings.horizontalPadding)
                            .padding(.bottom, 20)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    private var novelReaderSkeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 标题骨架
                SkeletonView(height: 22, width: 280, cornerRadius: 4)
                    .padding(.top, 20)

                // 模拟段落 - 每组 3-4 行文本
                Group {
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: 200, cornerRadius: 2)
                }

                Group {
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: 160, cornerRadius: 2)
                }

                // 模拟插图
                SkeletonRoundedRectangle(height: 200)

                Group {
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: 180, cornerRadius: 2)
                }

                Group {
                    SkeletonView(height: 14, width: nil, cornerRadius: 2)
                    SkeletonView(height: 14, width: 220, cornerRadius: 2)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var progressPercentage: Int {
        guard !store.spans.isEmpty else { return 0 }
        let currentIndex = scrollPositionID ?? 0
        return Int(Double(currentIndex) / Double(store.spans.count) * 100)
    }

    private func performRestorePosition() {
        guard !store.hasRestoredPosition else { return }

        // 如果没有保存的进度，直接设置标志并返回（首次打开新小说的情况）
        guard let index = store.savedIndex else {
            store.hasRestoredPosition = true
            return
        }

        guard let proxy = scrollProxy else { return }

        guard !store.isLoading else { return }

        guard !store.spans.isEmpty else { return }

        // 标记为已恢复，之后的操作才能进行保存
        store.hasRestoredPosition = true

        let safeIndex = min(max(index, 0), store.spans.count - 1)

        // 瞬间跳转到目标位置，不使用动画
        proxy.scrollTo(safeIndex, anchor: .top)

        // 同步当前的追踪 ID
        scrollPositionID = safeIndex
    }

    private var contentSection: some View {
        ForEach(store.spans) { span in
            NovelSpanRenderer(
                span: span,
                store: store,
                paragraphIndex: span.id,
                onImageTap: { illustId in
                    navigateToIllust = illustId
                },
                onLinkTap: { url in
                    openExternalLink(url)
                }
            )
            .id(span.id)
            .onAppear {
                store.paragraphAppeared(index: span.id)
            }
            .onDisappear {
                store.paragraphDisappeared(index: span.id)
            }
        }
    }

    @ViewBuilder
    private var seriesNavigationSection: some View {
        if let navigation = store.seriesNavigation, navigation.hasAdjacentNovel {
            VStack(spacing: 12) {
                if let prev = navigation.prevNovel {
                    Button(action: {
                        openSeriesNovel(prev.id)
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            VStack(alignment: .leading) {
                                Text("上一章")
                                    .font(.caption)
                                Text(prev.title)
                                    .font(.subheadline)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                if let next = navigation.nextNovel {
                    Button(action: {
                        openSeriesNovel(next.id)
                    }) {
                        HStack {
                            Spacer()
                            Text(next.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            VStack(alignment: .trailing) {
                                Text("下一章")
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 20)
        }
    }

    private func openSeriesNovel(_ novelId: Int) {
        navigateToNovel = novelId
    }

    private func openExternalLink(_ url: String) {
        guard let url = URL(string: url) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

struct SeriesNavigationView: View {
    let navigation: SeriesNavigation
    let onSelectNovel: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let prev = navigation.prevNovel {
                    Section("上一章") {
                        Button(action: {
                            selectNovel(prev.id)
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(prev.title)
                                Spacer()
                            }
                        }
                    }
                }

                if let next = navigation.nextNovel {
                    Section("下一章") {
                        Button(action: {
                            selectNovel(next.id)
                        }) {
                            HStack {
                                Text(next.title)
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                        }
                    }
                }
            }
            .navigationTitle("系列导航")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func selectNovel(_ novelId: Int) {
        dismiss()
        DispatchQueue.main.async {
            onSelectNovel(novelId)
        }
    }
}

#Preview {
    NovelReaderView(novelId: 12345)
}
