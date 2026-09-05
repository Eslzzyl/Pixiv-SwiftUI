import SwiftUI

/// 主导航视图
@available(iOS 16.0, *)
struct MainTabView: View {
    let accountStore: AccountStore

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            MainTabViewNew(accountStore: accountStore)
        } else {
            MainTabViewLegacy(accountStore: accountStore)
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private struct MainTabViewNew: View {
    @State private var selectedTab: NavigationItem = .recommend
    @Bindable var accountStore: AccountStore
    @Environment(UserSettingStore.self) var userSettingStore

    init(accountStore: AccountStore) {
        self.accountStore = accountStore
    }

    private var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    private var mainItems: [NavigationItem] {
        isPad ? NavigationItem.mainItems : NavigationItem.mainItemsForPhone
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(mainItems) { item in
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

            if isPad {
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

        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .onAppear {
            let validTabs = Set(mainItems)
            let savedTab = NavigationItem(rawValue: userSettingStore.userSetting.defaultTab) ?? .recommend
            selectedTab = validTabs.contains(savedTab) ? savedTab : .recommend
        }
    }
}

@available(iOS 16.0, *)
private struct MainTabViewLegacy: View {
    @State private var selectedTab: NavigationItem = .recommend
    @Bindable var accountStore: AccountStore
    @Environment(UserSettingStore.self) var userSettingStore

    private var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    private var mainItems: [NavigationItem] {
        isPad ? NavigationItem.mainItemsForLegacy : NavigationItem.mainItemsForLegacyPhone
    }

    init(accountStore: AccountStore) {
        self.accountStore = accountStore
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(mainItems) { item in
                item.destination
                    .tabItem {
                        Label(item.title, systemImage: item.icon)
                    }
                    .tag(item)
            }
        }
        .onAppear {
            let validTabs = Set(mainItems)
            let savedTab = NavigationItem(rawValue: userSettingStore.userSetting.defaultTab) ?? .recommend
            selectedTab = validTabs.contains(savedTab) ? savedTab : .recommend
        }
    }
}

#Preview {
    MainTabView(accountStore: .shared)
}
