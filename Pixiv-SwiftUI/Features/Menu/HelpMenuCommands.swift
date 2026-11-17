import SwiftUI

#if os(macOS)
struct HelpMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(String(localized: "Pixiv-SwiftUI 帮助")) {
                open(AppLinks.wiki)
            }
            .keyboardShortcut("?", modifiers: .command)

            Button(String(localized: "反馈问题")) {
                open(AppLinks.issues)
            }

            Button(String(localized: "查看更新")) {
                open(AppLinks.releases)
            }
        }
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
