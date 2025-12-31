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

            // 速览页（占位）
            VStack {
                Image(systemName: "photo.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("速览")
                    .font(.headline)
                Text("敬请期待")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.97))
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

            // 我的页面（占位）
            VStack {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                Text("我的")
                    .font(.headline)
                Text("敬请期待")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: logout) {
                    Label("登出", systemImage: "power.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.red)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.97))
            .tabItem {
                Label("我的", systemImage: "person.fill")
            }
            .tag(3)
        }
    }

    /// 登出
    private func logout() {
        do {
            try accountStore.logout()
        } catch {
            print("登出失败: \(error)")
        }
    }
}

#Preview {
    MainTabView(accountStore: AccountStore())
}
