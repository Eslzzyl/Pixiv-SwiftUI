import SwiftUI

struct TagChip: View {
    let tag: Tag
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#")
                .foregroundColor(.secondary)
                .font(.caption)
            
            if let translatedName = tag.translatedName {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(tag.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(translatedName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Text(tag.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    HStack {
        TagChip(tag: Tag(name: "オリジナル", translatedName: "原创"))
        TagChip(tag: Tag(name: "女の子"))
    }
}
