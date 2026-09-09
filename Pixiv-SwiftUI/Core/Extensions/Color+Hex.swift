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

    /// 创建自适应浅色与深色外观的动态色彩
    init(lightHex: Int, darkHex: Int) {
        #if os(iOS)
        self.init(uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(Color(hex: darkHex))
            } else {
                return UIColor(Color(hex: lightHex))
            }
        })
        #elseif os(macOS)
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            if match == .darkAqua {
                return NSColor(Color(hex: darkHex))
            } else {
                return NSColor(Color(hex: lightHex))
            }
        }))
        #else
        self.init(hex: lightHex)
        #endif
    }

    var hex: Int {
        #if os(iOS)
        let uiColor = UIColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let redVal = Int(max(0, min(255, round(red * 255.0)))) << 16
            let greenVal = Int(max(0, min(255, round(green * 255.0)))) << 8
            let blueVal = Int(max(0, min(255, round(blue * 255.0))))
            return redVal + greenVal + blueVal
        }
        guard let components = uiColor.cgColor.components, components.count >= 3 else {
            return 0x000000
        }
        let redVal = Int(components[0] * 255.0) << 16
        let greenVal = Int(components[1] * 255.0) << 8
        let blueVal = Int(components[2] * 255.0)
        return redVal + greenVal + blueVal
        #else
        let nsColor = NSColor(self)
        if let srgb = nsColor.usingColorSpace(.sRGB) {
            let redVal = Int(max(0, min(255, round(srgb.redComponent * 255.0)))) << 16
            let greenVal = Int(max(0, min(255, round(srgb.greenComponent * 255.0)))) << 8
            let blueVal = Int(max(0, min(255, round(srgb.blueComponent * 255.0))))
            return redVal + greenVal + blueVal
        }
        guard let components = nsColor.cgColor.components, components.count >= 3 else {
            return 0x000000
        }
        let redVal = Int(components[0] * 255.0) << 16
        let greenVal = Int(components[1] * 255.0) << 8
        let blueVal = Int(components[2] * 255.0)
        return redVal + greenVal + blueVal
        #endif
    }

    /// 计算颜色的 WCAG 相对明度 (0.0 为纯黑, 1.0 为纯白)
    var relativeLuminance: Double {
        #if os(iOS)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        if UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return Color.luminance(red: Double(red), green: Double(green), blue: Double(blue))
        }
        #elseif os(macOS)
        if let srgb = NSColor(self).usingColorSpace(.sRGB) {
            return Color.luminance(red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
        }
        #endif
        let hexVal = self.hex
        let redVal = Double((hexVal >> 16) & 0xFF) / 255.0
        let greenVal = Double((hexVal >> 8) & 0xFF) / 255.0
        let blueVal = Double(hexVal & 0xFF) / 255.0
        return Color.luminance(red: redVal, green: greenVal, blue: blueVal)
    }

    private static func luminance(red: Double, green: Double, blue: Double) -> Double {
        func toLinear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * toLinear(red) + 0.7152 * toLinear(green) + 0.0722 * toLinear(blue)
    }

    /// 判断颜色是否偏浅 (明度 > 0.45)
    var isLight: Bool {
        relativeLuminance > 0.45
    }

    /// 适用于当前颜色作为背景时的高对比前景色（浅底用深黑，深底用纯白）
    var contrastingTextColor: Color {
        isLight ? Color(white: 0.1) : Color.white
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
