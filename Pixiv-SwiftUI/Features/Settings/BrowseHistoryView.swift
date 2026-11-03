import SwiftUI
import SwiftData
import os.log

enum BrowseHistoryType: String, CaseIterable {
    case illust = "插画"
    case novel = "小说"
}

struct BrowseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) var themeManager
    @Environment(AccountStore.self) var accountStore
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

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    private var filteredIllusts: [Illusts] {
        userSettingStore.filterIllusts(illusts)
    }

    private var filteredNovels: [Novel] {
        userSettingStore.filterNovels(novels)
    }

    var body: some View {
        contentView
            .navigationTitle("历史")
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
                guard illusts.isEmpty && novels.isEmpty else { return }
                await loadHistory()
            }
            .onChange(of: selectedType) { _, _ in
                Task { await loadHistory() }
            }
            .onChange(of: accountStore.accountGeneration) { _, _ in
                illusts = []
                novels = []
                allHistoryIds = []
                loadedCount = 0
                error = nil
                Task {
                    await loadHistory()
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
        GeometryReader { proxy in
            let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: userSettingStore.userSetting)
            let horizontalPadding: CGFloat = 24
            let availableWidth = proxy.size.width - horizontalPadding
            let waterfallWidth = availableWidth > 0 ? availableWidth : nil

            ScrollView {
                VStack(spacing: 0) {
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
                        illustGridContent(columnCount: dynamicColumnCount, waterfallWidth: waterfallWidth)
                    } else {
                        novelListContent
                    }
                }
            }
            .illustDetailNavigationSourceScope()
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
    private func illustGridContent(columnCount: Int, waterfallWidth: CGFloat?) -> some View {
        if isLoading && filteredIllusts.isEmpty {
            illustLoadingContent(columnCount: columnCount, waterfallWidth: waterfallWidth)
        } else if filteredIllusts.isEmpty && loadedCount >= allHistoryIds.count {
            emptyContent(type: "插画")
        } else {
            illustGrid(columnCount: columnCount, waterfallWidth: waterfallWidth)
        }
    }

    @ViewBuilder
    private var novelListContent: some View {
        if isLoading && filteredNovels.isEmpty {
            novelLoadingContent
        } else if filteredNovels.isEmpty && loadedCount >= allHistoryIds.count {
            emptyContent(type: "小说")
        } else {
            novelList
        }
    }

    private func illustLoadingContent(columnCount: Int, waterfallWidth: CGFloat?) -> some View {
        SkeletonIllustWaterfallGrid(
            columnCount: columnCount,
            itemCount: skeletonItemCount,
            width: waterfallWidth
        )
        .padding(.horizontal, 12)
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
    }

    private var novelLoadingContent: some View {
        LazyVStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { _ in
                SkeletonNovelListCard()
            }
        }
    }

    private func emptyContent(type: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无历史")
                .font(.headline)
            Text("浏览\(type)时会产生历史记录")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(minHeight: 300)
    }

    private func illustGrid(columnCount: Int, waterfallWidth: CGFloat?) -> some View {
        VStack(spacing: 12) {
            WaterfallGrid(data: filteredIllusts, columnCount: columnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                IllustDetailNavigationLink(
                    illust: illust,
                    context: filteredIllusts,
                    contextProvider: { filteredIllusts },
                    hasMore: { loadedCount < allHistoryIds.count },
                    loadMore: { await loadMore() }
                ) {
                    IllustCard(
                        illust: illust,
                        columnCount: columnCount,
                        columnWidth: columnWidth,
                        feedPreviewQuality: userSettingStore.userSetting.feedPreviewQuality,
                        shouldBlur: userSettingStore.userSetting.shouldBlurIllust(illust),
                        accentColor: themeManager.currentColor
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if loadedCount < allHistoryIds.count {
                LazyVStack {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                        .padding()
                        .onAppear {
                            Task { await loadMore() }
                        }
                }
            } else if !filteredIllusts.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))
    }

    private var novelList: some View {
        Group {
            ForEach(filteredNovels, id: \.id) { novel in
                NovelDetailNavigationLink(novel: novel) {
                    NovelListCard(novel: novel)
                }
                .buttonStyle(.plain)

                if novel.id != filteredNovels.last?.id {
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
            } else if !filteredNovels.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    private func loadHistory() async {
        Logger.general.debug("loadHistory: selectedType=\(String(describing: selectedType))")
        isLoading = true
        error = nil

        do {
            if selectedType == .illust {
                allHistoryIds = try illustStore.getGlanceHistoryIds(limit: 100)
                Logger.general.debug("loadHistory: illustIds=\(String(describing: allHistoryIds))")
                loadedCount = 0
                illusts = []
                await loadBatch()
            } else {
                allHistoryIds = try novelStore.getGlanceHistoryIds(limit: 100)
                Logger.general.debug("loadHistory: novelIds=\(String(describing: allHistoryIds))")
                loadedCount = 0
                novels = []
                await loadBatch()
            }
        } catch {
            Logger.general.error("loadHistory error: \(error.localizedDescription, privacy: .public)")
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
            let cachedIllusts = try illustStore.getCachedIllusts(idsToLoad)
            let idToIllust = Dictionary(uniqueKeysWithValues: cachedIllusts.map { ($0.id, $0) })
            let newIllusts = idsToLoad.compactMap { idToIllust[$0] }

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

#Preview {
    NavigationStack {
        BrowseHistoryView()
            .environment(UserSettingStore())
            .environment(ThemeManager.shared)
            .environment(BookmarkActionService.shared)
            .environment(AccountStore.shared)
    }
}
