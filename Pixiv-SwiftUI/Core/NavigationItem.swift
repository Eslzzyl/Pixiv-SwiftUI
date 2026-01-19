import SwiftUI

/// 导航项目枚举，用于统一管理 iOS TabBar 和 macOS Sidebar 的项目
enum NavigationItem: String, CaseIterable, Identifiable, Hashable {
    case recommend
    case updates
    case bookmarks
    case bookmarksPublic
    case bookmarksPrivate
    case search
    case novel
    
    // 额外项（侧边栏中使用）
    case history
    case downloads
    case settings
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .recommend: return "推荐"
        case .updates: return "动态"
        case .bookmarks: return "收藏"
        case .bookmarksPublic: return "公开收藏"
        case .bookmarksPrivate: return "非公开收藏"
        case .search: return "搜索"
        case .novel: return "小说"
        case .history: return "历史"
        case .downloads: return "下载"
        case .settings: return "设置"
        }
    }
    
    var icon: String {
        switch self {
        case .recommend: return "house.fill"
        case .updates: return "person.2.fill"
        case .bookmarks: return "heart.fill"
        case .bookmarksPublic: return "heart.fill"
        case .bookmarksPrivate: return "heart.slash.fill"
        case .search: return "magnifyingglass"
        case .novel: return "book.fill"
        case .history: return "clock"
        case .downloads: return "arrow.down.circle"
        case .settings: return "gear"
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
        case .bookmarksPublic:
            BookmarksPage(initialRestrict: "public")
        case .bookmarksPrivate:
            BookmarksPage(initialRestrict: "private")
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
        case .settings:
            NavigationStack {
                ProfileSettingView()
                    .pixivNavigationDestinations()
            }
        }
    }
    
    /// 获取主导航项（用于 iOS TabBar）
    static var mainItems: [NavigationItem] {
        [.recommend, .updates, .bookmarks, .search, .novel]
    }
    
    /// 获取辅助导航项（用于 macOS 侧边栏底部或其他区域）
    static var secondaryItems: [NavigationItem] {
        [.history, .downloads, .settings]
    }
}
