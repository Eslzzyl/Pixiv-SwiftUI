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
    @State private var visibleParagraphs: Set<Int> = []
    @State private var scrollProxy: ScrollViewProxy?
    @State private var scrollPositionID: Int?

    init(novelId: Int) {
        self.novelId = novelId
        let initialStore = NovelReaderStore(novelId: novelId)
        print("[NovelReaderView] 初始化 - novelId: \(novelId), savedIndex: \(initialStore.savedIndex?.description ?? "nil")")
        _store = State(initialValue: initialStore)
        _scrollPositionID = State(initialValue: initialStore.savedIndex)
    }

    private let debounceDelay: TimeInterval = 0.2
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        @Bindable var store = store
        ZStack {
            readerBackground
            contentView
        }
        .navigationTitle(store.novel?.title ?? "加载中...")
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
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

                    Button(action: { showSettings = true }) {
                        Label("阅读设置", systemImage: "textformat.size")
                    }

                    if store.seriesNavigation?.prevNovel != nil || store.seriesNavigation?.nextNovel != nil {
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
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            NovelReaderSettingsView(store: store)
        }
        .sheet(isPresented: $showSeriesNavigation) {
            SeriesNavigationView(store: store)
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
        .onAppear {
            print("[NovelReaderView] 视图onAppear")
            Task {
                await store.fetch()
            }
        }
        .onDisappear {
            print("[NovelReaderView] 视图onDisappear")
            if let firstVisible = scrollPositionID {
                print("[NovelReaderView] 视图消失时保存进度 - firstVisible: \(firstVisible)")
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
            ProgressView("加载中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("加载失败")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button("重试") {
                    Task {
                        await store.fetch()
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Spacer().frame(height: 20)

                        contentSection

                        Divider()
                            .padding(.vertical, 20)

                        seriesNavigationSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, store.settings.horizontalPadding)
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrollPositionID, anchor: .top)
                .onChange(of: scrollPositionID) { _, newValue in
                    print("[NovelReaderView] 滚动位置变化 - 新值: \(newValue?.description ?? "nil")")
                    if let index = newValue {
                        store.saveProgress(index: index)
                    }
                }
                .onAppear {
                    print("[NovelReaderView] ScrollView onAppear")
                    scrollProxy = proxy
                    performRestorePosition()
                }
                .onChange(of: store.isLoading) { _, loading in
                    print("[NovelReaderView] isLoading变化: \(loading)")
                    if !loading {
                        performRestorePosition()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .novelReaderShouldRestorePosition)) { _ in
                    print("[NovelReaderView] 收到恢复位置通知")
                    performRestorePosition()
                }
            }
        }
    }

    private func performRestorePosition() {
        print("[NovelReaderView] performRestorePosition调用 - hasRestoredPosition: \(store.hasRestoredPosition), savedIndex: \(store.savedIndex?.description ?? "nil"), isLoading: \(store.isLoading), spans.count: \(store.spans.count)")
        
        guard !store.hasRestoredPosition else {
            print("[NovelReaderView] 位置已恢复过，跳过")
            return
        }
        
        // 如果没有保存的进度，直接设置标志并返回（首次打开新小说的情况）
        guard let index = store.savedIndex else {
            print("[NovelReaderView] savedIndex为nil，首次打开小说，设置允许保存")
            store.hasRestoredPosition = true
            return
        }
        
        guard let proxy = scrollProxy else {
            print("[NovelReaderView] scrollProxy为nil，无法恢复")
            return
        }
        
        guard !store.isLoading else {
            print("[NovelReaderView] 正在加载中，跳过恢复")
            return
        }
        
        guard !store.spans.isEmpty else {
            print("[NovelReaderView] spans为空，等待内容加载完成，不设置hasRestoredPosition")
            return
        }

        print("[NovelReaderView] 开始恢复位置到index: \(index)")
        
        // 标记为已恢复，之后的操作才能进行保存
        store.hasRestoredPosition = true
        
        // 瞬间跳转到目标位置，不使用动画
        proxy.scrollTo(index, anchor: .top)
        
        // 同步当前的追踪 ID
        scrollPositionID = index
        
        print("[NovelReaderView] 位置恢复完成 - scrollPositionID已设置为: \(index)")
    }

    private var contentSection: some View {
        ForEach(Array(store.spans.enumerated()), id: \.offset) { index, span in
            NovelSpanRenderer(
                span: span,
                store: store,
                paragraphIndex: index,
                onImageTap: { illustId in
                    navigateToIllust = illustId
                },
                onLinkTap: { url in
                    openExternalLink(url)
                }
            )
            .id(index)
            .onAppear {
                visibleParagraphs.insert(index)
                triggerDebouncedUpdate()
            }
            .onDisappear {
                visibleParagraphs.remove(index)
                triggerDebouncedUpdate()
            }
        }
    }

    private func triggerDebouncedUpdate() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            store.updateVisibleParagraphs(visibleParagraphs)
        }
    }

    private var seriesNavigationSection: some View {
        VStack(spacing: 12) {
            if let prev = store.seriesNavigation?.prevNovel {
                Button(action: {
                    navigateToNovel = prev.id
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

            if let next = store.seriesNavigation?.nextNovel {
                Button(action: {
                    navigateToNovel = next.id
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

    private func openExternalLink(_ url: String) {
        guard let url = URL(string: url) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

struct SeriesNavigationView: View {
    @Bindable var store: NovelReaderStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let prev = store.seriesNavigation?.prevNovel {
                    Section("上一章") {
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text(prev.title)
                                Spacer()
                            }
                        }
                    }
                }

                if let next = store.seriesNavigation?.nextNovel {
                    Section("下一章") {
                        Button(action: {
                            dismiss()
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
}

#Preview {
    NovelReaderView(novelId: 12345)
}
