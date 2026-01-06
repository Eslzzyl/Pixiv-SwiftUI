import SwiftUI

struct NovelReaderSettingsView: View {
    @Bindable var store: NovelReaderStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                fontSizeSection
                lineHeightSection
                horizontalPaddingSection
                themeSection
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

    private var fontSizeSection: some View {
        Section {
            HStack {
                Text("A")
                    .font(.system(size: 12))

                Slider(
                    value: $store.settings.fontSize,
                    in: 12...24,
                    step: 1
                )

                Text("A")
                    .font(.system(size: 20))
            }

            HStack {
                Text("当前字号")
                Spacer()
                Text("\(Int(store.settings.fontSize))pt")
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
                    value: $store.settings.lineHeight,
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
                Text(String(format: "%.1f", store.settings.lineHeight))
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("行距")
        } footer: {
            Text("调整段落之间的行距大小")
        }
    }

    private var horizontalPaddingSection: some View {
        Section {
            HStack {
                Image(systemName: "arrow.left.and.right")
                    .foregroundColor(.secondary)

                Slider(
                    value: $store.settings.horizontalPadding,
                    in: 0...40,
                    step: 1
                )

                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("当前边距")
                Spacer()
                Text("\(Int(store.settings.horizontalPadding))pt")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("左右边距")
        } footer: {
            Text("调整小说正文的左右边距")
        }
    }

    private var themeSection: some View {
        Section {
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

    private func resetToDefaults() {
        store.settings.fontSize = 16
        store.settings.lineHeight = 1.8
        store.settings.horizontalPadding = 16
        store.settings.theme = .system
    }
}

#Preview {
    NovelReaderSettingsView(store: NovelReaderStore(novelId: 12345))
}
