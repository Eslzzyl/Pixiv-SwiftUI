import SwiftUI

struct NovelRankingPage: View {
    @StateObject private var store = NovelStore()
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
        .keyboardShortcut("r", modifiers: .command)
        .toolbar {
            #if os(macOS)
            ToolbarItem {
                RefreshButton(refreshAction: { await store.loadAllRankings(forceRefresh: true) })
            }
            #endif
        }
    }
}

struct NovelRankingList: View {
    @ObservedObject var store: NovelStore
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
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(novel.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)

                HStack(spacing: 4) {
                    Text(novel.user.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 2) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 10))
                        Text(formatTextLength(novel.textLength))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                if !novel.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(novel.tags.prefix(5)) { tag in
                                Text(tag.name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }

            Spacer()

            VStack(spacing: 4) {
                Image(systemName: novel.isBookmarked ? "heart.fill" : "heart")
                    .foregroundColor(novel.isBookmarked ? .red : .secondary)
                    .font(.system(size: 18))

                Text("\(novel.totalBookmarks)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .systemBackground))
        #endif
    }

    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            let value = Double(length) / 10000
            let formatted = String(format: "%.1f", value)
            return "\(formatted) " + String(localized: "万字")
        } else if length >= 1000 {
            let value = Double(length) / 1000
            let formatted = String(format: "%.1f", value)
            return "\(formatted) " + String(localized: "千字")
        }
        return "\(length) " + String(localized: "字")
    }
}

#Preview {
    NavigationStack {
        NovelRankingPage()
    }
}
