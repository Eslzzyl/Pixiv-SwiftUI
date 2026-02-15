import SwiftUI

#if os(macOS)
struct FileMenuCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(String(localized: "新建窗口")) {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .importExport) {
            Button(String(localized: "导入数据...")) { }
                .disabled(true)

            Button(String(localized: "导出数据...")) { }
                .disabled(true)
        }
    }
}
#endif
