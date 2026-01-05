import SwiftUI

struct TagChip: View {
    @Environment(\.colorScheme) var colorScheme
    let name: String
    let translatedName: String?
    
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
            
            if let translatedName = translatedName {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(translatedName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
        .cornerRadius(12)
    }
}

#Preview {
    HStack {
        TagChip(name: "オリジナル", translatedName: "原创")
        TagChip(name: "女の子")
    }
}
