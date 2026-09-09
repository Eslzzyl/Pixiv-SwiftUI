import SwiftUI

struct ThemeColor: Identifiable {
    let id: String
    let nameKey: String
    let lightHex: Int
    let darkHex: Int
    let legacyHexes: [Int]
    let isCustom: Bool

    var hex: Int { lightHex }

    var color: Color {
        if isCustom {
            return Color(hex: lightHex)
        }
        return Color(lightHex: lightHex, darkHex: darkHex)
    }

    var onColor: Color {
        Color(
            lightHex: Color(hex: lightHex).isLight ? 0x1A1A1A : 0xFFFFFF,
            darkHex: Color(hex: darkHex).isLight ? 0x1A1A1A : 0xFFFFFF
        )
    }

    init(
        id: String? = nil,
        nameKey: String,
        lightHex: Int,
        darkHex: Int,
        legacyHexes: [Int] = [],
        isCustom: Bool = false
    ) {
        self.id = id ?? (isCustom ? "custom" : String(lightHex))
        self.nameKey = nameKey
        self.lightHex = lightHex
        self.darkHex = darkHex
        self.legacyHexes = legacyHexes
        self.isCustom = isCustom
    }

    init(id: String? = nil, nameKey: String, hex: Int, isCustom: Bool = false) {
        self.init(
            id: id,
            nameKey: nameKey,
            lightHex: hex,
            darkHex: hex,
            legacyHexes: [],
            isCustom: isCustom
        )
    }

    func matches(seedColor: Int) -> Bool {
        lightHex == seedColor || darkHex == seedColor || legacyHexes.contains(seedColor)
    }
}

struct ThemeColors {
    static let all: [ThemeColor] = [
        ThemeColor(
            nameKey: "theme.pixivBlue",
            lightHex: 0x0096FA,
            darkHex: 0x38ACFF,
            legacyHexes: [0x0078D4]
        ),
        ThemeColor(
            nameKey: "theme.sakuraPink",
            lightHex: 0xFF4D82,
            darkHex: 0xFF6B9D,
            legacyHexes: [0xFFB7C5, 0xD83B68]
        ),
        ThemeColor(
            nameKey: "theme.grassGreen",
            lightHex: 0x22C55E,
            darkHex: 0x34D399,
            legacyHexes: [0x40BF77, 0x1B8746]
        ),
        ThemeColor(
            nameKey: "theme.sunnyYellow",
            lightHex: 0xFF8A00,
            darkHex: 0xFFA000,
            legacyHexes: [0xFFD700, 0xB45309]
        ),
        ThemeColor(
            nameKey: "theme.violet",
            lightHex: 0x8B5CF6,
            darkHex: 0xA78BFA,
            legacyHexes: [0x6D28D9]
        ),
        ThemeColor(
            nameKey: "theme.coralRed",
            lightHex: 0xFF5252,
            darkHex: 0xFF6B6B,
            legacyHexes: [0xFF7F50, 0xD94824]
        ),
        ThemeColor(
            nameKey: "theme.cyan",
            lightHex: 0x00B4D8,
            darkHex: 0x38BDF8,
            legacyHexes: [0x00CED1, 0x00838F]
        ),
        ThemeColor(
            nameKey: "theme.custom",
            lightHex: 0x0096FA,
            darkHex: 0x38ACFF,
            isCustom: true
        )
    ]

    static var defaultColor: ThemeColor {
        all[0]
    }

    static func find(byHex hex: Int) -> ThemeColor? {
        all.first { $0.matches(seedColor: hex) }
    }
}
