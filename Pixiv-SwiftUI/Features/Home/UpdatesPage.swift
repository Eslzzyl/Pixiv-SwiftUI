import SwiftUI
import Observation

@MainActor
@Observable
private final class UpdatesFeedProjection {
    var filteredUpdates: [Illusts] = []
    var shouldBlurMap: [Int: Bool] = [:]

    func recalculate(store: UpdatesStore, settingStore: UserSettingStore, contentType: TypeFilterButton.ContentType) {
        let base = settingStore.filterIllusts(store.updates)
        switch contentType {
        case .all:
            filteredUpdates = base
        case .illust:
            filteredUpdates = base.filter { $0.type != "manga" }
        case .manga:
            filteredUpdates = base.filter { $0.type == "manga" }
        }
        shouldBlurMap = Dictionary(uniqueKeysWithValues: filteredUpdates.map {
            ($0.id, settingStore.userSetting.shouldBlurIllust($0))
        })
    }

    func shouldBlur(for illust: Illusts) -> Bool {
        shouldBlurMap[illust.id] ?? false
    }
}

struct UpdatesPage: View {
    @State private var store = UpdatesStore()
    @State private var navigationRouter = PixivNavigationRouter()
    @State private var showProfilePanel = false
    @State private var contentType: TypeFilterButton.ContentType = .all
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess
    @State private var feedProjection = UpdatesFeedProjection()
    @Environment(UserSettingStore.self) var settingStore
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.scenePhase) private var scenePhase
    var accountStore: AccountStore = AccountStore.shared
    @State private var prefetchTracker = PrefetchTracker()

    private var restrictString: String {
        selectedRestrict == .privateAccess ? "private" : "public"
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
        @Bindable var navigationRouter = navigationRouter

        return NavigationStack(path: $navigationRouter.path) {
            GeometryReader { proxy in
                let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
                let horizontalPadding: CGFloat = 24
                let availableWidth = proxy.size.width - horizontalPadding
                let waterfallWidth = availableWidth > 0 ? availableWidth : nil

                if !isLoggedIn {
                    NotLoggedInView {
                        NotificationCenter.default.post(name: .showLoginSheet, object: nil)
                    }
                } else {
                    UpdatesFeedContent(
                        store: store,
                        projection: feedProjection,
                        settingStore: settingStore,
                        themeManager: themeManager,
                        accountStore: accountStore,
                        restrict: restrictString,
                        prefetchTracker: prefetchTracker,
                        contentType: $contentType,
                        dynamicColumnCount: dynamicColumnCount,
                        waterfallWidth: waterfallWidth,
                        skeletonItemCount: skeletonItemCount
                    )
                    .illustDetailNavigationSourceScope()
                    .navigationTitle("动态")
                    .pixivNavigationDestinations()
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
                    Task { await store.refreshUpdates(restrict: restrictString) }
                }
            }
            .sheet(isPresented: $showProfilePanel.preservingSheetPresentation(while: scenePhase)) {
                #if os(iOS)
                ProfilePanelView(
                    accountStore: accountStore,
                    isPresented: $showProfilePanel,
                    parentNavigationRouter: navigationRouter
                )
                #endif
            }
            .onChange(of: accountStore.navigationRequest, initial: true) { _, newValue in
                if let request = newValue {
                    switch request {
                    case .userDetail(let userId):
                        navigationRouter.push(.user(id: userId))
                    case .illustDetail(let illust):
                        navigationRouter.push(
                            IllustDetailNavigationSessionStore.shared.makeRoute(
                                illust: illust,
                                context: feedProjection.filteredUpdates,
                                contextProvider: { feedProjection.filteredUpdates },
                                hasMore: { store.nextUrlUpdates != nil },
                                loadMore: { await store.loadMoreUpdates() }
                            )
                        )
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
            .onChange(of: accountStore.accountGeneration) { _, _ in
                navigationRouter.popToRoot()
                if isLoggedIn {
                    let userId = accountStore.currentAccount?.userId ?? ""
                    Task {
                        await store.refreshFollowing(userId: userId)
                        await store.refreshUpdates(restrict: restrictString)
                    }
                }
            }
            .task {
                guard isLoggedIn, store.updates.isEmpty else { return }
                let userId = accountStore.currentAccount?.userId ?? ""
                await store.fetchFollowing(userId: userId)
                await store.fetchUpdates(restrict: restrictString)
            }
        }
        .environment(\.pixivNavigationRouter, navigationRouter)
    }
}

private struct UpdatesFeedContent: View {
    let store: UpdatesStore
    let projection: UpdatesFeedProjection
    let settingStore: UserSettingStore
    let themeManager: ThemeManager
    let accountStore: AccountStore
    let restrict: String
    let prefetchTracker: PrefetchTracker
    @Binding var contentType: TypeFilterButton.ContentType
    let dynamicColumnCount: Int
    let waterfallWidth: CGFloat?
    let skeletonItemCount: Int

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FollowingHorizontalList(store: store)
                    .padding(.vertical, 8)

                if (store.isLoadingUpdates || !store.hasFetchedUpdates) && store.updates.isEmpty {
                    SkeletonIllustWaterfallGrid(
                        columnCount: dynamicColumnCount,
                        itemCount: skeletonItemCount,
                        width: waterfallWidth
                    )
                    .padding(.horizontal, 12)
                    .frame(minHeight: 400)
                    .transition(.opacity.animation(.easeInOut(duration: 0.25)))
                } else if let error = store.error, store.updates.isEmpty {
                    ErrorStateView(message: error.localizedDescription, retryAction: {
                        Task { await store.refreshUpdates(restrict: restrict) }
                    })
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else if store.updates.isEmpty {
                    UpdatesEmptyState()
                } else {
                    UpdatesIllustGrid(
                        store: store,
                        projection: projection,
                        settingStore: settingStore,
                        themeManager: themeManager,
                        prefetchTracker: prefetchTracker,
                        dynamicColumnCount: dynamicColumnCount,
                        waterfallWidth: waterfallWidth
                    )
                }
            }
        }
        .refreshable {
            let userId = accountStore.currentAccount?.userId ?? ""
            await store.refreshFollowing(userId: userId)
            await store.refreshUpdates(restrict: restrict)
        }
        .onChange(of: contentType) { _, _ in
            projection.recalculate(store: store, settingStore: settingStore, contentType: contentType)
        }
        .onChange(of: store.updates) { _, _ in
            projection.recalculate(store: store, settingStore: settingStore, contentType: contentType)
        }
        .onFilterSettingsChange(from: settingStore) {
            projection.recalculate(store: store, settingStore: settingStore, contentType: contentType)
        }
        .onAppear {
            projection.recalculate(store: store, settingStore: settingStore, contentType: contentType)
        }
    }
}

private struct UpdatesIllustGrid: View {
    let store: UpdatesStore
    let projection: UpdatesFeedProjection
    let settingStore: UserSettingStore
    let themeManager: ThemeManager
    let prefetchTracker: PrefetchTracker
    let dynamicColumnCount: Int
    let waterfallWidth: CGFloat?

    var body: some View {
        WaterfallGrid(
            data: projection.filteredUpdates,
            columnCount: dynamicColumnCount,
            width: waterfallWidth,
            aspectRatio: { $0.safeAspectRatio }
        ) { illust, columnWidth in
            IllustDetailNavigationLink(
                illust: illust,
                context: projection.filteredUpdates,
                contextProvider: { projection.filteredUpdates },
                hasMore: { store.nextUrlUpdates != nil },
                loadMore: { await store.loadMoreUpdates() }
            ) {
                IllustCard(
                    illust: illust,
                    columnCount: dynamicColumnCount,
                    columnWidth: columnWidth,
                    expiration: DefaultCacheExpiration.updates,
                    feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                    shouldBlur: projection.shouldBlur(for: illust),
                    accentColor: themeManager.currentColor
                )
                .equatable()
            }
            .buttonStyle(.plain)
            .onAppear {
                prefetchIllustsIfNeeded(
                    from: illust,
                    in: projection.filteredUpdates,
                    quality: settingStore.userSetting.feedPreviewQuality,
                    multiPagePrefetchCount: settingStore.userSetting.listMultiPagePrefetchCount,
                    tracker: prefetchTracker
                )
            }
        }
        .padding(.horizontal, 12)
        .transition(.opacity.animation(.easeInOut(duration: 0.25)))

        UpdatesPaginationFooter(store: store, projection: projection)
    }
}

private struct UpdatesPaginationFooter: View {
    let store: UpdatesStore
    let projection: UpdatesFeedProjection

    var body: some View {
        if let nextURL = store.nextUrlUpdates {
            LazyVStack {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
                    .id(nextURL)
                    .onAppear {
                        Task { await store.loadMoreUpdates() }
                    }
            }
        } else if !projection.filteredUpdates.isEmpty {
            Text(String(localized: "已经到底了"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

private struct UpdatesEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("暂无动态")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 50)
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

#Preview {
    NotLoggedInView(onLogin: {})
}

#Preview("动态空态") {
    UpdatesEmptyState()
}

#Preview("动态分页") {
    UpdatesPaginationFooter(store: UpdatesStore(), projection: UpdatesFeedProjection())
}

#Preview("Updates content") {
    let settings = UserSettingStore()
    return UpdatesFeedContent(
        store: UpdatesStore(),
        projection: UpdatesFeedProjection(),
        settingStore: settings,
        themeManager: ThemeManager(userSettingStore: settings),
        accountStore: AccountStore.shared,
        restrict: "public",
        prefetchTracker: PrefetchTracker(),
        contentType: .constant(.all),
        dynamicColumnCount: 2,
        waterfallWidth: 320,
        skeletonItemCount: 4
    )
}

#Preview("Updates grid") {
    let settings = UserSettingStore()
    return UpdatesIllustGrid(
        store: UpdatesStore(),
        projection: UpdatesFeedProjection(),
        settingStore: settings,
        themeManager: ThemeManager(userSettingStore: settings),
        prefetchTracker: PrefetchTracker(),
        dynamicColumnCount: 2,
        waterfallWidth: 320
    )
}
