import SwiftUI

struct ThemeSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) var themeManager
    @State private var colorSchemeMode: Int = 0
    @State private var showingColorPicker = false
    @State private var customColor: Color = .blue

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
                    let isSelected: Bool = {
                        if theme.isCustom {
                            return userSettingStore.userSetting.isCustomTheme
                        } else {
                            return !userSettingStore.userSetting.isCustomTheme && theme.matches(seedColor: userSettingStore.userSetting.seedColor)
                        }
                    }()

                    let displayTheme = theme.isCustom
                        ? ThemeColor(id: theme.id, nameKey: theme.nameKey, hex: userSettingStore.userSetting.customThemeColor, isCustom: true)
                        : theme

                    ThemeColorCard(
                        theme: displayTheme,
                        isSelected: isSelected
                    ) {
                        if theme.isCustom {
                            if isSelected {
                                customColor = Color(hex: userSettingStore.userSetting.customThemeColor)
                                showingColorPicker = true
                            } else {
                                themeManager.setThemeColor(displayTheme.hex, isCustom: true)
                            }
                        } else {
                            themeManager.setThemeColor(displayTheme.hex, isCustom: false)
                        }
                    }
                    .contextMenu {
                        if theme.isCustom {
                            Button {
                                customColor = Color(hex: userSettingStore.userSetting.customThemeColor)
                                showingColorPicker = true
                            } label: {
                                Label(String(localized: "自定义颜色"), systemImage: "paintpalette")
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .sheet(isPresented: $showingColorPicker) {
            NavigationStack {
                Form {
                    Section {
                        ColorPicker(String(localized: "选择颜色"), selection: $customColor, supportsOpacity: false)
                    }
                }
                .navigationTitle(String(localized: "自定义主题色"))
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "确定")) {
                            themeManager.setThemeColor(customColor.hex, isCustom: true)
                            showingColorPicker = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "取消")) {
                            showingColorPicker = false
                        }
                    }
                }
            }
            #if os(macOS)
            .frame(width: 300, height: 150)
            #else
            .presentationDetents([.height(200)])
            #endif
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
            .tint(.secondary)
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
