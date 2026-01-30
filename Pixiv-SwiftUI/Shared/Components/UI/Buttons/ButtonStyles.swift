import SwiftUI

private struct ThemeColorKey: EnvironmentKey {
    static let defaultValue: Color = Color(hex: 0x0096FA)
}

extension EnvironmentValues {
    var themeColor: Color {
        get { self[ThemeColorKey.self] }
        set { self[ThemeColorKey.self] = newValue }
    }
}

extension View {
    func themeColor(_ color: Color) -> some View {
        self.environment(\.themeColor, color)
    }
}

struct GlassButtonStyle: ButtonStyle {
    var color: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color != nil ? .white : .primary)
            .contentShape(Capsule())
            .background {
                if #available(iOS 26.0, macOS 26.0, *) {
                    if let color = color {
                        Capsule()
                            .fill(color)
                            .glassEffect(in: .capsule)
                    } else {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(in: .capsule)
                    }
                } else {
                    if let color = color {
                        Capsule()
                            .fill(color)
                            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring, value: configuration.isPressed)
    }
}
