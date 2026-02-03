import SwiftUI
import Combine

@MainActor
class SearchStore: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchHistory: [SearchTag] = []
    @Published var suggestions: [SearchTag] = []
    @Published var trendTags: [TrendTag] = []
    @Published var isLoadingTrendTags: Bool = false
    @Published var illustResults: [Illusts] = []
    @Published var userResults: [UserPreviews] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // 分页状态
    @Published var illustOffset: Int = 0
    @Published var illustLimit: Int = 30
    @Published var illustHasMore: Bool = false
    @Published var isLoadingMoreIllusts: Bool = false

    @Published var userOffset: Int = 0
    @Published var userHasMore: Bool = false
    @Published var isLoadingMoreUsers: Bool = false

    @Published var novelResults: [Novel] = []
    @Published var novelOffset: Int = 0
    @Published var novelLimit: Int = 30
    @Published var novelHasMore: Bool = false
    @Published var isLoadingMoreNovels: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let api = PixivAPI.shared
    private let cache = CacheManager.shared

    private let trendTagsExpiration: CacheExpiration = .hours(1)

    init() {
        loadSearchHistory()

        $searchText
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                let trimmedText = text.trimmingCharacters(in: .whitespaces)
                if trimmedText.isEmpty {
                    self.suggestions = []
                    return
                }
                let searchWord = trimmedText.split(separator: " ").last.map(String.init) ?? trimmedText
                Task {
                    await self.fetchSuggestions(word: searchWord)
                }
            }
            .store(in: &cancellables)
    }

    func loadSearchHistory() {
        if let data = UserDefaults.standard.data(forKey: "SearchHistoryTags"),
           let history = try? JSONDecoder().decode([SearchTag].self, from: data) {
            self.searchHistory = history
        }
    }

    func saveSearchHistory() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "SearchHistoryTags")
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
        if searchHistory.count > 20 {
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

    func fetchTrendTags() async {
        let cacheKey = CacheManager.trendTagsKey()

        if let cached: [TrendTag] = cache.get(forKey: cacheKey) {
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

    func fetchSuggestions(word: String) async {
        do {
            self.suggestions = try await api.getSearchAutoCompleteKeywords(word: word)
        } catch {
            print("Failed to fetch suggestions: \(error)")
        }
    }

    func search(word: String, sort: String = "date_desc") async {
        self.isLoading = true
        self.errorMessage = nil
        self.addHistory(word)

        self.illustOffset = 0
        self.userOffset = 0
        self.novelOffset = 0
        self.illustHasMore = false
        self.userHasMore = false
        self.novelHasMore = false

        do {
            async let illustsTask = api.searchIllusts(word: word, sort: sort, offset: 0, limit: illustLimit)
            async let usersTask = api.getSearchUser(word: word, offset: 0)
            async let novelsTask = api.searchNovels(word: word, offset: 0, limit: novelLimit)

            let fetchedIllusts = try await illustsTask
            let fetchedUsers = try await usersTask
            let fetchedNovels = try await novelsTask

            self.illustResults = fetchedIllusts
            self.userResults = fetchedUsers
            self.novelResults = fetchedNovels

            self.illustOffset = fetchedIllusts.count
            self.illustHasMore = fetchedIllusts.count == illustLimit
            self.userOffset = fetchedUsers.count
            self.userHasMore = !fetchedUsers.isEmpty
            self.novelOffset = fetchedNovels.count
            self.novelHasMore = fetchedNovels.count == novelLimit
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    /// 加载更多插画
    func loadMoreIllusts(word: String, sort: String = "date_desc") async {
        guard !isLoading, !isLoadingMoreIllusts, illustHasMore else { return }
        isLoadingMoreIllusts = true
        do {
            let more = try await api.searchIllusts(word: word, sort: sort, offset: self.illustOffset, limit: self.illustLimit)
            self.illustResults += more
            self.illustOffset += more.count
            self.illustHasMore = more.count == illustLimit
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

    /// 搜索小说
    func searchNovels(word: String, sort: String = "date_desc") async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        do {
            let fetchedNovels = try await api.searchNovels(word: word, sort: sort, offset: 0, limit: novelLimit)
            self.novelResults = fetchedNovels
            self.novelOffset = fetchedNovels.count
            self.novelHasMore = fetchedNovels.count == novelLimit
        } catch {
            print("Failed to search novels: \(error)")
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// 加载更多小说
    func loadMoreNovels(word: String, sort: String = "date_desc") async {
        guard !isLoading, !isLoadingMoreNovels, novelHasMore else { return }
        isLoadingMoreNovels = true
        do {
            let more = try await api.searchNovels(word: word, sort: sort, offset: self.novelOffset, limit: self.novelLimit)
            self.novelResults += more
            self.novelOffset += more.count
            self.novelHasMore = more.count == novelLimit
        } catch {
            print("Failed to load more novels: \(error)")
        }
        isLoadingMoreNovels = false
    }
}
