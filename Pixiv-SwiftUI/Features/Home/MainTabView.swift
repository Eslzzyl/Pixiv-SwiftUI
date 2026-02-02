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
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    private var isPadLandscape: Bool {
        isPad && verticalSizeClass == .compact
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(NavigationItem.mainItems) { item in
                if item == .search {
                    Tab(value: item, role: .search) {
                        item.destination
                    }
                } else {
                    Tab(item.title, systemImage: item.icon, value: item) {
                        item.destination
                    }
                }
            }

            if isPadLandscape {
                TabSection {
                    ForEach(NavigationItem.secondaryItems) { item in
                        Tab(item.title, systemImage: item.icon, value: item) {
                            item.destination
                        }
                        .defaultVisibility(.hidden, for: .tabBar)
                    }
                } header: {
                    Label("库", systemImage: "folder")
                }
            }

            if isPad && !isPadLandscape {
                ForEach(NavigationItem.secondaryItems) { item in
                    Tab(item.title, systemImage: item.icon, value: item) {
                        item.destination
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
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
            ForEach(NavigationItem.mainItemsForLegacy) { item in
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
