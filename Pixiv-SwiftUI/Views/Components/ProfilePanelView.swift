import SwiftUI
import Kingfisher

struct ProfilePanelView: View {
    @Bindable var accountStore: AccountStore
    @Environment(UserSettingStore.self) var userSettingStore
    @Binding var isPresented: Bool
    @State private var showingExportSheet = false
    @State private var showingLogoutAlert = false
    @State private var showingClearCacheAlert = false
    @State private var refreshTokenToExport: String = ""
    @State private var cacheSize: String = "计算中..."
    @State private var path = NavigationPath()

    enum ProfileDestination: Hashable {
        case userDetail(String)
        case browseHistory
        case settings
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                userInfoSection
                actionButtonsSection
                menuItemsSection
            }
            .navigationTitle("我的")
            #if os(iOS)
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
            #else
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.plain)
                }
            }
            #endif
            .sheet(isPresented: $showingExportSheet) {
                ExportTokenSheet(token: refreshTokenToExport) {
                    copyToClipboard(refreshTokenToExport)
                }
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
                }
            }
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    private var userInfoSection: some View {
        Section {
            if let account = accountStore.currentAccount {
                Button(action: {
                    isPresented = false
                    // 延迟一小会儿确保 Sheet 开始关闭后再触发导航请求
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        accountStore.requestNavigation(.userDetail(account.userId))
                    }
                }) {
                    HStack(spacing: 16) {
                        CachedAsyncImage(urlString: account.userImage, idealWidth: 60, expiration: DefaultCacheExpiration.myAvatar)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(account.name.isEmpty ? "Pixiv 用户" : account.name)
                                .font(.headline)

                            Text("ID: \(account.userId)")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if account.isPremium == 1 {
                                Text("Premium")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.yellow)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var actionButtonsSection: some View {
        Section {
            if let account = accountStore.currentAccount {
                Button(action: {
                    refreshTokenToExport = account.refreshToken
                    showingExportSheet = true
                }) {
                    Label("导出 Token", systemImage: "square.and.arrow.up")
                }

                NavigationLink(value: ProfileDestination.settings) {
                    Label("设置", systemImage: "gearshape")
                }

                NavigationLink(value: ProfileDestination.browseHistory) {
                    Label("浏览历史", systemImage: "clock")
                }
            }
        }
    }

    private var menuItemsSection: some View {
        Section {
            if let account = accountStore.currentAccount {
                HStack {
                    Label("用户 ID", systemImage: "person.badge.shield.checkmark")
                    Spacer()
                    Text(account.userId)
                        .foregroundColor(.secondary)
                    Button(action: { copyToClipboard(account.userId) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.body)
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    Label("账户", systemImage: "at")
                    Spacer()
                    Text(account.account)
                        .foregroundColor(.secondary)
                    Button(action: { copyToClipboard(account.account) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.body)
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
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                Label("图片缓存", systemImage: "photo")
                Spacer()
                Text(cacheSize)
                    .foregroundColor(.secondary)
                Button(action: {
                    showingClearCacheAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.body)
                }
                .buttonStyle(.borderless)
            }

            Button(role: .destructive, action: { showingLogoutAlert = true }) {
                Label("登出", systemImage: "power.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private func logout() {
        try? accountStore.logout()
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
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
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
