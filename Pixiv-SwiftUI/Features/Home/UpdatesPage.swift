import SwiftUI

struct UpdatesPage: View {
    @StateObject private var store = UpdatesStore()
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @Environment(UserSettingStore.self) var settingStore
    var accountStore: AccountStore = AccountStore.shared

    private var columnCount: Int {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? settingStore.userSetting.hCrossCount : settingStore.userSetting.crossCount
        #else
        settingStore.userSetting.hCrossCount
        #endif
    }

    private var filteredUpdates: [Illusts] {
        settingStore.filterIllusts(store.updates)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FollowingHorizontalList(store: store, path: $path)
                        .padding(.vertical, 8)

                    if store.isLoadingUpdates && store.updates.isEmpty {
                        VStack {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
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
                            WaterfallGrid(data: filteredUpdates, columnCount: columnCount) { illust, columnWidth in
                                NavigationLink(value: illust) {
                                    IllustCard(
                                        illust: illust,
                                        columnCount: columnCount,
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
            }
            .pixivNavigationDestinations()
            .navigationDestination(for: String.self) { _ in
                FollowingListView(store: FollowingListStore(), userId: accountStore.currentAccount?.userId ?? "")
            }
            .sheet(isPresented: $showProfilePanel) {
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
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
        }
        .onAppear {
            let userId = accountStore.currentAccount?.userId ?? ""
            Task {
                await store.fetchFollowing(userId: userId)
                await store.fetchUpdates()
            }
        }
    }
}
