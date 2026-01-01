import SwiftUI
import Combine

@MainActor
class SearchStore: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchHistory: [SearchTag] = []
    @Published var suggestions: [SearchTag] = []
    @Published var trendTags: [TrendTag] = []
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

    private var cancellables = Set<AnyCancellable>()
    private let api = PixivAPI.shared
    
    init() {
        loadSearchHistory()
        
        // 监听 searchText 变化，获取建议
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self = self else { return }
                if !text.isEmpty {
                    Task {
                        await self.fetchSuggestions(word: text)
                    }
                } else {
                    self.suggestions = []
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
    
    func fetchTrendTags() async {
        do {
            self.trendTags = try await api.getIllustTrendTags()
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
    
    func search(word: String) async {
        self.isLoading = true
        self.errorMessage = nil
        self.addHistory(word)

        // reset pagination
        self.illustOffset = 0
        self.userOffset = 0
        self.illustHasMore = false
        self.userHasMore = false

        do {
            // 并行请求插画和用户（第一页）
            async let illusts = api.searchIllusts(word: word, offset: 0, limit: illustLimit)
            async let users = api.getSearchUser(word: word, offset: 0)

            let fetchedIllusts = try await illusts
            let fetchedUsers = try await users

            self.illustResults = fetchedIllusts
            self.userResults = fetchedUsers

            self.illustOffset = fetchedIllusts.count
            self.illustHasMore = fetchedIllusts.count == illustLimit
            self.userOffset = fetchedUsers.count
            // 对于用户搜索，如果返回的数量不为 0，则允许继续尝试加载更多（基于 API 支持）
            self.userHasMore = fetchedUsers.count > 0
        } catch {
            self.errorMessage = error.localizedDescription
        }

        self.isLoading = false
    }

    /// 加载更多插画
    func loadMoreIllusts(word: String) async {
        guard !isLoading, !isLoadingMoreIllusts, illustHasMore else { return }
        isLoadingMoreIllusts = true
        do {
            let more = try await api.searchIllusts(word: word, offset: self.illustOffset, limit: self.illustLimit)
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
            // 根据返回数量判断是否还有更多
            self.userHasMore = more.count > 0
        } catch {
            print("Failed to load more users: \(error)")
        }
        isLoadingMoreUsers = false
    }
}

