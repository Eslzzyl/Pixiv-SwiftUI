import SwiftUI

struct PrivacySettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        Form {
            contentFilterSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "过滤"))
    }

    private var contentFilterSection: some View {
        Section {
            LabeledContent(String(localized: "R18 显示模式")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.r18DisplayMode },
                    set: { try? userSettingStore.setR18DisplayMode($0) }
                )) {
                    Text(String(localized: "正常显示")).tag(0)
                    Text(String(localized: "模糊显示")).tag(1)
                    Text(String(localized: "屏蔽")).tag(2)
                    Text(String(localized: "仅显示R18")).tag(3)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            LabeledContent(String(localized: "AI 显示模式")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.aiDisplayMode },
                    set: { try? userSettingStore.setAIDisplayMode($0) }
                )) {
                    Text(String(localized: "正常显示")).tag(0)
                    Text(String(localized: "屏蔽")).tag(1)
                    Text(String(localized: "仅显示AI作品")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "内容过滤"))
        } footer: {
            Text(String(localized: "设置如何显示 R18 和 AI 生成的内容"))
        }
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
