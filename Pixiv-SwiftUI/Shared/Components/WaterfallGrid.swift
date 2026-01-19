import SwiftUI

struct WaterfallGrid<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable, Content: View {
    let data: Data
    let columnCount: Int
    let spacing: CGFloat
    let width: CGFloat?
    let content: (Data.Element, CGFloat) -> Content
    
    @State private var containerWidth: CGFloat = 0
    
    init(data: Data, columnCount: Int, spacing: CGFloat = 12, width: CGFloat? = nil, @ViewBuilder content: @escaping (Data.Element, CGFloat) -> Content) {
        self.data = data
        self.columnCount = columnCount
        self.spacing = spacing
        self.width = width
        self.content = content
        
        // 如果提供了宽度，则直接初始化状态
        if let width = width {
            _containerWidth = State(initialValue: width)
        }
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
            if width == nil {
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
            }
            
            let currentWidth = width ?? containerWidth
            
            if currentWidth > 0 {
                let safeColumnWidth = max((currentWidth - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount), 50)
                
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
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
