import SwiftUI

struct NovelRankingPage: View {
    @State private var store = NovelStore()
    @State private var selectedMode: NovelRankingMode = .day

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Picker(String(localized: "排行类别"), selection: $selectedMode) {
                    ForEach(NovelRankingMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                NovelRankingList(store: store, mode: selectedMode)
            }
        }
        .navigationTitle(String(localized: "小说排行"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .task {
            await store.loadAllRankings()
        }
        .refreshable {
            await store.loadAllRankings(forceRefresh: true)
        }
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: { await store.loadAllRankings(forceRefresh: true) })
            }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
            Task {
                await store.loadAllRankings(forceRefresh: true)
            }
        }
    }
}

struct NovelRankingList: View {
    var store: NovelStore
    let mode: NovelRankingMode

    private var novels: [Novel] {
        store.novels(for: mode)
    }

    private var nextUrl: String? {
        switch mode {
        case .day:
            return store.nextUrlDailyRanking
        case .dayMale:
            return store.nextUrlDailyMaleRanking
        case .dayFemale:
            return store.nextUrlDailyFemaleRanking
        case .week:
            return store.nextUrlWeeklyRanking
        }
    }

    private var hasMoreData: Bool {
        nextUrl != nil
    }

    var body: some View {
        LazyVStack(spacing: 0) {
            if store.isLoadingRanking && novels.isEmpty {
                LazyVStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { _ in
                        SkeletonNovelListCard()
                    }
                }
            } else if novels.isEmpty {
                HStack {
                    Spacer()
                    Text(String(localized: "暂无排行数据"))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 200)
            } else {
                ForEach(novels) { novel in
                    NavigationLink(value: novel) {
                        NovelRankingListRow(novel: novel)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if novel.id == novels.last?.id && hasMoreData {
                            Task {
                                await store.loadMoreRanking(mode: mode)
                            }
                        }
                    }
                }

                if store.isLoadingRanking && !novels.isEmpty {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                        .padding()
                } else if !hasMoreData && !novels.isEmpty {
                    Text(String(localized: "已经到底了"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
    }
}

struct NovelRankingListRow: View {
    let novel: Novel

    var body: some View {
        NovelInfoTableRow(
            novel: novel,
            detailStyle: .author,
            showsBookmarkSummary: true,
            bookmarkSummaryText: NumberFormatter.formatCount(novel.totalBookmarks)
        )
    }
}

#Preview {
    NavigationStack {
        NovelRankingPage()
    }
}
