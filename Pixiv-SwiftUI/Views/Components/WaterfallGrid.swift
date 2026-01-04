import SwiftUI

struct WaterfallGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
    let data: Data
    let columnCount: Int
    let spacing: CGFloat
    let content: (Data.Element, CGFloat) -> Content
    
    @State private var containerWidth: CGFloat = 0
    
    init(data: Data, columnCount: Int, spacing: CGFloat = 12, @ViewBuilder content: @escaping (Data.Element, CGFloat) -> Content) {
        self.data = data
        self.columnCount = columnCount
        self.spacing = spacing
        self.content = content
    }
    
    private var columns: [[Data.Element]] {
        var result = Array(repeating: [Data.Element](), count: columnCount)
        for (index, item) in data.enumerated() {
            result[index % columnCount].append(item)
        }
        return result
    }
    
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
                let columnWidth = (containerWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
                
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        LazyVStack(spacing: spacing) {
                            ForEach(columns[columnIndex]) { item in
                                content(item, columnWidth)
                            }
                        }
                        .frame(width: columnWidth)
                    }
                }
            }
        }
    }
}
