import SwiftUI

#if os(macOS)
struct ToolsMenuCommands: Commands {
    var body: some Commands {
        CommandMenu(String(localized: "工具")) {
            Button(String(localized: "下载管理")) {
                NotificationCenter.default.post(name: .navigateToDownloads, object: nil)
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button(String(localized: "清除缓存")) {
                NotificationCenter.default.post(name: .clearCache, object: nil)
            }

            Button(String(localized: "清除历史记录")) {
                NotificationCenter.default.post(name: .clearHistory, object: nil)
            }
        }
    }
}
#endif
