import SwiftUI

/// 玻璃效果按钮样式
struct GlassButtonStyle: ButtonStyle {
    var color: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color != nil ? .white : .primary)
            .background {
                if #available(iOS 18.0, macOS 15.0, visionOS 1.0, *) {
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