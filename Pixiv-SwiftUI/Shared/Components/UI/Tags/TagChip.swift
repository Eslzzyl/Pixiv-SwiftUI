import SwiftUI

struct TagChip: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(ThemeManager.self) var themeManager
    let name: String
    let translatedName: String?

    private var displayTranslation: String? {
        if let translation = TagTranslationService.shared.getDisplayTranslation(
            for: name,
            officialTranslation: translatedName
        ) {
            return translation != name ? translation : nil
        }
        return nil
    }

    init(name: String, translatedName: String? = nil) {
        self.name = name
        self.translatedName = translatedName
    }

    init(tag: Tag) {
        self.name = tag.name
        self.translatedName = tag.translatedName
    }

    init(tag: NovelTag) {
        self.name = tag.name
        self.translatedName = tag.translatedName
    }

    init(searchTag: SearchTag) {
        self.name = searchTag.name
        self.translatedName = searchTag.translatedName
    }

    private var translationColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.75) : Color.black.opacity(0.68)
    }

    /// 标签前景颜色：浅色模式下稍微加深明度并提高饱和度，深色模式下稍微变浅提亮，提升文字可读性
    private var tagForegroundColor: Color {
        if colorScheme == .dark {
            return themeManager.currentColor.adjusted(brightnessDelta: 0.12, saturationMultiplier: 0.95)
        } else {
            return themeManager.currentColor.adjusted(brightnessDelta: -0.22, saturationMultiplier: 1.15)
        }
    }

    /// 标签背景颜色：浅色模式下采用清爽轻淡的底色与加深的前景拉开反差，深色模式下适度提升透明度
    private var tagBackgroundColor: Color {
        themeManager.currentColor.opacity(colorScheme == .dark ? 0.20 : 0.10)
    }

    /// 标签描边颜色：在深色模式下提供精致微弱轮廓
    private var tagBorderColor: Color {
        themeManager.currentColor.opacity(colorScheme == .dark ? 0.22 : 0.08)
    }

    var body: some View {
        let chipContent = HStack(spacing: 4) {
            Text("#")
                .foregroundColor(tagForegroundColor)
                .font(.caption)

            if let translation = displayTranslation {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(tagForegroundColor)
                        .lineLimit(1)
                        .layoutPriority(1)

                    Text(translation)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(translationColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(0)
                }
            } else {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(tagForegroundColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        chipContent.background {
            RoundedRectangle(cornerRadius: 12)
                .fill(tagBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(tagBorderColor, lineWidth: 0.8)
                )
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        TagChip(name: "オリジナル", translatedName: "原创")
        TagChip(name: "R-18")
        TagChip(name: "アイドルマスターシンデレラガールズ")
        TagChip(name: "ブルーアーカイブ")
        TagChip(name: "very_long_tag_name_without_translation")
    }
    .padding()
    .environment(ThemeManager.shared)
}
