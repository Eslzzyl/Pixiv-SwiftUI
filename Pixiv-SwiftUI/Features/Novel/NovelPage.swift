import SwiftUI

struct NovelPage: View {
    @StateObject private var store = NovelStore()
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    var accountStore: AccountStore = AccountStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    NovelHorizontalList(
                        title: "推荐",
                        novels: store.recomNovels,
                        listType: .recommend
                    )

                    NovelHorizontalList(
                        title: "关注新作",
                        novels: store.followingNovels,
                        listType: .following
                    )

                    NovelHorizontalList(
                        title: "收藏",
                        novels: store.bookmarkNovels,
                        listType: .bookmarks(userId: accountStore.currentAccount?.userId ?? "")
                    )
                }
                .padding(.vertical, 8)
            }
            .navigationTitle("小说")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
            }
            .pixivNavigationDestinations()
            .navigationDestination(for: NovelListType.self) { listType in
                NovelListPage(listType: listType)
            }
            .refreshable {
                await store.loadAll(userId: accountStore.currentAccount?.userId ?? "", forceRefresh: true)
            }
            .sheet(isPresented: $showProfilePanel) {
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            }
            .task {
                await store.loadAll(userId: accountStore.currentAccount?.userId ?? "")
            }
        }
    }
}

#Preview {
    NovelPage()
}
