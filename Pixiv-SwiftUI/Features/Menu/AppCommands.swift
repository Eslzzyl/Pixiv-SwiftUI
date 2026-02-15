import SwiftUI

struct AppCommands: Commands {
    let accountStore: AccountStore

    var body: some Commands {
        SidebarCommands()

        #if os(macOS)
        AppMenuCommands()
        FileMenuCommands()
        ViewMenuCommands()
        ToolsMenuCommands()
        HelpMenuCommands()
        #endif

        AccountCommands(accountStore: accountStore)

        #if os(macOS)
        CommandGroup(after: .pasteboard) {
            Button(String(localized: "查找")) {
                NotificationCenter.default.post(name: .navigateToSearch, object: nil)
            }
            .keyboardShortcut("f", modifiers: .command)
        }
        #endif
    }
}
