import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Color {
    init(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(hex: Int(rgb))
    }

    var hex: Int {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return 0x000000
        }
        #else
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return 0x000000
        }
        #endif
        let red = Int(components[0] * 255.0) << 16
        let green = Int(components[1] * 255.0) << 8
        let blue = Int(components[2] * 255.0)
        return red + green + blue
    }

    /// 根据明度与饱和度调整颜色，用于浅色模式加深、深色模式提亮
    func adjusted(brightnessDelta: CGFloat, saturationMultiplier: CGFloat = 1.0) -> Color {
        #if os(iOS)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        let newSaturation = min(max(saturation * saturationMultiplier, 0.0), 1.0)
        let newBrightness = min(max(brightness + brightnessDelta, 0.0), 1.0)
        return Color(
            hue: Double(hue),
            saturation: Double(newSaturation),
            brightness: Double(newBrightness),
            opacity: Double(alpha)
        )
        #elseif os(macOS)
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else {
            return self
        }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        let newSaturation = min(max(saturation * saturationMultiplier, 0.0), 1.0)
        let newBrightness = min(max(brightness + brightnessDelta, 0.0), 1.0)
        return Color(
            hue: Double(hue),
            saturation: Double(newSaturation),
            brightness: Double(newBrightness),
            opacity: Double(alpha)
        )
        #else
        return self
        #endif
    }
}
