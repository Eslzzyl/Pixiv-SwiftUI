import SwiftUI

/// 主导航视图
struct MainTabView: View {
    @State private var selectedTab = 0
    @Bindable var accountStore: AccountStore

    var body: some View {
        TabView(selection: $selectedTab) {
            // 推荐页
            RecommendView()
                .tabItem {
                    Label("推荐", systemImage: "star.fill")
                }
                .tag(0)

            // 速览页
            QuickView(accountStore: accountStore)
                .tabItem {
                    Label("速览", systemImage: "square.grid.2x2")
                }
                .tag(1)

            // 搜索页（占位）
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("搜索")
                    .font(.headline)
                Text("敬请期待")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.97))
            .tabItem {
                Label("搜索", systemImage: "magnifyingglass")
            }
            .tag(2)

            // 我的页面
            ProfileView(accountStore: accountStore)
                .tabItem {
                    Label("我的", systemImage: "person.fill")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView(accountStore: .shared)
}
