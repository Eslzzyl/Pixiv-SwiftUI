import SwiftUI

struct WaterfallGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Data: Equatable, Content: View {
    let data: Data
    let columnCount: Int
    let spacing: CGFloat
    let width: CGFloat?
    let aspectRatio: ((Data.Element) -> CGFloat)?
    let content: (Data.Element, CGFloat) -> Content

    @State private var containerWidth: CGFloat = 0
    @State private var columns: [[Data.Element]] = []

    init(data: Data, columnCount: Int, spacing: CGFloat = 12, width: CGFloat? = nil, aspectRatio: ((Data.Element) -> CGFloat)? = nil, @ViewBuilder content: @escaping (Data.Element, CGFloat) -> Content) {
        self.data = data
        self.columnCount = columnCount
        self.spacing = spacing
        self.width = width
        self.aspectRatio = aspectRatio
        self.content = content

        // 如果提供了宽度，则直接初始化状态
        if let width = width {
            _containerWidth = State(initialValue: width)
        }
    }
    
    private func recalculateColumns() {
        var result = Array(repeating: [Data.Element](), count: columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)

        guard columnCount > 0 else {
            columns = result
            return
        }

        // 如果没有提供高度提供者，退回到简单的取模分布
        if aspectRatio == nil {
            for (index, item) in data.enumerated() {
                result[index % columnCount].append(item)
            }
            columns = result
            return
        }

        // 使用最短列优先算法
        for item in data {
            // 找到当前高度最小的列
            if let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) {
                result[minIndex].append(item)

                // 累加高度
                // 这里约定 aspectRatio 返回 (width / height)
                // 那么 itemHeight = columnWidth / aspectRatio
                if let ratio = aspectRatio?(item) {
                    let itemHeight = (ratio > 0) ? (1.0 / ratio) : 1.0 // 归一化高度
                    columnHeights[minIndex] += itemHeight
                }
            }
        }
        columns = result
    }

    private var safeColumnWidth: CGFloat {
        let currentWidth = width ?? containerWidth
        if currentWidth > 0 {
            return max((currentWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)
        } else {
            // 当宽度为0时，使用估计值，避免在 iOS 上初始宽度过大
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
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        if columnIndex < columns.count {
                            LazyVStack(spacing: spacing) {
                                ForEach(columns[columnIndex]) { item in
                                    content(item, safeColumnWidth)
                                }
                            }
                            .frame(width: safeColumnWidth)
                        }
                    }
                }
            }
        }
        .onAppear {
            recalculateColumns()
        }
        .onChange(of: data) {
            recalculateColumns()
        }
        .onChange(of: columnCount) {
            recalculateColumns()
        }
    }
}
