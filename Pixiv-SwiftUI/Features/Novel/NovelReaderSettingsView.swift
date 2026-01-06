import SwiftUI

struct NovelReaderSettingsView: View {
    @Bindable var store: NovelReaderStore
    @Environment(\.dismiss) private var dismiss
    @State private var fontSize: CGFloat
    @State private var lineHeight: CGFloat
    @State private var selectedTheme: ReaderTheme

    init(store: NovelReaderStore) {
        self.store = store
        _fontSize = State(initialValue: store.settings.fontSize)
        _lineHeight = State(initialValue: store.settings.lineHeight)
        _selectedTheme = State(initialValue: store.settings.theme)
    }

    var body: some View {
        NavigationStack {
            Form {
                fontSizeSection
                lineHeightSection
                themeSection
                resetSection
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        saveSettings()
                        dismiss()
                    }
                }
            }
        }
    }

    private var fontSizeSection: some View {
        Section {
            HStack {
                Text("A")
                    .font(.system(size: 12))

                Slider(
                    value: $fontSize,
                    in: 12...24,
                    step: 1
                )

                Text("A")
                    .font(.system(size: 20))
            }

            HStack {
                Text("当前字号")
                Spacer()
                Text("\(Int(fontSize))pt")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("字体大小")
        } footer: {
            Text("调整小说正文字体的大小")
        }
    }

    private var lineHeightSection: some View {
        Section {
            HStack {
                Image(systemName: "text.alignleft")
                    .foregroundColor(.secondary)

                Slider(
                    value: $lineHeight,
                    in: 1.2...2.2,
                    step: 0.1
                )

                Image(systemName: "text.alignleft")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("当前行距")
                Spacer()
                Text(String(format: "%.1f", lineHeight))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("行距")
        } footer: {
            Text("调整段落之间的行距大小")
        }
    }

    private var themeSection: some View {
        Section {
            ForEach(ReaderTheme.allCases, id: \.self) { theme in
                Button(action: {
                    selectedTheme = theme
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

                        if selectedTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        } header: {
            Text("阅读主题")
        } footer: {
            Text("选择适合当前环境的阅读主题")
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

    private func saveSettings() {
        var newSettings = store.settings
        newSettings.fontSize = fontSize
        newSettings.lineHeight = lineHeight
        newSettings.theme = selectedTheme
        store.updateSettings(newSettings)
    }

    private func resetToDefaults() {
        fontSize = 16
        lineHeight = 1.8
        selectedTheme = .system
    }
}

#Preview {
    NovelReaderSettingsView(store: NovelReaderStore(novelId: 12345))
}
