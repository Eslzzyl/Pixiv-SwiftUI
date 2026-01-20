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
    @State private var selectedTab: NavigationItem = .recommend
    @Bindable var accountStore: AccountStore

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(NavigationItem.mainItems) { item in
                if item == .search {
                    Tab(item.title, systemImage: item.icon, value: item, role: .search) {
                        item.destination
                    }
                } else {
                    Tab(item.title, systemImage: item.icon, value: item) {
                        item.destination
                    }
                }
            }
        }
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
    }
}

@available(iOS 16.0, *)
private struct MainTabViewLegacy: View {
    @State private var selectedTab: NavigationItem = .recommend
    @Bindable var accountStore: AccountStore

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(NavigationItem.mainItems) { item in
                item.destination
                    .tabItem {
                        Label(item.title, systemImage: item.icon)
                    }
                    .tag(item)
            }
        }
    }
}

#Preview {
    MainTabView(accountStore: .shared)
}
