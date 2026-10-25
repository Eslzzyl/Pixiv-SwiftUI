import SwiftUI

struct ImageLoadProgressRing: View {
    let progress: Double?

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    private var boundedProgress: Double? {
        progress.map { min(max($0, 0), 1) }
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.72) : Color.white.opacity(0.88)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)

            if let boundedProgress {
                ZStack {
                    Circle()
                        .stroke(
                            themeManager.currentColor.opacity(colorScheme == .dark ? 0.32 : 0.18),
                            lineWidth: 2
                        )

                    Circle()
                        .trim(from: 0, to: boundedProgress)
                        .stroke(themeManager.currentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .padding(5)
                .animation(.easeInOut(duration: 0.2), value: boundedProgress)
            } else {
                ProgressView()
                    .controlSize(.mini)
                    .tint(themeManager.currentColor)
                    .frame(width: 24, height: 24)
            }
        }
        .frame(width: 24, height: 24)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "图片加载进度"))
        .accessibilityValue(boundedProgress.map { "\(Int($0 * 100))%" } ?? String(localized: "正在加载"))
    }
}

#Preview {
    ImageLoadProgressRing(progress: 0.42)
        .environment(ThemeManager(userSettingStore: UserSettingStore()))
}
