import SwiftUI
import Combine

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
    let isLazy: Bool
    let content: (Data.Element, CGFloat) -> Content

    @StateObject private var placementModel: PlacementModel

    @MainActor
    private final class PlacementModel: ObservableObject {
        @Published private(set) var columns: [[Data.Element]]
        private var processedIDs: [Data.Element.ID]
        private var processedHeights: [CGFloat]
        private var memberships: [Int]
        private var columnHeights: [CGFloat]
        private var processedColumnCount: Int

        init(data: Data, columnCount: Int, aspectRatio: ((Data.Element) -> CGFloat)?) {
            self.columns = []
            self.processedIDs = []
            self.processedHeights = []
            self.memberships = []
            self.columnHeights = []
            self.processedColumnCount = columnCount
            applyFull(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
        }

        func update(data: Data, columnCount: Int, aspectRatio: ((Data.Element) -> CGFloat)?) {
            let oldCount = processedIDs.count
            guard columnCount == processedColumnCount, data.count >= oldCount else {
                applyFull(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
                return
            }

            for (index, item) in data.prefix(oldCount).enumerated() {
                guard item.id == processedIDs[index] else {
                    applyFull(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
                    return
                }
                let height = normalizedHeight(for: item, aspectRatio: aspectRatio)
                if height != processedHeights[index] {
                    if columnCount > 0 {
                        columnHeights[memberships[index]] += height - processedHeights[index]
                    }
                    processedHeights[index] = height
                }
            }

            guard data.count > oldCount else { return }
            guard columnCount > 0 else {
                applyFull(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
                return
            }

            var nextColumns = columns
            processedIDs.reserveCapacity(data.count)
            processedHeights.reserveCapacity(data.count)
            memberships.reserveCapacity(data.count)
            for item in data.dropFirst(oldCount) {
                let height = normalizedHeight(for: item, aspectRatio: aspectRatio)
                let column = shortestColumn(in: columnHeights)
                nextColumns[column].append(item)
                columnHeights[column] += height
                processedIDs.append(item.id)
                processedHeights.append(height)
                memberships.append(column)
            }
            columns = nextColumns
        }

        private func applyFull(data: Data, columnCount: Int, aspectRatio: ((Data.Element) -> CGFloat)?) {
            var nextIDs: [Data.Element.ID] = []
            var nextHeights: [CGFloat] = []
            var nextMemberships: [Int] = []
            nextIDs.reserveCapacity(data.count)
            nextHeights.reserveCapacity(data.count)
            nextMemberships.reserveCapacity(data.count)
            var nextColumns = Array(repeating: [Data.Element](), count: max(columnCount, 0))
            var nextColumnHeights = Array(repeating: CGFloat(0), count: max(columnCount, 0))

            for (index, item) in data.enumerated() {
                let height = normalizedHeight(for: item, aspectRatio: aspectRatio)
                nextIDs.append(item.id)
                nextHeights.append(height)
                guard columnCount > 0 else {
                    nextMemberships.append(0)
                    continue
                }
                let column = aspectRatio == nil ? index % columnCount : shortestColumn(in: nextColumnHeights)
                nextColumns[column].append(item)
                nextMemberships.append(column)
                nextColumnHeights[column] += height
            }

            processedIDs = nextIDs
            processedHeights = nextHeights
            memberships = nextMemberships
            columnHeights = nextColumnHeights
            processedColumnCount = columnCount
            columns = nextColumns
        }

        private func normalizedHeight(for item: Data.Element, aspectRatio: ((Data.Element) -> CGFloat)?) -> CGFloat {
            guard let ratio = aspectRatio?(item) else { return 1 }
            return ratio > 0 ? 1 / ratio : 1
        }

        private func shortestColumn(in heights: [CGFloat]) -> Int {
            var shortest = 0
            for index in heights.indices.dropFirst() where heights[index] < heights[shortest] {
                shortest = index
            }
            return shortest
        }
    }

    init(
        data: Data,
        columnCount: Int,
        spacing: CGFloat = 12,
        width: CGFloat? = nil,
        aspectRatio: ((Data.Element) -> CGFloat)? = nil,
        isLazy: Bool = true,
        @ViewBuilder content: @escaping (Data.Element, CGFloat) -> Content
    ) {
        self.data = data
        self.columnCount = columnCount
        self.spacing = spacing
        self.width = width
        self.aspectRatio = aspectRatio
        self.isLazy = isLazy
        self.content = content
        _placementModel = StateObject(wrappedValue: PlacementModel(data: data, columnCount: columnCount, aspectRatio: aspectRatio))
    }

    private var safeColumnWidth: CGFloat {
        if columnCount > 0, let width, width > 0 {
            return max((width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)
        }
        #if os(iOS)
        return 150
        #else
        return 170
        #endif
    }

    var body: some View {
        Group {
            if let width, width > 0 || !placementModel.columns.isEmpty {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<max(columnCount, 0), id: \.self) { columnIndex in
                        if columnIndex < placementModel.columns.count {
                            if isLazy {
                                LazyVStack(spacing: spacing) {
                                    ForEach(placementModel.columns[columnIndex]) { item in
                                        content(item, safeColumnWidth)
                                    }
                                }
                                .frame(width: safeColumnWidth)
                            } else {
                                VStack(spacing: spacing) {
                                    ForEach(placementModel.columns[columnIndex]) { item in
                                        content(item, safeColumnWidth)
                                    }
                                }
                                .frame(width: safeColumnWidth)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .onAppear {
            placementModel.update(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
        }
        .onChange(of: data) {
            placementModel.update(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
        }
        .onChange(of: columnCount) {
            placementModel.update(data: data, columnCount: columnCount, aspectRatio: aspectRatio)
        }
    }
}

private struct WaterfallPreviewItem: Identifiable, Equatable {
    let id: Int
    let ratio: CGFloat
}

#Preview {
    WaterfallGrid(
        data: [WaterfallPreviewItem(id: 1, ratio: 1), WaterfallPreviewItem(id: 2, ratio: 0.5)],
        columnCount: 2,
        width: 320,
        aspectRatio: { $0.ratio }
    ) { item, width in
        RoundedRectangle(cornerRadius: 16)
            .fill(.blue.opacity(0.3))
            .frame(width: width, height: width / item.ratio)
    }
    .padding()
}
