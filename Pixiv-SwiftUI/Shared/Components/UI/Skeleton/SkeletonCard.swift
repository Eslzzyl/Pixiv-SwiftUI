import SwiftUI

struct SkeletonCard: View {
    let width: CGFloat
    let aspectRatio: CGFloat
    let showTitle: Bool
    let showSubtitle: Bool
    let cornerRadius: CGFloat

    init(
        width: CGFloat,
        aspectRatio: CGFloat = 1.0,
        showTitle: Bool = true,
        showSubtitle: Bool = true,
        cornerRadius: CGFloat = 12
    ) {
        self.width = width
        self.aspectRatio = aspectRatio
        self.showTitle = showTitle
        self.showSubtitle = showSubtitle
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        VStack(spacing: 0) {
            SkeletonRoundedRectangle(
                width: width,
                height: width / aspectRatio,
                cornerRadius: cornerRadius
            )

            if showTitle || showSubtitle {
                VStack(alignment: .leading, spacing: 4) {
                    if showTitle {
                        SkeletonView(height: 14, width: width - 16, cornerRadius: 2)
                    }
                    if showSubtitle {
                        SkeletonView(height: 12, width: width * 0.6, cornerRadius: 2)
                    }
                }
                .padding(8)
            }
        }
        .frame(width: width)
    }
}

typealias SkeletonIllustCard = SkeletonCard
typealias SkeletonNovelCard = SkeletonCard
typealias SkeletonRankingCard = SkeletonCard
typealias SkeletonUserCard = SkeletonCard

#Preview("Illust Card") {
    VStack(spacing: 12) {
        SkeletonIllustCard(width: 170, aspectRatio: 1.0, showTitle: true, showSubtitle: true)
        SkeletonNovelCard(width: 100, aspectRatio: 1.0, showTitle: true, showSubtitle: true)
        SkeletonUserCard(width: 80, aspectRatio: 1.0, showTitle: false, showSubtitle: true)
    }
    .padding()
}
