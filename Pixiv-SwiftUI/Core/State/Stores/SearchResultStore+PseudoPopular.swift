import Foundation
import os.log

// MARK: - PseudoPopular 嵌套类型

extension SearchResultStore {
    struct PseudoPopularQuery: Hashable {
        let word: String
        let searchTarget: SearchTargetOption
    }

    struct PseudoPopularSessionKey: Equatable {
        let word: String
        let showsAIGenerated: Bool
        let bookmarkFilter: BookmarkFilterOption
        let searchTarget: SearchTargetOption
        let minimumBookmarkCount: Int
        let startDate: String?
        let endDate: String?
        let usesUsersTagBuckets: Bool
    }

    struct PseudoPopularQueryState {
        let query: PseudoPopularQuery
        var nextOffset: Int = 0
        var fetchedPageCount: Int = 0
        var isExhausted: Bool = false
    }

    struct PseudoPopularBucketState {
        let threshold: BookmarkFilterOption
        var queryStates: [PseudoPopularQueryState]
    }

    struct PseudoPopularFallbackState {
        var nextOffset: Int = 0
        var fetchedPageCount: Int = 0
        var isExhausted: Bool = false
    }

    struct IllustPseudoPopularSessionState {
        let key: PseudoPopularSessionKey
        var allowedPagesPerSource: Int = 0
        var items: [Illusts] = []
        var bucketStates: [PseudoPopularBucketState] = []
        var fallbackState = PseudoPopularFallbackState()
    }

    struct NovelPseudoPopularSessionState {
        let key: PseudoPopularSessionKey
        var allowedPagesPerSource: Int = 0
        var items: [Novel] = []
        var bucketStates: [PseudoPopularBucketState] = []
        var fallbackState = PseudoPopularFallbackState()
    }
}

// MARK: - PseudoPopular 搜索方法

extension SearchResultStore {

    // MARK: - 按收藏数搜索

    /// 首先，排除掉用户设置的收藏数过少的 tag，进行搜索
    ///
    /// 搜索逻辑为：根据收藏数阈值，生成对应的 PseudoPopularQuery，根据 query 依次搜索一定页数的插画，
    /// 收集足够目标数量的插画后，再按照收藏数排序返回。
    func searchIllustsByBookmarkCount(
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

    func searchNovelsByBookmarkCount(
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

    // MARK: - PseudoPopular Tags 搜索

    func searchIllustsByPseudoPopularTags(
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

    func searchNovelsByPseudoPopularTags(
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

    // MARK: - Session 管理

    func prepareIllustPseudoPopularSessionIfNeeded(for key: PseudoPopularSessionKey) {
        guard illustPseudoPopularSession?.key != key else { return }
        illustPseudoPopularSession = IllustPseudoPopularSessionState(
            key: key,
            bucketStates: makePseudoPopularBucketStates(for: key)
        )
    }

    func prepareNovelPseudoPopularSessionIfNeeded(for key: PseudoPopularSessionKey) {
        guard novelPseudoPopularSession?.key != key else { return }
        novelPseudoPopularSession = NovelPseudoPopularSessionState(
            key: key,
            bucketStates: makePseudoPopularBucketStates(for: key)
        )
    }

    func populateIllustPseudoPopularSession(targetCount: Int, sessionID: UUID) async throws {
        guard var session = illustPseudoPopularSession else { return }
        try validateIllustPseudoPopularSession(sessionID)
        var madeProgress = true

        while session.items.count < targetCount, madeProgress {
            let previousCount = session.items.count
            madeProgress = false

            for bucketIndex in session.bucketStates.indices {
                try validateIllustPseudoPopularSession(sessionID)
                try await fetchIllustBucketPages(
                    into: &session,
                    bucketIndex: bucketIndex,
                    desiredCount: targetCount,
                    sessionID: sessionID
                )
                if session.items.count >= targetCount {
                    break
                }
            }

            if session.items.count < targetCount {
                try await fetchIllustFallbackPages(
                    into: &session,
                    desiredCount: targetCount,
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

    func populateNovelPseudoPopularSession(targetCount: Int, sessionID: UUID) async throws {
        guard var session = novelPseudoPopularSession else { return }
        try validateNovelPseudoPopularSession(sessionID)
        var madeProgress = true

        while session.items.count < targetCount, madeProgress {
            let previousCount = session.items.count
            madeProgress = false

            for bucketIndex in session.bucketStates.indices {
                try validateNovelPseudoPopularSession(sessionID)
                try await fetchNovelBucketPages(
                    into: &session,
                    bucketIndex: bucketIndex,
                    desiredCount: targetCount,
                    sessionID: sessionID
                )
                if session.items.count >= targetCount {
                    break
                }
            }

            if session.items.count < targetCount {
                try await fetchNovelFallbackPages(
                    into: &session,
                    desiredCount: targetCount,
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

    // MARK: - Bucket 抓取

    func fetchIllustBucketPages(
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

                let page = try await api.searchAPI.searchIllusts(
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

    func fetchNovelBucketPages(
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

                let page = try await api.searchAPI.searchNovels(
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

    // MARK: - Fallback 抓取

    func fetchIllustFallbackPages(
        into session: inout IllustPseudoPopularSessionState,
        desiredCount: Int,
        sessionID: UUID
    ) async throws {
        guard !session.fallbackState.isExhausted else { return }

        while session.items.count < desiredCount {
            try validateIllustPseudoPopularSession(sessionID)
            let page = try await api.searchAPI.searchIllusts(
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
                break
            } else {
                session.fallbackState.nextOffset += page.count
            }

            await Task.yield()
        }
    }

    func fetchNovelFallbackPages(
        into session: inout NovelPseudoPopularSessionState,
        desiredCount: Int,
        sessionID: UUID
    ) async throws {
        guard !session.fallbackState.isExhausted else { return }

        while session.items.count < desiredCount {
            try validateNovelPseudoPopularSession(sessionID)
            let page = try await api.searchAPI.searchNovels(
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
                break
            } else {
                session.fallbackState.nextOffset += page.count
            }

            await Task.yield()
        }
    }

    // MARK: - Bucket 与 Session Key 构建

    func makePseudoPopularBucketStates(for key: PseudoPopularSessionKey) -> [PseudoPopularBucketState] {
        guard key.usesUsersTagBuckets else { return [] }

        let thresholds: [BookmarkFilterOption]

        if key.minimumBookmarkCount >= BookmarkFilterOption.users500.rawValue {
            thresholds = [.users500]
        } else if key.minimumBookmarkCount >= BookmarkFilterOption.users250.rawValue {
            thresholds = [.users250, .users500]
        } else if key.minimumBookmarkCount >= BookmarkFilterOption.users100.rawValue {
            thresholds = [.users100, .users250, .users500]
        } else {
            thresholds = [.users100, .users250, .users500]
        }

        return thresholds.map { threshold in
            let queries = pseudoPopularQueries(
                for: key.word,
                threshold: threshold,
                searchTarget: key.searchTarget
            )
            return PseudoPopularBucketState(
                threshold: threshold,
                queryStates: queries.map { PseudoPopularQueryState(query: $0) }
            )
        }
    }

    func pseudoPopularQueries(
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

    func makePseudoPopularSessionKey(
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

    // MARK: - 验证

    func validateIllustPseudoPopularSession(_ sessionID: UUID) throws {
        guard illustPseudoPopularSessionID == sessionID else { throw CancellationError() }
    }

    func validateNovelPseudoPopularSession(_ sessionID: UUID) throws {
        guard novelPseudoPopularSessionID == sessionID else { throw CancellationError() }
    }

    // MARK: - 取消任务

    func cancelIllustPseudoPopularEnrichment() {
        illustPseudoPopularEnrichmentTask?.cancel()
        illustPseudoPopularEnrichmentTask = nil
    }

    func cancelNovelPseudoPopularEnrichment() {
        novelPseudoPopularEnrichmentTask?.cancel()
        novelPseudoPopularEnrichmentTask = nil
    }

    func cancelSupplementalSearch() {
        supplementalSearchTask?.cancel()
        supplementalSearchTask = nil
    }

    func seedIllustPseudoPopularSessionFromRegularResults(
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

    func seedNovelPseudoPopularSessionFromRegularResults(
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

    // MARK: - Enrichment（后台补充搜索）

    func scheduleIllustPseudoPopularEnrichment(
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
            pseudoPopularInitialSamplePageCount
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

                self.illustResults = self.appendNewResultsPreservingOrder(existing: self.illustResults, fetched: batch.items)
                self.illustPseudoPopularTargetCount = nextTargetCount
                self.illustPseudoPopularSamplePageCount = nextSamplePageCount
                self.illustOffset = batch.nextOffset
                self.illustHasMore = batch.hasMore
            } catch is CancellationError {
            } catch {
                Logger.search.error("Failed to enrich pseudo-popular illusts: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func scheduleNovelPseudoPopularEnrichment(
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
            pseudoPopularInitialSamplePageCount
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

                self.novelResults = self.appendNewResultsPreservingOrder(existing: self.novelResults, fetched: batch.items)
                self.novelPseudoPopularTargetCount = nextTargetCount
                self.novelPseudoPopularSamplePageCount = nextSamplePageCount
                self.novelOffset = batch.nextOffset
                self.novelHasMore = batch.hasMore
            } catch is CancellationError {
            } catch {
                Logger.search.error("Failed to enrich pseudo-popular novels: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Session 状态检查

    func illustSessionCanFetchMore(_ session: IllustPseudoPopularSessionState) -> Bool {
        if session.key.usesUsersTagBuckets {
            for bucketState in session.bucketStates where bucketState.queryStates.contains(where: { !$0.isExhausted }) {
                return true
            }
        }

        return !session.fallbackState.isExhausted
    }

    func novelSessionCanFetchMore(_ session: NovelPseudoPopularSessionState) -> Bool {
        if session.key.usesUsersTagBuckets {
            for bucketState in session.bucketStates where bucketState.queryStates.contains(where: { !$0.isExhausted }) {
                return true
            }
        }

        return !session.fallbackState.isExhausted
    }

    // MARK: - 辅助方法

    func mergeUniqueResults<Item: BookmarkSortableSearchResult>(
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

    func sortResultsByBookmarkCount<Item: BookmarkSortableSearchResult>(_ items: [Item]) -> [Item] {
        items.sorted { lhs, rhs in
            if lhs.totalBookmarks == rhs.totalBookmarks {
                return lhs.createDate > rhs.createDate
            }
            return lhs.totalBookmarks > rhs.totalBookmarks
        }
    }
}
