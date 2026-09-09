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
        cornerRadius: CGFloat = 16
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
                .padding(.bottom, 4)
            }
        }
        .frame(width: width)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .cornerRadius(cornerRadius)
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

            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    SkeletonView(height: 14, width: 100, cornerRadius: 2)
                    SkeletonView(height: 14, width: 88, cornerRadius: 2)
                }

                SkeletonView(height: 12, width: 80, cornerRadius: 2)

                HStack(spacing: 2) {
                    SkeletonView(height: 10, width: 40, cornerRadius: 2)
                    Spacer()
                    SkeletonView(height: 10, width: 30, cornerRadius: 2)
                }
                .frame(width: 100)
            }
        }
        .frame(width: width)
    }
}

struct SkeletonIllustRankingCard: View {
    let width: CGFloat

    init(width: CGFloat = 140) {
        self.width = width
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonRoundedRectangle(width: width, height: 140, cornerRadius: 16)

            SkeletonView(height: 14, width: width, cornerRadius: 2)
            SkeletonView(height: 12, width: width * 0.7, cornerRadius: 2)

            HStack(spacing: 0) {
                SkeletonView(height: 10, width: 30, cornerRadius: 2)
                Spacer()
                SkeletonView(height: 10, width: 30, cornerRadius: 2)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: width)
    }
}

struct SkeletonTrendTag: View {
    let width: CGFloat?

    init(width: CGFloat? = nil) {
        self.width = width
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.2))
                .frame(width: width)
                .frame(maxWidth: width ?? .infinity)
                .aspectRatio(1, contentMode: .fit)
                .skeleton()

            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(height: 16, width: width.map { $0 * 0.7 }, cornerRadius: 2)
                SkeletonView(height: 12, width: width.map { $0 * 0.5 }, cornerRadius: 2)
            }
            .padding(8)
        }
        .frame(width: width)
        .frame(maxWidth: width ?? .infinity)
    }
}

/// 用户卡片骨架屏，与 UserPreviewCard 布局一致
struct SkeletonUserCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 用户信息行
            HStack(spacing: 12) {
                SkeletonCircle(size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    SkeletonView(height: 14, width: 100, cornerRadius: 2)
                    SkeletonView(height: 10, width: 60, cornerRadius: 2)
                }

                Spacer()

                SkeletonCircle(size: 32)
            }
            .padding(.horizontal, 4)

            // 作品预览行
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    Color.gray.opacity(0.2)
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)
                        .skeleton()
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(16)
    }
}

#Preview("Skeleton Card") {
    VStack(spacing: 12) {
        SkeletonCard(width: 170, aspectRatio: 1.0, showTitle: true, showSubtitle: true, cornerRadius: 16)
        SkeletonNovelCard(width: 120)
        SkeletonIllustRankingCard(width: 120)
        SkeletonTrendTag(width: 170)
    }
    .padding()
}
