import Foundation

struct ThemeColor: Identifiable {
    let id = UUID()
    let nameKey: String
    let hex: Int
}

struct ThemeColors {
    static let all: [ThemeColor] = [
        ThemeColor(nameKey: "theme.pixivBlue", hex: 0x0096FA),
        ThemeColor(nameKey: "theme.sakuraPink", hex: 0xFFB7C5),
        ThemeColor(nameKey: "theme.mintGreen", hex: 0x98FB98),
        ThemeColor(nameKey: "theme.sunnyYellow", hex: 0xFFD700),
        ThemeColor(nameKey: "theme.skyBlue", hex: 0x87CEEB),
        ThemeColor(nameKey: "theme.lavender", hex: 0xE6E6FA),
        ThemeColor(nameKey: "theme.coralRed", hex: 0xFF7F50),
        ThemeColor(nameKey: "theme.cyan", hex: 0x00CED1)
    ]

    static var defaultColor: ThemeColor {
        all.first { $0.hex == 0x0096FA } ?? all[0]
    }
}
