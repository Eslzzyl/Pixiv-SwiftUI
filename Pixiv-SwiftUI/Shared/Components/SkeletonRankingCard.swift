import SwiftUI

struct SkeletonRankingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonRoundedRectangle(
                width: 100,
                height: 100,
                cornerRadius: 8
            )

            SkeletonView(height: 12, width: 90, cornerRadius: 2)
            SkeletonView(height: 10, width: 70, cornerRadius: 2)

            HStack(spacing: 4) {
                SkeletonCapsule(width: 40, height: 16)
                Spacer()
                SkeletonCapsule(width: 40, height: 16)
            }
            .frame(width: 100)
        }
        .frame(width: 120)
    }
}

#Preview {
    HStack(spacing: 10) {
        ForEach(0..<3, id: \.self) { _ in
            SkeletonRankingCard()
        }
    }
    .padding()
}
