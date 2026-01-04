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
                VStack(spacing: 0) {
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
                        .padding(.horizontal, 12)

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
                }
            }
            .navigationTitle("动态")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
            }
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
            .navigationDestination(for: String.self) { _ in
                FollowingListView(store: FollowingListStore(), userId: accountStore.currentAccount?.userId ?? "")
            }
            .sheet(isPresented: $showProfilePanel) {
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            }
        }
        .onAppear {
            Task {
                await store.fetchFollowing(userId: accountStore.currentAccount?.userId ?? "")
                await store.fetchUpdates()
            }
        }
    }
}
