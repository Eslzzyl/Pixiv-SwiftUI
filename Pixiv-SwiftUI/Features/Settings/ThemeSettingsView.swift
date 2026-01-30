import SwiftUI

struct ThemeSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) var themeManager
    @State private var colorSchemeMode: Int = 0

    private var preferredColorScheme: ColorScheme? {
        switch colorSchemeMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        Form {
            themeColorSection
            themeModeSection
        }
        .formStyle(.grouped)
        .preferredColorScheme(preferredColorScheme)
        .navigationTitle(String(localized: "外观"))
        .onAppear {
            colorSchemeMode = userSettingStore.userSetting.colorSchemeMode
        }
        .onChange(of: userSettingStore.userSetting.colorSchemeMode) { _, newValue in
            colorSchemeMode = newValue
        }
    }

    private var themeColorSection: some View {
        Section(String(localized: "主题色")) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(ThemeColors.all) { theme in
                    ThemeColorCard(
                        theme: theme,
                        isSelected: userSettingStore.userSetting.seedColor == theme.hex
                    ) {
                        themeManager.setThemeColor(theme.hex)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var themeModeSection: some View {
        Section(String(localized: "主题模式")) {
            Picker(String(localized: "主题模式"), selection: Binding(
                get: { userSettingStore.userSetting.colorSchemeMode },
                set: { mode in
                    try? userSettingStore.setColorSchemeMode(mode)
                }
            )) {
                Text(String(localized: "跟随系统")).tag(0)
                Text(String(localized: "浅色")).tag(1)
                Text(String(localized: "深色")).tag(2)
            }
            #if os(macOS)
            .pickerStyle(.menu)
            #endif
            .help(String(localized: "选择界面主题模式"))
        }
    }
}

#Preview {
    NavigationStack {
        ThemeSettingsView()
            .environment(UserSettingStore.shared)
            .environment(ThemeManager.shared)
    }
}
