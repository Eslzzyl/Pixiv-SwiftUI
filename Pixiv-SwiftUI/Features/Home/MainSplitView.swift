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
    @State private var credentialExportAccount: AccountPersist?
    @State private var showClearCacheAlert = false
    @State private var showClearHistoryAlert = false
    @State private var loginWebViewItem: LoginWebViewItem?
    @State private var showingManualPHPSESSIDAlert = false
    @State private var manualPHPSESSIDInput = ""
    @Environment(UserSettingStore.self) var userSettingStore
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
                    }
                }

                Section("搜索") {
                    NavigationLink(value: NavigationItem.search) {
                        sidebarLabel(for: .search)
                    }
                }

                Section("库") {
                    ForEach(NavigationItem.secondaryItems) { item in
                        NavigationLink(value: item) {
                            sidebarLabel(for: item)
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

                                Button("导出登录凭证…") {
                                    credentialExportAccount = account
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
        #if os(macOS)
        .sheet(item: $credentialExportAccount) { account in
            LoginCredentialsExportSheet(account: account)
        }
        #endif
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
        Label(item.title, systemImage: item.icon)
            .symbolRenderingMode(.monochrome)
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
private struct LoginCredentialsExportSheet: View {
    private enum CredentialKind: Equatable {
        case refreshToken
        case phpSessId
    }

    let account: AccountPersist
    @Environment(\.dismiss) private var dismiss

    @State private var copiedCredential: CredentialKind?
    @State private var isRefreshTokenRevealed = false
    @State private var isPHPSESSIDRevealed = false
    @State private var resetCopyTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    accountHeaderCard

                    credentialCard(
                        kind: .refreshToken,
                        title: "Refresh Token",
                        badge: "App API",
                        icon: "key.fill",
                        description: "用于移动端 App API 鉴权与令牌刷新",
                        value: account.refreshToken,
                        isRevealed: isRefreshTokenRevealed,
                        onToggleReveal: { isRefreshTokenRevealed.toggle() },
                        emptyMessage: "当前账号未保存 Refresh Token"
                    )

                    credentialCard(
                        kind: .phpSessId,
                        title: "PHPSESSID",
                        badge: "Web API",
                        icon: "globe",
                        description: "用于网页端 Ajax 接口认证与 Cookie 凭证",
                        value: account.webPHPSESSID ?? "",
                        isRevealed: isPHPSESSIDRevealed,
                        onToggleReveal: { isPHPSESSIDRevealed.toggle() },
                        emptyMessage: "未登录 Web API（可在账号菜单中通过网页授权登录）"
                    )

                    securityNoticeCard
                }
                .padding(18)
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("导出登录凭证")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .frame(width: 500, height: 480)
    }

    private var accountHeaderCard: some View {
        HStack(spacing: 12) {
            AnimatedAvatarImage(
                urlString: account.userImage,
                size: 40,
                expiration: DefaultCacheExpiration.myAvatar
            )
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("@\(account.account)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text("ID: \(account.userId)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    private func credentialCard(
        kind: CredentialKind,
        title: String,
        badge: String,
        icon: String,
        description: String,
        value: String,
        isRevealed: Bool,
        onToggleReveal: @escaping () -> Void,
        emptyMessage: String
    ) -> some View {
        let isAvailable = !value.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                    .frame(width: 18)

                Text(LocalizedStringKey(title))
                    .font(.headline)

                Text(LocalizedStringKey(badge))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2), in: Capsule())

                Spacer()
            }

            Text(LocalizedStringKey(description))
                .font(.caption)
                .foregroundStyle(.secondary)

            if isAvailable {
                HStack(spacing: 8) {
                    Group {
                        if isRevealed {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(verbatim: value)
                                    .font(.system(size: 12, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(.vertical, 2)
                            }
                        } else {
                            Text(verbatim: maskedString(for: value))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    Button(action: onToggleReveal) {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isRevealed ? "隐藏凭证" : "查看完整凭证")

                    Button {
                        copy(value, as: kind)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copiedCredential == kind ? "checkmark" : "doc.on.doc")
                                .font(.caption)
                            Text(LocalizedStringKey(copiedCredential == kind ? "已复制" : "复制"))
                                .font(.caption.weight(.medium))
                        }
                        .frame(width: 60)
                    }
                    .buttonStyle(.bordered)
                    .tint(copiedCredential == kind ? .green : nil)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                )
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(emptyMessage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }

    private var securityNoticeCard: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.subheadline)
                .foregroundStyle(.orange)

            Text("登录凭证拥有与密码等同的访问权限，请妥善保管，切勿分享给他人。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func maskedString(for raw: String) -> String {
        guard raw.count > 10 else {
            return String(repeating: "•", count: max(raw.count, 16))
        }
        let prefix = raw.prefix(4)
        let suffix = raw.suffix(4)
        return "\(prefix)••••••••••••••••\(suffix)"
    }

    private func copy(_ value: String, as credential: CredentialKind) {
        guard !value.isEmpty else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        setCopiedFeedback(credential)
    }

    private func setCopiedFeedback(_ credential: CredentialKind) {
        resetCopyTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            copiedCredential = credential
        }

        resetCopyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if !Task.isCancelled && copiedCredential == credential {
                withAnimation(.easeInOut(duration: 0.2)) {
                    copiedCredential = nil
                }
            }
        }
    }
}

#Preview("完整凭证") {
    LoginCredentialsExportSheet(
        account: AccountPersist(
            userId: "12345678",
            userImage: "",
            accessToken: "",
            refreshToken: "sample_refresh_token_abcdef1234567890",
            deviceToken: "",
            name: "Pixiv Artist",
            account: "artist_pixiv",
            mailAddress: "",
            passWord: "",
            isPremium: 1,
            xRestrict: 0,
            isMailAuthorized: 1,
            webPHPSESSID: "12345678_sample_session_id_abcdef"
        )
    )
}

#Preview("未登录 Web API") {
    LoginCredentialsExportSheet(
        account: AccountPersist(
            userId: "87654321",
            userImage: "",
            accessToken: "",
            refreshToken: "sample_refresh_token_only",
            deviceToken: "",
            name: "普通画师",
            account: "normal_user",
            mailAddress: "",
            passWord: "",
            isPremium: 0,
            xRestrict: 0,
            isMailAuthorized: 1,
            webPHPSESSID: nil
        )
    )
}
#endif

#Preview {
    MainSplitView(accountStore: .shared)
}
