import SwiftUI

struct SkeletonWaterfallGrid: View {
    let columnCount: Int
    let itemCount: Int
    let aspectRatio: CGFloat

    init(columnCount: Int = 2, itemCount: Int = 6, aspectRatio: CGFloat = 1.0) {
        self.columnCount = columnCount
        self.itemCount = itemCount
        self.aspectRatio = aspectRatio
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
                                SkeletonCard(
                                    width: columnWidth,
                                    aspectRatio: aspectRatio,
                                    showTitle: true,
                                    showSubtitle: true
                                )
                            }
                        }
                        .frame(width: columnWidth)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { _ in
                        VStack(spacing: spacing) {
                            ForEach(0..<(itemCount / columnCount), id: \.self) { _ in
                                SkeletonCard(width: 150, aspectRatio: aspectRatio)
                            }
                        }
                    }
                }
            }
        }
    }
}

typealias SkeletonIllustWaterfallGrid = SkeletonWaterfallGrid
typealias SkeletonNovelWaterfallGrid = SkeletonWaterfallGrid

#Preview("Illust Waterfall Grid") {
    SkeletonIllustWaterfallGrid(columnCount: 2, itemCount: 6)
        .padding()
}

#Preview("Novel Waterfall Grid") {
    SkeletonNovelWaterfallGrid(columnCount: 3, itemCount: 9, aspectRatio: 0.75)
        .padding()
}
