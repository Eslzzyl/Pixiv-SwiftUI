import SwiftUI

struct UpdatesPage: View {
    @StateObject private var store = UpdatesStore()
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false
    @Environment(UserSettingStore.self) var settingStore
    var accountStore: AccountStore = AccountStore.shared

    @State private var dynamicColumnCount: Int = 4

    private var filteredUpdates: [Illusts] {
        settingStore.filterIllusts(store.updates)
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var body: some View {
        NavigationStack(path: $path) {
            if !isLoggedIn {
                NotLoggedInView(onLogin: {
                    showAuthView = true
                })
            } else {
                GeometryReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            FollowingHorizontalList(store: store, path: $path)
                                .padding(.vertical, 8)

                            if store.isLoadingUpdates && store.updates.isEmpty {
                                SkeletonIllustWaterfallGrid(columnCount: dynamicColumnCount, itemCount: 12)
                                    .padding(.horizontal, 12)
                            } else if store.updates.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("暂无动态")
                                        .foregroundColor(.gray)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 50)
                            } else {
                                LazyVStack(spacing: 12) {
                                    WaterfallGrid(data: filteredUpdates, columnCount: dynamicColumnCount) { illust, columnWidth in
                                        NavigationLink(value: illust) {
                                            IllustCard(
                                                illust: illust,
                                                columnCount: dynamicColumnCount,
                                                columnWidth: columnWidth,
                                                expiration: DefaultCacheExpiration.updates
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    if store.nextUrlUpdates != nil {
                                        ProgressView()
                                            .padding()
                                            .id(store.nextUrlUpdates)
                                            .onAppear {
                                                Task {
                                                    await store.loadMoreUpdates()
                                                }
                                            }
                                    }
                                }
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                    .refreshable {
                        let userId = accountStore.currentAccount?.userId ?? ""
                        await store.refreshFollowing(userId: userId)
                        await store.refreshUpdates()
                    }
                    .navigationTitle("动态")
                    .pixivNavigationDestinations()
                    .navigationDestination(for: String.self) { _ in
                        FollowingListView(store: FollowingListStore(), userId: accountStore.currentAccount?.userId ?? "")
                    }
                    .onChange(of: accountStore.navigationRequest) { _, newValue in
                        if let request = newValue {
                            switch request {
                            case .userDetail(let userId):
                                path.append(User(id: .string(userId), name: "", account: ""))
                            case .illustDetail(let illust):
                                path.append(illust)
                            }
                            accountStore.navigationRequest = nil
                        }
                    }
                    .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
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
        .onAppear {
            if isLoggedIn {
                let userId = accountStore.currentAccount?.userId ?? ""
                Task {
                    await store.fetchFollowing(userId: userId)
                    await store.fetchUpdates()
                }
            }
        }
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore, onGuestMode: nil)
        }
    }
}

/// 未登录时显示的占位视图
struct NotLoggedInView: View {
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("登录后查看动态")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("关注画师后，这里将显示他们的最新作品")
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
