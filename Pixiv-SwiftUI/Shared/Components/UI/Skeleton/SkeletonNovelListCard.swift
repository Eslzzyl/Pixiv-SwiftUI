import SwiftUI

struct SkeletonNovelListCard: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonRoundedRectangle(width: 80, height: 80, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 16, width: 200, cornerRadius: 2)
                SkeletonView(height: 14, width: 150, cornerRadius: 2)
                SkeletonView(height: 12, width: 100, cornerRadius: 2)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 8) {
        SkeletonNovelListCard()
        SkeletonNovelListCard()
        SkeletonNovelListCard()
    }
    .padding()
}
