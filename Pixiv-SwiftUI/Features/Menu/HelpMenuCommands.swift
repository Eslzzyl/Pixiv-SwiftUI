import SwiftUI

#if os(macOS)
struct HelpMenuCommands: Commands {
    private let githubRepo = "https://github.com/U2FsdGVkX1/Pixiv-SwiftUI"

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button(String(localized: "Pixiv-SwiftUI 帮助")) {
                if let url = URL(string: "\(githubRepo)/wiki") {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("?", modifiers: .command)

            Button(String(localized: "反馈问题")) {
                if let url = URL(string: "\(githubRepo)/issues") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button(String(localized: "查看更新")) {
                if let url = URL(string: "\(githubRepo)/releases") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
#endif
