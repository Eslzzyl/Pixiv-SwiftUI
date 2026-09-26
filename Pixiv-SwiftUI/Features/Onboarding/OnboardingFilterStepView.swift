import SwiftUI

/// 向导步骤 3：内容展示与隐私配置
struct OnboardingFilterStepView: View {
    @Environment(UserSettingStore.self) private var userSettingStore
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            headerSection

            r18FilterSection

            aiFilterSection

            #if os(iOS)
            backgroundBlurSection
            #endif
        }
        .frame(maxWidth: 580)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "内容展示与隐私"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(String(localized: "根据您的使用习惯，配置敏感内容和 AI 作品的显示策略。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var r18FilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "R-18 作品显示"))
                .font(.headline)
                .foregroundStyle(.primary)

            Picker("", selection: Binding(
                get: { userSettingStore.userSetting.r18DisplayMode },
                set: { try? userSettingStore.setR18DisplayMode($0) }
            )) {
                Text(String(localized: "正常显示")).tag(0)
                Text(String(localized: "模糊显示")).tag(1)
                Text(String(localized: "屏蔽")).tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private var aiFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "AI 生成作品"))
                .font(.headline)
                .foregroundStyle(.primary)

            Picker("", selection: Binding(
                get: { userSettingStore.userSetting.aiDisplayMode },
                set: { try? userSettingStore.setAIDisplayMode($0) }
            )) {
                Text(String(localized: "正常显示")).tag(0)
                Text(String(localized: "屏蔽 AI")).tag(1)
            }
            .pickerStyle(.segmented)
        }
    }

    #if os(iOS)
    private var backgroundBlurSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "后台时模糊页面预览"))
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Text(String(localized: "切到多任务后台时自动模糊当前界面，防止敏感内容外泄"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: Binding(
                get: { userSettingStore.userSetting.blurAppPreviewInBackground },
                set: { try? userSettingStore.setBlurAppPreviewInBackground($0) }
            ))
            .labelsHidden()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
    #endif
}

#Preview {
    OnboardingFilterStepView()
        .padding()
        .frame(width: 600)
        .environment(UserSettingStore.shared)
        .environment(ThemeManager.shared)
}
