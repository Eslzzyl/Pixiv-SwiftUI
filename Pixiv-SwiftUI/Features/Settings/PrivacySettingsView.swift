import SwiftUI

struct PrivacySettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        Form {
            contentFilterSection
            rankingFilterSection
            #if os(iOS)
            backgroundPreviewSection
            #endif
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "过滤"))
    }

    private func rankingModeBinding(for mode: IllustRankingMode) -> Binding<Bool> {
        Binding(
            get: { userSettingStore.isIllustRankingModeEnabled(mode) },
            set: { try? userSettingStore.setIllustRankingMode(mode, enabled: $0) }
        )
    }

    private func isLastEnabledRankingMode(_ mode: IllustRankingMode) -> Bool {
        userSettingStore.enabledIllustRankingModes.count == 1 && userSettingStore.isIllustRankingModeEnabled(mode)
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
                .tint(.secondary)
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            LabeledContent(String(localized: "R18G 显示模式")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.r18gDisplayMode },
                    set: { try? userSettingStore.setR18gDisplayMode($0) }
                )) {
                    Text(String(localized: "正常显示")).tag(0)
                    Text(String(localized: "模糊显示")).tag(1)
                    Text(String(localized: "屏蔽")).tag(2)
                    Text(String(localized: "仅显示R18G")).tag(3)
                }
                .tint(.secondary)
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

            LabeledContent(String(localized: "剧透内容显示模式")) {
                Picker("", selection: Binding(
                    get: { userSettingStore.userSetting.spoilerDisplayMode },
                    set: { try? userSettingStore.setSpoilerDisplayMode($0) }
                )) {
                    Text(String(localized: "正常显示")).tag(0)
                    Text(String(localized: "模糊显示")).tag(1)
                    Text(String(localized: "屏蔽")).tag(2)
                    Text(String(localized: "仅显示剧透")).tag(3)
                }
                .tint(.secondary)
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
                .tint(.secondary)
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }

        } header: {
            Text(String(localized: "内容过滤"))
        } footer: {
            Text(verbatim: "设置如何显示 R18、R18G、剧透内容和 AI 生成的作品")
        }
    }

    private var rankingFilterSection: some View {
        #if os(iOS)
        Section {
            ForEach(userSettingStore.orderedIllustRankingModes) { mode in
                RankingModeRow(
                    mode: mode,
                    isEnabled: rankingModeBinding(for: mode),
                    isLastEnabled: isLastEnabledRankingMode(mode)
                )
            }
            .onMove { fromOffsets, toOffset in
                try? userSettingStore.moveIllustRankingModes(fromOffsets: fromOffsets, toOffset: toOffset)
            }
        } header: {
            Text(String(localized: "排行榜分组"))
        } footer: {
            Text(String(localized: "左侧三横图标用于提示可调整顺序，拖动排序，开关控制是否显示。至少保留一个分组。"))
        }
        .environment(\.editMode, .constant(.active))
        #else
        Section {
            ForEach(userSettingStore.orderedIllustRankingModes) { mode in
                RankingModeRow(
                    mode: mode,
                    isEnabled: rankingModeBinding(for: mode),
                    isLastEnabled: isLastEnabledRankingMode(mode)
                )
            }
            .onMove { fromOffsets, toOffset in
                try? userSettingStore.moveIllustRankingModes(fromOffsets: fromOffsets, toOffset: toOffset)
            }
        } header: {
            Text(String(localized: "排行榜分组"))
        } footer: {
            Text(String(localized: "开关控制是否在排行榜中显示。iPhone 和 iPad 可以直接拖动调整顺序。"))
        }
        #endif
    }

    #if os(iOS)
    private var backgroundPreviewSection: some View {
        Section {
            Toggle(
                String(localized: "后台时模糊页面预览"),
                isOn: Binding(
                    get: { userSettingStore.userSetting.blurAppPreviewInBackground },
                    set: { try? userSettingStore.setBlurAppPreviewInBackground($0) }
                )
            )
        } header: {
            Text(String(localized: "后台预览"))
        } footer: {
            Text(String(localized: "开启后，应用切到后台或进入最近任务时会模糊当前页面预览"))
        }
    }
    #endif
}

private struct RankingModeRow: View {
    let mode: IllustRankingMode
    @Binding var isEnabled: Bool
    let isLastEnabled: Bool

    private let dragPreviewInset: CGFloat = -12

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(verbatim: mode.title)
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .disabled(isLastEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(
            .dragPreview,
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .inset(by: dragPreviewInset)
        )
    }
}

#Preview {
    NavigationStack {
        PrivacySettingsView()
    }
}
