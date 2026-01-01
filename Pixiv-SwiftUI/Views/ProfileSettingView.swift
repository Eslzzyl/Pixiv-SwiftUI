import SwiftUI

/// 设置页面
struct ProfileSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var showingResetAlert = false
    @State private var blockAI: Bool = false
    @State private var swipeChangeArtwork: Bool = false
    
    init() {
        _blockAI = State(initialValue: false)
        _swipeChangeArtwork = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            Form {
                imageQualitySection
                layoutSection
                displaySection
                aboutSection
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                blockAI = userSettingStore.userSetting.blockAI
                swipeChangeArtwork = userSettingStore.userSetting.swipeChangeArtwork
            }
        }
    }

    private var imageQualitySection: some View {
        Section {
            QualitySettingRow(
                title: "列表预览画质",
                icon: "square.grid.2x2",
                description: "推荐页等列表中的图片质量",
                selection: Binding(
                    get: { userSettingStore.userSetting.feedPreviewQuality },
                    set: { try? userSettingStore.setFeedPreviewQuality($0) }
                )
            )

            QualitySettingRow(
                title: "插画详情页画质",
                icon: "photo.on.rectangle",
                description: "插画详情页的主图质量",
                selection: Binding(
                    get: { userSettingStore.userSetting.pictureQuality },
                    set: { try? userSettingStore.setPictureQuality($0) }
                )
            )

            QualitySettingRow(
                title: "大图预览画质",
                icon: "magnifyingglass",
                description: "图片预览和缩放时的质量",
                selection: Binding(
                    get: { userSettingStore.userSetting.zoomQuality },
                    set: { try? userSettingStore.setZoomQuality($0) }
                )
            )
        } header: {
            Text("图片质量")
        } footer: {
            Text("中等画质节省流量，大图画质更清晰，原图画质最高清（可能消耗更多流量）")
        }
    }

    private var layoutSection: some View {
        Section("布局") {
            Picker("竖屏列数", selection: Binding(
                get: { userSettingStore.userSetting.crossCount },
                set: { try? userSettingStore.setCrossCount($0) }
            )) {
                Text("1 列").tag(1)
                Text("2 列").tag(2)
                Text("3 列").tag(3)
                Text("4 列").tag(4)
            }

            Picker("横屏列数", selection: Binding(
                get: { userSettingStore.userSetting.hCrossCount },
                set: { try? userSettingStore.setHCrossCount($0) }
            )) {
                Text("2 列").tag(2)
                Text("3 列").tag(3)
                Text("4 列").tag(4)
                Text("5 列").tag(5)
                Text("6 列").tag(6)
            }
        }
    }

    private var displaySection: some View {
        Section("显示") {
            Toggle("屏蔽 AI 作品", isOn: $blockAI)
                .onChange(of: blockAI) { _, newValue in
                    userSettingStore.userSetting.blockAI = newValue
                    try? userSettingStore.saveSetting()
                }
            
            NavigationLink(destination: BlockSettingView()) {
                Text("屏蔽设置")
            }
            
            Toggle("滑动切换作品", isOn: $swipeChangeArtwork)
                .onChange(of: swipeChangeArtwork) { _, newValue in
                    userSettingStore.userSetting.swipeChangeArtwork = newValue
                    try? userSettingStore.saveSetting()
                }
            
            Picker("R18 显示模式", selection: Binding(
                get: { userSettingStore.userSetting.r18DisplayMode },
                set: { try? userSettingStore.setR18DisplayMode($0) }
            )) {
                Text("正常显示").tag(0)
                Text("模糊显示").tag(1)
                Text("屏蔽").tag(2)
            }
        }
    }

    /// 关于
    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }

            Button("重置所有设置", role: .destructive) {
                showingResetAlert = true
            }
        }
    }
}

/// 画质设置行
struct QualitySettingRow: View {
    let title: String
    let icon: String
    let description: String
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Picker("画质", selection: $selection) {
                Text("中等").tag(0)
                Text("大图").tag(1)
                Text("原图").tag(2)
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProfileSettingView()
}
