import SwiftUI

/// 我的页面
struct ProfileView: View {
    @Bindable var accountStore: AccountStore
    @State private var showingExportSheet = false
    @State private var showingSettingView = false
    @State private var showingLogoutAlert = false
    @State private var refreshTokenToExport: String = ""

    var body: some View {
        NavigationStack {
            List {
                userInfoSection
                actionButtonsSection
                menuItemsSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .sheet(isPresented: $showingExportSheet) {
                ExportTokenSheet(token: refreshTokenToExport) {
                    copyToClipboard(refreshTokenToExport)
                }
            }
            .sheet(isPresented: $showingSettingView) {
                ProfileSettingView()
            }
            .alert("确认登出", isPresented: $showingLogoutAlert) {
                Button("取消", role: .cancel) { }
                Button("登出", role: .destructive) {
                    logout()
                }
            } message: {
                Text("您确定要退出当前账号吗？")
            }
            .task {
                await accountStore.refreshCurrentAccount()
            }
        }
    }

    /// 用户信息区域
    private var userInfoSection: some View {
        Section {
            if let account = accountStore.currentAccount {
                NavigationLink(destination: UserDetailView(userId: account.userId)) {
                    HStack(spacing: 16) {
                        CachedAsyncImage(urlString: account.userImage)
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
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("未登录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// 操作按钮区域
    private var actionButtonsSection: some View {
        Section {
            if let account = accountStore.currentAccount {
                Button(action: {
                    refreshTokenToExport = account.refreshToken
                    showingExportSheet = true
                }) {
                    Label("导出 Token", systemImage: "square.and.arrow.up")
                        .foregroundStyle(.primary)
                }
            }

            Button(action: {
                showingSettingView = true
            }) {
                Label("设置", systemImage: "gearshape")
                    .foregroundStyle(.primary)
            }
        }
    }

    /// 菜单项区域
    private var menuItemsSection: some View {
        Section {
            if let account = accountStore.currentAccount {
                LabeledContent {
                    Button(action: { copyToClipboard(account.userId) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                } label: {
                    Label("用户 ID", systemImage: "person.badge.shield.checkmark")
                }

                LabeledContent {
                    Button(action: { copyToClipboard(account.account) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                } label: {
                    Label("账户", systemImage: "at")
                }

                if !account.mailAddress.isEmpty {
                    LabeledContent {
                        Button(action: { copyToClipboard(account.mailAddress) }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    } label: {
                        Label("邮箱", systemImage: "envelope")
                    }
                }
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



/// 导出 Token 弹窗
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

#Preview {
    ProfileView(accountStore: .shared)
}
