import SwiftUI
import Foundation
import Combine
import SwiftData

#if os(macOS)
import AppKit
#endif

final class SettingsWindowManager: ObservableObject {
    static let shared = SettingsWindowManager()

    @Published var isVisible = false

    #if os(macOS)
    private var window: NSWindow?
    #endif

    private init() {}

    #if os(macOS)
    func show() {
        if window == nil {
            let view = SettingsContainerView()
                .environment(AccountStore.shared)
                .environment(UserSettingStore.shared)
                .modelContainer(DataContainer.shared.modelContainer)

            let hostingController = NSHostingController(rootView: view)

            // 创建窗口，初始尺寸与视图最小尺寸一致
            let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            let newWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
                                   styleMask: styleMask,
                                   backing: .buffered,
                                   defer: false)

            newWindow.contentViewController = hostingController
            newWindow.title = "设置"
            newWindow.isReleasedWhenClosed = false
            newWindow.minSize = NSSize(width: 700, height: 500)

            // 基础样式配置
            newWindow.titleVisibility = .hidden
            newWindow.titlebarAppearsTransparent = true
            newWindow.isMovableByWindowBackground = true

            // 异步配置 Toolbar 和显示窗口，以避免 "layoutSubtreeIfNeeded" 递归警告
            DispatchQueue.main.async {
                let toolbar = NSToolbar(identifier: "SettingsToolbar")
                toolbar.allowsUserCustomization = false
                toolbar.autosavesConfiguration = false
                toolbar.displayMode = .iconOnly
                newWindow.toolbar = toolbar
                newWindow.toolbarStyle = .unified
                newWindow.titlebarSeparatorStyle = .none

                newWindow.center()
                newWindow.makeKeyAndOrderFront(nil)
            }

            self.window = newWindow
        } else {
            window?.makeKeyAndOrderFront(nil)
        }
        isVisible = true
    }

    func hide() {
        window?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
    #else
    func show() {}
    func hide() {}
    func toggle() {}
    #endif
}
