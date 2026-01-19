import SwiftUI

struct DownloadSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        Form {
            downloadSettingsSection
        }
        .formStyle(.grouped)
        .navigationTitle("下载设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var downloadSettingsSection: some View {
        Section {
            LabeledContent("下载画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.downloadQuality },
                    set: { try? userSettingStore.setDownloadQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                .frame(width: 100)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }

            LabeledContent("最大并行任务数") {
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
            LabeledContent("按作者创建文件夹") {
                Toggle("", isOn: Binding(
                    get: { userSettingStore.userSetting.createAuthorFolder },
                    set: { try? userSettingStore.setCreateAuthorFolder($0) }
                ))
            }
            #endif

            LabeledContent("保存完成显示提示") {
                Toggle("", isOn: Binding(
                    get: { userSettingStore.userSetting.showSaveCompleteToast },
                    set: { try? userSettingStore.setShowSaveCompleteToast($0) }
                ))
            }
        } header: {
            Text("下载设置")
        } footer: {
            Text("设置下载相关选项")
        }
    }
}

#Preview {
    NavigationStack {
        DownloadSettingView()
    }
    .frame(maxWidth: 600)
}
