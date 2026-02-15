import SwiftUI

#if os(macOS)
struct ViewMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .toolbar) {
            Button(String(localized: "刷新")) {
                NotificationCenter.default.post(name: .refreshCurrentPage, object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Divider()

            Button(String(localized: "切换侧边栏")) {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
        }
    }
}
#endif
