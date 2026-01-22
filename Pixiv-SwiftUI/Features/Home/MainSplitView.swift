import SwiftUI

/// macOS 侧边栏导航架构
struct MainSplitView: View {
    @Bindable var accountStore: AccountStore
    @State private var selectedItem: NavigationItem? = .recommend
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var isBookmarksExpanded = true
    @State private var showAuthView = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedItem) {
                Section("浏览") {
                    ForEach(NavigationItem.mainItems.filter { $0 != .bookmarks }) { item in
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                    
                    DisclosureGroup(isExpanded: $isBookmarksExpanded) {
                        NavigationLink(value: NavigationItem.bookmarksPublic) {
                            Label("公开", systemImage: "person.2")
                        }
                        NavigationLink(value: NavigationItem.bookmarksPrivate) {
                            Label("非公开", systemImage: "lock")
                        }
                    } label: {
                        Label("我的收藏", systemImage: "heart.fill")
                    }
                }
                
                Section("库") {
                    ForEach(NavigationItem.secondaryItems) { item in
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Pixiv")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if let account = accountStore.currentAccount, accountStore.isLoggedIn {
                        HStack {
                            CachedAsyncImage(urlString: account.userImage, idealWidth: 40, expiration: DefaultCacheExpiration.myAvatar)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                                Text("@\(account.account)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()

                            Button(action: {
                                SettingsWindowManager.shared.show()
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                            .help("设置")

                            Menu {
                                Button("个人主页") {
                                    selectedItem = .recommend
                                    accountStore.requestNavigation(.userDetail(account.userId))
                                }
                                Divider()
                                Button("登出", role: .destructive) {
                                    try? accountStore.logout()
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .onHover { hovering in
                                if hovering {
                                    NSCursor.pointingHand.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                        }
                        .padding(12)
                    } else {
                        Button(action: {
                            showAuthView = true
                        }) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .font(.title3)
                                Text("登录账号")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(12)
                    }
                }
            }
            #endif
        } detail: {
            detailView
        }
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore, onGuestMode: nil)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let selectedItem = selectedItem {
            selectedItem.destination
        } else {
            NavigationStack {
                ContentUnavailableView("请选择一个项目", systemImage: "sidebar.left")
                    .navigationTitle("Pixiv")
            }
        }
    }
}

#Preview {
    MainSplitView(accountStore: .shared)
}
