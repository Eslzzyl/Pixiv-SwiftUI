import SwiftUI

/// 我的页面
struct ProfileView: View {
    @Bindable var accountStore: AccountStore
    @State private var showingExportSheet = false
    @State private var showingSettingView = false
    @State private var refreshTokenToExport: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    userInfoSection
                    actionButtonsSection
                    Divider()
                    menuItemsSection
                }
                .padding()
            }
            .background(Color(red: 0.97, green: 0.97, blue: 0.97))
            .navigationTitle("我的")
            .sheet(isPresented: $showingExportSheet) {
                ExportTokenSheet(token: refreshTokenToExport) {
                    copyToClipboard(refreshTokenToExport)
                }
            }
            .sheet(isPresented: $showingSettingView) {
                ProfileSettingView()
            }
        }
    }

    /// 用户信息区域
    private var userInfoSection: some View {
        VStack(spacing: 16) {
            if let account = accountStore.currentAccount {
                CachedAsyncImage(urlString: account.userImage)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)

                VStack(spacing: 4) {
                    Text(account.name.isEmpty ? "Pixiv 用户" : account.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("ID: \(account.userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if account.isPremium == 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Premium")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(12)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 24)
    }

    /// 操作按钮区域
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            if let account = accountStore.currentAccount {
                Button(action: {
                    refreshTokenToExport = account.refreshToken
                    showingExportSheet = true
                }) {
                    Label("导出 Token", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.blue)
                }

                Button(action: {
                    showingSettingView = true
                }) {
                    Label("设置", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                }
            }
        }
    }

    /// 菜单项区域
    private var menuItemsSection: some View {
        VStack(spacing: 0) {
            if let account = accountStore.currentAccount {
                MenuItemRow(
                    icon: "person.badge.shield.checkmark",
                    title: "用户 ID",
                    subtitle: account.userId,
                    action: { copyToClipboard(account.userId) }
                )

                MenuItemRow(
                    icon: "at",
                    title: "账户",
                    subtitle: account.account,
                    action: { copyToClipboard(account.account) }
                )

                if !account.mailAddress.isEmpty {
                    MenuItemRow(
                        icon: "envelope",
                        title: "邮箱",
                        subtitle: account.mailAddress,
                        action: { copyToClipboard(account.mailAddress) }
                    )
                }
            }

            MenuItemRow(
                icon: "power.circle.fill",
                title: "登出",
                subtitle: nil,
                isDestructive: true,
                action: logout
            )
        }
        .background(Color(white: 0.97))
        .cornerRadius(12)
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

/// 菜单项行
struct MenuItemRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundColor(isDestructive ? .red : .blue)

                Text(title)
                    .foregroundColor(isDestructive ? .red : .primary)

                Spacer()

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
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
