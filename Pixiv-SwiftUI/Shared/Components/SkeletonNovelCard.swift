import SwiftUI

struct SkeletonNovelCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonRoundedRectangle(
                width: 100,
                height: 100,
                cornerRadius: 8
            )

            VStack(alignment: .leading, spacing: 4) {
                SkeletonView(height: 14, width: 90, cornerRadius: 2)
                SkeletonView(height: 12, width: 70, cornerRadius: 2)
            }
            .frame(width: 100, alignment: .leading)

            HStack(spacing: 2) {
                SkeletonCapsule(width: 50, height: 16)
                Spacer()
                SkeletonCapsule(width: 30, height: 16)
            }
            .frame(width: 100)
        }
        .frame(width: 120)
    }
}

struct SkeletonNovelWaterfallGrid: View {
    let columnCount: Int
    let itemCount: Int

    init(columnCount: Int = 2, itemCount: Int = 4) {
        self.columnCount = columnCount
        self.itemCount = itemCount
    }

    private let spacing: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let columnWidth = max((proxy.size.width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columnCount, id: \.self) { columnIndex in
                    LazyVStack(spacing: spacing) {
                        ForEach(0..<(itemCount / columnCount + (columnIndex < itemCount % columnCount ? 1 : 0)), id: \.self) { _ in
                            SkeletonNovelCard()
                                .frame(width: columnWidth)
                        }
                    }
                    .frame(width: columnWidth)
                }
            }
        }
    }
}

struct SkeletonNovelListCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SkeletonRoundedRectangle(
                width: 80,
                height: 100,
                cornerRadius: 8
            )

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 16, width: 200, cornerRadius: 2)
                SkeletonView(height: 12, width: 150, cornerRadius: 2)
                SkeletonView(height: 12, width: 120, cornerRadius: 2)

                Spacer()

                HStack {
                    SkeletonCapsule(width: 80, height: 20)
                    Spacer()
                    SkeletonCapsule(width: 40, height: 20)
                }
            }
        }
        .padding()
        .frame(width: 320)
    }
}

struct SkeletonNovelHorizontalList: View {
    let itemCount: Int

    init(itemCount: Int = 5) {
        self.itemCount = itemCount
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<itemCount, id: \.self) { _ in
                    SkeletonNovelCard()
                }
            }
            .padding(.horizontal)
        }
    }
}

#Preview("Novel Card") {
    SkeletonNovelCard()
        .padding()
}

#Preview("Novel Waterfall") {
    SkeletonNovelWaterfallGrid(columnCount: 2, itemCount: 4)
        .padding()
}

#Preview("Novel List Card") {
    SkeletonNovelListCard()
        .padding()
}

#Preview("Novel Horizontal") {
    SkeletonNovelHorizontalList(itemCount: 5)
        .padding()
}
