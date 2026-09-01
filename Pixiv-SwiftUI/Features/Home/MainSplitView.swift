import SwiftUI
import Combine
import SwiftData
#if os(macOS)
import AppKit
#endif

/// macOS 侧边栏导航架构
struct MainSplitView: View {
    let accountStore: AccountStore
    @State private var selectedItem: NavigationItem? = .recommend
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showAuthView = false
    @State private var showAccountSwitch = false
    @State private var showDataExport = false
    @State private var showClearCacheAlert = false
    @State private var showClearHistoryAlert = false
    @State private var loginWebViewItem: LoginWebViewItem?
    @State private var showingManualPHPSESSIDAlert = false
    @State private var manualPHPSESSIDInput = ""
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedItem) {
                Section("浏览") {
                    ForEach([NavigationItem.recommend, NavigationItem.ranking, NavigationItem.updates, NavigationItem.bookmarks, NavigationItem.novel] as [NavigationItem]) { item in
                        NavigationLink(value: item) {
                            sidebarLabel(for: item)
                        }
                        .listItemTint(themeManager.currentColor)
                        .listRowBackground(sidebarSelectionBackground(for: item))
                    }
                }

                Section("搜索") {
                    NavigationLink(value: NavigationItem.search) {
                        sidebarLabel(for: .search)
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .search))
                }

                Section("库") {
                    ForEach(NavigationItem.secondaryItems) { item in
                        NavigationLink(value: item) {
                            sidebarLabel(for: item)
                        }
                        .listItemTint(themeManager.currentColor)
                        .listRowBackground(sidebarSelectionBackground(for: item))
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
                            AnimatedAvatarImage(urlString: account.userImage, size: 32, expiration: DefaultCacheExpiration.myAvatar)

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
                                openWindow(id: "settings")
                            }) {
                                Image(systemName: "gearshape")
                                    .font(.title3)
                                    .foregroundColor(.primary)
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

                                Menu("Web API") {
                                    if accountStore.isWebLoggedIn {
                                        Button("登出 Web API") {
                                            accountStore.updateCurrentAccountAjaxCookies(
                                                phpSessId: nil,
                                                yuidB: nil,
                                                pAbDId: nil,
                                                pAbId: nil,
                                                pAbId2: nil
                                            )
                                        }
                                    } else {
                                        Button("通过网页获取凭证") {
                                            let codeVerifier = PKCEHelper.generateCodeVerifier()
                                            let codeChallenge = PKCEHelper.generateCodeChallenge(codeVerifier: codeVerifier)
                                            let urlString = "https://app-api.pixiv.net/web/v1/login?code_challenge=\(codeChallenge)&code_challenge_method=S256&client=pixiv-android"
                                            if let url = URL(string: urlString) {
                                                self.loginWebViewItem = LoginWebViewItem(url: url)
                                            }
                                        }

                                        Button("手动输入 PHPSESSID...") {
                                            showingManualPHPSESSIDAlert = true
                                        }
                                    }
                                }

                                Divider()

                                Button("数据导入/导出") {
                                    showDataExport = true
                                }

                                Divider()

                                Menu("切换账号") {
                                    ForEach(accountStore.accounts) { acc in
                                        Button {
                                            if acc.userId != account.userId {
                                                Task {
                                                    await accountStore.switchAccount(acc)
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                if acc.userId == account.userId {
                                                    Image(systemName: "checkmark")
                                                }
                                                Text(acc.name)
                                            }
                                        }
                                    }

                                    Divider()

                                    Button("添加账号...") {
                                        showAuthView = true
                                    }
                                }

                                Divider()
                                Button("登出", role: .destructive) {
                                    Task {
                                        try? await accountStore.logout()
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .tint(.primary)
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
                        VStack(spacing: 0) {
                            Button(action: {
                                showAuthView = true
                            }) {
                                HStack {
                                    Image(systemName: "person.circle")
                                        .font(.title3)
                                    Text("登录账号")
                                    Spacer()
                                    Button(action: {
                                        openWindow(id: "settings")
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
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(12)

                            if !accountStore.accounts.isEmpty {
                                Divider()
                                    .padding(.horizontal, 12)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("切换账号")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 8)

                                    ForEach(accountStore.accounts) { acc in
                                        Button {
                                            Task {
                                                await accountStore.switchAccount(acc)
                                            }
                                        } label: {
                                            HStack {
                                                AnimatedAvatarImage(urlString: acc.userImage, size: 24)
                                                Text(acc.name)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                    }
                                }
                                .padding(.bottom, 8)
                            }
                        }
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
        .sheet(isPresented: $showDataExport) {
            DataExportView()
        }
        .sheet(item: $loginWebViewItem) { item in
            LoginWebView(
                url: item.url,
                onCallback: { _, cookies in
                    loginWebViewItem = nil
                    var phpSessId: String?
                    var yuidB: String?
                    var pAbDId: String?
                    var pAbId: String?
                    var pAbId2: String?

                    for cookie in cookies where cookie.domain.contains("pixiv.net") {
                        switch cookie.name {
                        case "PHPSESSID":
                            if cookie.value.contains("_") {
                                phpSessId = cookie.value
                            }
                        case "yuid_b": yuidB = cookie.value
                        case "p_ab_d_id": pAbDId = cookie.value
                        case "p_ab_id": pAbId = cookie.value
                        case "p_ab_id_2": pAbId2 = cookie.value
                        default: break
                        }
                    }

                    accountStore.updateCurrentAccountAjaxCookies(
                        phpSessId: phpSessId,
                        yuidB: yuidB,
                        pAbDId: pAbDId,
                        pAbId: pAbId,
                        pAbId2: pAbId2
                    )
                },
                onError: { error in
                    loginWebViewItem = nil
                    accountStore.error = AppError.authenticationError(error.localizedDescription)
                }
            )
            .frame(width: 800, height: 660)
        }
        .alert("输入 PHPSESSID", isPresented: $showingManualPHPSESSIDAlert) {
            TextField("请输入类似 xxxx_xxxx 的 Cookie 值", text: $manualPHPSESSIDInput)
            Button("确定") {
                if !manualPHPSESSIDInput.isEmpty {
                    accountStore.updateCurrentAccountAjaxCookies(
                        phpSessId: manualPHPSESSIDInput,
                        yuidB: nil,
                        pAbDId: nil,
                        pAbId: nil,
                        pAbId2: nil
                    )
                    manualPHPSESSIDInput = ""
                }
            }
            Button("取消", role: .cancel) {
                manualPHPSESSIDInput = ""
            }
        } message: {
            Text("通过手动输入 Cookie 中的 PHPSESSID 字段来登录 Web API。")
        }
        #if os(macOS)
        .handleMenuCommands(
            accountStore: accountStore,
            selectedItem: $selectedItem,
            columnVisibility: $columnVisibility,
            showAuthView: $showAuthView,
            showClearCacheAlert: $showClearCacheAlert,
            showClearHistoryAlert: $showClearHistoryAlert,
            modelContext: modelContext
        )
        #endif
        .onAppear {
            selectedItem = NavigationItem(rawValue: userSettingStore.userSetting.defaultTab) ?? .recommend
        }
    }

    private func sidebarLabel(for item: NavigationItem) -> some View {
        let isSelected = selectedItem == item

        return Label {
            Text(item.title)
                .foregroundStyle(isSelected ? .white : .primary)
        } icon: {
            Image(systemName: item.icon)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isSelected ? .white : themeManager.currentColor)
        }
        #if os(macOS)
        .background(SidebarRowSelectionStyle())
        #endif
    }

    private func sidebarSelectionBackground(for item: NavigationItem) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(selectedItem == item ? themeManager.currentColor : .clear)
            .padding(.horizontal, 8)
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

#if os(macOS)
struct SidebarRowSelectionStyle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        var currentView: NSView? = nsView
        while let view = currentView {
            if let rowView = view as? NSTableRowView {
                rowView.selectionHighlightStyle = .none
                rowView.needsDisplay = true
                return
            }
            currentView = view.superview
        }
    }
}
#endif

#Preview {
    MainSplitView(accountStore: .shared)
}
