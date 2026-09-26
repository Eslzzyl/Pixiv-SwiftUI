import SwiftUI

/// 向导步骤 4：外观与画质配置
struct OnboardingAppearanceStepView: View {
    @Environment(UserSettingStore.self) private var userSettingStore
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerSection

            imageQualitySection

            colorSchemeSection

            themeColorSection
        }
        .frame(maxWidth: 580)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "外观与画质"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(String(localized: "配置界面主题模式与浏览画质。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 画质设置（直接复用系统设置项，无额外映射）

    private var imageQualitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "图片画质"))
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                qualityRow(
                    title: String(localized: "列表预览画质"),
                    selection: Binding(
                        get: { userSettingStore.userSetting.feedPreviewQuality },
                        set: { try? userSettingStore.setFeedPreviewQuality($0) }
                    )
                )

                qualityRow(
                    title: String(localized: "插画详情页画质"),
                    selection: Binding(
                        get: { userSettingStore.userSetting.pictureQuality },
                        set: { try? userSettingStore.setPictureQuality($0) }
                    )
                )

                qualityRow(
                    title: String(localized: "漫画详情页画质"),
                    selection: Binding(
                        get: { userSettingStore.userSetting.mangaQuality },
                        set: { try? userSettingStore.setMangaQuality($0) }
                    )
                )

                qualityRow(
                    title: String(localized: "大图预览画质"),
                    selection: Binding(
                        get: { userSettingStore.userSetting.zoomQuality },
                        set: { try? userSettingStore.setZoomQuality($0) }
                    )
                )
            }
        }
    }

    private func qualityRow(title: String, selection: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: selection) {
                Text(String(localized: "中等")).tag(0)
                Text(String(localized: "大图")).tag(1)
                Text(String(localized: "原图")).tag(2)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    // MARK: - 主题模式

    private var colorSchemeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "界面主题模式"))
                .font(.headline)
                .foregroundStyle(.primary)

            Picker("", selection: Binding(
                get: { userSettingStore.userSetting.colorSchemeMode },
                set: { try? userSettingStore.setColorSchemeMode($0) }
            )) {
                Text(String(localized: "跟随系统")).tag(0)
                Text(String(localized: "浅色")).tag(1)
                Text(String(localized: "深色")).tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 主题强调色（明确标记激活颜色）

    private var themeColorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "主题强调色"))
                .font(.headline)
                .foregroundStyle(.primary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 42), spacing: 12, alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(ThemeColors.all.filter { !$0.isCustom }) { theme in
                    let isSelected = !userSettingStore.userSetting.isCustomTheme &&
                        theme.matches(seedColor: userSettingStore.userSetting.seedColor)

                    Button {
                        themeManager.setThemeColor(theme.hex, isCustom: false)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 32, height: 32)

                            if isSelected {
                                Circle()
                                    .strokeBorder(theme.color, lineWidth: 2.5)
                                    .frame(width: 40, height: 40)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(theme.onColor)
                            }
                        }
                        .frame(width: 42, height: 42)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(LocalizedStringKey(theme.nameKey)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        }
    }
}

#Preview {
    OnboardingAppearanceStepView()
        .padding()
        .frame(width: 600)
        .environment(UserSettingStore.shared)
        .environment(ThemeManager.shared)
}
