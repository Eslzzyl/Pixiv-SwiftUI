import SwiftUI

struct TagChip: View {
    @Environment(\.colorScheme) var colorScheme
    let name: String
    let translatedName: String?
    
    private var displayTranslation: String? {
        return TagTranslationService.shared.getDisplayTranslation(
            for: name,
            officialTranslation: translatedName
        )
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
                .foregroundColor(.secondary)
                .font(.caption)

            if let translation = displayTranslation {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
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
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
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
}
