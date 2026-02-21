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

    var body: some View {
        HStack(spacing: 4) {
            Text("#")
                .foregroundColor(themeManager.currentColor)
                .font(.caption)

            if let translation = displayTranslation {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.currentColor.opacity(colorScheme == .dark ? 0.9 : 0.8))
                        .lineLimit(1)
                        .layoutPriority(1)

                    Text(translation)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutPriority(0)
                }
            } else {
                Text(name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentColor.opacity(colorScheme == .dark ? 0.9 : 0.8))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(themeManager.currentColor.opacity(colorScheme == .dark ? 0.15 : 0.1))
        .cornerRadius(12)
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
