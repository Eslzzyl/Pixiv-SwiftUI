#if os(iOS)
import SwiftUI
import Kingfisher

struct ProfilePanelView: View {
    @Bindable var accountStore: AccountStore
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) var themeManager
    @Binding var isPresented: Bool
    @State private var showingExportSheet = false
    @State private var showingLogoutAlert = false
    @State private var showingClearCacheAlert = false
    @State private var refreshTokenToExport: String = ""
    @State private var cacheSize: String = "计算中..."
    @State private var path = NavigationPath()
    @State private var showingAuthView = false

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if accountStore.isLoggedIn, let account = accountStore.currentAccount {
                    Section {
                        headerView(account: account)
                    }

                    Section {
                        NavigationLink(value: ProfileDestination.browseHistory) {
                            Label("浏览历史", systemImage: "clock")
                        }

                        NavigationLink(value: ProfileDestination.downloadTasks) {
                            Label("下载任务", systemImage: "arrow.down.circle")
                        }

                        NavigationLink(value: ProfileDestination.dataExport) {
                            Label("数据导入/导出", systemImage: "square.and.arrow.down.on.square")
                        }

                        NavigationLink(value: ProfileDestination.settings) {
                            Label("设置", systemImage: "gearshape")
                        }
                    }

                    Section("账户信息") {
                        HStack {
                            Label("用户 ID", systemImage: "person.badge.shield.checkmark")
                            Spacer()
                            Text(account.userId)
                                .foregroundColor(.secondary)
                            Button(action: { copyToClipboard(account.userId) }) {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }

                        if !account.mailAddress.isEmpty {
                            HStack {
                                Label("邮箱", systemImage: "envelope")
                                Spacer()
                                Text(account.mailAddress)
                                    .foregroundColor(.secondary)
                                Button(action: { copyToClipboard(account.mailAddress) }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        Button(action: {
                            refreshTokenToExport = account.refreshToken
                            showingExportSheet = true
                        }) {
                            Label("导出 Token", systemImage: "key")
                        }
                    }

                    Section("切换账号") {
                        ForEach(accountStore.accounts) { acc in
                            Button(action: {
                                if acc.userId != account.userId {
                                    Task {
                                        await accountStore.switchAccount(acc)
                                    }
                                }
                            }) {
                                HStack {
                                    CachedAsyncImage(urlString: acc.userImage, idealWidth: 32)
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading) {
                                        Text(acc.name)
                                            .font(.body)
                                        Text("@\(acc.account)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    if acc.userId == account.userId {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: { showingAuthView = true }) {
                            Label("登录另一个账号...", systemImage: "person.badge.plus")
                        }
                    }

                     Section("通用") {
                         HStack {
                             Label("图片缓存", systemImage: "photo")
                             Spacer()
                             Text(cacheSize)
                                 .foregroundColor(.secondary)
                             Button(action: { showingClearCacheAlert = true }) {
                                 Image(systemName: "trash")
                             }
                             .buttonStyle(.borderless)
                         }

                         NavigationLink(value: ProfileDestination.about) {
                             Label("关于", systemImage: "info.circle")
                         }

                         Button(role: .destructive, action: { showingLogoutAlert = true }) {
                             Label("登出", systemImage: "power.circle.fill")
                         }
                     }
                } else {
                    guestContent
                }
            }
            .navigationTitle(accountStore.isLoggedIn ? "我的" : "设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                ExportTokenSheet(token: refreshTokenToExport) {
                    copyToClipboard(refreshTokenToExport)
                }
            }
            .sheet(isPresented: $showingAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
            }
            .alert("确认登出", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("登出", role: .destructive) {
                    logout()
                }
            } message: {
                Text("您确定要退出当前账号吗？")
            }
            .alert("确认清空缓存", isPresented: $showingClearCacheAlert) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) {
                    Task { await clearCache() }
                }
            } message: {
                Text("您确定要清空所有图片缓存吗？此操作不可撤销。")
            }
            .task {
                await loadCacheSize()
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case .userDetail(let userId):
                    UserDetailView(userId: userId)
                case .browseHistory:
                    BrowseHistoryView()
                case .settings:
                    ProfileSettingView(isPresented: $isPresented)
                case .downloadTasks:
                    DownloadTasksView()
                case .blockSettings:
                    BlockSettingView()
                case .translationSettings:
                    TranslationSettingView()
                case .downloadSettings:
                    DownloadSettingView()
                case .dataExport:
                    DataExportView()
                case .about:
                    AboutSettingsView()
                case .appearance:
                    ThemeSettingsView()
                }
            }
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var guestContent: some View {
        Section {
            HStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("游客")
                        .font(.headline)
                    Text("登录以同步收藏和关注")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("登录") {
                    showingAuthView = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }

        if !accountStore.accounts.isEmpty {
            Section("切换账号") {
                ForEach(accountStore.accounts) { acc in
                    Button(action: {
                        Task {
                            await accountStore.switchAccount(acc)
                        }
                    }) {
                        HStack {
                            CachedAsyncImage(urlString: acc.userImage, idealWidth: 32)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())

                            VStack(alignment: .leading) {
                                Text(acc.name)
                                    .font(.body)
                                Text("@\(acc.account)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        Section {
            NavigationLink(value: ProfileDestination.settings) {
                Label("设置", systemImage: "gearshape")
            }

            HStack {
                Label("图片缓存", systemImage: "photo")
                Spacer()
                Text(cacheSize)
                    .foregroundColor(.secondary)
                Button(action: { showingClearCacheAlert = true }) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func headerView(account: AccountPersist) -> some View {
        HStack(spacing: 16) {
            Button(action: {
                isPresented = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    accountStore.requestNavigation(.userDetail(account.userId))
                }
            }) {
                CachedAsyncImage(urlString: account.userImage, idealWidth: 60, expiration: DefaultCacheExpiration.myAvatar)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(account.name.isEmpty ? "Pixiv 用户" : account.name)
                    .font(.headline)

                Text("@\(account.account)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if account.isPremium == 1 {
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func logout() {
        Task {
            try? await accountStore.logout()
        }
    }

    private func loadCacheSize() async {
        do {
            let size = try await Kingfisher.ImageCache.default.diskStorageSize
            cacheSize = formatSize(Int(size))
        } catch {
            cacheSize = "获取失败"
        }
    }

    private func clearCache() async {
        Kingfisher.ImageCache.default.clearMemoryCache()
        await Kingfisher.ImageCache.default.clearDiskCache()
        await loadCacheSize()
    }

    private func formatSize(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1024 / 1024
        if mb > 1024 {
            return String(format: "%.2f GB", mb / 1024)
        } else {
            return String(format: "%.2f MB", mb)
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}

struct ExportTokenSheet: View {
    let token: String
    let onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isCopied = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                    .padding(.top, 32)

                Text("Refresh Token")
                    .font(.headline)

                Text("此 Token 用于重新登录，请妥善保管")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                ScrollView {
                    Text(token)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.95))
                        .cornerRadius(8)
                }
                .frame(maxHeight: 150)

                Button(action: {
                    onCopy()
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { isCopied = false }
                }) {
                    Label(isCopied ? "已复制" : "复制 Token", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isCopied ? Color.green : Color.blue)
                        .cornerRadius(12)
                        .foregroundColor(.white)
                }
                .disabled(isCopied)

                Spacer()
            }
            .padding()
            .navigationTitle("导出 Token")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
#endif
