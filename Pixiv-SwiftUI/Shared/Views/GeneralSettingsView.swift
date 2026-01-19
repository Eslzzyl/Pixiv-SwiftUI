import SwiftUI

struct GeneralSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        Form {
            imageQualitySection
            layoutSection
        }
        .formStyle(.grouped)
        .navigationTitle("通用")
    }

    private var imageQualitySection: some View {
        Section {
            LabeledContent("列表预览画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.feedPreviewQuality },
                    set: { try? userSettingStore.setFeedPreviewQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }

            LabeledContent("插画详情页画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.pictureQuality },
                    set: { try? userSettingStore.setPictureQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }

            LabeledContent("大图预览画质") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.zoomQuality },
                    set: { try? userSettingStore.setZoomQuality($0) }
                )) {
                    Text("中等").tag(0)
                    Text("大图").tag(1)
                    Text("原图").tag(2)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #else
                .pickerStyle(.segmented)
                .frame(width: 150)
                #endif
            }
        } header: {
            Text("图片质量")
        } footer: {
            Text("中等画质节省流量，大图画质更清晰，原图画质最高清（可能消耗更多流量）")
        }
    }

    private var layoutSection: some View {
        Section {
            LabeledContent("竖屏列数") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.crossCount },
                    set: { try? userSettingStore.setCrossCount($0) }
                )) {
                    Text("1 列").tag(1)
                    Text("2 列").tag(2)
                    Text("3 列").tag(3)
                    Text("4 列").tag(4)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            LabeledContent("横屏列数") {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.hCrossCount },
                    set: { try? userSettingStore.setHCrossCount($0) }
                )) {
                    Text("2 列").tag(2)
                    Text("3 列").tag(3)
                    Text("4 列").tag(4)
                    Text("5 列").tag(5)
                    Text("6 列").tag(6)
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text("布局")
        }
    }
}

#Preview {
    NavigationStack {
        GeneralSettingsView()
    }
}
