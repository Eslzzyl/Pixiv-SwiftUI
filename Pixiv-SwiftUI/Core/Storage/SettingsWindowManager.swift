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
            window = NSWindow(contentViewController: hostingController)
            window?.title = "设置"
            window?.setContentSize(NSSize(width: 700, height: 600))
            window?.minSize = NSSize(width: 600, height: 500)
            window?.isReleasedWhenClosed = false
            window?.styleMask.insert(.resizable)
        }
        window?.makeKeyAndOrderFront(nil)
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
