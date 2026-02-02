import SwiftUI

struct IllustRankingPage: View {
    @Environment(IllustStore.self) var store
    @State private var selectedMode: IllustRankingMode = .day
    @State private var isLoading = false
    @State private var error: String?
    @Environment(UserSettingStore.self) var settingStore
    @Environment(AccountStore.self) var accountStore

    @State private var dynamicColumnCount: Int = 4

    private var rankingTypes: [IllustRankingType] {
        [.daily, .dailyMale, .dailyFemale, .week, .month]
    }

    private var illusts: [Illusts] {
        store.illusts(for: selectedMode)
    }

    private var nextUrl: String? {
        switch selectedMode {
        case .day:
            return store.nextUrlDailyRanking
        case .dayMale:
            return store.nextUrlDailyMaleRanking
        case .dayFemale:
            return store.nextUrlDailyFemaleRanking
        case .week:
            return store.nextUrlWeeklyRanking
        case .month:
            return store.nextUrlMonthlyRanking
        case .weekOriginal, .weekRookie:
            return nil
        }
    }

    private var hasMoreData: Bool {
        nextUrl != nil
    }

    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(illusts)
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    var body: some View {
        GeometryReader { _ in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Picker(String(localized: "排行类别"), selection: $selectedMode) {
                        ForEach(rankingTypes) { type in
                            Text(type.title)
                                .tag(type.mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if illusts.isEmpty && isLoading {
                        SkeletonIllustWaterfallGrid(
                            columnCount: dynamicColumnCount,
                            itemCount: skeletonItemCount
                        )
                        .padding(.horizontal, 12)
                        .frame(minHeight: 400)
                    } else if illusts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text(String(localized: "没有排行数据"))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 200)
                    } else {
                        WaterfallGrid(data: filteredIllusts, columnCount: dynamicColumnCount, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                            NavigationLink(value: illust) {
                                IllustCard(illust: illust, columnCount: dynamicColumnCount, columnWidth: columnWidth, expiration: DefaultCacheExpiration.recommend)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)

                        if hasMoreData {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                                .padding()
                                .id(nextUrl)
                                .onAppear {
                                    Task {
                                        await store.loadMoreRanking(mode: selectedMode)
                                    }
                                }
                        } else if !filteredIllusts.isEmpty {
                            Text(String(localized: "已经到底了"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "插画排行"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .task {
                isLoading = true
                await store.loadAllRankings()
                isLoading = false
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
            .onChange(of: selectedMode) { _, _ in
                isLoading = true
                Task {
                    await store.loadAllRankings()
                    isLoading = false
                }
            }
            .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
            .onChange(of: accountStore.currentUserId) { _, _ in
                Task {
                    isLoading = true
                    await store.loadAllRankings(forceRefresh: true)
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        IllustRankingPage()
    }
}
