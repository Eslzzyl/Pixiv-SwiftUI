import SwiftUI
import Combine
import Observation

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
    private let cache = CacheManager.shared
    private let suggestionManager = SearchSuggestionManager.shared

    private let trendTagsExpiration: CacheExpiration = .hours(1)
    private let recommendedTagsExpiration: CacheExpiration = .hours(1)

    private var historyKey: String {
        let userId = AccountStore.shared.currentUserId
        return "SearchHistoryTags_\(userId)"
    }

    init() {
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

        if let cached: [TrendTag] = cache.get(forKey: cacheKey) {
            print("[SearchStore] Use cached trend tags for key: \(cacheKey)")
            self.trendTags = cached
            return
        }

        guard AccountStore.shared.isLoggedIn else {
            print("[SearchStore] Skip fetching trend tags in guest mode")
            return
        }

        isLoadingTrendTags = true
        defer { isLoadingTrendTags = false }

        do {
            let tags = try await api.getIllustTrendTags()
            self.trendTags = tags
            cache.set(tags, forKey: cacheKey, expiration: trendTagsExpiration)
        } catch {
            print("Failed to fetch trend tags: \(error)")
        }
    }

    func fetchRecommendedTags(forceRefresh: Bool = false) async {
        // 推荐标签 / 为你推荐标签依赖 Pixiv Web Ajax 会话（cookies）。
        // 没有有效的 Web 登录时不要请求，也不要用热门标签兜底，避免“推荐=热门”的错乱。
        guard AccountStore.shared.isWebLoggedIn else {
            print("[SearchStore] Skip fetching recommended tags: Web(Ajax) not logged in")
            return
        }

        let tagsKey = CacheManager.recommendedTagsKey()
        let groupsKey = CacheManager.recommendByTagGroupsKey()

        if !forceRefresh,
           let cachedTags: [TrendTag] = cache.get(forKey: tagsKey),
           let cachedGroups: [RecommendByTagGroup] = cache.get(forKey: groupsKey) {
            print("[SearchStore] Use cached recommended tags and groups")
            self.recommendedSearchTags = cachedTags
            self.recommendByTagGroups = cachedGroups
            return
        }

        isLoadingRecommendedTags = true
        defer { isLoadingRecommendedTags = false }

        do {
            let response = try await api.getSearchSuggestion(mode: "all")

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
                            imageUrls: ImageUrls(
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
                    imageUrls: ImageUrls(
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
            print("[SearchStore] Failed to fetch recommended tags via Ajax: \(error)")
            print("[SearchStore] Ajax state: isLoggedIn=\(AccountStore.shared.isLoggedIn), isWebLoggedIn=\(AccountStore.shared.isWebLoggedIn), hasAjaxSession=\(AccountStore.shared.hasAjaxSession)")
        }
    }

    func fetchSuggestions(word: String) async {
        self.suggestions = await suggestionManager.fetchSuggestions(query: word)
    }

    func clearMemoryCache() {
        self.trendTags = []
        self.recommendedSearchTags = []
        self.suggestions = []
        print("[SearchStore] Memory cache cleared")
    }
}
