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
        
        do {
            // 并行请求插画和用户
            async let illusts = api.getSearchIllust(word: word)
            async let users = api.getSearchUser(word: word)
            
            self.illustResults = try await illusts
            self.userResults = try await users
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        self.isLoading = false
    }
}
