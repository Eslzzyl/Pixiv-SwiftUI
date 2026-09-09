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

    var currentColor: Color = ThemeColors.defaultColor.color

    var onCurrentColor: Color {
        currentColor.contrastingTextColor
    }

    private let userSettingStore: UserSettingStore

    init(userSettingStore: UserSettingStore = .shared) {
        self.userSettingStore = userSettingStore
        // updateThemeColor() 延迟到 UserSetting 异步加载完成后调用
        // 参见 AppInitializer.performInitialization()
    }

    func updateThemeColor() {
        if userSettingStore.userSetting.isCustomTheme {
            let customHex = userSettingStore.userSetting.customThemeColor
            let baseColor = Color(hex: customHex)
            let lightHex = baseColor.isLight ? baseColor.adjusted(brightnessDelta: -0.22, saturationMultiplier: 1.15).hex : customHex
            let darkHex = (!baseColor.isLight && baseColor.relativeLuminance < 0.2)
                ? baseColor.adjusted(brightnessDelta: 0.22, saturationMultiplier: 0.9).hex
                : customHex
            currentColor = Color(lightHex: lightHex, darkHex: darkHex)
        } else {
            let seedHex = userSettingStore.userSetting.seedColor
            if let theme = ThemeColors.find(byHex: seedHex) {
                currentColor = theme.color
            } else {
                currentColor = ThemeColors.defaultColor.color
            }
        }
    }

    func setThemeColor(_ hex: Int, isCustom: Bool = false) {
        if isCustom {
            userSettingStore.userSetting.isCustomTheme = true
            userSettingStore.userSetting.customThemeColor = hex
        } else {
            userSettingStore.userSetting.isCustomTheme = false
            userSettingStore.userSetting.seedColor = hex
        }
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
