import SwiftUI

/// 瀑布流网格视图
///
/// 使用 HStack + 多列 LazyVStack 实现瀑布流布局。
/// 采用增量式列更新：当 data 追加新元素时，仅将新元素分配到最短列，
/// 避免全量重算导致已渲染视图的 identity 变化。
struct WaterfallGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Data: Equatable, Content: View {
    let data: Data
    let columnCount: Int
    let spacing: CGFloat
    let width: CGFloat?
    let aspectRatio: ((Data.Element) -> CGFloat)?
    let content: (Data.Element, CGFloat) -> Content

    @State private var columns: [[Data.Element]] = []
    /// 上次完成列分配时的数据总量，用于增量追加
    @State private var previousDataCount: Int = 0
    /// 上次完成列分配时的元素身份，用于区分追加和整批替换
    @State private var previousDataIDs: [AnyHashable] = []

    init(data: Data, columnCount: Int, spacing: CGFloat = 12, width: CGFloat? = nil, aspectRatio: ((Data.Element) -> CGFloat)? = nil, @ViewBuilder content: @escaping (Data.Element, CGFloat) -> Content) {
        self.data = data
        self.columnCount = columnCount
        self.spacing = spacing
        self.width = width
        self.aspectRatio = aspectRatio
        self.content = content

        // 初始化时同步计算一次，避免 onAppear 时的闪烁
        let initialColumns = Self.calculateColumnsSynchronously(
            data: data,
            columnCount: columnCount,
            aspectRatio: aspectRatio
        )
        _columns = State(initialValue: initialColumns)
        _previousDataCount = State(initialValue: data.count)
        _previousDataIDs = State(initialValue: data.map { AnyHashable($0.id) })
    }

    private static func calculateColumnsSynchronously(
        data: Data,
        columnCount: Int,
        aspectRatio: ((Data.Element) -> CGFloat)?
    ) -> [[Data.Element]] {
        guard columnCount > 0 else {
            return []
        }
        var result = Array(repeating: [Data.Element](), count: columnCount)
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)

        if aspectRatio == nil {
            for (index, item) in data.enumerated() {
                result[index % columnCount].append(item)
            }
            return result
        }

        for item in data {
            if let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) {
                result[minIndex].append(item)
                if let ratio = aspectRatio?(item) {
                    let itemHeight = (ratio > 0) ? (1.0 / ratio) : 1.0
                    columnHeights[minIndex] += itemHeight
                }
            }
        }
        return result
    }

    /// 增量追加：仅将 data 中新出现的元素分配到最短列。
    /// 避免全量重算导致已渲染视图的 identity 变化，从而触发不必要的重新绘制。
    private func appendNewItems() {
        let newCount = data.count
        let currentDataIDs = data.map { AnyHashable($0.id) }
        guard currentDataIDs != previousDataIDs else {
            return
        }
        guard newCount > previousDataCount,
              currentDataIDs.starts(with: previousDataIDs),
              columns.count == columnCount,
              columnCount > 0,
              !columns.isEmpty
        else {
            // 条件不满足时回退全量重算（如首次加载、列数变化、数据减少）
            fullRecalculate()
            return
        }

        // 计算当前各列的累积高度
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)
        if let aspectRatio = aspectRatio {
            for col in 0..<columnCount {
                for item in columns[col] {
                    let ratio = aspectRatio(item)
                    columnHeights[col] += (ratio > 0) ? (1.0 / ratio) : 1.0
                }
            }
        } else {
            for col in 0..<columnCount {
                columnHeights[col] = CGFloat(columns[col].count)
            }
        }

        // 只分配新元素到当前最短列
        for i in previousDataCount..<newCount {
            let item = data[data.index(data.startIndex, offsetBy: i)]
            if let minIndex = columnHeights.indices.min(by: { columnHeights[$0] < columnHeights[$1] }) {
                columns[minIndex].append(item)
                if let ratio = aspectRatio?(item) {
                    let itemHeight = (ratio > 0) ? (1.0 / ratio) : 1.0
                    columnHeights[minIndex] += itemHeight
                } else {
                    columnHeights[minIndex] += 1.0
                }
            }
        }

        previousDataCount = newCount
        previousDataIDs = currentDataIDs
    }

    private func fullRecalculate() {
        columns = Self.calculateColumnsSynchronously(
            data: data,
            columnCount: columnCount,
            aspectRatio: aspectRatio
        )
        previousDataCount = data.count
        previousDataIDs = data.map { AnyHashable($0.id) }
    }

    private var safeColumnWidth: CGFloat {
        if let width = width, width > 0 {
            return max((width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)
        }
        // 当宽度为0时使用估计值，避免初始布局过大
        #if os(iOS)
        return 150
        #else
        return 170
        #endif
    }

    var body: some View {
        Group {
            if let width, width > 0 || !columns.isEmpty {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            guard columns.isEmpty || data.count != previousDataCount else { return }
            fullRecalculate()
        }
        .onChange(of: data) {
            appendNewItems()
        }
        .onChange(of: columnCount) {
            fullRecalculate()
        }
    }
}
