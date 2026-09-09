import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable, Hashable {
    case recommend
    case ranking
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
        case .ranking: return String(localized: "排行")
        case .updates: return String(localized: "动态")
        case .bookmarks: return String(localized: "收藏")
        case .search: return String(localized: "搜索")
        case .novel: return String(localized: "小说")
        case .history: return String(localized: "历史")
        case .downloads: return String(localized: "下载")
        }
    }

    var icon: String {
        switch self {
        case .recommend: return "house"
        case .ranking: return "trophy"
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
            LazyView(RecommendView())
        case .ranking:
            LazyView(PixivNavigationStack {
                IllustRankingPage()
            })
        case .updates:
            LazyView(UpdatesPage())
        case .bookmarks:
            LazyView(BookmarksPage())
        case .search:
            LazyView(SearchView())
        case .novel:
            LazyView(NovelPage())
        case .history:
            LazyView(PixivNavigationStack {
                BrowseHistoryView()
            })
        case .downloads:
            LazyView(PixivNavigationStack {
                DownloadTasksView()
            })
        }
    }

    static var mainItems: [NavigationItem] {
        [.recommend, .ranking, .updates, .bookmarks, .search, .novel]
    }

    static var mainItemsForPhone: [NavigationItem] {
        [.recommend, .updates, .bookmarks, .search, .novel]
    }

    static var mainItemsForLegacy: [NavigationItem] {
        [.recommend, .ranking, .updates, .bookmarks, .novel, .search]
    }

    static var mainItemsForLegacyPhone: [NavigationItem] {
        [.recommend, .updates, .bookmarks, .novel, .search]
    }

    static var secondaryItems: [NavigationItem] {
        [.history, .downloads]
    }
}
