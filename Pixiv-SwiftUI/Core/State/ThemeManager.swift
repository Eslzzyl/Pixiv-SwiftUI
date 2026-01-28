import SwiftUI
import Observation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var currentColor: Color = Color(hex: 0x0096FA)

    private let userSettingStore: UserSettingStore

    init(userSettingStore: UserSettingStore = .shared) {
        self.userSettingStore = userSettingStore
        updateThemeColor()
    }

    func updateThemeColor() {
        currentColor = Color(hex: userSettingStore.userSetting.seedColor)
    }

    func setThemeColor(_ hex: Int) {
        userSettingStore.userSetting.seedColor = hex
        try? userSettingStore.saveSetting()
        updateThemeColor()
    }

    @MainActor
    func applyThemeMode() {
        let mode = userSettingStore.userSetting.colorSchemeMode
        #if os(iOS)
        let style: UIUserInterfaceStyle = {
            switch mode {
            case 1: return .light
            case 2: return .dark
            default: return .unspecified
            }
        }()
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { $0.overrideUserInterfaceStyle = style }
        #elseif os(macOS)
        let appearance: NSAppearance? = {
            switch mode {
            case 1: return NSAppearance(named: .aqua)
            case 2: return NSAppearance(named: .darkAqua)
            default: return nil
            }
        }()
        NSApp.appearance = appearance
        NSApp.windows.forEach { $0.appearance = appearance }
        #endif
    }
}
