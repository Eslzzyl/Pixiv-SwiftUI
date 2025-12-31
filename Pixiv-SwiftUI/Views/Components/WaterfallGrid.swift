import SwiftUI

struct WaterfallGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
    let data: Data
    let columnCount: Int
    let content: (Data.Element) -> Content
    let onLoadMore: ((Data.Element) -> Void)?
    
    init(data: Data, columnCount: Int, onLoadMore: ((Data.Element) -> Void)? = nil, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.columnCount = columnCount
        self.content = content
        self.onLoadMore = onLoadMore
    }
    
    private var columns: [[Data.Element]] {
        var result = Array(repeating: [Data.Element](), count: columnCount)
        for (index, item) in data.enumerated() {
            result[index % columnCount].append(item)
        }
        return result
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<columnCount, id: \.self) { columnIndex in
                LazyVStack(spacing: 12) {
                    ForEach(columns[columnIndex]) { item in
                        content(item)
                            .onAppear {
                                onLoadMore?(item)
                            }
                    }
                }
            }
        }
        .padding(12)
    }
}
