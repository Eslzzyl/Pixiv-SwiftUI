import SwiftUI

/// 主导航视图
@available(iOS 16.0, *)
struct MainTabView: View {
    @Bindable var accountStore: AccountStore

    var body: some View {
        if #available(iOS 26.0, *) {
            MainTabViewNew(accountStore: accountStore)
        } else {
            MainTabViewLegacy(accountStore: accountStore)
        }
    }
}

@available(iOS 26.0, *)
private struct MainTabViewNew: View {
    @State private var selectedTab: TabSelection = .recommend
    @Bindable var accountStore: AccountStore

    enum TabSelection: Hashable {
        case recommend
        case updates
        case bookmarks
        case search
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("推荐", systemImage: "house.fill", value: .recommend) {
                RecommendView()
            }

            Tab("动态", systemImage: "person.2.fill", value: .updates) {
                UpdatesPage()
            }

            Tab("收藏", systemImage: "heart.fill", value: .bookmarks) {
                BookmarksPage()
            }

            Tab("搜索", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView()
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }
}

@available(iOS 16.0, *)
private struct MainTabViewLegacy: View {
    @State private var selectedTab = 0
    @Bindable var accountStore: AccountStore

    var body: some View {
        TabView(selection: $selectedTab) {
            RecommendView()
                .tabItem {
                    Label("推荐", systemImage: "house.fill")
                }
                .tag(0)

            UpdatesPage()
                .tabItem {
                    Label("动态", systemImage: "person.2.fill")
                }
                .tag(1)

            BookmarksPage()
                .tabItem {
                    Label("收藏", systemImage: "heart.fill")
                }
                .tag(2)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView(accountStore: .shared)
}
