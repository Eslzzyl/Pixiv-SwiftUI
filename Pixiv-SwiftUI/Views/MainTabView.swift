import SwiftUI

/// 主导航视图
struct MainTabView: View {
    @Bindable var accountStore: AccountStore

    var body: some View {
        if #available(iOS 18.0, *) {
            MainTabViewNew(accountStore: accountStore)
        } else if #available(iOS 16.0, *) {
            MainTabViewOld(accountStore: accountStore)
        } else {
            MainTabViewLegacy(accountStore: accountStore)
        }
    }
}

@available(iOS 18.0, *)
private struct MainTabViewNew: View {
    @State private var selectedTab: TabSelection = .recommend
    @Bindable var accountStore: AccountStore

    enum TabSelection: Hashable {
        case recommend
        case quick
        case search
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("推荐", systemImage: "star.fill", value: .recommend) {
                RecommendView()
            }

            Tab("速览", systemImage: "square.grid.2x2", value: .quick) {
                QuickView(accountStore: accountStore)
            }

            Tab("搜索", systemImage: "magnifyingglass", value: .search, role: .search) {
                SearchView()
            }

            Tab("我的", systemImage: "person.fill", value: .profile) {
                ProfileView(accountStore: accountStore)
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

@available(iOS 16.0, *)
private struct MainTabViewOld: View {
    @State private var selectedTab = 0
    @Bindable var accountStore: AccountStore

    var body: some View {
        TabView(selection: $selectedTab) {
            RecommendView()
                .tabItem {
                    Label("推荐", systemImage: "star.fill")
                }
                .tag(0)

            QuickView(accountStore: accountStore)
                .tabItem {
                    Label("速览", systemImage: "square.grid.2x2")
                }
                .tag(1)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(2)

            ProfileView(accountStore: accountStore)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

private struct MainTabViewLegacy: View {
    @State private var selectedTab = 0
    @Bindable var accountStore: AccountStore

    var body: some View {
        TabView(selection: $selectedTab) {
            RecommendView()
                .tabItem {
                    Label("推荐", systemImage: "star.fill")
                }
                .tag(0)

            QuickView(accountStore: accountStore)
                .tabItem {
                    Label("速览", systemImage: "square.grid.2x2")
                }
                .tag(1)

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }
                .tag(2)

            ProfileView(accountStore: accountStore)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView(accountStore: .shared)
}
