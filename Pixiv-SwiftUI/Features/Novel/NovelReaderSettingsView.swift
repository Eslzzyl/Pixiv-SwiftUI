import SwiftUI

struct NovelReaderSettingsView: View {
    @Bindable var store: NovelReaderStore
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        #if os(macOS)
        Form {
            layoutSection
            themeSection
            translationDisplayModeSection
            resetSection
        }
        .formStyle(.grouped)
        .frame(width: 300, height: 400)
        #else
        NavigationStack {
            Form {
                layoutSection
                themeSection
                translationDisplayModeSection
                resetSection
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    private var layoutSection: some View {
        Section("排版") {
            fontFamilyPicker
            fontSizeRow
            lineHeightRow
            horizontalPaddingRow
            firstLineIndentRow
        }
    }

    private var fontFamilyPicker: some View {
        Picker("字体", selection: $store.settings.fontFamily) {
            ForEach(ReaderFontFamily.allCases, id: \.self) { family in
                Text(family.displayName).tag(family)
            }
        }
    }

    private var fontSizeRow: some View {
        HStack {
            Text("字号")
                .frame(width: 60, alignment: .leading)
            Slider(
                value: Binding(
                    get: { store.settings.fontSize },
                    set: { store.settings.fontSize = $0.rounded() }
                ),
                in: 12...24
            )
            Text("\(Int(store.settings.fontSize))pt")
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var lineHeightRow: some View {
        HStack {
            Text("行距")
                .frame(width: 60, alignment: .leading)
            Slider(
                value: $store.settings.lineHeight,
                in: 1.2...2.2
            )
            Text(String(format: "%.1f", store.settings.lineHeight))
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var horizontalPaddingRow: some View {
        HStack {
            Text("边距")
                .frame(width: 60, alignment: .leading)
            Slider(
                value: Binding(
                    get: { store.settings.horizontalPadding },
                    set: { store.settings.horizontalPadding = $0.rounded() }
                ),
                in: 0...40
            )
            Text("\(Int(store.settings.horizontalPadding))")
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
                .frame(width: 50, alignment: .trailing)
        }
    }

    private var firstLineIndentRow: some View {
        HStack {
            Text("首行缩进")
                .frame(width: 60, alignment: .leading)
            Spacer()
            #if os(macOS)
            Toggle("", isOn: $store.settings.firstLineIndent)
                .toggleStyle(.switch)
                .labelsHidden()
            #else
            Toggle("", isOn: $store.settings.firstLineIndent)
                .labelsHidden()
            #endif
        }
        .padding(.vertical, 2)
    }

    private var themeSection: some View {
        Section("主题") {
            ForEach(ReaderTheme.allCases, id: \.self) { theme in
                Button(action: {
                    store.settings.theme = theme
                }) {
                    HStack {
                        Circle()
                            .fill(themeColor(theme))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        Text(theme.displayName)
                            .foregroundColor(.primary)

                        Spacer()

                        if store.settings.theme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(themeManager.currentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var translationDisplayModeSection: some View {
        Section("译文") {
            Picker("显示模式", selection: $store.settings.translationDisplayMode) {
                ForEach(TranslationDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    private var resetSection: some View {
        Section {
            Button(action: resetToDefaults) {
                HStack {
                    Spacer()
                    Text("恢复默认设置")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func themeColor(_ theme: ReaderTheme) -> Color {
        switch theme {
        case .light:
            return .white
        case .dark:
            return Color(red: 0.11, green: 0.11, blue: 0.11)
        case .system:
            return Color.clear
        case .sepia:
            return Color(red: 0.96, green: 0.94, blue: 0.88)
        }
    }

    private func resetToDefaults() {
        store.settings.fontSize = 16
        store.settings.lineHeight = 1.8
        store.settings.fontFamily = .default
        store.settings.horizontalPadding = 16
        store.settings.theme = .system
        store.settings.translationDisplayMode = .translationOnly
        store.settings.firstLineIndent = true
    }
}

#Preview {
    NovelReaderSettingsView(store: NovelReaderStore(novelId: 12345))
}
