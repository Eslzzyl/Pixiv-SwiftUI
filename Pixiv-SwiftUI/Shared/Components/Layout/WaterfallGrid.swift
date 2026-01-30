import SwiftUI

struct WaterfallGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
    let data: Data
    let columnCount: Int
    let spacing: CGFloat
    let width: CGFloat?
    let heightProvider: ((Data.Element) -> CGFloat)?
    let content: (Data.Element, CGFloat) -> Content

    @State private var containerWidth: CGFloat = 0

    // 使用 State 缓存计算好的列数据，避免每次 View 更新都重算
    // 但因为我们希望响应 data 变化，我们使用 computed property 配合 memoization 思想
    // 或者简单地，在 layout 算法中如果数据量大才会有性能问题。
    // 为了支持"最短列优先"，我们需要计算布局。

    private var columns: [[Data.Element]] {
        var result = Array(repeating: [Data.Element](), count: columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)

        guard columnCount > 0 else { return result }

        // 如果没有提供高度提供者，退回到简单的取模分布
        if heightProvider == nil {
            for (index, item) in data.enumerated() {
                result[index % columnCount].append(item)
            }
            return result
        }

        // 使用最短列优先算法
        // 注意：这里假设所有列宽相同
        for item in data {
            // 找到当前高度最小的列
            // 使用 min(by:) 找到索引
            if let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) {
                result[minIndex].append(item)

                // 累加高度
                // 假设宽度固定，高度由 aspectRatio 决定: height = width / aspectRatio
                // 或者 heightProvider 直接返回 aspectRatio (h/w) 或 height
                // 这里约定 heightProvider 返回 aspectRatio (width / height)
                // 那么 itemHeight = columnWidth / aspectRatio
                if let aspectRatio = heightProvider?(item) {
                    let itemHeight = (aspectRatio > 0) ? (1.0 / aspectRatio) : 1.0 // 归一化高度，只关心相对值
                    columnHeights[minIndex] += itemHeight
                }
            }
        }

        return result
    }

    init(data: Data, columnCount: Int, spacing: CGFloat = 12, width: CGFloat? = nil, heightProvider: ((Data.Element) -> CGFloat)? = nil, @ViewBuilder content: @escaping (Data.Element, CGFloat) -> Content) {
        self.data = data
        self.columnCount = columnCount
        self.spacing = spacing
        self.width = width
        self.heightProvider = heightProvider
        self.content = content

        // 如果提供了宽度，则直接初始化状态
        if let width = width {
            _containerWidth = State(initialValue: width)
        }
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
    }
}
