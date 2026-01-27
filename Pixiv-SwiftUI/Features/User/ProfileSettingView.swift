import SwiftUI

struct ProfileSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingStore.self) var userSettingStore
    @Binding var isPresented: Bool
    @State private var showingResetAlert = false

    init(isPresented: Binding<Bool> = .constant(false)) {
        self._isPresented = isPresented
    }

    var body: some View {
        Form {
            imageQualitySection
            layoutSection
            #if os(iOS)
            displaySection
            networkSection
            #endif
            aboutSection
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            #endif
        }
        .alert("确认重置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
            }
        } message: {
            Text("确定要重置所有设置为默认值吗？")
        }
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
                .frame(width: 100)
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
                .frame(width: 100)
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
                .frame(width: 100)
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
                .frame(width: 80)
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
                .frame(width: 80)
                #endif
            }
        } header: {
            Text("布局")
        }
    }

    #if os(iOS)
    private var displaySection: some View {
        Section {
            NavigationLink(value: ProfileDestination.blockSettings) {
                Text("屏蔽设置")
            }

            NavigationLink(value: ProfileDestination.translationSettings) {
                Text("翻译设置")
            }

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
            Text("显示")
        }
    }

    @ObservedObject private var networkModeStore = NetworkModeStore.shared

    private var networkSection: some View {
        Section {
            LabeledContent("网络模式") {
                Picker("", selection: $networkModeStore.currentMode) {
                    ForEach(NetworkMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
            }

            NavigationLink(value: ProfileDestination.downloadSettings) {
                Text("下载设置")
            }
        } header: {
            Text("网络")
        }
    }
    #endif

    private var aboutSection: some View {
        Group {
            Section {
                Button("重置所有设置") {
                    showingResetAlert = true
                }
                #if os(macOS)
                .buttonStyle(.link)
                #endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingView(isPresented: .constant(false))
    }
    .frame(maxWidth: 600)
}
