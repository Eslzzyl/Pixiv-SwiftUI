import SwiftUI

/// 向导步骤 1：欢迎概览
struct OnboardingWelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image("launch")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(spacing: 8) {
                Text(String(localized: "欢迎"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.primary)

                Text(String(localized: "专为 Apple 平台打造的原生 Pixiv 客户端"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "本向导将引导您完成基础配置："))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                VStack(alignment: .leading, spacing: 8) {
                    bulletPoint(String(localized: "选择适合当前网络环境的直连或代理模式"))
                    bulletPoint(String(localized: "设置 R-18 与 AI 生成作品的内容过滤偏好"))
                    bulletPoint(String(localized: "选择界面主题色彩与图片清晰度策略"))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            }

            Text(String(localized: "所有选项稍后均可在应用“设置”中随时调整。"))
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: 560)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    OnboardingWelcomeStepView()
        .padding()
        .frame(width: 600)
}
