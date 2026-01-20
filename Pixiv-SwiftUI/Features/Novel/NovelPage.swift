import SwiftUI

struct NovelPage: View {
    @StateObject private var store = NovelStore()
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false
    var accountStore: AccountStore = AccountStore.shared

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var body: some View {
        NavigationStack(path: $path) {
            if !isLoggedIn {
                NovelNotLoggedInView(onLogin: {
                    showAuthView = true
                })
            } else {
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

                        NovelRankingPreview(store: store)
                    }
                    .padding(.vertical, 8)
                }
                .navigationTitle("小说")
                .pixivNavigationDestinations()
                .navigationDestination(for: NovelListType.self) { listType in
                    NovelListPage(listType: listType)
                }
                .refreshable {
                    await store.loadAll(userId: accountStore.currentAccount?.userId ?? "", forceRefresh: true)
                }
                .task {
                    await store.loadAll(userId: accountStore.currentAccount?.userId ?? "", forceRefresh: false)
                }
            }
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
            }
            #endif
        }
        .sheet(isPresented: $showProfilePanel) {
            #if os(iOS)
            ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            #endif
        }
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore, onGuestMode: nil)
        }
    }
}

struct NovelNotLoggedInView: View {
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("登录后解锁更多小说")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("关注作者、收藏小说，同步阅读进度")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onLogin) {
                Text("立即登录")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

#Preview {
    NovelPage()
}
