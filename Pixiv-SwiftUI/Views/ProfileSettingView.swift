import SwiftUI

/// 设置页面
struct ProfileSettingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settingStore = UserSettingStore()
    @State private var showingResetAlert = false

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
        }
    }

    /// 图片质量设置
    @State private var feedPreviewQuality: Int = 0
    @State private var pictureQuality: Int = 0
    @State private var zoomQuality: Int = 0

    private var imageQualitySection: some View {
        Section {
            QualitySettingRow(
                title: "列表预览画质",
                icon: "square.grid.2x2",
                description: "推荐页等列表中的图片质量",
                selection: $feedPreviewQuality
            )

            QualitySettingRow(
                title: "插画详情页画质",
                icon: "photo.on.rectangle",
                description: "插画详情页的主图质量",
                selection: $pictureQuality
            )

            QualitySettingRow(
                title: "大图预览画质",
                icon: "magnifyingglass",
                description: "图片预览和缩放时的质量",
                selection: $zoomQuality
            )
        } header: {
            Text("图片质量")
        } footer: {
            Text("中等画质节省流量，大图画质更清晰，原图画质最高清（可能消耗更多流量）")
        }
    }

    /// 布局设置
    @State private var crossCount: Int = 2
    @State private var hCrossCount: Int = 4

    private var layoutSection: some View {
        Section("布局") {
            Picker("竖屏列数", selection: $crossCount) {
                Text("1 列").tag(1)
                Text("2 列").tag(2)
                Text("3 列").tag(3)
                Text("4 列").tag(4)
            }

            Picker("横屏列数", selection: $hCrossCount) {
                Text("2 列").tag(2)
                Text("3 列").tag(3)
                Text("4 列").tag(4)
                Text("5 列").tag(5)
                Text("6 列").tag(6)
            }
        }
    }

    /// 显示设置
    @State private var feedAIBadge: Bool = true
    @State private var swipeChangeArtwork: Bool = true

    private var displaySection: some View {
        Section("显示") {
            Toggle("显示 AI 作品徽章", isOn: $feedAIBadge)
            Toggle("滑动切换作品", isOn: $swipeChangeArtwork)
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
