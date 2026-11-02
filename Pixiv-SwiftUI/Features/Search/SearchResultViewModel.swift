import Foundation
import os.log

struct SearchFilterState: Equatable {
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

@MainActor
@Observable
final class SearchResultViewModel {
    let word: String

    var sortOption: SearchSortOption
    var novelSortOption: SearchSortOption
    var filterState = SearchFilterState()
    var cachedShouldBlurFlags: [Bool] = []

    var isResolvingNovelLoadMore = false
    var isNovelLoadMorePaused = false
    var isResolvingIllustLoadMore = false
    var isIllustLoadMorePaused = false

    private let novelAutoLoadBurstLimit = 5
    @ObservationIgnored let store: SearchResultStore
    @ObservationIgnored private let settingStore: UserSettingStore
    @ObservationIgnored private let accountStore: AccountStore

    init(
        word: String,
        store: SearchResultStore = SearchResultStore(),
        settingStore: UserSettingStore = .shared,
        accountStore: AccountStore = .shared
    ) {
        self.word = word
        self.store = store
        self.settingStore = settingStore
        self.accountStore = accountStore
        let defaultSort = SearchSortOption(rawValue: settingStore.userSetting.defaultSearchSort) ?? .dateDesc
        self.sortOption = defaultSort
        self.novelSortOption = defaultSort
    }

    // MARK: - Filtered Results

    var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(store.illustResults)
    }

    var filteredUsers: [UserPreviews] {
        settingStore.filterUserPreviews(store.userResults)
    }

    var filteredNovels: [Novel] {
        settingStore.filterNovels(store.novelResults)
    }

    var shouldShowIllustBookmarkCount: Bool {
        sortOption == .popularDesc && settingStore.userSetting.showSearchPopularBookmarkCount
    }

    var shouldShowNovelBookmarkCount: Bool {
        novelSortOption != .popularDesc || settingStore.userSetting.showSearchPopularBookmarkCount
    }

    // MARK: - Blur Cache

    func recalculateShouldBlurFlags() {
        cachedShouldBlurFlags = filteredIllusts.map { settingStore.userSetting.shouldBlurIllust($0) }
    }

    func shouldBlurFromCache(for illust: Illusts) -> Bool {
        guard let index = filteredIllusts.firstIndex(where: { $0.id == illust.id }),
              index < cachedShouldBlurFlags.count
        else { return false }
        return cachedShouldBlurFlags[index]
    }

    // MARK: - Search Orchestration

    func performIllustSearch() async {
        await store.search(
            word: word,
            sort: sortOption.rawValue,
            preferLocalPopularSort: sortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            novelSort: novelSortOption.rawValue,
            novelPreferLocalPopularSort: novelSortOption == .popularDesc && accountStore.currentAccount?.isPremium != 1,
            showsAIGenerated: filterState.showsAIGeneratedWorks,
            bookmarkFilter: filterState.bookmarkFilter,
            searchTarget: filterState.searchTarget,
            startDate: filterState.startDate,
            endDate: filterState.endDate
        )
    }

    func performNovelSearch() async {
        isNovelLoadMorePaused = false
        await store.searchNovels(
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

    func performCurrentTabSearch(selectedTab: Int) async {
        if selectedTab == 0 {
            await performIllustSearch()
        } else if selectedTab == 1 {
            await performNovelSearch()
        }
    }

    // MARK: - Load More

    func loadMoreIllustResults() async {
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

    func loadMoreNovelResults() async {
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

    @MainActor
    func loadMoreNovelResultsRespectingFilters(forceManualContinuation: Bool = false) async {
        if forceManualContinuation {
            isNovelLoadMorePaused = false
        }

        guard !isResolvingNovelLoadMore else { return }
        isResolvingNovelLoadMore = true
        defer { isResolvingNovelLoadMore = false }

        var burstCount = 0

        while burstCount < novelAutoLoadBurstLimit {
            let initialStoreCount = store.novelResults.count
            let initialVisibleCount = filteredNovels.count

            await loadMoreNovelResults()

            let totalFetched = store.novelResults.count - initialStoreCount
            if totalFetched == 0 || store.novelLoadMoreError != nil {
                break
            }

            burstCount += 1

            let visibleGain = filteredNovels.count - initialVisibleCount
            if store.novelHasMore && visibleGain * 2 < totalFetched {
                isNovelLoadMorePaused = true
                break
            }
        }
    }

    @MainActor
    func loadMoreIllustResultsRespectingFilters(forceManualContinuation: Bool = false) async {
        if forceManualContinuation {
            isIllustLoadMorePaused = false
        }

        guard !isResolvingIllustLoadMore else { return }
        isResolvingIllustLoadMore = true
        defer { isResolvingIllustLoadMore = false }

        let initialStoreCount = store.illustResults.count
        let initialVisibleCount = filteredIllusts.count

        await loadMoreIllustResults()

        let totalFetched = store.illustResults.count - initialStoreCount
        let visibleGain = filteredIllusts.count - initialVisibleCount
        if store.illustHasMore && visibleGain * 10 < totalFetched && store.illustLoadMoreError == nil {
            isIllustLoadMorePaused = true
        }
    }
}
