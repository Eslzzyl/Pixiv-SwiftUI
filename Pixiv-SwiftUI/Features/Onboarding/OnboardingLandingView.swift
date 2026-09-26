import SwiftUI

/// 常用设置向导容器页面（4 步流程）
struct OnboardingLandingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) private var dismiss

    @Binding var isCompleted: Bool
    var isEmbeddedInNavigation: Bool = false

    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        mainContent
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(uiColor: .systemGroupedBackground))
            #endif
            .navigationTitle(String(localized: "设置向导"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            topProgressBar
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                stepContentView
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 580)
                    .frame(maxWidth: .infinity)
            }

            Divider()

            bottomActionBar
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                #if os(macOS)
                .background(Color(nsColor: .windowBackgroundColor))
                #else
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 顶部步骤进度指示

    private var topProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(format: String(localized: "步骤 %d / %d"), currentStep.stepNumber, OnboardingStep.totalSteps))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(currentStep.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(themeManager.currentColor)
            }

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue ? themeManager.currentColor : Color.secondary.opacity(0.2))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.25), value: currentStep)
                }
            }
        }
        .frame(maxWidth: 580)
    }

    // MARK: - 步骤视图切换

    @ViewBuilder
    private var stepContentView: some View {
        switch currentStep {
        case .welcome:
            OnboardingWelcomeStepView()
        case .network:
            OnboardingNetworkStepView()
        case .contentFilter:
            OnboardingFilterStepView()
        case .appearance:
            OnboardingAppearanceStepView()
        }
    }

    // MARK: - 底部导航控制栏

    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            if currentStep == .welcome {
                Button(String(localized: "跳过向导")) {
                    finishOnboarding()
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                Button(String(localized: "上一步")) {
                    goToPreviousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if currentStep == .welcome {
                Button(String(localized: "开始设置")) {
                    goToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.currentColor)
            } else if currentStep == .appearance {
                Button(String(localized: "完成设置")) {
                    finishOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.currentColor)
            } else {
                Button(String(localized: "下一步")) {
                    goToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.currentColor)
            }
        }
        .frame(maxWidth: 580)
    }

    private func goToPreviousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = prev
        }
    }

    private func goToNextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentStep = next
        }
    }

    private func finishOnboarding() {
        isCompleted = true
        if isEmbeddedInNavigation {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingLandingView(isCompleted: .constant(false))
            .environment(ThemeManager.shared)
    }
}
