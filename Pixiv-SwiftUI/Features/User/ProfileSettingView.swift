import SwiftUI

struct ProfileSettingView: View {
    @Environment(\ .dismiss) private var dismiss
    @Environment(UserSettingStore.self) var userSettingStore
    @Binding var isPresented: Bool
    @State private var showingResetAlert = false

    init(isPresented: Binding<Bool> = .constant(false)) {
        self._isPresented = isPresented
    }

    var body: some View {
        Form {
            generalSection
            #if os(iOS)
            appearanceSection
            filterSection
            featureSection
            resetSection
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

    private var generalSection: some View {
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

            LabeledContent("默认启动标签页") {
                Picker("", selection: Binding(
                    get: { NavigationItem(rawValue: userSettingStore.userSetting.defaultTab) ?? .recommend },
                    set: { try? userSettingStore.setDefaultTab($0) }
                )) {
                    ForEach(NavigationItem.mainItems) { item in
                        Text(item.title).tag(item)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text("通用")
        } footer: {
            Text("中等画质节省流量，大图画质更清晰，原图画质最高清（可能消耗更多流量）")
        }
    }

    #if os(iOS)
    private var appearanceSection: some View {
        Section {
            NavigationLink(value: ProfileDestination.appearance) {
                Text("外观")
            }
        } header: {
            Text("外观")
        }
    }

    private var filterSection: some View {
        Section {
            NavigationLink(value: ProfileDestination.privacy) {
                Text("过滤")
            }

            NavigationLink(value: ProfileDestination.blockSettings) {
                Text("屏蔽")
            }
        } header: {
            Text("过滤与屏蔽")
        }
    }

    @ObservedObject private var networkModeStore = NetworkModeStore.shared

    private var featureSection: some View {
        Section {
            NavigationLink(value: ProfileDestination.translationSettings) {
                Text("翻译")
            }

            NavigationLink(value: ProfileDestination.downloadSettings) {
                Text("下载")
            }

            LabeledContent("网络模式") {
                Picker("", selection: $networkModeStore.currentMode) {
                    ForEach(NetworkMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
            }
        } header: {
            Text("功能")
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showingResetAlert = true
            } label: {
                HStack {
                    Spacer()
                    Text("重置所有设置")
                    Spacer()
                }
            }
        }
    }
    #endif

    private var aboutSection: some View {
        Group {
            Section {
                #if os(macOS)
                Button("重置所有设置") {
                    showingResetAlert = true
                }
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
