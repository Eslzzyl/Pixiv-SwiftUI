import SwiftUI

struct NovelReaderSettingsView: View {
    @Bindable var store: NovelReaderStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                layoutSection
                themeSection
                translationDisplayModeSection
                resetSection
            }
            .navigationTitle("阅读设置")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var layoutSection: some View {
        Section("排版") {
            fontSizeRow
            lineHeightRow
            horizontalPaddingRow
            firstLineIndentRow
        }
    }

    private var fontSizeRow: some View {
        HStack {
            Text("字号")
                .frame(width: 60, alignment: .leading)
            Slider(
                value: $store.settings.fontSize,
                in: 12...24,
                step: 1
            )
            Text("\(Int(store.settings.fontSize))pt")
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .trailing)
        }
    }

    private var lineHeightRow: some View {
        HStack {
            Text("行距")
                .frame(width: 60, alignment: .leading)
            Slider(
                value: $store.settings.lineHeight,
                in: 1.2...2.2,
                step: 0.1
            )
            Text(String(format: "%.1f", store.settings.lineHeight))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var horizontalPaddingRow: some View {
        HStack {
            Text("边距")
                .frame(width: 60, alignment: .leading)
            Slider(
                value: $store.settings.horizontalPadding,
                in: 0...40,
                step: 1
            )
            Text("\(Int(store.settings.horizontalPadding))")
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private var firstLineIndentRow: some View {
        HStack {
            Text("首行缩进")
            Spacer()
            Toggle("", isOn: $store.settings.firstLineIndent)
                .labelsHidden()
        }
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
                                .foregroundColor(.blue)
                        }
                    }
                }
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
        store.settings.horizontalPadding = 16
        store.settings.theme = .system
        store.settings.translationDisplayMode = .translationOnly
        store.settings.firstLineIndent = true
    }
}

#Preview {
    NovelReaderSettingsView(store: NovelReaderStore(novelId: 12345))
}
