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

struct SkeletonNovelCard: View {
    let width: CGFloat

    init(width: CGFloat = 120) {
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonRoundedRectangle(width: 100, height: 100, cornerRadius: 8)

            SkeletonView(height: 14, width: 100, cornerRadius: 2)
            SkeletonView(height: 12, width: 80, cornerRadius: 2)

            HStack(spacing: 2) {
                SkeletonView(height: 10, width: 40, cornerRadius: 2)
                Spacer()
                SkeletonView(height: 10, width: 30, cornerRadius: 2)
            }
            .frame(width: 100)
        }
        .frame(width: width)
    }
}

struct SkeletonIllustRankingCard: View {
    let width: CGFloat

    init(width: CGFloat = 120) {
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonRoundedRectangle(width: 100, height: 100, cornerRadius: 8)

            SkeletonView(height: 14, width: 100, cornerRadius: 2)
            SkeletonView(height: 12, width: 80, cornerRadius: 2)

            HStack(spacing: 0) {
                SkeletonView(height: 10, width: 30, cornerRadius: 2)
                Spacer()
                SkeletonView(height: 10, width: 30, cornerRadius: 2)
            }
            .frame(width: 100)
        }
        .frame(width: width)
    }
}

struct SkeletonTrendTag: View {
    let width: CGFloat

    init(width: CGFloat = 170) {
        self.width = width
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            SkeletonRoundedRectangle(
                width: width,
                height: width,
                cornerRadius: 16
            )

            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(height: 16, width: width * 0.7, cornerRadius: 2)
                SkeletonView(height: 12, width: width * 0.5, cornerRadius: 2)
            }
            .padding(8)
        }
        .frame(width: width)
    }
}

#Preview("Skeleton Card") {
    VStack(spacing: 12) {
        SkeletonCard(width: 170, aspectRatio: 1.0, showTitle: true, showSubtitle: true)
        SkeletonNovelCard(width: 120)
        SkeletonIllustRankingCard(width: 120)
        SkeletonTrendTag(width: 170)
    }
    .padding()
}
