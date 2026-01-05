import SwiftUI

struct DownloadSettingView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    
    var body: some View {
        Form {
            downloadSettingsSection
        }
        .navigationTitle("下载设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private var downloadSettingsSection: some View {
        Section {
            Picker("下载画质", selection: Binding(
                get: { userSettingStore.userSetting.downloadQuality },
                set: { try? userSettingStore.setDownloadQuality($0) }
            )) {
                Text("中等").tag(0)
                Text("大图").tag(1)
                Text("原图").tag(2)
            }
            
            Stepper(value: Binding(
                get: { userSettingStore.userSetting.maxRunningTask },
                set: { try? userSettingStore.setMaxRunningTask($0) }
            ), in: 1...5) {
                HStack {
                    Text("最大并行任务数")
                    Spacer()
                    Text("\(userSettingStore.userSetting.maxRunningTask)")
                        .foregroundColor(.secondary)
                }
            }
            
            #if os(macOS)
            Toggle("按作者创建文件夹", isOn: Binding(
                get: { userSettingStore.userSetting.createAuthorFolder },
                set: { try? userSettingStore.setCreateAuthorFolder($0) }
            ))
            #endif
            
            Toggle("保存完成显示提示", isOn: Binding(
                get: { userSettingStore.userSetting.showSaveCompleteToast },
                set: { try? userSettingStore.setShowSaveCompleteToast($0) }
            ))
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
}
