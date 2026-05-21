import SwiftUI

private struct SearchFilterState: Equatable {
    var bookmarkFilter: BookmarkFilterOption = .none
    var searchTarget: SearchTargetOption = .partialMatchForTags
    var showsAIGeneratedWorks = true
    var startDate: Date?
    var endDate: Date?

    var hasDateRange: Bool {
        startDate != nil || endDate != nil
    }

    var hasActiveFilters: Bool {
        bookmarkFilter != .none
            || searchTarget != .partialMatchForTags
            || !showsAIGeneratedWorks
            || hasDateRange
    }
}

struct SearchResultView: View {
    let word: String
    let preloadToken: UUID?
    @State var store = SearchResultStore()
    @State private var selectedTab = 0
    @State private var sortOption: SearchSortOption = SearchSortOption(rawValue: UserSettingStore.shared.userSetting.defaultSearchSort) ?? .dateDesc
    @State private var novelSortOption: SearchSortOption = SearchSortOption(rawValue: UserSettingStore.shared.userSetting.defaultSearchSort) ?? .dateDesc
    @State private var filterState = SearchFilterState()
    @Environment(UserSettingStore.self) var settingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss
    let instanceId = UUID()

    private var viewId: String {
        "\(instanceId)"
    }

    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(store.illustResults)
    }

    private var filteredUsers: [UserPreviews] {
        settingStore.filterUserPreviews(store.userResults)
    }

    private var filteredNovels: [Novel] {
        settingStore.filterNovels(store.novelResults)
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    private var shouldShowIllustBookmarkCount: Bool {
        sortOption == .popularDesc && settingStore.userSetting.showSearchPopularBookmarkCount
    }

    private var shouldShowNovelBookmarkCount: Bool {
        novelSortOption != .popularDesc || settingStore.userSetting.showSearchPopularBookmarkCount
    }

    private func performIllustSearch() async {
        await store.search(
            word: word,
            sort: sortOption.rawValue,
            preferLocalPopularSort: sortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            prefetchNovelSort: novelSortOption.rawValue,
            prefetchNovelPreferLocalPopularSort: novelSortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            allowsPseudoPopularPreload: accountStore.currentAccount?.isPremium != 1,
            preloadToken: preloadToken,
            showsAIGenerated: filterState.showsAIGeneratedWorks,
            bookmarkFilter: filterState.bookmarkFilter,
            searchTarget: filterState.searchTarget,
            startDate: filterState.startDate,
            endDate: filterState.endDate
        )
    }

    private func performNovelSearch() async {
        await store.searchNovels(
            word: word,
            sort: novelSortOption.rawValue,
            preferLocalPopularSort: novelSortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            allowsPseudoPopularPreload: accountStore.currentAccount?.isPremium != 1,
            showsAIGenerated: filterState.showsAIGeneratedWorks,
            bookmarkFilter: filterState.bookmarkFilter,
            searchTarget: filterState.searchTarget,
            startDate: filterState.startDate,
            endDate: filterState.endDate
        )
    }

    private func performCurrentTabSearch() async {
        if selectedTab == 0 {
            await performIllustSearch()
        } else if selectedTab == 1 {
            await performNovelSearch()
        }
    }

    private func loadMoreIllustResults() async {
        await store.loadMoreIllusts(
            word: word,
            sort: sortOption.rawValue,
            preferLocalPopularSort: sortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            showsAIGenerated: filterState.showsAIGeneratedWorks,
            bookmarkFilter: filterState.bookmarkFilter,
            searchTarget: filterState.searchTarget,
            startDate: filterState.startDate,
            endDate: filterState.endDate
        )
    }

    private func loadMoreNovelResults() async {
        await store.loadMoreNovels(
            word: word,
            sort: novelSortOption.rawValue,
            preferLocalPopularSort: novelSortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            showsAIGenerated: filterState.showsAIGeneratedWorks,
            bookmarkFilter: filterState.bookmarkFilter,
            searchTarget: filterState.searchTarget,
            startDate: filterState.startDate,
            endDate: filterState.endDate
        )
    }

    @ViewBuilder
    private func resultContent(columnCount: Int, waterfallWidth: CGFloat?, userColumnCount: Int) -> some View {
        if store.isLoading && store.illustResults.isEmpty && store.novelResults.isEmpty && store.userResults.isEmpty {
            SkeletonIllustWaterfallGrid(
                columnCount: columnCount,
                itemCount: skeletonItemCount,
                width: waterfallWidth
            )
            .padding(.horizontal, 12)
        } else if let error = store.errorMessage, store.illustResults.isEmpty && store.novelResults.isEmpty && store.userResults.isEmpty {
            ContentUnavailableView("出错了", systemImage: "exclamationmark.triangle", description: Text(error))
        } else if selectedTab == 0 {
            illustTabContent(columnCount: columnCount, waterfallWidth: waterfallWidth)
        } else if selectedTab == 1 {
            novelTabContent
        } else {
            userTabContent(columnCount: userColumnCount)
        }
    }

    @ViewBuilder
    private func illustTabContent(columnCount: Int, waterfallWidth: CGFloat?) -> some View {
        if filteredIllusts.isEmpty && !store.illustResults.isEmpty && settingStore.blockedTags.contains(word) {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "eye.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("标签 \"\(word)\" 已被屏蔽")
                    .font(.title2)
                    .foregroundColor(.primary)

                Text("您已屏蔽此标签，因此没有显示相关插画")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    try? settingStore.removeBlockedTag(word)
                }) {
                    Text("取消屏蔽")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))

                Spacer()
            }
            .padding()
            .frame(minHeight: 300)
        } else if filteredIllusts.isEmpty && !store.isLoading {
            if store.illustHasMore {
                VStack(spacing: 12) {
                    ProgressView()
                        .onAppear {
                            Task {
                                await loadMoreIllustResults()
                            }
                        }

                    Text("正在加载更多结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minHeight: 300)
            } else {
            ContentUnavailableView("没有找到插画", systemImage: "magnifyingglass", description: Text("尝试搜索其他标签"))
                .frame(minHeight: 300)
            }
        } else {
            VStack(spacing: 12) {
                WaterfallGrid(data: filteredIllusts, columnCount: columnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                    NavigationLink(value: illust) {
                        IllustCard(
                            illust: illust,
                            columnCount: columnCount,
                            columnWidth: columnWidth,
                            showsBookmarkCount: shouldShowIllustBookmarkCount
                        )
                    }
                    .buttonStyle(.plain)
                }

                if store.illustHasMore {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                        .padding()
                        .onAppear {
                            Task {
                                await loadMoreIllustResults()
                            }
                        }
                } else if !filteredIllusts.isEmpty {
                    Text(String(localized: "已经到底了"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal, 12)
        }
    }

    @ViewBuilder
    private var novelTabContent: some View {
        if filteredNovels.isEmpty && !store.novelResults.isEmpty && !store.isLoading {
            if store.novelHasMore {
                VStack(spacing: 12) {
                    ProgressView()
                        .onAppear {
                            Task {
                                await loadMoreNovelResults()
                            }
                        }

                    Text("正在加载更多结果")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(minHeight: 300)
            } else {
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "book.closed")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("没有找到小说")
                        .font(.title2)
                        .foregroundColor(.primary)

                    Text("尝试搜索其他标签")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Spacer()
                }
                .frame(minHeight: 300)
            }
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filteredNovels) { novel in
                    NavigationLink(value: novel) {
                        NovelListCard(novel: novel, showsBookmarkCount: shouldShowNovelBookmarkCount)
                    }
                    .buttonStyle(.plain)
                }

                if store.novelHasMore {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                        .padding()
                        .onAppear {
                            Task {
                                await loadMoreNovelResults()
                            }
                        }
                } else if !filteredNovels.isEmpty {
                    Text(String(localized: "已经到底了"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func userTabContent(columnCount: Int) -> some View {
        if filteredUsers.isEmpty && !store.userResults.isEmpty && !store.isLoading {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "eye.slash")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                Text("没有找到画师")
                    .font(.title2)
                    .foregroundColor(.primary)

                Text("您已屏蔽所有搜索到的画师")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .frame(minHeight: 300)
        } else {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: columnCount), spacing: 12) {
                ForEach(filteredUsers, id: \.id) { userPreview in
                    NavigationLink(value: userPreview.user) {
                        UserPreviewCard(userPreview: userPreview)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            if store.userHasMore {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
                    .onAppear {
                        Task {
                            await store.loadMoreUsers(word: word)
                        }
                    }
            } else if !filteredUsers.isEmpty {
                Text(String(localized: "已经到底了"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    @ToolbarContentBuilder
    private var searchToolbar: some ToolbarContent {
        if selectedTab == 0 {
            ToolbarItemGroup(placement: .primaryAction) {
                SearchFiltersButton(filterState: $filterState)
                SearchSortButton(
                    sortOption: $sortOption,
                    isPremium: accountStore.currentAccount?.isPremium == 1,
                    contentType: .illust
                )
            }
        } else if selectedTab == 1 {
            ToolbarItemGroup(placement: .primaryAction) {
                SearchFiltersButton(filterState: $filterState)
                SearchSortButton(
                    sortOption: $novelSortOption,
                    isPremium: accountStore.currentAccount?.isPremium == 1,
                    contentType: .novel
                )
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
            let userColumnCount = ResponsiveGrid.userColumnCount(for: proxy.size.width)
            let horizontalPadding: CGFloat = 24
            let availableWidth = proxy.size.width - horizontalPadding
            let waterfallWidth = availableWidth > 0 ? availableWidth : nil

            ScrollView {
                LazyVStack(spacing: 0) {
                    Picker("类型", selection: $selectedTab) {
                        Text("插画").tag(0)
                        Text("小说").tag(1)
                        Text("画师").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .onChange(of: selectedTab) { _, newValue in
                        print("[SearchResultView] selectedTab changed to \(newValue)")
                    }

                    resultContent(columnCount: dynamicColumnCount, waterfallWidth: waterfallWidth, userColumnCount: userColumnCount)
                }
            }
            .navigationTitle(word)
            .toolbar { searchToolbar }
            .onChange(of: sortOption) { _, _ in
                guard selectedTab == 0 else { return }
                Task {
                    await performIllustSearch()
                }
            }
            .onChange(of: novelSortOption) { _, _ in
                guard selectedTab == 1 else { return }
                Task {
                    await performNovelSearch()
                }
            }
            .onChange(of: filterState) { _, _ in
                Task {
                    await performCurrentTabSearch()
                }
            }
            .onChange(of: selectedTab) { _, newValue in
                print("[SearchResultView] selectedTab changed to \(newValue)")
                if newValue == 1 {
                    Task {
                        await performNovelSearch()
                    }
                }
            }
            .onAppear {
                print("[SearchResultView] Appeared: word='\(word)', viewId=\(viewId)")
            }
            .task {
                print("[SearchResultView] task started: word='\(word)', viewId=\(viewId)")
                if store.illustResults.isEmpty && store.novelResults.isEmpty && store.userResults.isEmpty {
                    print("[SearchResultView] performing search")
                    await performIllustSearch()
                } else {
                    print("[SearchResultView] skipping search - results already exist")
                }
            }
            .onDisappear {
                store.cancelBackgroundTasks()
                print("[SearchResultView] disappeared: word='\(word)', viewId=\(viewId)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchResultView(word: "测试", preloadToken: nil)
    }
}

private struct SearchAIFilterButton: View {
    @Binding var showsAIGeneratedWorks: Bool

    var body: some View {
        Menu {
            Button {
                showsAIGeneratedWorks.toggle()
            } label: {
                HStack {
                    Text(String(localized: "显示 AI 生成作品"))
                    if showsAIGeneratedWorks {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "sparkles")
                .symbolVariant(showsAIGeneratedWorks ? .none : .fill)
        }
    }
}

private struct SearchFiltersButton: View {
    @Binding var filterState: SearchFilterState
    @State private var isPresentingSheet = false

    var body: some View {
        Button {
            isPresentingSheet = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(filterState.hasActiveFilters ? .fill : .none)
        }
        #if os(macOS)
        .popover(isPresented: $isPresentingSheet, arrowEdge: .bottom) {
            SearchFiltersSheet(filterState: $filterState)
                .frame(width: 360)
        }
        #else
        .sheet(isPresented: $isPresentingSheet) {
            SearchFiltersSheet(filterState: $filterState)
        }
        #endif
    }
}

private struct SearchFiltersSheet: View {
    @Binding var filterState: SearchFilterState
    @Environment(\.dismiss) private var dismiss

    @State private var draftState: SearchFilterState
    @State private var isDateRangeEnabled: Bool

    private let minDate: Date

    init(filterState: Binding<SearchFilterState>) {
        _filterState = filterState
        let initialState = filterState.wrappedValue
        _draftState = State(initialValue: initialState)
        _isDateRangeEnabled = State(initialValue: initialState.hasDateRange)
        minDate = Calendar.current.date(from: DateComponents(year: 2007, month: 8, day: 1)) ?? .distantPast
    }

    var body: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            Text("筛选")
                .font(.headline)

            bookmarkFilterSection
            searchTargetSection
            aiFilterSection
            dateRangeSection

            HStack {
                Button("重置") {
                    resetFilters()
                }

                Spacer()

                Button("取消") {
                    dismiss()
                }

                Button("应用") {
                    applyFilters()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        #else
        NavigationStack {
            Form {
                bookmarkFilterSection
                searchTargetSection
                aiFilterSection
                dateRangeSection
            }
            .navigationTitle("筛选")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("应用") {
                        applyFilters()
                    }
                }

                ToolbarItem(placement: .bottomBar) {
                    Button("重置") {
                        resetFilters()
                    }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
        #endif
    }

    private var bookmarkFilterSection: some View {
        Section("收藏阈值") {
            Picker("收藏阈值", selection: $draftState.bookmarkFilter) {
                ForEach(BookmarkFilterOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }
    }

    private var searchTargetSection: some View {
        Section("搜索范围") {
            Picker("搜索范围", selection: $draftState.searchTarget) {
                ForEach(SearchTargetOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }
    }

    private var aiFilterSection: some View {
        Section("内容过滤") {
            Toggle("显示 AI 生成作品", isOn: $draftState.showsAIGeneratedWorks)
        }
    }

    private var dateRangeSection: some View {
        Section("时间范围") {
            Toggle("启用时间筛选", isOn: $isDateRangeEnabled)

            if isDateRangeEnabled {
                DatePicker(
                    "开始日期",
                    selection: Binding(
                        get: { draftState.startDate ?? draftState.endDate ?? Date() },
                        set: { draftState.startDate = $0 }
                    ),
                    in: minDate...Date(),
                    displayedComponents: .date
                )

                DatePicker(
                    "结束日期",
                    selection: Binding(
                        get: { draftState.endDate ?? draftState.startDate ?? Date() },
                        set: { draftState.endDate = $0 }
                    ),
                    in: minDate...Date(),
                    displayedComponents: .date
                )
            }
        }
    }

    private func resetFilters() {
        draftState = SearchFilterState()
        isDateRangeEnabled = false
    }

    private func applyFilters() {
        if isDateRangeEnabled {
            var normalizedStartDate = Calendar.current.startOfDay(for: draftState.startDate ?? Date())
            var normalizedEndDate = Calendar.current.startOfDay(for: draftState.endDate ?? normalizedStartDate)

            if normalizedStartDate > normalizedEndDate {
                swap(&normalizedStartDate, &normalizedEndDate)
            }

            draftState.startDate = normalizedStartDate
            draftState.endDate = normalizedEndDate
        } else {
            draftState.startDate = nil
            draftState.endDate = nil
        }

        filterState = draftState
        dismiss()
    }
}
