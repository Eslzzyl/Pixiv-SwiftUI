import SwiftUI

struct SkeletonWaterfallGrid: View {
    let columnCount: Int
    let itemCount: Int
    let aspectRatio: CGFloat
    let width: CGFloat?
    let spacing: CGFloat

    init(columnCount: Int = 2, itemCount: Int = 6, aspectRatio: CGFloat = 1.0, width: CGFloat? = nil, spacing: CGFloat = 12) {
        self.columnCount = columnCount
        self.itemCount = itemCount
        self.aspectRatio = aspectRatio
        self.width = width
        self.spacing = spacing
    }

    @State private var containerWidth: CGFloat = 0

    private var safeColumnWidth: CGFloat {
        let currentWidth = width ?? containerWidth
        if currentWidth > 0 {
            return max((currentWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)
        } else {
            #if os(iOS)
            return 150
            #else
            return 170
            #endif
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if width == nil {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            containerWidth = proxy.size.width
                        }
                        .onChange(of: proxy.size.width) { _, newValue in
                            if newValue > 0 && abs(newValue - containerWidth) > 1 {
                                containerWidth = newValue
                            }
                        }
                }
                .frame(height: 0)
            }

            if width != nil || containerWidth > 0 {
                let columnWidth = safeColumnWidth

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
