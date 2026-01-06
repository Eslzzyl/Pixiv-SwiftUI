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

    init(novelId: Int) {
        self.novelId = novelId
        _store = State(initialValue: NovelReaderStore(novelId: novelId))
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

                    Button(action: {
                        if store.isPositionBooked {
                            store.clearPosition()
                        } else {
                            store.savePosition()
                        }
                    }) {
                        Label(
                            store.isPositionBooked ? "清除书签" : "记录书签",
                            systemImage: store.isPositionBooked ? "bookmark.slash" : "bookmark"
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

                    Button(action: { @MainActor in
                        Task { @MainActor in
                            await store.toggleTranslation()
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
            print("[NovelReaderView] onAppear, novelId: \(novelId)")
            Task {
                await store.fetch()
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
                        contentSection

                        Divider()
                            .padding(.vertical, 20)

                        seriesNavigationSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, store.settings.horizontalPadding)
                }
                .onChange(of: store.savedIndex) { _, newIndex in
                    if let index = newIndex {
                        withAnimation {
                            proxy.scrollTo(index, anchor: .top)
                        }
                        // 给一些时间让滚动完成
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            store.savedIndex = nil
                        }
                    }
                }
                .onAppear {
                    // 如果已经有 savedIndex（比如从 fetch 返回后的初始显示）
                    if let index = store.savedIndex {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(index, anchor: .top)
                            store.savedIndex = nil
                        }
                    }
                }
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    markParagraphVisible(index)
                }
                .onDisappear {
                    markParagraphInvisible(index)
                }
            }
        }
        .padding(.top, 20)
    }

    private func markParagraphVisible(_ index: Int) {
        visibleParagraphs.insert(index)
        triggerDebouncedUpdate()
    }

    private func markParagraphInvisible(_ index: Int) {
        visibleParagraphs.remove(index)
        triggerDebouncedUpdate()
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
