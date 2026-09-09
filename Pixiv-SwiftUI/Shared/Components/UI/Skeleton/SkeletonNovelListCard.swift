import SwiftUI

struct SkeletonNovelListCard: View {
    var showsBookmarkSummary = true

    var body: some View {
        HStack(spacing: 12) {
            SkeletonRoundedRectangle(width: 80, height: 80, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    SkeletonView(height: 18, cornerRadius: 2)
                    SkeletonView(height: 18, width: 180, cornerRadius: 2)
                }

                SkeletonView(height: 14, width: 150, cornerRadius: 2)

                HStack(spacing: 4) {
                    SkeletonCapsule(width: 44, height: 18)
                    SkeletonCapsule(width: 56, height: 18)
                }
                .frame(height: 22, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)

            if showsBookmarkSummary {
                VStack(spacing: 4) {
                    SkeletonView(height: 18, width: 18, cornerRadius: 9)
                    SkeletonView(height: 12, width: 36, cornerRadius: 2)
                }
                .frame(width: 44)
            }

        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }
}

struct SkeletonNovelSeriesCard: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonRoundedRectangle(width: 80, height: 80, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    SkeletonView(height: 17, cornerRadius: 2)
                    SkeletonView(height: 17, width: 180, cornerRadius: 2)
                }

                SkeletonView(height: 14, width: 100, cornerRadius: 2)

                HStack(spacing: 12) {
                    SkeletonView(height: 14, width: 54, cornerRadius: 2)
                    HStack(spacing: 4) {
                        SkeletonView(height: 14, width: 14, cornerRadius: 7)
                        SkeletonView(height: 14, width: 42, cornerRadius: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .topLeading)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
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
