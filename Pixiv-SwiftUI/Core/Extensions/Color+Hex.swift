import SwiftUI

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
}
