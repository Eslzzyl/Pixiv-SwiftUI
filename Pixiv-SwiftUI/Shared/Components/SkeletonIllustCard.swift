import SwiftUI

struct SkeletonIllustCard: View {
    let columnCount: Int
    let columnWidth: CGFloat?
    let aspectRatio: CGFloat

    init(columnCount: Int = 2, columnWidth: CGFloat? = nil, aspectRatio: CGFloat = 1.0) {
        self.columnCount = columnCount
        self.columnWidth = columnWidth
        self.aspectRatio = aspectRatio
    }

    private var cardWidth: CGFloat {
        columnWidth ?? 170
    }

    private var imageHeight: CGFloat {
        cardWidth / aspectRatio
    }

    var body: some View {
        VStack(spacing: 0) {
            SkeletonRoundedRectangle(
                width: cardWidth,
                height: imageHeight,
                cornerRadius: 12
            )
            .aspectRatio(aspectRatio, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(height: 14, width: cardWidth - 16, cornerRadius: 2)
                SkeletonView(height: 12, width: cardWidth * 0.6, cornerRadius: 2)
            }
            .padding(8)
        }
        .frame(width: cardWidth)
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

struct SkeletonIllustWaterfallGrid: View {
    let columnCount: Int
    let itemCount: Int

    init(columnCount: Int = 2, itemCount: Int = 6) {
        self.columnCount = columnCount
        self.itemCount = itemCount
    }

    @State private var containerWidth: CGFloat = 0
    private let spacing: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        containerWidth = proxy.size.width
                    }
                    .onChange(of: proxy.size.width) { _, newValue in
                        containerWidth = newValue
                    }
            }
            .frame(height: 0)

            if containerWidth > 0 {
                let columnWidth = max((containerWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)

                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        VStack(spacing: spacing) {
                            ForEach(0..<(itemCount / columnCount + (columnIndex < itemCount % columnCount ? 1 : 0)), id: \.self) { _ in
                                SkeletonIllustCard(columnCount: columnCount, columnWidth: columnWidth)
                            }
                        }
                        .frame(width: columnWidth)
                    }
                }
            } else {
                // 回退，使用估计宽度避免完全不显示
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { _ in
                        VStack(spacing: spacing) {
                            ForEach(0..<(itemCount / columnCount), id: \.self) { _ in
                                SkeletonIllustCard(columnCount: columnCount, columnWidth: 150)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview("Illust Card") {
    SkeletonIllustCard(columnCount: 2, columnWidth: 170)
        .padding()
}

#Preview("Waterfall Grid") {
    SkeletonIllustWaterfallGrid(columnCount: 2, itemCount: 6)
        .padding()
}
