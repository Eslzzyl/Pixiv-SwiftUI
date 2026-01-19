import SwiftUI

struct DisplaySettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        Form {
            r18Section
        }
        .formStyle(.grouped)
        .navigationTitle("显示")
    }

    private var r18Section: some View {
        Section {
            LabeledContent("R18 显示模式") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.r18DisplayMode },
                    set: { try? userSettingStore.setR18DisplayMode($0) }
                )) {
                    Text("正常显示").tag(0)
                    Text("模糊显示").tag(1)
                    Text("屏蔽").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text("内容过滤")
        } footer: {
            Text("设置如何显示包含 R18 标签的内容")
        }
    }
}

#Preview {
    NavigationStack {
        DisplaySettingsView()
    }
}
