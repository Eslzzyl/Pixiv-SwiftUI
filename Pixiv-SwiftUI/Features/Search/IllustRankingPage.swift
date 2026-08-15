import SwiftUI

struct IllustRankingPage: View {
    @Environment(IllustStore.self) var store
    var initialMode: IllustRankingMode?
    @State private var selectedMode: IllustRankingMode = .day
    @State private var hasInitializedMode = false
    @State private var selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var usesLatestDate = true
    @State private var isLoading = false
    @State private var error: String?
    @State private var showProfilePanel = false
    @Environment(UserSettingStore.self) var settingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager
    @State private var prefetchTracker = PrefetchTracker()
    @State private var filteredIllusts: [Illusts] = []
    @State private var shouldBlurFlags: [Bool] = []

    private var rankingModes: [IllustRankingMode] {
        settingStore.enabledIllustRankingModes
    }

    private var illusts: [Illusts] {
        store.illusts(for: selectedMode)
    }

    private var nextUrl: String? {
        store.nextUrl(for: selectedMode)
    }

    private var hasMoreData: Bool {
        nextUrl != nil
    }

    private func recalculateFilteredIllusts() {
        filteredIllusts = settingStore.filterIllusts(illusts)
        shouldBlurFlags = filteredIllusts.map { settingStore.userSetting.shouldBlurIllust($0) }
    }

    private func shouldBlurFromCache(for illust: Illusts) -> Bool {
        guard let index = filteredIllusts.firstIndex(where: { $0.id == illust.id }),
              index < shouldBlurFlags.count
        else { return false }
        return shouldBlurFlags[index]
    }

    private var latestDisplayDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }

    private var rankingRequestDate: Date? {
        usesLatestDate ? nil : selectedDate
    }

    private var dateSelection: Binding<Date> {
        Binding(
            get: { usesLatestDate ? latestDisplayDate : selectedDate },
            set: { newValue in
                selectedDate = newValue
                usesLatestDate = false
            }
        )
    }

    private var modeAndDateRow: some View {
        HStack(spacing: 12) {
            // Menu-style picker for ranking mode (auto-adopts Liquid Glass on iOS 26+)
            Picker(String(localized: "排行模式"), selection: $selectedMode) {
                ForEach(rankingModes) { mode in
                    Text(verbatim: mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.menu)

            Spacer()

            // Date controls
            HStack(spacing: 6) {
                if !usesLatestDate {
                    Button(String(localized: "重置")) {
                        usesLatestDate = true
                        Task {
                            await loadRankings(forceRefresh: true)
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }

                DatePicker(
                    "",
                    selection: dateSelection,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                #if os(macOS)
                .controlSize(.small)
                #endif
            }
        }
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    private func syncSelectedModeIfNeeded() -> Bool {
        guard let firstMode = rankingModes.first else {
            return false
        }

        guard !rankingModes.contains(selectedMode) else {
            return false
        }

        selectedMode = firstMode
        return true
    }

    private func loadRankings(forceRefresh: Bool = false) async {
        guard !rankingModes.isEmpty else {
            isLoading = false
            return
        }

        if syncSelectedModeIfNeeded() {
            return
        }

        isLoading = true
        await store.loadAllRankings(
            date: rankingRequestDate,
            forceRefresh: forceRefresh,
            modes: rankingModes
        )
        isLoading = false
    }

    var body: some View {
        GeometryReader { proxy in
            let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
            let horizontalPadding: CGFloat = 24
            let availableWidth = proxy.size.width - horizontalPadding
            let waterfallWidth = availableWidth > 0 ? availableWidth : nil

            ScrollView {
                VStack(spacing: 0) {
                    modeAndDateRow
                        .onFilterSettingsChange(from: settingStore, perform: recalculateFilteredIllusts)
                        .padding()

                    if illusts.isEmpty && isLoading {
                        SkeletonIllustWaterfallGrid(
                            columnCount: dynamicColumnCount,
                            itemCount: skeletonItemCount,
                            width: waterfallWidth
                        )
                        .padding(.horizontal, 12)
                        .frame(minHeight: 400)
                        .transition(.opacity)
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
                        WaterfallGrid(data: filteredIllusts, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                            NavigationLink(value: illust) {
                                IllustCard(
                                    illust: illust,
                                    columnCount: dynamicColumnCount,
                                    columnWidth: columnWidth,
                                    expiration: DefaultCacheExpiration.recommend,
                                    feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                                    shouldBlur: shouldBlurFromCache(for: illust),
                                    accentColor: themeManager.currentColor
                                )
                                .equatable()
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                prefetchIllustsIfNeeded(from: illust, in: filteredIllusts, quality: settingStore.userSetting.feedPreviewQuality, tracker: prefetchTracker)
                            }
                        }
                        .padding(.horizontal, 12)
                        .transition(.opacity)

                        if hasMoreData {
                            LazyVStack {
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
            .animation(.easeInOut(duration: 0.25), value: isLoading)
            .navigationTitle(String(localized: "插画排行"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .task {
                guard illusts.isEmpty else { return }
                await loadRankings()
            }
            .refreshable {
                await loadRankings(forceRefresh: true)
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
                .hideSharedBackgroundIfAvailable()
                #endif
            }
            .background {
                Button("") {
                    Task {
                        await loadRankings(forceRefresh: true)
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .hidden()
            }
            #if os(iOS)
            .sheet(isPresented: $showProfilePanel) {
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            }
            #endif
            .onChange(of: selectedMode) { _, _ in
                Task {
                    await loadRankings()
                }
            }
            .onChange(of: selectedDate) { _, _ in
                Task {
                    await loadRankings(forceRefresh: true)
                }
            }
            .onChange(of: accountStore.accountGeneration) { _, _ in
                Task {
                    await loadRankings(forceRefresh: true)
                }
            }
            .onChange(of: settingStore.userSetting.enabledIllustRankingModes) { _, _ in
                if syncSelectedModeIfNeeded() {
                    return
                }

                Task {
                    await loadRankings()
                }
            }
            .onChange(of: illusts) { _, _ in
                recalculateFilteredIllusts()
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
                Task {
                    await loadRankings(forceRefresh: true)
                }
            }
            .onAppear {
                recalculateFilteredIllusts()
                if !hasInitializedMode {
                    hasInitializedMode = true
                    if let initialMode = initialMode, rankingModes.contains(initialMode) {
                        selectedMode = initialMode
                    } else {
                        _ = syncSelectedModeIfNeeded()
                    }
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
