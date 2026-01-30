import SwiftUI

struct DownloadSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        Form {
            downloadSettingsSection
        }
        .formStyle(.grouped)
    }

    private var downloadSettingsSection: some View {
        Section {
            LabeledContent(String(localized: "下载画质")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.downloadQuality },
                    set: { try? userSettingStore.setDownloadQuality($0) }
                )) {
                    Text(String(localized: "中等")).tag(0)
                    Text(String(localized: "大图")).tag(1)
                    Text(String(localized: "原图")).tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(minWidth: 180)
                #endif
            }

            LabeledContent(String(localized: "最大并行任务数")) {
                Stepper(
                    "\(userSettingStore.userSetting.maxRunningTask)",
                    value: Binding(
                        get: { userSettingStore.userSetting.maxRunningTask },
                        set: { try? userSettingStore.setMaxRunningTask($0) }
                    ),
                    in: 1...5
                )
            }

            #if os(macOS)
            LabeledContent(String(localized: "按作者创建文件夹")) {
                Toggle("", isOn: Binding(
                    get: { userSettingStore.userSetting.createAuthorFolder },
                    set: { try? userSettingStore.setCreateAuthorFolder($0) }
                ))
                .toggleStyle(.switch)
            }
            #endif

            LabeledContent(String(localized: "保存完成显示提示")) {
                Toggle("", isOn: Binding(
                    get: { userSettingStore.userSetting.showSaveCompleteToast },
                    set: { try? userSettingStore.setShowSaveCompleteToast($0) }
                ))
                #if os(macOS)
                .toggleStyle(.switch)
                #endif
            }
        } header: {
            Text(String(localized: "下载设置"))
        } footer: {
            Text(String(localized: "设置下载相关选项"))
        }
    }
}

#Preview {
    NavigationStack {
        DownloadSettingView()
    }
    .frame(maxWidth: 600)
}
