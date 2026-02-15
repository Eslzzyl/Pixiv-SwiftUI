import SwiftUI

#if os(macOS)
struct AppMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(String(localized: "关于 Pixiv-SwiftUI")) {
                showAboutPanel()
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(String(localized: "设置...")) {
                SettingsWindowManager.shared.show()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }

    private func showAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "Pixiv-SwiftUI"
        alert.informativeText = """
        版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        构建: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")

        一款现代化的 Pixiv 客户端
        支持 iOS 和 macOS
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "确定"))
        alert.runModal()
    }
}
#endif
