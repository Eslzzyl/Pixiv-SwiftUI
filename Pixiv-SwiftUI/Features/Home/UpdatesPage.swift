import SwiftUI

struct UpdatesPage: View {
    @StateObject private var store = UpdatesStore()
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false
    @State private var contentType: TypeFilterButton.ContentType = .all
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess
    @Environment(UserSettingStore.self) var settingStore
    var accountStore: AccountStore = AccountStore.shared

    @State private var dynamicColumnCount: Int = 4

    private var restrictString: String {
        selectedRestrict == .privateAccess ? "private" : "public"
    }

    private var filteredUpdates: [Illusts] {
        let base = settingStore.filterIllusts(store.updates)
        switch contentType {
        case .all:
            return base
        case .illust:
            return base.filter { $0.type != "manga" }
        case .manga:
            return base.filter { $0.type == "manga" }
        }
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !isLoggedIn {
                    NotLoggedInView(onLogin: {
                        showAuthView = true
                    })
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            FollowingHorizontalList(store: store, path: $path)
                                .padding(.vertical, 8)

                            if store.isLoadingUpdates && store.updates.isEmpty {
                                SkeletonIllustWaterfallGrid(
                                    columnCount: dynamicColumnCount,
                                    itemCount: skeletonItemCount
                                )
                                .padding(.horizontal, 12)
                                .frame(minHeight: 400)
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
                                WaterfallGrid(data: filteredUpdates, columnCount: dynamicColumnCount, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
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
                                .padding(.horizontal, 12)

                                if store.nextUrlUpdates != nil {
                                    ProgressView()
                                        #if os(macOS)
                                        .controlSize(.small)
                                        #endif
                                        .padding()
                                        .id(store.nextUrlUpdates)
                                        .onAppear {
                                            Task {
                                                await store.loadMoreUpdates()
                                            }
                                        }
                                } else if !filteredUpdates.isEmpty {
                                    Text(String(localized: "已经到底了"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                        }
                    }
                    .refreshable {
                        let userId = accountStore.currentAccount?.userId ?? ""
                        async let following = store.refreshFollowing(userId: userId)
                        async let updates = store.refreshUpdates(restrict: restrictString)
                        _ = await (following, updates)
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
                    .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
                        if isLoggedIn {
                            let userId = accountStore.currentAccount?.userId ?? ""
                            Task {
                                async let following = store.refreshFollowing(userId: userId)
                                async let updates = store.refreshUpdates(restrict: restrictString)
                                _ = await (following, updates)
                            }
                        }
                    }
                    .onChange(of: accountStore.currentUserId) { _, _ in
                        if isLoggedIn {
                            let userId = accountStore.currentAccount?.userId ?? ""
                            Task {
                                async let following = store.refreshFollowing(userId: userId)
                                async let updates = store.refreshUpdates(restrict: restrictString)
                                _ = await (following, updates)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    TypeFilterButton(
                        selectedType: $contentType,
                        restrict: .publicAccess,
                        selectedRestrict: $selectedRestrict,
                        cacheFilter: .constant(nil)
                    )
                    .menuIndicator(.hidden)
                }
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
                ToolbarItem {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
                #endif
                #if os(macOS)
                ToolbarItem {
                    RefreshButton(refreshAction: {
                        let userId = accountStore.currentAccount?.userId ?? ""
                        await store.refreshFollowing(userId: userId)
                        await store.refreshUpdates(restrict: restrictString)
                    })
                }
                #endif
            }
            .onChange(of: selectedRestrict) { _, newValue in
                if newValue != nil {
                    Task {
                        await store.refreshUpdates(restrict: restrictString)
                    }
                }
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
                        async let following = store.fetchFollowing(userId: userId)
                        async let updates = store.fetchUpdates(restrict: restrictString)
                        _ = await (following, updates)
                    }
                }
            }
            .sheet(isPresented: $showAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
            }
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
