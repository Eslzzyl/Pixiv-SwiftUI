import SwiftUI

struct AppCommands: Commands {
    let accountStore: AccountStore

    var body: some Commands {
        SidebarCommands()

        #if os(macOS)
        CommandGroup(replacing: .appSettings) {
            Button("设置...") {
                SettingsWindowManager.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        #endif

        CommandMenu("账户") {
            Section {
                if accountStore.accounts.isEmpty {
                    Button("未登录") { }
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

            Button("添加账号...") {
                NotificationCenter.default.post(name: NSNotification.Name("ShowLoginSheet"), object: nil)
            }

            Button("退出登录") {
                Task {
                    try? await accountStore.logout()
                }
            }
            .disabled(!accountStore.isLoggedIn)
            .keyboardShortcut("L", modifiers: [.command, .shift])
        }
    }
}
