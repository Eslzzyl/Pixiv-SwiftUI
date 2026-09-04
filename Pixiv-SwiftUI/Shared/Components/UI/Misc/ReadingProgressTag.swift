import SwiftUI

struct ReadingProgressTag: View {
    @Environment(\.colorScheme) var colorScheme
    let percentage: Int

    var body: some View {
        let tagContent = HStack(spacing: 2) {
            Text("\(percentage)%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        tagContent.background {
            Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15)
        }
        .clipShape(.rect(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 16) {
        ReadingProgressTag(percentage: 0)
        ReadingProgressTag(percentage: 25)
        ReadingProgressTag(percentage: 50)
        ReadingProgressTag(percentage: 75)
        ReadingProgressTag(percentage: 100)
    }
    .padding()
}
