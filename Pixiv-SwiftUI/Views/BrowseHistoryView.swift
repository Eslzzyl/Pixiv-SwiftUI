import SwiftUI
import SwiftData

struct BrowseHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var illustStore = IllustStore()
    @State private var illusts: [Illusts] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: Error?
    @State private var showingClearAlert = false
    @State private var allHistoryIds: [Int] = []
    @State private var loadedCount = 0
    private let batchSize = 20

    var body: some View {
        Group {
            if isLoading && illusts.isEmpty {
                loadingView
            } else if let error = error {
                errorView(error)
            } else if illusts.isEmpty {
                emptyView
            } else {
                contentView
            }
        }
        .navigationTitle("浏览历史")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !illusts.isEmpty {
                    Button(role: .destructive, action: { showingClearAlert = true }) {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .alert("确认清空", isPresented: $showingClearAlert) {
            Button("取消", role: .cancel) { }
            Button("清空", role: .destructive) {
                clearHistory()
            }
        } message: {
            Text("确定要清空所有浏览历史吗？此操作不可撤销。")
        }
        .task {
            await loadHistory()
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("暂无浏览历史")
                .font(.headline)
            Text("浏览插画时会产生历史记录")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        ScrollView {
            WaterfallGrid(data: illusts, columnCount: calculateColumnCount()) { illust, columnWidth in
                NavigationLink(value: illust) {
                    BrowseHistoryCard(illust: illust, columnWidth: columnWidth)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if loadedCount < allHistoryIds.count {
                ProgressView()
                    .padding()
                    .onAppear {
                        Task { await loadMore() }
                    }
            }
        }
    }

    private func calculateColumnCount() -> Int {
        #if os(iOS)
        let width = UIScreen.main.bounds.width
        if width >= 1024 {
            return 5
        } else if width >= 768 {
            return 4
        } else if width >= 414 {
            return 3
        } else {
            return 2
        }
        #else
        return 4
        #endif
    }

    private func loadHistory() async {
        isLoading = true
        error = nil

        do {
            allHistoryIds = try illustStore.getGlanceHistoryIds(limit: 100)
            loadedCount = 0
            illusts = []
            await loadBatch()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func loadBatch() async {
        guard loadedCount < allHistoryIds.count else { return }

        let endIndex = min(loadedCount + batchSize, allHistoryIds.count)
        let idsToLoad = Array(allHistoryIds[loadedCount..<endIndex])

        do {
            var newIllusts: [Illusts] = []
            for id in idsToLoad {
                if let cached = try? illustStore.getIllust(id) {
                    newIllusts.append(cached)
                } else {
                    let detail = try await PixivAPI.shared.getIllustDetail(illustId: id)
                    newIllusts.append(detail)
                }
            }

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

    private func loadMore() async {
        guard !isLoadingMore && loadedCount < allHistoryIds.count else { return }
        isLoadingMore = true
        await loadBatch()
        isLoadingMore = false
    }

    private func clearHistory() {
        do {
            try illustStore.clearGlanceHistory()
            illusts = []
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
        let hideR18 = isR18 && userSettingStore.userSetting.r18DisplayMode == 2
        let hideAI = isAI && userSettingStore.userSetting.blockAI
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
