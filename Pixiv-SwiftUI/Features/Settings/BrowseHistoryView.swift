import SwiftUI
import SwiftData

enum BrowseHistoryType: String, CaseIterable {
    case illust = "插画"
    case novel = "小说"
}

struct BrowseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var illustStore = IllustStore()
    @State private var novelStore = NovelStore()
    @State private var selectedType: BrowseHistoryType = .illust
    @State private var illusts: [Illusts] = []
    @State private var novels: [Novel] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: Error?
    @State private var allHistoryIds: [Int] = []
    @State private var loadedCount = 0
    @State private var showingClearAlert = false
    private let batchSize = 20

    @State private var dynamicColumnCount: Int = 4

    @Environment(AccountStore.self) var accountStore

    var body: some View {
        contentView
            .navigationTitle("浏览历史")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !illusts.isEmpty || !novels.isEmpty {
                        Button(action: { showingClearAlert = true }) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
            .confirmationDialog("清空历史", isPresented: $showingClearAlert) {
                Button("清空插画", role: .destructive) {
                    clearIllustHistory()
                }
                Button("清空小说", role: .destructive) {
                    clearNovelHistory()
                }
                Button("全部清空", role: .destructive) {
                    clearAllHistory()
                }
                Button("取消", role: .cancel) { }
            }
            .task {
                await loadHistory()
            }
            .onChange(of: selectedType) { _, _ in
                Task { await loadHistory() }
            }
            .onChange(of: accountStore.currentUserId) { _, _ in
                Task {
                    await loadHistory()
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Picker("类型", selection: $selectedType) {
                    Text("插画").tag(BrowseHistoryType.illust)
                    Text("小说").tag(BrowseHistoryType.novel)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 8)

                if let error = error {
                    errorContent(error)
                } else if selectedType == .illust {
                    illustGridContent
                } else {
                    novelListContent
                }
            }
        }
    }

    @ViewBuilder
    private func errorContent(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("加载失败")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                Task { await loadHistory() }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
        .frame(minHeight: 300)
    }

    @ViewBuilder
    private var illustGridContent: some View {
        if isLoading && illusts.isEmpty {
            illustLoadingContent
        } else if illusts.isEmpty {
            emptyContent(type: "插画")
        } else {
            illustGrid
        }
    }

    @ViewBuilder
    private var novelListContent: some View {
        if isLoading && novels.isEmpty {
            novelLoadingContent
        } else if novels.isEmpty {
            emptyContent(type: "小说")
        } else {
            novelList
        }
    }

    private var illustLoadingContent: some View {
        SkeletonIllustWaterfallGrid(columnCount: dynamicColumnCount, itemCount: 12)
            .padding(.horizontal, 12)
    }

    private var novelLoadingContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonNovelListCard()
            }
        }
        .padding(.horizontal, 12)
    }

    private func emptyContent(type: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无浏览历史")
                .font(.headline)
            Text("浏览\(type)时会产生历史记录")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    private var illustGrid: some View {
        LazyVStack(spacing: 12) {
            WaterfallGrid(data: illusts, columnCount: dynamicColumnCount, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                NavigationLink(value: illust) {
                    BrowseHistoryCard(illust: illust, columnWidth: columnWidth)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if loadedCount < allHistoryIds.count {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
                    .onAppear {
                        Task { await loadMore() }
                    }
            } else if !illusts.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .responsiveGridColumnCount(userSetting: userSettingStore.userSetting, columnCount: $dynamicColumnCount)
    }

    private var novelList: some View {
        Group {
            ForEach(novels, id: \.id) { novel in
                NavigationLink(value: novel) {
                    NovelListCard(novel: novel)
                }
                .buttonStyle(.plain)

                if novel.id != novels.last?.id {
                    Divider()
                        .padding(.leading, 12)
                }
            }

            if loadedCount < allHistoryIds.count {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
                    .onAppear {
                        Task { await loadMore() }
                    }
            } else if !novels.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private func loadHistory() async {
        print("[BrowseHistoryView] loadHistory: selectedType=\(selectedType)")
        isLoading = true
        error = nil

        do {
            if selectedType == .illust {
                allHistoryIds = try illustStore.getGlanceHistoryIds(limit: 100)
                print("[BrowseHistoryView] loadHistory: illustIds=\(allHistoryIds)")
                loadedCount = 0
                illusts = []
                await loadBatch()
            } else {
                allHistoryIds = try novelStore.getGlanceHistoryIds(limit: 100)
                print("[BrowseHistoryView] loadHistory: novelIds=\(allHistoryIds)")
                loadedCount = 0
                novels = []
                await loadBatch()
            }
        } catch {
            print("[BrowseHistoryView] loadHistory error: \(error)")
            self.error = error
        }

        isLoading = false
    }

    private func loadBatch() async {
        guard loadedCount < allHistoryIds.count else { return }

        let endIndex = min(loadedCount + batchSize, allHistoryIds.count)
        let idsToLoad = Array(allHistoryIds[loadedCount..<endIndex])

        if selectedType == .illust {
            await loadIllustBatch(idsToLoad: idsToLoad, endIndex: endIndex)
        } else {
            await loadNovelBatch(idsToLoad: idsToLoad, endIndex: endIndex)
        }
    }

    private func loadIllustBatch(idsToLoad: [Int], endIndex: Int) async {
        do {
            let newIllusts = try illustStore.getCachedIllusts(idsToLoad)

            await MainActor.run {
                illusts.append(contentsOf: newIllusts)
                loadedCount = endIndex
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }

    private func loadNovelBatch(idsToLoad: [Int], endIndex: Int) async {
        do {
            let cachedNovels = try novelStore.getNovels(idsToLoad)
            let idToNovel = Dictionary(uniqueKeysWithValues: cachedNovels.map { ($0.id, $0) })
            let newNovels = idsToLoad.compactMap { idToNovel[$0] }

            await MainActor.run {
                novels.append(contentsOf: newNovels)
                loadedCount = endIndex
            }
        } catch {
            await MainActor.run {
                self.error = error
            }
        }
    }

    private func loadMore() async {
        guard !isLoadingMore && loadedCount < allHistoryIds.count else { return }
        isLoadingMore = true
        await loadBatch()
        isLoadingMore = false
    }

    private func clearIllustHistory() {
        do {
            try illustStore.clearGlanceHistory()
            illusts = []
            allHistoryIds = []
            loadedCount = 0
        } catch {
            self.error = error
        }
    }

    private func clearNovelHistory() {
        let store = NovelStore()
        do {
            try store.clearGlanceHistory()
            novels = []
            allHistoryIds = []
            loadedCount = 0
        } catch {
            self.error = error
        }
    }

    private func clearAllHistory() {
        do {
            try illustStore.clearGlanceHistory()
            let store = NovelStore()
            try store.clearGlanceHistory()
            illusts = []
            novels = []
            allHistoryIds = []
            loadedCount = 0
        } catch {
            self.error = error
        }
    }
}

struct BrowseHistoryCard: View {
    @Environment(UserSettingStore.self) var userSettingStore
    let illust: Illusts
    let columnWidth: CGFloat

    @State private var isBookmarked: Bool

    private var isR18: Bool {
        return illust.xRestrict >= 1
    }

    private var shouldBlur: Bool {
        return isR18 && userSettingStore.userSetting.r18DisplayMode == 1
    }

    private var shouldHide: Bool {
        let r18Mode = userSettingStore.userSetting.r18DisplayMode
        let aiMode = userSettingStore.userSetting.aiDisplayMode

        let hideR18 = (isR18 && r18Mode == 2) || (!isR18 && r18Mode == 3)
        let hideAI = (isAI && aiMode == 1) || (!isAI && aiMode == 2)

        return hideR18 || hideAI
    }

    private var isAI: Bool {
        return illust.illustAIType == 2
    }

    private var isUgoira: Bool {
        return illust.type == "ugoira"
    }

    private var bookmarkIconName: String {
        if !isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    init(illust: Illusts, columnWidth: CGFloat) {
        self.illust = illust
        self.columnWidth = columnWidth
        _isBookmarked = State(initialValue: illust.isBookmarked)
    }

    var body: some View {
        if shouldHide {
            Color.clear.frame(height: 0)
        } else {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(
                        urlString: ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.feedPreviewQuality),
                        aspectRatio: illust.safeAspectRatio,
                        idealWidth: columnWidth
                    )
                    .clipped()
                    .blur(radius: shouldBlur ? 20 : 0)

                    if isAI {
                        Text("AI")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(4)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }

                    HStack(spacing: 4) {
                        if isUgoira {
                            Text("动图")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }

                        if illust.pageCount > 1 {
                            Text("\(illust.pageCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                    }
                    .padding(6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(illust.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)

                    HStack {
                        Text(illust.user.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button(action: toggleBookmark) {
                            Image(systemName: bookmarkIconName)
                                .foregroundColor(isBookmarked ? .red : .secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
                    }
                }
                .padding(8)
            }
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            #endif
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        }
    }

    private func toggleBookmark() {
        let wasBookmarked = isBookmarked
        let illustId = illust.id

        isBookmarked.toggle()
        if wasBookmarked {
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else {
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = "public"
        }

        Task {
            do {
                if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: false)
                }
            } catch {
                await MainActor.run {
                    isBookmarked = wasBookmarked
                    if wasBookmarked {
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = "public"
                    } else {
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BrowseHistoryView()
            .environment(UserSettingStore())
    }
}
