import SwiftUI

struct UpdatesPage: View {
    @State private var store = UpdatesStore()
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false
    @State private var contentType: TypeFilterButton.ContentType = .all
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess
    @Environment(UserSettingStore.self) var settingStore
    @Environment(ThemeManager.self) var themeManager
    var accountStore: AccountStore = AccountStore.shared
    @State private var prefetchTracker = PrefetchTracker()
    @State private var filteredUpdates: [Illusts] = []
    @State private var shouldBlurMap: [Int: Bool] = [:]

    private var restrictString: String {
        selectedRestrict == .privateAccess ? "private" : "public"
    }

    private func recalculateFilteredUpdates() {
        let base = settingStore.filterIllusts(store.updates)
        switch contentType {
        case .all:
            filteredUpdates = base
        case .illust:
            filteredUpdates = base.filter { $0.type != "manga" }
        case .manga:
            filteredUpdates = base.filter { $0.type == "manga" }
        }
        shouldBlurMap = Dictionary(
            uniqueKeysWithValues: filteredUpdates.map {
                ($0.id, settingStore.userSetting.shouldBlurIllust($0))
            }
        )
    }

    private func shouldBlurFromCache(for illust: Illusts) -> Bool {
        shouldBlurMap[illust.id] ?? false
    }

    private var isLoggedIn: Bool {        accountStore.isLoggedIn
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
            GeometryReader { proxy in
                let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
                let horizontalPadding: CGFloat = 24
                let availableWidth = proxy.size.width - horizontalPadding
                let waterfallWidth = availableWidth > 0 ? availableWidth : nil

                Group {
                    if !isLoggedIn {
                        NotLoggedInView(onLogin: {
                            showAuthView = true
                        })
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                FollowingHorizontalList(store: store, path: $path)
                                    .padding(.vertical, 8)

                                if (store.isLoadingUpdates || !store.hasFetchedUpdates) && store.updates.isEmpty {
                                    SkeletonIllustWaterfallGrid(
                                        columnCount: dynamicColumnCount,
                                        itemCount: skeletonItemCount,
                                        width: waterfallWidth
                                    )
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 400)
                                    .transition(.opacity)
                                } else if let error = store.error, store.updates.isEmpty {
                                    ErrorStateView(message: error.localizedDescription ?? "未知错误", retryAction: {
                                        Task {
                                            await store.refreshUpdates()
                                        }
                                    })
                                    .frame(maxWidth: .infinity, minHeight: 200)
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
                                    WaterfallGrid(data: filteredUpdates, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                                        IllustCard(
                                            illust: illust,
                                            columnCount: dynamicColumnCount,
                                            columnWidth: columnWidth,
                                            expiration: DefaultCacheExpiration.updates,
                                            feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                                            shouldBlur: shouldBlurFromCache(for: illust),
                                            accentColor: themeManager.currentColor
                                        )
                                        .equatable()
                                        .onTapGesture {
                                            path.append(illust)
                                        }
                                        .onAppear {
                                            prefetchIllustsIfNeeded(from: illust, in: filteredUpdates, quality: settingStore.userSetting.feedPreviewQuality, tracker: prefetchTracker)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .transition(.opacity)

                                    if store.nextUrlUpdates != nil {
                                        LazyVStack {
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
                        .animation(.easeInOut(duration: 0.25), value: store.isLoadingUpdates)
                        .refreshable {
                            let userId = accountStore.currentAccount?.userId ?? ""
                            await store.refreshFollowing(userId: userId)
                            await store.refreshUpdates(restrict: restrictString)
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
                        .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
                            if isLoggedIn {
                                let userId = accountStore.currentAccount?.userId ?? ""
                                Task {
                                    await store.refreshFollowing(userId: userId)
                                    await store.refreshUpdates(restrict: restrictString)
                                }
                            }
                        }
                        .onChange(of: accountStore.currentUserId) { _, _ in
                            if isLoggedIn {
                                let userId = accountStore.currentAccount?.userId ?? ""
                                Task {
                                    await store.refreshFollowing(userId: userId)
                                    await store.refreshUpdates(restrict: restrictString)
                                }
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
                .hideSharedBackgroundIfAvailable()
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
            .onChange(of: contentType) { _, _ in
                recalculateFilteredUpdates()
            }
            .onChange(of: store.updates) { _, _ in
                recalculateFilteredUpdates()
            }
            .sheet(isPresented: $showProfilePanel) {
                #if os(iOS)
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
                #endif
            }
            .task {
                guard isLoggedIn else { return }
                guard store.updates.isEmpty else { return }
                let userId = accountStore.currentAccount?.userId ?? ""
                await store.fetchFollowing(userId: userId)
                await store.fetchUpdates(restrict: restrictString)
            }
            .sheet(isPresented: $showAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
            }
            .onFilterSettingsChange(from: settingStore, perform: recalculateFilteredUpdates)
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
