import SwiftUI
import Observation
import os.log

protocol BookmarkSortableSearchResult {
    var id: Int { get }
    var totalBookmarks: Int { get }
    var createDate: String { get }
}

extension Illusts: BookmarkSortableSearchResult {}
extension Novel: BookmarkSortableSearchResult {}

@MainActor
@Observable
final class SearchResultStore {
    struct SearchBatch<T> {
        let items: [T]
        let nextOffset: Int
        let hasMore: Bool
    }

    struct SearchRequestSignature: Equatable {
        let word: String
        let sort: String
        let preferLocalPopularSort: Bool
        let showsAIGenerated: Bool
        let bookmarkFilter: BookmarkFilterOption
        let searchTarget: SearchTargetOption
        let startDate: String?
        let endDate: String?
    }

    struct SearchExecutionContext {
        let word: String
        let sort: String
        let preferLocalPopularSort: Bool
        let showsAIGenerated: Bool
        let bookmarkFilter: BookmarkFilterOption
        let searchTarget: SearchTargetOption
        let startDate: Date?
        let endDate: Date?
    }

    var illustResults: [Illusts] = []
    var userResults: [UserPreviews] = []
    var novelResults: [Novel] = []

    var isLoading: Bool = false
    var error: AppError?
    @ObservationIgnored private var illustNextURL: String?
    @ObservationIgnored private var novelNextURL: String?

    // 分页状态
    var illustOffset: Int = 0
    var illustLimit: Int = 30
    var illustHasMore: Bool = false
    var isLoadingMoreIllusts: Bool = false
    var illustLoadMoreError: AppError?

    var userOffset: Int = 0
    var userHasMore: Bool = false
    var isLoadingMoreUsers: Bool = false

    var novelOffset: Int = 0
    var novelLimit: Int = 30
    var novelHasMore: Bool = false
    var isLoadingMoreNovels: Bool = false
    var novelLoadMoreError: AppError?

    @ObservationIgnored let api = PixivAPI.shared
    @ObservationIgnored let pseudoPopularInitialSamplePageCount = 1
    @ObservationIgnored let pseudoPopularBackgroundSamplePageCount = 3
    @ObservationIgnored let pseudoPopularColdStartTargetCount = 8
    @ObservationIgnored let pseudoPopularSearchEntryPreloadTargetCount = 6
    @ObservationIgnored let pseudoPopularFastEntryTargetCount = 12
    @ObservationIgnored let pseudoPopularPreloadWarmupDelayMilliseconds = 250
    @ObservationIgnored let pseudoPopularDeferredPreloadDelayMilliseconds = 1200
    @ObservationIgnored let pseudoPopularSearchEntryAwaitMilliseconds = 120
    @ObservationIgnored let pseudoPopularImplicitMinimumBookmarkCount = BookmarkFilterOption.users100.rawValue
    @ObservationIgnored let pseudoPopularTitleAndCaptionMinimumBookmarkCount = BookmarkFilterOption.users250.rawValue
    @ObservationIgnored var illustPseudoPopularTargetCount: Int = 0
    @ObservationIgnored var novelPseudoPopularTargetCount: Int = 0
    @ObservationIgnored var illustPseudoPopularSamplePageCount: Int = 0
    @ObservationIgnored var novelPseudoPopularSamplePageCount: Int = 0
    @ObservationIgnored var illustPseudoPopularSessionID = UUID()
    @ObservationIgnored var novelPseudoPopularSessionID = UUID()
    @ObservationIgnored var illustPseudoPopularEnrichmentTask: Task<Void, Never>?
    @ObservationIgnored var novelPseudoPopularEnrichmentTask: Task<Void, Never>?
    @ObservationIgnored var illustPseudoPopularPreloadTask: Task<Void, Never>?
    @ObservationIgnored var novelPseudoPopularPreloadTask: Task<Void, Never>?
    @ObservationIgnored var supplementalSearchTask: Task<Void, Never>?
    @ObservationIgnored var illustPseudoPopularSession: IllustPseudoPopularSessionState?
    @ObservationIgnored var novelPseudoPopularSession: NovelPseudoPopularSessionState?
    @ObservationIgnored var novelSearchSignature: SearchRequestSignature?
    @ObservationIgnored var activeSearchSessionID = UUID()
    static let searchEntryPreheater = SearchResultStore()
    static var searchEntryPreloadToken: UUID?
    static var searchEntryPreloadTask: Task<Void, Never>?

    private func isActiveSearchSession(_ sessionID: UUID) -> Bool {
        !Task.isCancelled && activeSearchSessionID == sessionID
    }

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
        let searchSessionID = UUID()
        self.activeSearchSessionID = searchSessionID
        self.isLoading = true
        error = nil
        SearchStore.shared.addHistory(word)

        defer {
            if isActiveSearchSession(searchSessionID) {
                isLoading = false
            }
        }

        self.illustOffset = 0
        self.userOffset = 0
        self.novelOffset = 0
        self.illustNextURL = nil
        self.novelNextURL = nil
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
            guard isActiveSearchSession(searchSessionID) else { return }
        }
        let finalWord = baseWord + bookmarkFilter.suffix
        let illustSessionID = illustPseudoPopularSessionID
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
                let response = try await api.searchAPI.searchIllustsPage(
                    word: finalWord,
                    searchTarget: searchTarget.rawValue,
                    sort: sort,
                    searchAIType: searchAITypeParameter(for: showsAIGenerated),
                    startDate: startDate,
                    endDate: endDate,
                    offset: 0,
                    limit: illustLimit
                )
                fetchedIllusts = response.illusts
                self.illustNextURL = response.nextUrl
                self.illustOffset = nextOffset(from: response.nextUrl) ?? fetchedIllusts.count
                self.illustHasMore = response.nextUrl != nil
            }

            guard isActiveSearchSession(searchSessionID) else { return }
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

            let fetchedUsers = try await api.searchAPI.getSearchUser(word: word, offset: 0)

            guard isActiveSearchSession(searchSessionID) else { return }
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
            guard isActiveSearchSession(searchSessionID) else { return }
            self.error = AppError.unknown(error)
        }
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
        let searchSessionID = activeSearchSessionID
        guard isActiveSearchSession(searchSessionID), !isLoading, !isLoadingMoreIllusts, illustHasMore else { return }
        isLoadingMoreIllusts = true
        illustLoadMoreError = nil
        defer {
            if activeSearchSessionID == searchSessionID {
                isLoadingMoreIllusts = false
            }
        }
        let baseWord = normalizeSearchWord(word)
        let usesPseudoPopularSort = preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: bookmarkFilter,
            searchTarget: searchTarget
        )
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
                guard isActiveSearchSession(searchSessionID) else { return }
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
                guard isActiveSearchSession(searchSessionID) else { return }
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
                guard let nextURL = self.illustNextURL else {
                    self.illustHasMore = false
                    return
                }
                let response: IllustsResponseDTO = try await api.fetchNext(urlString: nextURL)
                guard isActiveSearchSession(searchSessionID) else { return }
                self.illustResults = mergeUniqueResults(self.illustResults, with: response.illusts.map { $0.toDomain() })
                self.illustNextURL = response.nextUrl
                self.illustOffset = nextOffset(from: response.nextUrl) ?? self.illustResults.count
                self.illustHasMore = response.nextUrl != nil
            }
        } catch {
            guard isActiveSearchSession(searchSessionID) else { return }
            Logger.search.error("Failed to load more illusts: \(error.localizedDescription, privacy: .public)")
            illustLoadMoreError = AppError.unknown(error)
        }
    }

    /// 加载更多用户
    func loadMoreUsers(word: String) async {
        let searchSessionID = activeSearchSessionID
        guard isActiveSearchSession(searchSessionID), !isLoading, !isLoadingMoreUsers, userHasMore else { return }
        isLoadingMoreUsers = true
        defer {
            if activeSearchSessionID == searchSessionID {
                isLoadingMoreUsers = false
            }
        }
        do {
            let more = try await api.searchAPI.getSearchUser(word: word, offset: self.userOffset)
            guard isActiveSearchSession(searchSessionID) else { return }
            self.userResults += more
            self.userOffset += more.count
            self.userHasMore = !more.isEmpty
        } catch {
            guard isActiveSearchSession(searchSessionID) else { return }
            Logger.search.error("Failed to load more users: \(error.localizedDescription, privacy: .public)")
        }
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

        guard isActiveSearchSession(searchSessionID), !isLoading else { return }
        isLoading = true
        error = nil
        novelLoadMoreError = nil
        novelOffset = 0
        novelNextURL = nil
        novelHasMore = false
        self.novelPseudoPopularTargetCount = 0
        self.novelPseudoPopularSamplePageCount = 0
        self.novelPseudoPopularSessionID = UUID()
        cancelNovelPseudoPopularEnrichment()
        cancelNovelPseudoPopularPreload()

        defer {
            if isActiveSearchSession(searchSessionID) {
                isLoading = false
            }
        }

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
            guard isActiveSearchSession(searchSessionID) else { return }
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
            guard isActiveSearchSession(searchSessionID) else { return }
            self.error = AppError.unknown(error)
        }
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
        let searchSessionID = activeSearchSessionID
        guard isActiveSearchSession(searchSessionID), !isLoading, !isLoadingMoreNovels, novelHasMore else { return }
        isLoadingMoreNovels = true
        novelLoadMoreError = nil
        defer {
            if activeSearchSessionID == searchSessionID {
                isLoadingMoreNovels = false
            }
        }
        let baseWord = normalizeSearchWord(word)
        let usesPseudoPopularSort = preferLocalPopularSort && sort == SearchSortOption.popularDesc.rawValue
        let usesUsersTagPseudoPopularSort = usesPseudoPopularSort && searchTarget != .titleAndCaption
        let pseudoPopularMinimumBookmarkCount = effectivePseudoPopularMinimumBookmarkCount(
            for: bookmarkFilter,
            searchTarget: searchTarget
        )
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
                guard isActiveSearchSession(searchSessionID) else { return }
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
                guard isActiveSearchSession(searchSessionID) else { return }
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
                guard let nextURL = self.novelNextURL else {
                    self.novelHasMore = false
                    return
                }
                let response: NovelResponse = try await api.fetchNext(urlString: nextURL)
                guard isActiveSearchSession(searchSessionID) else { return }
                self.novelResults = mergeUniqueResults(self.novelResults, with: response.novels)
                self.novelNextURL = response.nextUrl
                self.novelOffset = nextOffset(from: response.nextUrl) ?? self.novelResults.count
                self.novelHasMore = response.nextUrl != nil
            }
        } catch {
            guard isActiveSearchSession(searchSessionID) else { return }
            Logger.search.error("Failed to load more novels: \(error.localizedDescription, privacy: .public)")
            novelLoadMoreError = AppError.unknown(error)
        }
    }

    func cancelBackgroundTasks() {
        activeSearchSessionID = UUID()
        isLoading = false
        isLoadingMoreIllusts = false
        isLoadingMoreUsers = false
        isLoadingMoreNovels = false
        illustPseudoPopularSessionID = UUID()
        novelPseudoPopularSessionID = UUID()
        cancelIllustPseudoPopularEnrichment()
        cancelNovelPseudoPopularEnrichment()
        cancelIllustPseudoPopularPreload()
        cancelNovelPseudoPopularPreload()
        cancelSupplementalSearch()
    }

    /// 取消小说搜索相关的后台任务（enrichment + preload），防止其异步修改 novelHasMore
    func cancelNovelBackgroundTasks() {
        novelPseudoPopularSessionID = UUID()
        cancelNovelPseudoPopularEnrichment()
        cancelNovelPseudoPopularPreload()
    }

    /// 取消插画搜索相关的后台任务（enrichment + preload），防止其异步修改 illustHasMore
    func cancelIllustBackgroundTasks() {
        illustPseudoPopularSessionID = UUID()
        cancelIllustPseudoPopularEnrichment()
        cancelIllustPseudoPopularPreload()
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

        let response = try await api.searchAPI.searchNovelsPage(
            word: baseWord + context.bookmarkFilter.suffix,
            searchTarget: context.searchTarget.rawValue,
            sort: context.sort,
            searchAIType: searchAITypeParameter(for: context.showsAIGenerated),
            startDate: context.startDate,
            endDate: context.endDate,
            offset: 0,
            limit: novelLimit
        )
        let fetchedNovels = response.novels

        if updatePseudoPopularState {
            self.novelNextURL = response.nextUrl
            self.novelOffset = nextOffset(from: response.nextUrl) ?? fetchedNovels.count
            self.novelHasMore = response.nextUrl != nil
        }
        return fetchedNovels
    }

    private func nextOffset(from nextURL: String?) -> Int? {
        guard
            let nextURL,
            let components = URLComponents(string: nextURL),
            let value = components.queryItems?.first(where: { $0.name == "offset" })?.value
        else {
            return nil
        }

        return Int(value)
    }

    // MARK: - Helper 方法

    func makeSearchRequestSignature(
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

    func normalizeSearchWord(_ word: String) -> String {
        word
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func effectivePseudoPopularMinimumBookmarkCount(
        for bookmarkFilter: BookmarkFilterOption,
        searchTarget: SearchTargetOption
    ) -> Int {
        let implicitMinimum = searchTarget == .titleAndCaption
            ? pseudoPopularTitleAndCaptionMinimumBookmarkCount
            : pseudoPopularImplicitMinimumBookmarkCount
        return max(bookmarkFilter.rawValue, implicitMinimum)
    }

    func initialPseudoPopularTargetCount(existingCount: Int, limit: Int) -> Int {
        let baseline = existingCount > 0
            ? pseudoPopularFastEntryTargetCount
            : pseudoPopularColdStartTargetCount
        return min(limit, max(existingCount, baseline))
    }

    func existingIllustPseudoPopularItemCount(
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

    func existingNovelPseudoPopularItemCount(
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

    func searchAITypeParameter(for showsAIGenerated: Bool) -> Int {
        showsAIGenerated ? 0 : 1
    }

    func dateKey(for date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    func parseDateKey(_ key: String?) -> Date? {
        guard let key else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: key)
    }

    func appendNewResultsPreservingOrder<Item: BookmarkSortableSearchResult>(
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

    func scheduleSupplementalSearch(
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
                let fetchedUsers = try await self.api.searchAPI.getSearchUser(word: context.word, offset: 0)

                guard !Task.isCancelled, sessionID == self.activeSearchSessionID else { return }
                guard self.novelSearchSignature == nil || self.novelSearchSignature == prefetchNovelSignature else { return }

                self.novelResults = fetchedNovels
                self.userResults = fetchedUsers
                self.userOffset = fetchedUsers.count
                self.userHasMore = !fetchedUsers.isEmpty
                self.novelSearchSignature = prefetchNovelSignature
            } catch is CancellationError {
            } catch {
                Logger.search.error("Failed to complete supplemental search preload: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
