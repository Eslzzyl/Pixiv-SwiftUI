import SwiftUI
import Combine
import Observation
import os.log

@MainActor
@Observable
class SearchStore {
    static let shared = SearchStore()

    var searchText: String = "" {
        didSet {
            searchTextSubject.send(searchText)
        }
    }
    var searchHistory: [SearchTag] = []
    var suggestions: [UnifiedSearchSuggestion] = []
    var trendTags: [TrendTag] = []
    var isLoadingTrendTags: Bool = false
    var recommendedSearchTags: [TrendTag] = []
    var isLoadingRecommendedTags: Bool = false
    var recommendByTagGroups: [RecommendByTagGroup] = []

    private var cancellables = Set<AnyCancellable>()
    private let searchTextSubject = PassthroughSubject<String, Never>()
    private let api = PixivAPI.shared
    private let cache: CacheStorageProtocol
    private let authSession: AuthSessionProtocol
    private let suggestionManager = SearchSuggestionManager.shared

    private let trendTagsExpiration: CacheExpiration = .hours(1)
    private let recommendedTagsExpiration: CacheExpiration = .hours(1)
    private var requestGeneration: UInt = 0

    private var historyKey: String {
        let userId = authSession.currentUserId
        return "SearchHistoryTags_\(userId)"
    }

    init(
        authSession: AuthSessionProtocol = AccountStore.shared,
        cache: CacheStorageProtocol = CacheManager.shared
    ) {
        self.authSession = authSession
        self.cache = cache
        loadSearchHistory()

        searchTextSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                guard let searchWord = self.activeSuggestionToken(in: text) else {
                    self.suggestions = []
                    return
                }
                Task {
                    await self.fetchSuggestions(word: searchWord)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clearMemoryCache()
                self?.loadSearchHistory()
            }
        }
    }

    func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([SearchTag].self, from: data) {
            self.searchHistory = history
        } else {
            self.searchHistory = []
        }
    }

    func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func addHistory(_ tag: SearchTag) {
        var tagToInsert = tag

        if let index = searchHistory.firstIndex(where: { $0.name == tag.name }) {
            let existingTag = searchHistory[index]
            // 如果新 tag 没有翻译名，但旧 tag 有，则使用旧 tag 的翻译名
            if tagToInsert.translatedName == nil && existingTag.translatedName != nil {
                tagToInsert = existingTag
            }
            searchHistory.remove(at: index)
        }

        searchHistory.insert(tagToInsert, at: 0)
        if searchHistory.count > 100 {
            searchHistory.removeLast()
        }
        saveSearchHistory()
    }

    func addHistory(_ text: String) {
        addHistory(SearchTag(name: text, translatedName: nil))
    }

    func clearHistory() {
        searchHistory = []
        saveSearchHistory()
    }

    func removeHistory(_ name: String) {
        searchHistory.removeAll { $0.name == name }
        saveSearchHistory()
    }

    private func activeSuggestionToken(in text: String) -> String? {
        guard !text.isEmpty else { return nil }
        guard let lastScalar = text.unicodeScalars.last, !CharacterSet.whitespacesAndNewlines.contains(lastScalar) else {
            return nil
        }

        let tokens = text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        guard var token = tokens.last else { return nil }
        if token.hasPrefix("-"), token.count > 1 {
            token.removeFirst()
        }
        guard !token.isEmpty, token.uppercased() != "OR" else {
            return nil
        }
        return token
    }

    func fetchTrendTags() async {
        let cacheKey = CacheManager.trendTagsKey()
        let requestGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        if let cached: [TrendTag] = cache.get(forKey: cacheKey) {
            Logger.search.debug("Use cached trend tags for key: \(cacheKey)")
            self.trendTags = cached
            return
        }

        guard authSession.isLoggedIn else {
            Logger.search.debug("Skip fetching trend tags in guest mode")
            return
        }

        isLoadingTrendTags = true
        defer {
            if isCurrentRequest(generation: requestGeneration, userId: requestUserId) {
                isLoadingTrendTags = false
            }
        }

        do {
            let tags = try await api.searchAPI.getIllustTrendTags()
            guard isCurrentRequest(generation: requestGeneration, userId: requestUserId) else { return }
            self.trendTags = tags
            cache.set(tags, forKey: cacheKey, expiration: trendTagsExpiration)
        } catch {
            Logger.search.error("Failed to fetch trend tags: \(error.localizedDescription, privacy: .public)")
        }
    }

    func fetchRecommendedTags(forceRefresh: Bool = false) async {
        // 推荐标签 / 为你推荐标签依赖 Pixiv Web Ajax 会话（cookies）。
        // 没有有效的 Web 登录时不要请求，也不要用热门标签兜底，避免“推荐=热门”的错乱。
        guard authSession.isWebLoggedIn else {
            Logger.search.debug("Skip fetching recommended tags: Web(Ajax) not logged in")
            return
        }

        let requestGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        let tagsKey = CacheManager.recommendedTagsKey(userId: requestUserId)
        let groupsKey = CacheManager.recommendByTagGroupsKey(userId: requestUserId)

        if !forceRefresh,
           let cachedTags: [TrendTag] = cache.get(forKey: tagsKey),
           let cachedGroups: [RecommendByTagGroup] = cache.get(forKey: groupsKey) {
            Logger.search.debug("Use cached recommended tags and groups")
            self.recommendedSearchTags = cachedTags
            self.recommendByTagGroups = cachedGroups
            return
        }

        guard !isLoadingRecommendedTags else { return }
        isLoadingRecommendedTags = true
        defer {
            if isCurrentRequest(generation: requestGeneration, userId: requestUserId) {
                isLoadingRecommendedTags = false
            }
        }

        do {
            let response = try await api.getSearchSuggestion(mode: "all")
            guard isCurrentRequest(generation: requestGeneration, userId: requestUserId) else { return }

            // 只展示“推荐标签”。热门标签由 App API 的趋势标签模块单独展示。
            let displayTags: [SuggestionTag] = response.body.recommendTags?.illust ?? []

            if displayTags.isEmpty && (response.body.recommendByTags?.illust.isEmpty ?? true) { return }

            // 构建索引用于快速寻找缩略图
            var thumbnailMap: [String: SuggestionThumbnail] = [:]
            if let thumbnails = response.body.thumbnails {
                for thumb in thumbnails {
                    thumbnailMap[thumb.id] = thumb
                }
            }

            // 翻译字典
            let translations = response.body.tagTranslation ?? [:]

            // 构建分组标签对象用于首页的展示 (recommendByTags)
            var newRecommendByTagGroups: [RecommendByTagGroup] = []
            if let tagGroups = response.body.recommendByTags?.illust {
                newRecommendByTagGroups = tagGroups.compactMap { tag -> RecommendByTagGroup? in
                    let illusts: [TrendTagIllust] = tag.ids.compactMap { idItem in
                        let idString: String
                        switch idItem {
                        case .string(let str): idString = str
                        case .int(let i): idString = String(i)
                        }

                        guard let thumb = thumbnailMap[idString] else { return nil }
                        return TrendTagIllust(
                            id: Int(thumb.id) ?? 0,
                            title: thumb.title,
                            imageUrls: ImageUrlsDTO(
                                squareMedium: thumb.url,
                                medium: thumb.url,
                                large: thumb.url
                            ),
                            width: nil,
                            height: nil
                        )
                    }
                    guard !illusts.isEmpty else { return nil }
                    let officialTrans = translations[tag.tag]?.zh ?? translations[tag.tag]?.en
                    let translatedName = TagTranslationService.shared.getDisplayTranslation(for: tag.tag, officialTranslation: officialTrans)
                    return RecommendByTagGroup(tag: tag.tag, translatedName: translatedName, illusts: illusts)
                }
            }
            self.recommendByTagGroups = newRecommendByTagGroups

            self.recommendedSearchTags = displayTags.compactMap { tag -> TrendTag? in
                // 找到第一个 ID 对应的插画
                guard let firstId = tag.ids.first else { return nil }
                let idString: String
                switch firstId {
                case .string(let str): idString = str
                case .int(let i): idString = String(i)
                }

                guard let thumb = thumbnailMap[idString] else { return nil }

                let officialTrans = translations[tag.tag]?.zh ?? translations[tag.tag]?.en
                let translatedName = TagTranslationService.shared.getDisplayTranslation(for: tag.tag, officialTranslation: officialTrans)

                let trendIllust = TrendTagIllust(
                    id: Int(thumb.id) ?? 0,
                    title: thumb.title,
                    imageUrls: ImageUrlsDTO(
                        squareMedium: thumb.url,
                        medium: thumb.url,
                        large: thumb.url
                    ),
                    width: nil,
                    height: nil
                )

                return TrendTag(
                    tag: tag.tag,
                    translatedName: translatedName,
                    illust: trendIllust
                )
            }

            // 缓存结果
            cache.set(self.recommendedSearchTags, forKey: tagsKey, expiration: recommendedTagsExpiration)
            cache.set(self.recommendByTagGroups, forKey: groupsKey, expiration: recommendedTagsExpiration)
        } catch {
            // Ajax 失败时不做热门标签兜底：避免推荐内容错误地变成热门标签。
            // 保留当前内存中的推荐数据（可能来自上一次成功或缓存命中）。
            Logger.search.error("Failed to fetch recommended tags via Ajax: \(error.localizedDescription, privacy: .public)")
            Logger.search.debug("Ajax state: isLoggedIn=\(self.authSession.isLoggedIn), isWebLoggedIn=\(self.authSession.isWebLoggedIn), hasAjaxSession=\(self.authSession.hasAjaxSession)")
        }
    }

    func fetchSuggestions(word: String) async {
        self.suggestions = await suggestionManager.fetchSuggestions(query: word)
    }

    func clearMemoryCache() {
        requestGeneration &+= 1
        self.trendTags = []
        self.recommendedSearchTags = []
        self.recommendByTagGroups = []
        self.suggestions = []
        self.isLoadingTrendTags = false
        self.isLoadingRecommendedTags = false
        Logger.search.debug("Memory cache cleared")
    }

    private func isCurrentRequest(generation: UInt, userId: String) -> Bool {
        requestGeneration == generation &&
            authSession.accountGeneration == generation &&
            authSession.currentUserId == userId
    }
}
