import SwiftUI

struct AccountCommands: Commands {
    let accountStore: AccountStore

    var body: some Commands {
        CommandMenu(String(localized: "账户")) {
            Section {
                if accountStore.accounts.isEmpty {
                    Button(String(localized: "未登录")) { }
                        .disabled(true)
                } else {
                    ForEach(accountStore.accounts, id: \.userId) { account in
                        Button {
                            Task {
                                await accountStore.switchAccount(account)
                            }
                        } label: {
                            if account.userId == accountStore.currentUserId {
                                Text("✓ \(account.name)")
                            } else {
                                Text(account.name)
                            }
                        }
                    }
                }
            }

            Divider()

            Button(String(localized: "添加账号...")) {
                NotificationCenter.default.post(name: .showLoginSheet, object: nil)
            }

            Button(String(localized: "退出登录")) {
                Task {
                    try? await accountStore.logout()
                }
            }
            .disabled(!accountStore.isLoggedIn)
            .keyboardShortcut("L", modifiers: [.command, .shift])

            Divider()

            #if os(macOS)
            Button(String(localized: "个人资料")) {
                NotificationCenter.default.post(name: .navigateToProfile, object: nil)
            }
            .keyboardShortcut("i", modifiers: .command)
            .disabled(!accountStore.isLoggedIn)
            #endif
        }
    }
}
