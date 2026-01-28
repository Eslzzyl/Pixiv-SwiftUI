import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable, Hashable {
    case recommend
    case updates
    case bookmarks
    case search
    case novel

    case history
    case downloads

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .recommend: return String(localized: "推荐")
        case .updates: return String(localized: "动态")
        case .bookmarks: return String(localized: "收藏")
        case .search: return String(localized: "搜索")
        case .novel: return String(localized: "小说")
        case .history: return String(localized: "浏览历史")
        case .downloads: return String(localized: "下载任务")
        }
    }

    var icon: String {
        switch self {
        case .recommend: return "house"
        case .updates: return "person.2"
        case .bookmarks: return "heart"
        case .search: return "magnifyingglass"
        case .novel: return "book"
        case .history: return "clock"
        case .downloads: return "arrow.down.circle"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .recommend:
            RecommendView()
        case .updates:
            UpdatesPage()
        case .bookmarks:
            BookmarksPage()
        case .search:
            SearchView()
        case .novel:
            NovelPage()
        case .history:
            NavigationStack {
                BrowseHistoryView()
                    .pixivNavigationDestinations()
            }
        case .downloads:
            NavigationStack {
                DownloadTasksView()
                    .pixivNavigationDestinations()
            }
        }
    }

    static var mainItems: [NavigationItem] {
        [.recommend, .updates, .bookmarks, .search, .novel]
    }

    static var secondaryItems: [NavigationItem] {
        [.history, .downloads]
    }
}
