// swiftlint:disable file_length
import SwiftUI
import Observation

private protocol BookmarkSortableSearchResult {
    var id: Int { get }
    var totalBookmarks: Int { get }
    var createDate: String { get }
}

extension Illusts: BookmarkSortableSearchResult {}
extension Novel: BookmarkSortableSearchResult {}

@MainActor
@Observable
final class SearchResultStore {
    private struct SearchBatch<T> {
        let items: [T]
        let nextOffset: Int
        let hasMore: Bool
    }

    private struct SearchRequestSignature: Equatable {
        let word: String
        let sort: String
        let preferLocalPopularSort: Bool
        let showsAIGenerated: Bool
        let bookmarkFilter: BookmarkFilterOption
        let searchTarget: SearchTargetOption
        let startDate: String?
        let endDate: String?
    }

    private struct SearchExecutionContext {
        let word: String
        let sort: String
        let preferLocalPopularSort: Bool
        let showsAIGenerated: Bool
        let bookmarkFilter: BookmarkFilterOption
        let searchTarget: SearchTargetOption
        let startDate: Date?
        let endDate: Date?
    }

    private struct PseudoPopularQuery: Hashable {
        let word: String
        let searchTarget: SearchTargetOption
    }

    private struct PseudoPopularSessionKey: Equatable {
        let word: String
        let showsAIGenerated: Bool
        let bookmarkFilter: BookmarkFilterOption
        let searchTarget: SearchTargetOption
        let minimumBookmarkCount: Int
        let startDate: String?
        let endDate: String?
        let usesUsersTagBuckets: Bool
    }

    private struct PseudoPopularQueryState {
        let query: PseudoPopularQuery
        var nextOffset: Int = 0
        var fetchedPageCount: Int = 0
        var isExhausted: Bool = false
    }

    private struct PseudoPopularBucketState {
        let threshold: BookmarkFilterOption
        var queryStates: [PseudoPopularQueryState]
    }

    private struct PseudoPopularFallbackState {
        var nextOffset: Int = 0
        var fetchedPageCount: Int = 0
        var isExhausted: Bool = false
    }

    private struct IllustPseudoPopularSessionState {
        let key: PseudoPopularSessionKey
        var allowedPagesPerSource: Int = 0
        var items: [Illusts] = []
        var bucketStates: [PseudoPopularBucketState] = []
        var fallbackState = PseudoPopularFallbackState()
    }

    private struct NovelPseudoPopularSessionState {
        let key: PseudoPopularSessionKey
        var allowedPagesPerSource: Int = 0
        var items: [Novel] = []
        var bucketStates: [PseudoPopularBucketState] = []
        var fallbackState = PseudoPopularFallbackState()
    }

    var illustResults: [Illusts] = []
    var userResults: [UserPreviews] = []
    var novelResults: [Novel] = []

    var isLoading: Bool = false
    var errorMessage: String?

    // 分页状态
    var illustOffset: Int = 0
    var illustLimit: Int = 30
    var illustHasMore: Bool = false
    var isLoadingMoreIllusts: Bool = false

    var userOffset: Int = 0
    var userHasMore: Bool = false
    var isLoadingMoreUsers: Bool = false

    var novelOffset: Int = 0
    var novelLimit: Int = 30
    var novelHasMore: Bool = false
    var isLoadingMoreNovels: Bool = false

    @ObservationIgnored private let api = PixivAPI.shared
    @ObservationIgnored private let pseudoPopularInitialSamplePageCount = 1
    @ObservationIgnored private let pseudoPopularBackgroundSamplePageCount = 3
    @ObservationIgnored private let pseudoPopularColdStartTargetCount = 8
    @ObservationIgnored private let pseudoPopularSearchEntryPreloadTargetCount = 6
    @ObservationIgnored private let pseudoPopularFastEntryTargetCount = 12
    @ObservationIgnored private let pseudoPopularPreloadWarmupDelayMilliseconds = 250
    @ObservationIgnored private let pseudoPopularDeferredPreloadDelayMilliseconds = 1200
    @ObservationIgnored private let pseudoPopularSearchEntryAwaitMilliseconds = 120
    @ObservationIgnored private let pseudoPopularImplicitMinimumBookmarkCount = BookmarkFilterOption.users100.rawValue
    @ObservationIgnored private let pseudoPopularTitleAndCaptionMinimumBookmarkCount = BookmarkFilterOption.users250.rawValue
    @ObservationIgnored private var illustPseudoPopularTargetCount: Int = 0
    @ObservationIgnored private var novelPseudoPopularTargetCount: Int = 0
    @ObservationIgnored private var illustPseudoPopularSamplePageCount: Int = 0
    @ObservationIgnored private var novelPseudoPopularSamplePageCount: Int = 0
    @ObservationIgnored private var illustPseudoPopularSessionID = UUID()
    @ObservationIgnored private var novelPseudoPopularSessionID = UUID()
    @ObservationIgnored private var illustPseudoPopularEnrichmentTask: Task<Void, Never>?
    @ObservationIgnored private var novelPseudoPopularEnrichmentTask: Task<Void, Never>?
    @ObservationIgnored private var illustPseudoPopularPreloadTask: Task<Void, Never>?
    @ObservationIgnored private var novelPseudoPopularPreloadTask: Task<Void, Never>?
    @ObservationIgnored private var supplementalSearchTask: Task<Void, Never>?
    @ObservationIgnored private var illustPseudoPopularSession: IllustPseudoPopularSessionState?
    @ObservationIgnored private var novelPseudoPopularSession: NovelPseudoPopularSessionState?
    @ObservationIgnored private var novelSearchSignature: SearchRequestSignature?
    @ObservationIgnored private var activeSearchSessionID = UUID()
    private static let searchEntryPreheater = SearchResultStore()
    private static var searchEntryPreloadToken: UUID?
    private static var searchEntryPreloadTask: Task<Void, Never>?

    func search(
        word: String,
        sort: String = "date_desc",
        preferLocalPopularSort: Bool = false,
        prefetchNovelSort: String = SearchSortOption.dateDesc.rawValue,
        prefetchNovelPreferLocalPopularSort: Bool = false,
        allowsPseudoPopularPreload: Bool = false,
        preloadToken: UUID? = nil,
        showsAIGenerated: Bool = true,
        bookmarkFilter: BookmarkFilterOption = .none,
        searchTarget: SearchTargetOption = .partialMatchForTags,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {
        self.isLoading = true
        self.errorMessage = nil
        SearchStore.shared.addHistory(word)
        self.activeSearchSessionID = UUID()

        self.illustOffset = 0
        self.userOffset = 0
        self.novelOffset = 0
        self.illustHasMore = false
        self.userHasMore = false
        self.novelHasMore = false
        self.illustPseudoPopularTargetCount = 0
        self.novelPseudoPopularTargetCount = 0
        self.illustPseudoPopularSamplePageCount = 0
        self.novelPseudoPopularSamplePageCount = 0
        self.illustPseudoPopularSessionID = UUID()
        self.novelPseudoPopularSessionID = UUID()
        self.novelSearchSignature = nil
        cancelIllustPseudoPopularEnrichment()
        cancelNovelPseudoPopularEnrichment()
        cancelIllustPseudoPopularPreload()
        cancelNovelPseudoPopularPreload()
        cancelSupplementalSearch()

        let baseWord = normalizeSearchWord(word)
        let usesPseudoPopularSort = preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: bookmarkFilter,
            searchTarget: searchTarget
        )
        if usesPseudoPopularSort {
            await adoptSearchEntryPseudoPopularPreloadIfAvailable(
                token: preloadToken,
                word: baseWord,
                showsAIGenerated: showsAIGenerated,
                bookmarkFilter: bookmarkFilter,
                searchTarget: searchTarget,
                minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                startDate: startDate,
                endDate: endDate,
                usesUsersTagBuckets: usesUsersTagPseudoPopularSort
            )
        }
        let finalWord = baseWord + bookmarkFilter.suffix
        let illustSessionID = illustPseudoPopularSessionID
        let searchSessionID = activeSearchSessionID
        let illustInitialTargetCount = usesPseudoPopularSort
            ? initialPseudoPopularTargetCount(
                existingCount: existingIllustPseudoPopularItemCount(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    usesUsersTagBuckets: usesUsersTagPseudoPopularSort
                ),
                limit: illustLimit
            )
            : illustLimit
        let prefetchedNovelSignature = makeSearchRequestSignature(
            word: word,
            sort: prefetchNovelSort,
            preferLocalPopularSort: prefetchNovelPreferLocalPopularSort,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: bookmarkFilter,
            searchTarget: searchTarget,
            startDate: startDate,
            endDate: endDate
        )

        do {
            let fetchedIllusts: [Illusts]

            if usesUsersTagPseudoPopularSort {
                let illustBatch = try await searchIllustsByPseudoPopularTags(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: illustInitialTargetCount,
                    samplePageCount: pseudoPopularInitialSamplePageCount
                )
                fetchedIllusts = illustBatch.items
                self.illustPseudoPopularTargetCount = illustInitialTargetCount
                self.illustPseudoPopularSamplePageCount = pseudoPopularInitialSamplePageCount
                self.illustOffset = illustBatch.nextOffset
                self.illustHasMore = illustBatch.hasMore
            } else if usesPseudoPopularSort {
                let illustBatch = try await searchIllustsByBookmarkCount(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    searchTarget: searchTarget,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: illustInitialTargetCount,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    samplePageCount: pseudoPopularInitialSamplePageCount
                )
                fetchedIllusts = illustBatch.items
                self.illustPseudoPopularTargetCount = illustInitialTargetCount
                self.illustPseudoPopularSamplePageCount = pseudoPopularInitialSamplePageCount
                self.illustOffset = illustBatch.nextOffset
                self.illustHasMore = illustBatch.hasMore
            } else {
                fetchedIllusts = try await api.searchIllusts(
                    word: finalWord,
                    searchTarget: searchTarget.rawValue,
                    sort: sort,
                    searchAIType: searchAITypeParameter(for: showsAIGenerated),
                    startDate: startDate,
                    endDate: endDate,
                    offset: 0,
                    limit: illustLimit
                )
                self.illustOffset = fetchedIllusts.count
                self.illustHasMore = fetchedIllusts.count == illustLimit
            }

            self.illustResults = fetchedIllusts

            if !usesPseudoPopularSort {
                seedIllustPseudoPopularSessionFromRegularResults(
                    items: fetchedIllusts,
                    sourceSort: sort,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
                if allowsPseudoPopularPreload {
                    scheduleIllustPseudoPopularPreload(
                        searchSessionID: searchSessionID,
                        word: baseWord,
                        showsAIGenerated: showsAIGenerated,
                        bookmarkFilter: bookmarkFilter,
                        searchTarget: searchTarget,
                        minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                        startDate: startDate,
                        endDate: endDate
                    )
                }
            }

            if usesPseudoPopularSort {
                self.userResults = []
                self.novelResults = []
                self.isLoading = false
                scheduleIllustPseudoPopularEnrichment(
                    sessionID: illustSessionID,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
                scheduleSupplementalSearch(
                    sessionID: searchSessionID,
                    context: SearchExecutionContext(
                        word: word,
                        sort: prefetchNovelSort,
                        preferLocalPopularSort: prefetchNovelPreferLocalPopularSort,
                        showsAIGenerated: showsAIGenerated,
                        bookmarkFilter: bookmarkFilter,
                        searchTarget: searchTarget,
                        startDate: startDate,
                        endDate: endDate
                    ),
                    prefetchNovelSignature: prefetchedNovelSignature,
                )
                return
            }

            let fetchedNovels = try await fetchNovelResults(
                    context: SearchExecutionContext(
                        word: word,
                        sort: prefetchNovelSort,
                        preferLocalPopularSort: prefetchNovelPreferLocalPopularSort,
                        showsAIGenerated: showsAIGenerated,
                        bookmarkFilter: bookmarkFilter,
                        searchTarget: searchTarget,
                        startDate: startDate,
                    endDate: endDate
                ),
                targetCount: novelLimit,
                samplePageCount: pseudoPopularInitialSamplePageCount,
                updatePseudoPopularState: true
            )

            let fetchedUsers = try await api.getSearchUser(word: word, offset: 0)

            self.userResults = fetchedUsers
            self.novelResults = fetchedNovels
            self.userOffset = fetchedUsers.count
            self.userHasMore = !fetchedUsers.isEmpty
            self.novelSearchSignature = prefetchedNovelSignature

            if !(prefetchNovelPreferLocalPopularSort && prefetchNovelSort == SearchSortOption.popularDesc.rawValue) {
                seedNovelPseudoPopularSessionFromRegularResults(
                    items: fetchedNovels,
                    sourceSort: prefetchNovelSort,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    /// 加载更多插画
    func loadMoreIllusts(
        word: String,
        sort: String = "date_desc",
        preferLocalPopularSort: Bool = false,
        showsAIGenerated: Bool = true,
        bookmarkFilter: BookmarkFilterOption = .none,
        searchTarget: SearchTargetOption = .partialMatchForTags,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {
        guard !isLoading, !isLoadingMoreIllusts, illustHasMore else { return }
        isLoadingMoreIllusts = true
        let baseWord = normalizeSearchWord(word)
        let usesPseudoPopularSort = preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: bookmarkFilter,
            searchTarget: searchTarget
        )
        let finalWord = baseWord + bookmarkFilter.suffix
        cancelIllustPseudoPopularEnrichment()
        do {
            if usesUsersTagPseudoPopularSort {
                let nextTargetCount = max(illustPseudoPopularTargetCount, illustResults.count) + illustLimit
                let nextSamplePageCount = max(
                    illustPseudoPopularSamplePageCount + 1,
                    pseudoPopularBackgroundSamplePageCount
                )
                let batch = try await searchIllustsByPseudoPopularTags(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: nextTargetCount,
                    samplePageCount: nextSamplePageCount
                )
                self.illustResults = appendNewResultsPreservingOrder(existing: self.illustResults, fetched: batch.items)
                self.illustPseudoPopularTargetCount = nextTargetCount
                self.illustPseudoPopularSamplePageCount = nextSamplePageCount
                self.illustOffset = batch.nextOffset
                self.illustHasMore = batch.hasMore
                scheduleIllustPseudoPopularEnrichment(
                    sessionID: illustPseudoPopularSessionID,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
            } else if usesPseudoPopularSort {
                let nextTargetCount = max(illustPseudoPopularTargetCount, illustResults.count) + illustLimit
                let nextSamplePageCount = max(
                    illustPseudoPopularSamplePageCount + 1,
                    pseudoPopularBackgroundSamplePageCount
                )
                let batch = try await searchIllustsByBookmarkCount(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    searchTarget: searchTarget,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: nextTargetCount,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    samplePageCount: nextSamplePageCount
                )
                self.illustResults = appendNewResultsPreservingOrder(existing: self.illustResults, fetched: batch.items)
                self.illustPseudoPopularTargetCount = nextTargetCount
                self.illustPseudoPopularSamplePageCount = nextSamplePageCount
                self.illustOffset = batch.nextOffset
                self.illustHasMore = batch.hasMore
                scheduleIllustPseudoPopularEnrichment(
                    sessionID: illustPseudoPopularSessionID,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
            } else {
                let more = try await api.searchIllusts(
                    word: finalWord,
                    searchTarget: searchTarget.rawValue,
                    sort: sort,
                    searchAIType: searchAITypeParameter(for: showsAIGenerated),
                    startDate: startDate,
                    endDate: endDate,
                    offset: self.illustOffset,
                    limit: self.illustLimit
                )
                self.illustResults += more
                self.illustOffset += more.count
                self.illustHasMore = more.count == illustLimit
            }
        } catch {
            print("Failed to load more illusts: \(error)")
        }
        isLoadingMoreIllusts = false
    }

    /// 加载更多用户
    func loadMoreUsers(word: String) async {
        guard !isLoading, !isLoadingMoreUsers, userHasMore else { return }
        isLoadingMoreUsers = true
        do {
            let more = try await api.getSearchUser(word: word, offset: self.userOffset)
            self.userResults += more
            self.userOffset += more.count
            self.userHasMore = !more.isEmpty
        } catch {
            print("Failed to load more users: \(error)")
        }
        isLoadingMoreUsers = false
    }

    /// 搜索小说 (带独立状态但目前都合并在一起)
    func searchNovels(
        word: String,
        sort: String = "date_desc",
        preferLocalPopularSort: Bool = false,
        allowsPseudoPopularPreload: Bool = false,
        showsAIGenerated: Bool = true,
        bookmarkFilter: BookmarkFilterOption = .none,
        searchTarget: SearchTargetOption = .partialMatchForTags,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {
        let searchSessionID = activeSearchSessionID
        let baseWord = normalizeSearchWord(word)
        let usesPseudoPopularSort = preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: bookmarkFilter,
            searchTarget: searchTarget
        )
        let novelInitialTargetCount = usesPseudoPopularSort
            ? initialPseudoPopularTargetCount(
                existingCount: existingNovelPseudoPopularItemCount(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    usesUsersTagBuckets: usesUsersTagPseudoPopularSort
                ),
                limit: novelLimit
            )
            : novelLimit
        let requestSignature = makeSearchRequestSignature(
            word: word,
            sort: sort,
            preferLocalPopularSort: preferLocalPopularSort,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: bookmarkFilter,
            searchTarget: searchTarget,
            startDate: startDate,
            endDate: endDate
        )

        if novelSearchSignature == requestSignature {
            if preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue {
                scheduleNovelPseudoPopularEnrichment(
                    sessionID: novelPseudoPopularSessionID,
                    word: normalizeSearchWord(word),
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: effectivePseudoPopularMinimumBookmarkCount(
                        for: bookmarkFilter,
                        searchTarget: searchTarget
                    ),
                    startDate: startDate,
                    endDate: endDate
                )
            } else if allowsPseudoPopularPreload {
                scheduleNovelPseudoPopularPreload(
                    searchSessionID: searchSessionID,
                    word: normalizeSearchWord(word),
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: effectivePseudoPopularMinimumBookmarkCount(
                        for: bookmarkFilter,
                        searchTarget: searchTarget
                    ),
                    startDate: startDate,
                    endDate: endDate
                )
            }
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        self.novelPseudoPopularTargetCount = 0
        self.novelPseudoPopularSamplePageCount = 0
        self.novelPseudoPopularSessionID = UUID()
        cancelNovelPseudoPopularEnrichment()
        cancelNovelPseudoPopularPreload()

        do {
            let fetchedNovels = try await fetchNovelResults(
                context: SearchExecutionContext(
                    word: word,
                    sort: sort,
                    preferLocalPopularSort: preferLocalPopularSort,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    startDate: startDate,
                    endDate: endDate
                ),
                targetCount: novelInitialTargetCount,
                samplePageCount: pseudoPopularInitialSamplePageCount,
                updatePseudoPopularState: true
            )
            self.novelResults = fetchedNovels
            self.novelSearchSignature = requestSignature

            if !usesPseudoPopularSort {
                seedNovelPseudoPopularSessionFromRegularResults(
                    items: fetchedNovels,
                    sourceSort: sort,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
            }

            if preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue {
                scheduleNovelPseudoPopularEnrichment(
                    sessionID: novelPseudoPopularSessionID,
                    word: normalizeSearchWord(word),
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: effectivePseudoPopularMinimumBookmarkCount(
                        for: bookmarkFilter,
                        searchTarget: searchTarget
                    ),
                    startDate: startDate,
                    endDate: endDate
                )
            } else if allowsPseudoPopularPreload {
                scheduleNovelPseudoPopularPreload(
                    searchSessionID: searchSessionID,
                    word: normalizeSearchWord(word),
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: effectivePseudoPopularMinimumBookmarkCount(
                        for: bookmarkFilter,
                        searchTarget: searchTarget
                    ),
                    startDate: startDate,
                    endDate: endDate
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// 加载更多小说
    func loadMoreNovels(
        word: String,
        sort: String = "date_desc",
        preferLocalPopularSort: Bool = false,
        showsAIGenerated: Bool = true,
        bookmarkFilter: BookmarkFilterOption = .none,
        searchTarget: SearchTargetOption = .partialMatchForTags,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) async {
        guard !isLoading, !isLoadingMoreNovels, novelHasMore else { return }
        isLoadingMoreNovels = true
        let baseWord = normalizeSearchWord(word)
        let usesPseudoPopularSort = preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: bookmarkFilter,
            searchTarget: searchTarget
        )
        let finalWord = baseWord + bookmarkFilter.suffix
        cancelNovelPseudoPopularEnrichment()

        do {
            if usesUsersTagPseudoPopularSort {
                let nextTargetCount = max(novelPseudoPopularTargetCount, novelResults.count) + novelLimit
                let nextSamplePageCount = max(
                    novelPseudoPopularSamplePageCount + 1,
                    pseudoPopularBackgroundSamplePageCount
                )
                let batch = try await searchNovelsByPseudoPopularTags(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: nextTargetCount,
                    samplePageCount: nextSamplePageCount
                )
                self.novelResults = appendNewResultsPreservingOrder(existing: self.novelResults, fetched: batch.items)
                self.novelPseudoPopularTargetCount = nextTargetCount
                self.novelPseudoPopularSamplePageCount = nextSamplePageCount
                self.novelOffset = batch.nextOffset
                self.novelHasMore = batch.hasMore
                scheduleNovelPseudoPopularEnrichment(
                    sessionID: novelPseudoPopularSessionID,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
            } else if usesPseudoPopularSort {
                let nextTargetCount = max(novelPseudoPopularTargetCount, novelResults.count) + novelLimit
                let nextSamplePageCount = max(
                    novelPseudoPopularSamplePageCount + 1,
                    pseudoPopularBackgroundSamplePageCount
                )
                let batch = try await searchNovelsByBookmarkCount(
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    searchTarget: searchTarget,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: nextTargetCount,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    samplePageCount: nextSamplePageCount
                )
                self.novelResults = appendNewResultsPreservingOrder(existing: self.novelResults, fetched: batch.items)
                self.novelPseudoPopularTargetCount = nextTargetCount
                self.novelPseudoPopularSamplePageCount = nextSamplePageCount
                self.novelOffset = batch.nextOffset
                self.novelHasMore = batch.hasMore
                scheduleNovelPseudoPopularEnrichment(
                    sessionID: novelPseudoPopularSessionID,
                    word: baseWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate
                )
            } else {
                let more = try await api.searchNovels(
                    word: finalWord,
                    searchTarget: searchTarget.rawValue,
                    sort: sort,
                    searchAIType: searchAITypeParameter(for: showsAIGenerated),
                    startDate: startDate,
                    endDate: endDate,
                    offset: self.novelOffset,
                    limit: self.novelLimit
                )
                self.novelResults += more
                self.novelOffset += more.count
                self.novelHasMore = more.count == novelLimit
            }
        } catch {
            print("Failed to load more novels: \(error)")
        }
        isLoadingMoreNovels = false
    }

    func cancelBackgroundTasks() {
        illustPseudoPopularSessionID = UUID()
        novelPseudoPopularSessionID = UUID()
        cancelIllustPseudoPopularEnrichment()
        cancelNovelPseudoPopularEnrichment()
        cancelIllustPseudoPopularPreload()
        cancelNovelPseudoPopularPreload()
        cancelSupplementalSearch()
    }

    private func fetchNovelResults(
        context: SearchExecutionContext,
        targetCount: Int,
        samplePageCount: Int,
        updatePseudoPopularState: Bool
    ) async throws -> [Novel] {
        let baseWord = normalizeSearchWord(context.word)
        let usesPseudoPopularSort = context.preferLocalPopularSort && context.sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && context.searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: context.bookmarkFilter,
            searchTarget: context.searchTarget
        )

        if usesUsersTagPseudoPopularSort {
            let batch = try await searchNovelsByPseudoPopularTags(
                word: baseWord,
                showsAIGenerated: context.showsAIGenerated,
                bookmarkFilter: context.bookmarkFilter,
                searchTarget: context.searchTarget,
                minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                startDate: context.startDate,
                endDate: context.endDate,
                targetCount: targetCount,
                samplePageCount: samplePageCount
            )
            if updatePseudoPopularState {
                self.novelPseudoPopularTargetCount = targetCount
                self.novelPseudoPopularSamplePageCount = samplePageCount
                self.novelOffset = batch.nextOffset
                self.novelHasMore = batch.hasMore
            }
            return batch.items
        }

        if usesPseudoPopularSort {
            let batch = try await searchNovelsByBookmarkCount(
                word: baseWord,
                showsAIGenerated: context.showsAIGenerated,
                searchTarget: context.searchTarget,
                startDate: context.startDate,
                endDate: context.endDate,
                targetCount: targetCount,
                minimumBookmarkCount: pseudoPopularMinimumBookmarkCount,
                samplePageCount: samplePageCount
            )
            if updatePseudoPopularState {
                self.novelPseudoPopularTargetCount = targetCount
                self.novelPseudoPopularSamplePageCount = samplePageCount
                self.novelOffset = batch.nextOffset
                self.novelHasMore = batch.hasMore
            }
            return batch.items
        }

        let fetchedNovels = try await api.searchNovels(
            word: baseWord + context.bookmarkFilter.suffix,
            searchTarget: context.searchTarget.rawValue,
            sort: context.sort,
            searchAIType: searchAITypeParameter(for: context.showsAIGenerated),
            startDate: context.startDate,
            endDate: context.endDate,
            offset: 0,
            limit: novelLimit
        )

        if updatePseudoPopularState {
            self.novelOffset = fetchedNovels.count
            self.novelHasMore = fetchedNovels.count == novelLimit
        }
        return fetchedNovels
    }

    private func searchIllustsByBookmarkCount(
        word: String,
        showsAIGenerated: Bool,
        searchTarget: SearchTargetOption,
        startDate: Date?,
        endDate: Date?,
        targetCount: Int,
        minimumBookmarkCount: Int = 0,
        samplePageCount: Int
    ) async throws -> SearchBatch<Illusts> {
        let sessionKey = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: false
        )
        let sessionID = illustPseudoPopularSessionID

        prepareIllustPseudoPopularSessionIfNeeded(for: sessionKey)
        if var session = illustPseudoPopularSession {
            session.allowedPagesPerSource = max(session.allowedPagesPerSource, max(1, samplePageCount))
            illustPseudoPopularSession = session
        }

        try await populateIllustPseudoPopularSession(targetCount: targetCount, sessionID: sessionID)
        try validateIllustPseudoPopularSession(sessionID)

        guard let session = illustPseudoPopularSession else {
            return SearchBatch(items: [], nextOffset: 0, hasMore: false)
        }

        let sorted = sortResultsByBookmarkCount(session.items)
        let limited = Array(sorted.prefix(targetCount))

        return SearchBatch(
            items: limited,
            nextOffset: limited.count,
            hasMore: sorted.count > targetCount || illustSessionCanFetchMore(session)
        )
    }

    private func searchNovelsByBookmarkCount(
        word: String,
        showsAIGenerated: Bool,
        searchTarget: SearchTargetOption,
        startDate: Date?,
        endDate: Date?,
        targetCount: Int,
        minimumBookmarkCount: Int = 0,
        samplePageCount: Int
    ) async throws -> SearchBatch<Novel> {
        let sessionKey = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: false
        )
        let sessionID = novelPseudoPopularSessionID

        prepareNovelPseudoPopularSessionIfNeeded(for: sessionKey)
        if var session = novelPseudoPopularSession {
            session.allowedPagesPerSource = max(session.allowedPagesPerSource, max(1, samplePageCount))
            novelPseudoPopularSession = session
        }

        try await populateNovelPseudoPopularSession(targetCount: targetCount, sessionID: sessionID)
        try validateNovelPseudoPopularSession(sessionID)

        guard let session = novelPseudoPopularSession else {
            return SearchBatch(items: [], nextOffset: 0, hasMore: false)
        }

        let sorted = sortResultsByBookmarkCount(session.items)
        let limited = Array(sorted.prefix(targetCount))

        return SearchBatch(
            items: limited,
            nextOffset: limited.count,
            hasMore: sorted.count > targetCount || novelSessionCanFetchMore(session)
        )
    }

    private func searchIllustsByPseudoPopularTags(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        targetCount: Int,
        samplePageCount: Int
    ) async throws -> SearchBatch<Illusts> {
        let sessionKey = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: bookmarkFilter,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: true
        )
        let sessionID = illustPseudoPopularSessionID

        prepareIllustPseudoPopularSessionIfNeeded(for: sessionKey)
        if var session = illustPseudoPopularSession {
            session.allowedPagesPerSource = max(session.allowedPagesPerSource, max(1, samplePageCount))
            illustPseudoPopularSession = session
        }

        try await populateIllustPseudoPopularSession(targetCount: targetCount, sessionID: sessionID)
        try validateIllustPseudoPopularSession(sessionID)

        guard let session = illustPseudoPopularSession else {
            return SearchBatch(items: [], nextOffset: 0, hasMore: false)
        }

        let sorted = sortResultsByBookmarkCount(session.items)
        let limited = Array(sorted.prefix(targetCount))

        return SearchBatch(
            items: limited,
            nextOffset: limited.count,
            hasMore: sorted.count > targetCount || illustSessionCanFetchMore(session)
        )
    }

    private func searchNovelsByPseudoPopularTags(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        targetCount: Int,
        samplePageCount: Int
    ) async throws -> SearchBatch<Novel> {
        let sessionKey = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: bookmarkFilter,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: true
        )
        let sessionID = novelPseudoPopularSessionID

        prepareNovelPseudoPopularSessionIfNeeded(for: sessionKey)
        if var session = novelPseudoPopularSession {
            session.allowedPagesPerSource = max(session.allowedPagesPerSource, max(1, samplePageCount))
            novelPseudoPopularSession = session
        }

        try await populateNovelPseudoPopularSession(targetCount: targetCount, sessionID: sessionID)
        try validateNovelPseudoPopularSession(sessionID)

        guard let session = novelPseudoPopularSession else {
            return SearchBatch(items: [], nextOffset: 0, hasMore: false)
        }

        let sorted = sortResultsByBookmarkCount(session.items)
        let limited = Array(sorted.prefix(targetCount))

        return SearchBatch(
            items: limited,
            nextOffset: limited.count,
            hasMore: sorted.count > targetCount || novelSessionCanFetchMore(session)
        )
    }

    private func prepareIllustPseudoPopularSessionIfNeeded(for key: PseudoPopularSessionKey) {
        guard illustPseudoPopularSession?.key != key else { return }
        illustPseudoPopularSession = IllustPseudoPopularSessionState(
            key: key,
            bucketStates: makePseudoPopularBucketStates(for: key)
        )
    }

    private func prepareNovelPseudoPopularSessionIfNeeded(for key: PseudoPopularSessionKey) {
        guard novelPseudoPopularSession?.key != key else { return }
        novelPseudoPopularSession = NovelPseudoPopularSessionState(
            key: key,
            bucketStates: makePseudoPopularBucketStates(for: key)
        )
    }

    private func populateIllustPseudoPopularSession(targetCount: Int, sessionID: UUID) async throws {
        guard var session = illustPseudoPopularSession else { return }
        let desiredCount = max(1, targetCount)
        var madeProgress = true

        while session.items.count < desiredCount && madeProgress {
            try validateIllustPseudoPopularSession(sessionID)
            let previousCount = session.items.count

            if session.key.usesUsersTagBuckets {
                for index in session.bucketStates.indices {
                    try await fetchIllustBucketPages(
                        into: &session,
                        bucketIndex: index,
                        desiredCount: desiredCount,
                        sessionID: sessionID
                    )
                    if session.items.count >= desiredCount {
                        break
                    }
                }
            }

            if session.items.count < desiredCount {
                try await fetchIllustFallbackPages(
                    into: &session,
                    desiredCount: desiredCount,
                    sessionID: sessionID
                )
            }

            madeProgress = session.items.count > previousCount || illustSessionCanFetchMore(session)
            if session.items.count == previousCount {
                break
            }
        }

        try validateIllustPseudoPopularSession(sessionID)
        illustPseudoPopularSession = session
    }

    private func populateNovelPseudoPopularSession(targetCount: Int, sessionID: UUID) async throws {
        guard var session = novelPseudoPopularSession else { return }
        let desiredCount = max(1, targetCount)
        var madeProgress = true

        while session.items.count < desiredCount && madeProgress {
            try validateNovelPseudoPopularSession(sessionID)
            let previousCount = session.items.count

            if session.key.usesUsersTagBuckets {
                for index in session.bucketStates.indices {
                    try await fetchNovelBucketPages(
                        into: &session,
                        bucketIndex: index,
                        desiredCount: desiredCount,
                        sessionID: sessionID
                    )
                    if session.items.count >= desiredCount {
                        break
                    }
                }
            }

            if session.items.count < desiredCount {
                try await fetchNovelFallbackPages(
                    into: &session,
                    desiredCount: desiredCount,
                    sessionID: sessionID
                )
            }

            madeProgress = session.items.count > previousCount || novelSessionCanFetchMore(session)
            if session.items.count == previousCount {
                break
            }
        }

        try validateNovelPseudoPopularSession(sessionID)
        novelPseudoPopularSession = session
    }

    private func fetchIllustBucketPages(
        into session: inout IllustPseudoPopularSessionState,
        bucketIndex: Int,
        desiredCount: Int,
        sessionID: UUID
    ) async throws {
        guard session.key.usesUsersTagBuckets else { return }

        var bucketState = session.bucketStates[bucketIndex]

        for queryIndex in bucketState.queryStates.indices {
            while session.items.count < desiredCount {
                let queryState = bucketState.queryStates[queryIndex]
                guard !queryState.isExhausted,
                      queryState.fetchedPageCount < session.allowedPagesPerSource else {
                    break
                }
                try validateIllustPseudoPopularSession(sessionID)

                let page = try await api.searchIllusts(
                    word: queryState.query.word,
                    searchTarget: queryState.query.searchTarget.rawValue,
                    sort: SearchSortOption.dateDesc.rawValue,
                    searchAIType: searchAITypeParameter(for: session.key.showsAIGenerated),
                    startDate: parseDateKey(session.key.startDate),
                    endDate: parseDateKey(session.key.endDate),
                    offset: queryState.nextOffset,
                    limit: illustLimit
                )
                try validateIllustPseudoPopularSession(sessionID)

                let filteredPage = page.filter { $0.totalBookmarks >= bucketState.threshold.rawValue }
                session.items = mergeUniqueResults(session.items, with: filteredPage)
                bucketState.queryStates[queryIndex].fetchedPageCount += 1

                if page.count < illustLimit {
                    bucketState.queryStates[queryIndex].isExhausted = true
                } else {
                    bucketState.queryStates[queryIndex].nextOffset += page.count
                }

                await Task.yield()
            }

            if session.items.count >= desiredCount {
                break
            }
        }

        session.bucketStates[bucketIndex] = bucketState
    }

    private func fetchNovelBucketPages(
        into session: inout NovelPseudoPopularSessionState,
        bucketIndex: Int,
        desiredCount: Int,
        sessionID: UUID
    ) async throws {
        guard session.key.usesUsersTagBuckets else { return }

        var bucketState = session.bucketStates[bucketIndex]

        for queryIndex in bucketState.queryStates.indices {
            while session.items.count < desiredCount {
                let queryState = bucketState.queryStates[queryIndex]
                guard !queryState.isExhausted,
                      queryState.fetchedPageCount < session.allowedPagesPerSource else {
                    break
                }
                try validateNovelPseudoPopularSession(sessionID)

                let page = try await api.searchNovels(
                    word: queryState.query.word,
                    searchTarget: queryState.query.searchTarget.rawValue,
                    sort: SearchSortOption.dateDesc.rawValue,
                    searchAIType: searchAITypeParameter(for: session.key.showsAIGenerated),
                    startDate: parseDateKey(session.key.startDate),
                    endDate: parseDateKey(session.key.endDate),
                    offset: queryState.nextOffset,
                    limit: novelLimit
                )
                try validateNovelPseudoPopularSession(sessionID)

                let filteredPage = page.filter { $0.totalBookmarks >= bucketState.threshold.rawValue }
                session.items = mergeUniqueResults(session.items, with: filteredPage)
                bucketState.queryStates[queryIndex].fetchedPageCount += 1

                if page.count < novelLimit {
                    bucketState.queryStates[queryIndex].isExhausted = true
                } else {
                    bucketState.queryStates[queryIndex].nextOffset += page.count
                }

                await Task.yield()
            }

            if session.items.count >= desiredCount {
                break
            }
        }

        session.bucketStates[bucketIndex] = bucketState
    }

    private func fetchIllustFallbackPages(
        into session: inout IllustPseudoPopularSessionState,
        desiredCount: Int,
        sessionID: UUID
    ) async throws {
        while session.items.count < desiredCount {
            guard !session.fallbackState.isExhausted,
                  session.fallbackState.fetchedPageCount < session.allowedPagesPerSource else {
                break
            }
            try validateIllustPseudoPopularSession(sessionID)

            let page = try await api.searchIllusts(
                word: session.key.word,
                searchTarget: session.key.searchTarget.rawValue,
                sort: SearchSortOption.dateDesc.rawValue,
                searchAIType: searchAITypeParameter(for: session.key.showsAIGenerated),
                startDate: parseDateKey(session.key.startDate),
                endDate: parseDateKey(session.key.endDate),
                offset: session.fallbackState.nextOffset,
                limit: illustLimit
            )
            try validateIllustPseudoPopularSession(sessionID)

            let filteredPage = session.key.minimumBookmarkCount > 0
                ? page.filter { $0.totalBookmarks >= session.key.minimumBookmarkCount }
                : page
            session.items = mergeUniqueResults(session.items, with: filteredPage)
            session.fallbackState.fetchedPageCount += 1

            if page.count < illustLimit {
                session.fallbackState.isExhausted = true
            } else {
                session.fallbackState.nextOffset += page.count
            }

            await Task.yield()
        }
    }

    private func fetchNovelFallbackPages(
        into session: inout NovelPseudoPopularSessionState,
        desiredCount: Int,
        sessionID: UUID
    ) async throws {
        while session.items.count < desiredCount {
            guard !session.fallbackState.isExhausted,
                  session.fallbackState.fetchedPageCount < session.allowedPagesPerSource else {
                break
            }
            try validateNovelPseudoPopularSession(sessionID)

            let page = try await api.searchNovels(
                word: session.key.word,
                searchTarget: session.key.searchTarget.rawValue,
                sort: SearchSortOption.dateDesc.rawValue,
                searchAIType: searchAITypeParameter(for: session.key.showsAIGenerated),
                startDate: parseDateKey(session.key.startDate),
                endDate: parseDateKey(session.key.endDate),
                offset: session.fallbackState.nextOffset,
                limit: novelLimit
            )
            try validateNovelPseudoPopularSession(sessionID)

            let filteredPage = session.key.minimumBookmarkCount > 0
                ? page.filter { $0.totalBookmarks >= session.key.minimumBookmarkCount }
                : page
            session.items = mergeUniqueResults(session.items, with: filteredPage)
            session.fallbackState.fetchedPageCount += 1

            if page.count < novelLimit {
                session.fallbackState.isExhausted = true
            } else {
                session.fallbackState.nextOffset += page.count
            }

            await Task.yield()
        }
    }

    private func makePseudoPopularBucketStates(for key: PseudoPopularSessionKey) -> [PseudoPopularBucketState] {
        guard key.usesUsersTagBuckets else { return [] }

        return pseudoPopularThresholds(minimumFilter: key.bookmarkFilter).map { threshold in
            PseudoPopularBucketState(
                threshold: threshold,
                queryStates: pseudoPopularQueries(
                    for: key.word,
                    threshold: threshold,
                    searchTarget: key.searchTarget
                ).map { PseudoPopularQueryState(query: $0) }
            )
        }
    }

    private func pseudoPopularThresholds(minimumFilter: BookmarkFilterOption) -> [BookmarkFilterOption] {
        BookmarkFilterOption.allCases
            .filter { $0 != .none && $0.rawValue >= minimumFilter.rawValue }
            .sorted { $0.rawValue > $1.rawValue }
    }

    private func pseudoPopularQueries(
        for word: String,
        threshold: BookmarkFilterOption,
        searchTarget: SearchTargetOption
    ) -> [PseudoPopularQuery] {
        let trimmedWord = normalizeSearchWord(word)
        guard !trimmedWord.isEmpty else { return [] }

        let spacedTarget: SearchTargetOption = searchTarget == .exactMatchForTags ? .exactMatchForTags : .partialMatchForTags
        var queries: [PseudoPopularQuery] = [
            PseudoPopularQuery(
                word: "\(trimmedWord) \(threshold.rawValue)users入り",
                searchTarget: spacedTarget
            )
        ]

        if !trimmedWord.contains(where: \.isWhitespace) {
            queries.insert(
                PseudoPopularQuery(
                    word: "\(trimmedWord)\(threshold.rawValue)users入り",
                    searchTarget: .exactMatchForTags
                ),
                at: 0
            )
        }

        var deduplicated: [PseudoPopularQuery] = []
        var seen = Set<PseudoPopularQuery>()
        for query in queries where seen.insert(query).inserted {
            deduplicated.append(query)
        }
        return deduplicated
    }

    private func makeSearchRequestSignature(
        word: String,
        sort: String,
        preferLocalPopularSort: Bool,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        startDate: Date?,
        endDate: Date?
    ) -> SearchRequestSignature {
        SearchRequestSignature(
            word: normalizeSearchWord(word),
            sort: sort,
            preferLocalPopularSort: preferLocalPopularSort,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: bookmarkFilter,
            searchTarget: searchTarget,
            startDate: dateKey(for: startDate),
            endDate: dateKey(for: endDate)
        )
    }

    private func makePseudoPopularSessionKey(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        usesUsersTagBuckets: Bool
    ) -> PseudoPopularSessionKey {
        PseudoPopularSessionKey(
            word: normalizeSearchWord(word),
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: bookmarkFilter,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: dateKey(for: startDate),
            endDate: dateKey(for: endDate),
            usesUsersTagBuckets: usesUsersTagBuckets
        )
    }

    private func normalizeSearchWord(_ word: String) -> String {
        word
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func effectivePseudoPopularMinimumBookmarkCount(
        for bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption
    ) -> Int {
        let implicitMinimum = searchTarget == .titleAndCaption
            ? pseudoPopularTitleAndCaptionMinimumBookmarkCount
            : pseudoPopularImplicitMinimumBookmarkCount
        return max(bookmarkFilter.rawValue, implicitMinimum)
    }

    private func initialPseudoPopularTargetCount(existingCount: Int, limit: Int) -> Int {
        let baseline = existingCount > 0
            ? pseudoPopularFastEntryTargetCount
            : pseudoPopularColdStartTargetCount
        return min(limit, max(existingCount, baseline))
    }

    private func existingIllustPseudoPopularItemCount(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        usesUsersTagBuckets: Bool
    ) -> Int {
        let key = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: usesUsersTagBuckets ? bookmarkFilter : .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: usesUsersTagBuckets
        )
        guard illustPseudoPopularSession?.key == key else { return 0 }
        return illustPseudoPopularSession?.items.count ?? 0
    }

    private func existingNovelPseudoPopularItemCount(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        usesUsersTagBuckets: Bool
    ) -> Int {
        let key = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: usesUsersTagBuckets ? bookmarkFilter : .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: usesUsersTagBuckets
        )
        guard novelPseudoPopularSession?.key == key else { return 0 }
        return novelPseudoPopularSession?.items.count ?? 0
    }

    private func searchAITypeParameter(for showsAIGenerated: Bool) -> Int {
        showsAIGenerated ? 0 : 1
    }

    private func dateKey(for date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    private func parseDateKey(_ key: String?) -> Date? {
        guard let key else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key)
    }

    private func cancelIllustPseudoPopularEnrichment() {
        illustPseudoPopularEnrichmentTask?.cancel()
        illustPseudoPopularEnrichmentTask = nil
    }

    private func cancelNovelPseudoPopularEnrichment() {
        novelPseudoPopularEnrichmentTask?.cancel()
        novelPseudoPopularEnrichmentTask = nil
    }

    private func cancelIllustPseudoPopularPreload() {
        illustPseudoPopularPreloadTask?.cancel()
        illustPseudoPopularPreloadTask = nil
    }

    private func cancelNovelPseudoPopularPreload() {
        novelPseudoPopularPreloadTask?.cancel()
        novelPseudoPopularPreloadTask = nil
    }

    private func cancelSupplementalSearch() {
        supplementalSearchTask?.cancel()
        supplementalSearchTask = nil
    }

    private func adoptSearchEntryPseudoPopularPreloadIfAvailable(
        token: UUID?,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        usesUsersTagBuckets: Bool
    ) async {
        guard let token, Self.searchEntryPreloadToken == token else { return }

        let key = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: usesUsersTagBuckets ? bookmarkFilter : .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: usesUsersTagBuckets
        )

        if absorbSearchEntryPseudoPopularSessionIfAvailable(for: key) {
            return
        }

        guard let preloadTask = Self.searchEntryPreloadTask else { return }
        let finishedInTime = await Self.waitForSearchEntryPreloadTask(
            preloadTask,
            timeoutMilliseconds: pseudoPopularSearchEntryAwaitMilliseconds
        )
        guard finishedInTime, Self.searchEntryPreloadToken == token else { return }

        _ = absorbSearchEntryPseudoPopularSessionIfAvailable(for: key)
    }

    private func absorbSearchEntryPseudoPopularSessionIfAvailable(for key: PseudoPopularSessionKey) -> Bool {
        guard Self.searchEntryPreheater.illustPseudoPopularSession?.key == key,
              let session = Self.searchEntryPreheater.illustPseudoPopularSession,
              !session.items.isEmpty else {
            return false
        }

        illustPseudoPopularSession = session
        return true
    }

    private func seedIllustPseudoPopularSessionFromRegularResults(
        items: [Illusts],
        sourceSort: String,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?
    ) {
        guard !items.isEmpty else { return }

        let usesUsersTagBuckets = searchTarget != .titleAndCaption
        let sessionKey = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: usesUsersTagBuckets ? bookmarkFilter : .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: usesUsersTagBuckets
        )
        prepareIllustPseudoPopularSessionIfNeeded(for: sessionKey)

        guard var session = illustPseudoPopularSession else { return }
        let filteredItems = minimumBookmarkCount > 0
            ? items.filter { $0.totalBookmarks >= minimumBookmarkCount }
            : items
        session.items = mergeUniqueResults(session.items, with: filteredItems)
        if sourceSort == SearchSortOption.dateDesc.rawValue && bookmarkFilter == .none {
            session.fallbackState.fetchedPageCount = max(session.fallbackState.fetchedPageCount, 1)
            session.fallbackState.nextOffset = max(session.fallbackState.nextOffset, items.count)
            session.fallbackState.isExhausted = session.fallbackState.isExhausted || items.count < illustLimit
        }
        illustPseudoPopularSession = session
    }

    private func seedNovelPseudoPopularSessionFromRegularResults(
        items: [Novel],
        sourceSort: String,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?
    ) {
        guard !items.isEmpty else { return }

        let usesUsersTagBuckets = searchTarget != .titleAndCaption
        let sessionKey = makePseudoPopularSessionKey(
            word: word,
            showsAIGenerated: showsAIGenerated,
            bookmarkFilter: usesUsersTagBuckets ? bookmarkFilter : .none,
            searchTarget: searchTarget,
            minimumBookmarkCount: minimumBookmarkCount,
            startDate: startDate,
            endDate: endDate,
            usesUsersTagBuckets: usesUsersTagBuckets
        )
        prepareNovelPseudoPopularSessionIfNeeded(for: sessionKey)

        guard var session = novelPseudoPopularSession else { return }
        let filteredItems = minimumBookmarkCount > 0
            ? items.filter { $0.totalBookmarks >= minimumBookmarkCount }
            : items
        session.items = mergeUniqueResults(session.items, with: filteredItems)
        if sourceSort == SearchSortOption.dateDesc.rawValue && bookmarkFilter == .none {
            session.fallbackState.fetchedPageCount = max(session.fallbackState.fetchedPageCount, 1)
            session.fallbackState.nextOffset = max(session.fallbackState.nextOffset, items.count)
            session.fallbackState.isExhausted = session.fallbackState.isExhausted || items.count < novelLimit
        }
        novelPseudoPopularSession = session
    }

    private func validateIllustPseudoPopularSession(_ sessionID: UUID) throws {
        guard !Task.isCancelled, sessionID == illustPseudoPopularSessionID else {
            throw CancellationError()
        }
    }

    private func validateNovelPseudoPopularSession(_ sessionID: UUID) throws {
        guard !Task.isCancelled, sessionID == novelPseudoPopularSessionID else {
            throw CancellationError()
        }
    }

    private func scheduleSupplementalSearch(
        sessionID: UUID,
        context: SearchExecutionContext,
        prefetchNovelSignature: SearchRequestSignature
    ) {
        cancelSupplementalSearch()
        supplementalSearchTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                let fetchedNovels = try await self.fetchNovelResults(
                    context: context,
                    targetCount: self.novelLimit,
                    samplePageCount: self.pseudoPopularInitialSamplePageCount,
                    updatePseudoPopularState: true
                )
                let fetchedUsers = try await self.api.getSearchUser(word: context.word, offset: 0)

                guard !Task.isCancelled, sessionID == self.activeSearchSessionID else { return }
                guard self.novelSearchSignature == nil || self.novelSearchSignature == prefetchNovelSignature else { return }

                self.novelResults = fetchedNovels
                self.userResults = fetchedUsers
                self.userOffset = fetchedUsers.count
                self.userHasMore = !fetchedUsers.isEmpty
                self.novelSearchSignature = prefetchNovelSignature
            } catch is CancellationError {
            } catch {
                print("Failed to complete supplemental search preload: \(error)")
            }
        }
    }

    private func scheduleIllustPseudoPopularPreload(
        searchSessionID: UUID,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?
    ) {
        guard !word.isEmpty else { return }

        let usesUsersTagPseudoPopularSort = searchTarget != .titleAndCaption
        cancelIllustPseudoPopularPreload()
        illustPseudoPopularPreloadTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .milliseconds(self.pseudoPopularPreloadWarmupDelayMilliseconds))
                guard !Task.isCancelled, searchSessionID == self.activeSearchSessionID else { return }

                try await self.preloadIllustPseudoPopularSession(
                    word: word,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: minimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: self.pseudoPopularFastEntryTargetCount,
                    samplePageCount: self.pseudoPopularInitialSamplePageCount,
                    usesUsersTagPseudoPopularSort: usesUsersTagPseudoPopularSort
                )

                try await Task.sleep(for: .milliseconds(self.pseudoPopularDeferredPreloadDelayMilliseconds))
                guard !Task.isCancelled, searchSessionID == self.activeSearchSessionID else { return }

                try await self.preloadIllustPseudoPopularSession(
                    word: word,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: minimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: self.illustLimit,
                    samplePageCount: self.pseudoPopularBackgroundSamplePageCount,
                    usesUsersTagPseudoPopularSort: usesUsersTagPseudoPopularSort
                )
            } catch is CancellationError {
            } catch {
                print("Failed to preload pseudo-popular illusts: \(error)")
            }
        }
    }

    private func scheduleNovelPseudoPopularPreload(
        searchSessionID: UUID,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?
    ) {
        guard !word.isEmpty else { return }

        let usesUsersTagPseudoPopularSort = searchTarget != .titleAndCaption
        cancelNovelPseudoPopularPreload()
        novelPseudoPopularPreloadTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: .milliseconds(self.pseudoPopularPreloadWarmupDelayMilliseconds))
                guard !Task.isCancelled, searchSessionID == self.activeSearchSessionID else { return }

                try await self.preloadNovelPseudoPopularSession(
                    word: word,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: minimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: self.pseudoPopularFastEntryTargetCount,
                    samplePageCount: self.pseudoPopularInitialSamplePageCount,
                    usesUsersTagPseudoPopularSort: usesUsersTagPseudoPopularSort
                )

                try await Task.sleep(for: .milliseconds(self.pseudoPopularDeferredPreloadDelayMilliseconds))
                guard !Task.isCancelled, searchSessionID == self.activeSearchSessionID else { return }

                try await self.preloadNovelPseudoPopularSession(
                    word: word,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: bookmarkFilter,
                    searchTarget: searchTarget,
                    minimumBookmarkCount: minimumBookmarkCount,
                    startDate: startDate,
                    endDate: endDate,
                    targetCount: self.novelLimit,
                    samplePageCount: self.pseudoPopularBackgroundSamplePageCount,
                    usesUsersTagPseudoPopularSort: usesUsersTagPseudoPopularSort
                )
            } catch is CancellationError {
            } catch {
                print("Failed to preload pseudo-popular novels: \(error)")
            }
        }
    }

    private func preloadIllustPseudoPopularSession(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        targetCount: Int,
        samplePageCount: Int,
        usesUsersTagPseudoPopularSort: Bool
    ) async throws {
        if usesUsersTagPseudoPopularSort {
            _ = try await searchIllustsByPseudoPopularTags(
                word: word,
                showsAIGenerated: showsAIGenerated,
                bookmarkFilter: bookmarkFilter,
                searchTarget: searchTarget,
                minimumBookmarkCount: minimumBookmarkCount,
                startDate: startDate,
                endDate: endDate,
                targetCount: targetCount,
                samplePageCount: samplePageCount
            )
        } else {
            _ = try await searchIllustsByBookmarkCount(
                word: word,
                showsAIGenerated: showsAIGenerated,
                searchTarget: searchTarget,
                startDate: startDate,
                endDate: endDate,
                targetCount: targetCount,
                minimumBookmarkCount: minimumBookmarkCount,
                samplePageCount: samplePageCount
            )
        }
    }

    private func preloadNovelPseudoPopularSession(
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?,
        targetCount: Int,
        samplePageCount: Int,
        usesUsersTagPseudoPopularSort: Bool
    ) async throws {
        if usesUsersTagPseudoPopularSort {
            _ = try await searchNovelsByPseudoPopularTags(
                word: word,
                showsAIGenerated: showsAIGenerated,
                bookmarkFilter: bookmarkFilter,
                searchTarget: searchTarget,
                minimumBookmarkCount: minimumBookmarkCount,
                startDate: startDate,
                endDate: endDate,
                targetCount: targetCount,
                samplePageCount: samplePageCount
            )
        } else {
            _ = try await searchNovelsByBookmarkCount(
                word: word,
                showsAIGenerated: showsAIGenerated,
                searchTarget: searchTarget,
                startDate: startDate,
                endDate: endDate,
                targetCount: targetCount,
                minimumBookmarkCount: minimumBookmarkCount,
                samplePageCount: samplePageCount
            )
        }
    }

    static func scheduleSearchEntryPseudoPopularPreload(
        word: String,
        token: UUID,
        isPremium: Bool,
        defaultSort: SearchSortOption,
        showsAIGenerated: Bool = true
    ) {
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedWord.isEmpty, !isPremium, defaultSort == .popularDesc else { return }

        searchEntryPreloadToken = token
        searchEntryPreloadTask?.cancel()
        searchEntryPreloadTask = Task(priority: .utility) { @MainActor in
            do {
                let preheater = Self.searchEntryPreheater
                let minimumBookmarkCount = preheater.effectivePseudoPopularMinimumBookmarkCount(
                    for: .none,
                    searchTarget: .partialMatchForTags
                )
                let key = preheater.makePseudoPopularSessionKey(
                    word: normalizedWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: .none,
                    searchTarget: .partialMatchForTags,
                    minimumBookmarkCount: minimumBookmarkCount,
                    startDate: nil,
                    endDate: nil,
                    usesUsersTagBuckets: true
                )

                if preheater.illustPseudoPopularSession?.key != key {
                    preheater.illustPseudoPopularSession = nil
                }
                preheater.illustPseudoPopularSessionID = UUID()

                _ = try await preheater.searchIllustsByPseudoPopularTags(
                    word: normalizedWord,
                    showsAIGenerated: showsAIGenerated,
                    bookmarkFilter: .none,
                    searchTarget: .partialMatchForTags,
                    minimumBookmarkCount: minimumBookmarkCount,
                    startDate: nil,
                    endDate: nil,
                    targetCount: preheater.pseudoPopularSearchEntryPreloadTargetCount,
                    samplePageCount: preheater.pseudoPopularInitialSamplePageCount
                )
            } catch is CancellationError {
            } catch {
                print("Failed to preload search entry pseudo-popular results: \(error)")
            }
        }
    }

    private static func waitForSearchEntryPreloadTask(
        _ task: Task<Void, Never>,
        timeoutMilliseconds: Int
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await task.value
                return true
            }
            group.addTask {
                try? await Task.sleep(for: .milliseconds(timeoutMilliseconds))
                return false
            }

            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
    }

    private func scheduleIllustPseudoPopularEnrichment(
        sessionID: UUID,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?
    ) {
        guard illustHasMore else { return }

        let nextTargetCount = max(illustPseudoPopularTargetCount, illustResults.count) + illustLimit
        let nextSamplePageCount = max(
            illustPseudoPopularSamplePageCount + 1,
            pseudoPopularBackgroundSamplePageCount
        )
        let usesUsersTagPseudoPopularSort = searchTarget != .titleAndCaption

        cancelIllustPseudoPopularEnrichment()
        illustPseudoPopularEnrichmentTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                let batch: SearchBatch<Illusts>
                if usesUsersTagPseudoPopularSort {
                    batch = try await self.searchIllustsByPseudoPopularTags(
                        word: word,
                        showsAIGenerated: showsAIGenerated,
                        bookmarkFilter: bookmarkFilter,
                        searchTarget: searchTarget,
                        minimumBookmarkCount: minimumBookmarkCount,
                        startDate: startDate,
                        endDate: endDate,
                        targetCount: nextTargetCount,
                        samplePageCount: nextSamplePageCount
                    )
                } else {
                    batch = try await self.searchIllustsByBookmarkCount(
                        word: word,
                        showsAIGenerated: showsAIGenerated,
                        searchTarget: searchTarget,
                        startDate: startDate,
                        endDate: endDate,
                        targetCount: nextTargetCount,
                        minimumBookmarkCount: minimumBookmarkCount,
                        samplePageCount: nextSamplePageCount
                    )
                }

                guard !Task.isCancelled, sessionID == self.illustPseudoPopularSessionID else { return }

                self.illustResults = appendNewResultsPreservingOrder(
                    existing: self.illustResults,
                    fetched: batch.items
                )
                self.illustPseudoPopularTargetCount = nextTargetCount
                self.illustPseudoPopularSamplePageCount = nextSamplePageCount
                self.illustOffset = batch.nextOffset
                self.illustHasMore = batch.hasMore
            } catch is CancellationError {
            } catch {
                print("Failed to enrich pseudo-popular illusts: \(error)")
            }
        }
    }

    private func scheduleNovelPseudoPopularEnrichment(
        sessionID: UUID,
        word: String,
        showsAIGenerated: Bool,
        bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption,
        minimumBookmarkCount: Int,
        startDate: Date?,
        endDate: Date?
    ) {
        guard novelHasMore else { return }

        let nextTargetCount = max(novelPseudoPopularTargetCount, novelResults.count) + novelLimit
        let nextSamplePageCount = max(
            novelPseudoPopularSamplePageCount + 1,
            pseudoPopularBackgroundSamplePageCount
        )
        let usesUsersTagPseudoPopularSort = searchTarget != .titleAndCaption

        cancelNovelPseudoPopularEnrichment()
        novelPseudoPopularEnrichmentTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }

            do {
                let batch: SearchBatch<Novel>
                if usesUsersTagPseudoPopularSort {
                    batch = try await self.searchNovelsByPseudoPopularTags(
                        word: word,
                        showsAIGenerated: showsAIGenerated,
                        bookmarkFilter: bookmarkFilter,
                        searchTarget: searchTarget,
                        minimumBookmarkCount: minimumBookmarkCount,
                        startDate: startDate,
                        endDate: endDate,
                        targetCount: nextTargetCount,
                        samplePageCount: nextSamplePageCount
                    )
                } else {
                    batch = try await self.searchNovelsByBookmarkCount(
                        word: word,
                        showsAIGenerated: showsAIGenerated,
                        searchTarget: searchTarget,
                        startDate: startDate,
                        endDate: endDate,
                        targetCount: nextTargetCount,
                        minimumBookmarkCount: minimumBookmarkCount,
                        samplePageCount: nextSamplePageCount
                    )
                }

                guard !Task.isCancelled, sessionID == self.novelPseudoPopularSessionID else { return }

                self.novelResults = appendNewResultsPreservingOrder(
                    existing: self.novelResults,
                    fetched: batch.items
                )
                self.novelPseudoPopularTargetCount = nextTargetCount
                self.novelPseudoPopularSamplePageCount = nextSamplePageCount
                self.novelOffset = batch.nextOffset
                self.novelHasMore = batch.hasMore
            } catch is CancellationError {
            } catch {
                print("Failed to enrich pseudo-popular novels: \(error)")
            }
        }
    }

    private func illustSessionCanFetchMore(_ session: IllustPseudoPopularSessionState) -> Bool {
        if session.key.usesUsersTagBuckets {
            for bucketState in session.bucketStates where bucketState.queryStates.contains(where: { !$0.isExhausted }) {
                return true
            }
        }

        return !session.fallbackState.isExhausted
    }

    private func novelSessionCanFetchMore(_ session: NovelPseudoPopularSessionState) -> Bool {
        if session.key.usesUsersTagBuckets {
            for bucketState in session.bucketStates where bucketState.queryStates.contains(where: { !$0.isExhausted }) {
                return true
            }
        }

        return !session.fallbackState.isExhausted
    }

    private func appendNewResultsPreservingOrder<Item: BookmarkSortableSearchResult>(
        existing: [Item],
        fetched: [Item]
    ) -> [Item] {
        var combined = existing
        var existingIds = Set(existing.map(\.id))

        for item in fetched where !existingIds.contains(item.id) {
            combined.append(item)
            existingIds.insert(item.id)
        }

        return combined
    }

    private func mergeUniqueResults<Item: BookmarkSortableSearchResult>(
        _ existing: [Item],
        with incoming: [Item]
    ) -> [Item] {
        var merged = existing
        var existingIds = Set(existing.map(\.id))

        for item in incoming where !existingIds.contains(item.id) {
            merged.append(item)
            existingIds.insert(item.id)
        }

        return merged
    }

    private func sortResultsByBookmarkCount<Item: BookmarkSortableSearchResult>(_ items: [Item]) -> [Item] {
        items.sorted { lhs, rhs in
            if lhs.totalBookmarks == rhs.totalBookmarks {
                return lhs.createDate > rhs.createDate
            }
            return lhs.totalBookmarks > rhs.totalBookmarks
        }
    }
}
// swiftlint:enable file_length
