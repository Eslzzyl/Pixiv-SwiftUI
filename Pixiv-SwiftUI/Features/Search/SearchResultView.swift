import SwiftUI
import os.log

struct SearchResultView: View {
    let word: String
    let preloadToken: UUID?
    @State private var store = SearchResultStore()
    @State private var vm: SearchResultViewModel
    @State private var selectedTab = 0
    @State private var prefetchTracker = PrefetchTracker()
    @State private var searchTask: Task<Void, Never>?
    @Environment(UserSettingStore.self) var settingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) private var dismiss
    let instanceId = UUID()

    private var viewId: String {
        "\(instanceId)"
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    private func scheduleSearch(_ operation: @escaping @MainActor () async -> Void) {
        searchTask?.cancel()
        store.cancelBackgroundTasks()
        searchTask = Task { @MainActor in
            await operation()
        }
    }

    init(word: String, preloadToken: UUID?) {
        self.word = word
        self.preloadToken = preloadToken
        let storeInstance = SearchResultStore()
        _store = State(initialValue: storeInstance)
        _vm = State(initialValue: SearchResultViewModel(
            word: word,
            preloadToken: preloadToken,
            store: storeInstance,
            settingStore: UserSettingStore.shared,
            accountStore: AccountStore.shared
        ))
    }

    @ViewBuilder
    private var illustLoadMoreFooter: some View {        if let errorMessage = store.illustLoadMoreError {
            VStack(spacing: 8) {
                Text("加载更多失败")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(errorMessage.localizedDescription ?? "未知错误")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("重试") {
                    Task {
                        await vm.loadMoreIllustResults()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else if vm.isIllustLoadMorePaused {
            VStack(spacing: 8) {
                Text("已连续跳过多页被屏蔽内容")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("继续加载会再向后查找可显示的插画")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("继续加载") {
                    Task {
                        await vm.loadMoreIllustResultsRespectingFilters(forceManualContinuation: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            ProgressView()
                .padding()
                .onAppear {
                    Task {
                        await vm.loadMoreIllustResultsRespectingFilters()
                    }
                }
        }
    }

    @ViewBuilder
    private var novelLoadMoreFooter: some View {
        if let errorMessage = store.novelLoadMoreError {
            VStack(spacing: 8) {
                Text("加载更多失败")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(errorMessage.localizedDescription ?? "未知错误")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("重试") {
                    Task {
                        await vm.loadMoreNovelResultsRespectingFilters()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
        } else if vm.isNovelLoadMorePaused {
            VStack(spacing: 8) {
                Text("已连续跳过多页被屏蔽内容")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("继续加载会再向后查找可显示的小说")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("继续加载") {
                    Task {
                        await vm.loadMoreNovelResultsRespectingFilters(forceManualContinuation: true)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else {
            ProgressView()
                .padding()
                .onAppear {
                    Task {
                        await vm.loadMoreNovelResultsRespectingFilters()
                    }
                }
        }
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
            .transition(.opacity)
        } else if let error = store.error, store.illustResults.isEmpty && store.novelResults.isEmpty && store.userResults.isEmpty {
            ContentUnavailableView("出错了", systemImage: "exclamationmark.triangle", description: Text(error.localizedDescription ?? "未知错误"))
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
        if vm.filteredIllusts.isEmpty && !store.illustResults.isEmpty && settingStore.blockedTags.contains(word) {
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
                .adaptiveGlassButtonStyle(color: themeManager.currentColor)

                Spacer()
            }
            .padding()
            .frame(minHeight: 300)
        } else if vm.filteredIllusts.isEmpty && !store.isLoading {
            if store.illustHasMore {
                VStack(spacing: 12) {
                    Text("正在加载更多结果")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    illustLoadMoreFooter
                }
                .frame(minHeight: 300)
            } else {
            ContentUnavailableView("没有找到插画", systemImage: "magnifyingglass", description: Text("尝试搜索其他标签"))
                .frame(minHeight: 300)
            }
        } else {
            LazyVStack(spacing: 12) {
                WaterfallGrid(data: vm.filteredIllusts, columnCount: columnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                    NavigationLink(value: illust) {
                        IllustCard(
                            illust: illust,
                            columnCount: columnCount,
                            columnWidth: columnWidth,
                            showsBookmarkCount: vm.shouldShowIllustBookmarkCount,
                            feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                            shouldBlur: vm.shouldBlurFromCache(for: illust),
                            accentColor: themeManager.currentColor
                        )
                        .equatable()
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        prefetchIllustsIfNeeded(from: illust, in: vm.filteredIllusts, quality: settingStore.userSetting.feedPreviewQuality, tracker: prefetchTracker)
                    }
                }

                if store.illustHasMore && !store.isLoading {
                    illustLoadMoreFooter
                } else if !vm.filteredIllusts.isEmpty {
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
        if vm.filteredNovels.isEmpty && !store.novelResults.isEmpty && !store.isLoading {
            if store.novelHasMore {
                VStack(spacing: 12) {
                    Text("正在加载更多结果")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    novelLoadMoreFooter
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
                ForEach(vm.filteredNovels) { novel in
                    NavigationLink(value: novel) {
                        NovelListCard(novel: novel, showsBookmarkCount: vm.shouldShowNovelBookmarkCount)
                    }
                    .buttonStyle(.plain)
                }

                if store.novelHasMore {
                    novelLoadMoreFooter
                } else if !vm.filteredNovels.isEmpty {
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
        if vm.filteredUsers.isEmpty && !store.userResults.isEmpty && !store.isLoading {
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
                ForEach(vm.filteredUsers, id: \.id) { userPreview in
                    NavigationLink(value: userPreview.user.toDomain()) {
                        UserPreviewCard(userPreview: userPreview, accentColor: themeManager.currentColor)
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
            } else if !vm.filteredUsers.isEmpty {
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
                SearchFiltersButton(filterState: $vm.filterState)
                SearchSortButton(
                    sortOption: $vm.sortOption,
                    isPremium: accountStore.currentAccount?.isPremium == 1,
                    contentType: .illust
                )
            }
        } else if selectedTab == 1 {
            ToolbarItemGroup(placement: .primaryAction) {
                SearchFiltersButton(filterState: $vm.filterState)
                SearchSortButton(
                    sortOption: $vm.novelSortOption,
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
                        Logger.search.debug("selectedTab changed to \(newValue)")
                    }

                    resultContent(columnCount: dynamicColumnCount, waterfallWidth: waterfallWidth, userColumnCount: userColumnCount)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.isLoading)
            .navigationTitle(word)
            .toolbar { searchToolbar }
            .onChange(of: vm.sortOption) { _, _ in
                guard selectedTab == 0 else { return }
                scheduleSearch {
                    await vm.performIllustSearch()
                }
            }
            .onChange(of: vm.novelSortOption) { _, _ in
                guard selectedTab == 1 else { return }
                scheduleSearch {
                    await vm.performNovelSearch()
                }
            }
            .onChange(of: vm.filterState) { _, _ in
                scheduleSearch {
                    await vm.performCurrentTabSearch(selectedTab: selectedTab)
                }
            }
            .onChange(of: store.illustResults) { _, _ in
                vm.recalculateShouldBlurFlags()
            }
            .onAppear {
                vm.recalculateShouldBlurFlags()
            }
            .onChange(of: selectedTab) { _, newValue in
                Logger.search.debug("selectedTab changed to \(newValue)")
                if newValue == 1 {
                    scheduleSearch {
                        await vm.performNovelSearch()
                    }
                }
            }
            .onAppear {
                Logger.search.debug("Appeared: word='\(word)', viewId=\(viewId)")
            }
            .task {
                Logger.search.debug("task started: word='\(word)', viewId=\(viewId)")
                if store.illustResults.isEmpty && store.novelResults.isEmpty && store.userResults.isEmpty {
                    Logger.search.debug("performing search")
                    await vm.performIllustSearch()
                } else {
                    Logger.search.debug("skipping search - results already exist")
                }
            }
            .onDisappear {
                searchTask?.cancel()
                searchTask = nil
                store.cancelBackgroundTasks()
                Logger.search.debug("disappeared: word='\(word)', viewId=\(viewId)")
            }
            .onFilterSettingsChange(from: settingStore, perform: vm.recalculateShouldBlurFlags)
        }
    }
}

#Preview {
    NavigationStack {
        SearchResultView(word: "测试", preloadToken: nil)
    }
}

private struct SearchFiltersButton: View {
    @Binding var filterState: SearchFilterState
    @State private var isPresentingSheet = false

    var body: some View {
        Button {
            isPresentingSheet = true
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
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
