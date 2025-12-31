import SwiftUI

/// 搜索视图
struct SearchView: View {
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                if searchText.isEmpty {
                    ContentUnavailableView("搜索", systemImage: "magnifyingglass", description: Text("输入关键词开始搜索"))
                } else {
                    List {
                        Text("搜索结果: \(searchText)")
                    }
                }
            }
            .navigationTitle("搜索")
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer, prompt: "搜索插画、用户")
    }
}

#Preview {
    SearchView()
}
