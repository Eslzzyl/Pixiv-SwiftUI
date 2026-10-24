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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(accountStore: AccountStore) {
        self.accountStore = accountStore
    }

    private var usesRegularWidthLayout: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    private var mainItems: [NavigationItem] {
        usesRegularWidthLayout ? NavigationItem.mainItems : NavigationItem.mainItemsForPhone
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(mainItems) { item in
                if item == .search {
                    Tab(value: item, role: .search) {
                        item.destination
                            .tint(nil)
                    }
                } else {
                    Tab(item.title, systemImage: item.icon, value: item) {
                        item.destination
                            .tint(nil)
                    }
                }
            }

            if usesRegularWidthLayout {
                TabSection {
                    ForEach(NavigationItem.secondaryItems) { item in
                        Tab(item.title, systemImage: item.icon, value: item) {
                            item.destination
                                .tint(nil)
                        }
                        .defaultVisibility(.hidden, for: .tabBar)
                    }
                } header: {
                    Label("库", systemImage: "folder")
                }
            }

        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(themeManager.currentColor)
        #if os(iOS)
        .tabBarMinimizeBehavior(.onScrollDown)
        #endif
        .onAppear {
            restoreSelectedTab()
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            restoreSelectedTab()
        }
    }

    private func restoreSelectedTab() {
        let validTabs = Set(mainItems)
        let savedTab = NavigationItem(rawValue: userSettingStore.userSetting.defaultTab) ?? .recommend
        selectedTab = validTabs.contains(savedTab) ? savedTab : .recommend
    }
}

@available(iOS 16.0, *)
private struct MainTabViewLegacy: View {
    @State private var selectedTab: NavigationItem = .recommend
    @Bindable var accountStore: AccountStore
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesRegularWidthLayout: Bool {
        #if os(macOS)
        true
        #else
        horizontalSizeClass == .regular
        #endif
    }

    private var mainItems: [NavigationItem] {
        usesRegularWidthLayout ? NavigationItem.mainItemsForLegacy : NavigationItem.mainItemsForLegacyPhone
    }

    init(accountStore: AccountStore) {
        self.accountStore = accountStore
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(mainItems) { item in
                item.destination
                    .tint(nil)
                    .tabItem {
                        Label(item.title, systemImage: item.icon)
                    }
                    .tag(item)
            }
        }
        .tint(themeManager.currentColor)
        .onAppear {
            restoreSelectedTab()
        }
        .onChange(of: horizontalSizeClass) { _, _ in
            restoreSelectedTab()
        }
    }

    private func restoreSelectedTab() {
        let validTabs = Set(mainItems)
        let savedTab = NavigationItem(rawValue: userSettingStore.userSetting.defaultTab) ?? .recommend
        selectedTab = validTabs.contains(savedTab) ? savedTab : .recommend
    }
}

#Preview {
    MainTabView(accountStore: .shared)
}
