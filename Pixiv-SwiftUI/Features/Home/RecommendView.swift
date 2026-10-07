import SwiftUI

/// 推荐页面
struct RecommendView: View {
    @State private var vm = RecommendViewModel()
    @State private var isInitialLoadInProgress = false

    @State private var navigationRouter = PixivNavigationRouter()
    @State private var showProfilePanel = false

    @Environment(UserSettingStore.self) var settingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.scenePhase) private var scenePhase

    /// 预取进度追踪器（引用类型，避免 @State 触发不必要的视图重绘）
    @State private var prefetchTracker = PrefetchTracker()

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    private func mainList(containerWidth: CGFloat) -> some View {
        RecommendMainList(
            vm: vm,
            accountStore: accountStore,
            settingStore: settingStore,
            themeManager: themeManager,
            prefetchTracker: prefetchTracker,
            containerWidth: containerWidth,
            skeletonItemCount: skeletonItemCount,
            retryLoading: retryLoading
        )
    }

    var body: some View {
        @Bindable var navigationRouter = navigationRouter

        return NavigationStack(path: $navigationRouter.path) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    mainList(containerWidth: proxy.size.width)
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #else
            .background(Color(.systemBackground))
            #endif
            .navigationTitle(String(localized: "推荐"))
            .toolbar {
                ToolbarItem {
                    TypeFilterButton(
                        selectedType: $vm.contentType,
                        restrict: nil,
                        selectedRestrict: .constant(nil as TypeFilterButton.RestrictType?),
                        showAll: false,
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
                    RefreshButton(refreshAction: { await vm.refreshAll() })
                }
                #endif
            }
            .pixivNavigationDestinations()
            .onAppear {
                vm.loadCachedData()

                if vm.illusts.isEmpty {
                    guard !isInitialLoadInProgress else { return }
                    isInitialLoadInProgress = true
                    Task {
                        defer { isInitialLoadInProgress = false }

                        if vm.isLoggedIn {
                            async let usersTask = vm.recommendedUsersStore.fetchUsers()
                            async let illustsTask = vm.refreshIllusts(forceRefresh: false)
                            async let tagsTask: Void = accountStore.isWebLoggedIn ? vm.searchStore.fetchRecommendedTags() : ()
                            _ = await (usersTask, illustsTask, tagsTask)
                        } else {
                            await vm.refreshIllusts(forceRefresh: false)
                        }
                    }
                } else {
                    if vm.isLoggedIn {
                        Task {
                            await vm.recommendedUsersStore.fetchUsers()
                        }
                        if accountStore.isWebLoggedIn, vm.searchStore.recommendByTagGroups.isEmpty {
                            Task {
                                await vm.searchStore.fetchRecommendedTags()
                            }
                        }
                    }
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
                                context: vm.filteredIllusts,
                                contextProvider: { vm.filteredIllusts },
                                hasMore: { vm.hasMoreData },
                                loadMore: { await vm.loadMoreData() }
                            )
                        )
                    }
                    accountStore.navigationRequest = nil
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshCurrentPage)) { _ in
                Task {
                    await vm.refreshAll()
                }
            }
            .onChange(of: accountStore.accountGeneration) { _, _ in
                navigationRouter.popToRoot()
                Task {
                    vm.resetForAccountChange()
                    if vm.isLoggedIn {
                        async let illustsTask = vm.refreshIllusts()
                        async let usersTask = vm.recommendedUsersStore.refreshUsers()
                        async let tagsTask: Void = accountStore.isWebLoggedIn ? vm.searchStore.fetchRecommendedTags(forceRefresh: true) : ()
                        _ = await (illustsTask, usersTask, tagsTask)
                    } else {
                        await vm.refreshIllusts()
                    }
                }
            }
            .onChange(of: vm.contentType) { _, _ in
                Task {
                    vm.illusts = []
                    vm.recalculateFilteredIllusts()
                    vm.nextUrl = nil
                    vm.hasMoreData = true
                    await vm.refreshIllusts(forceRefresh: false)
                }
            }
        }
        .environment(\.pixivNavigationRouter, navigationRouter)
    }

    private func retryLoading() {
        Task {
            await vm.loadMoreData()
        }
    }

}

private struct RecommendMainList: View {
    let vm: RecommendViewModel
    let accountStore: AccountStore
    let settingStore: UserSettingStore
    let themeManager: ThemeManager
    let prefetchTracker: PrefetchTracker
    let containerWidth: CGFloat
    let skeletonItemCount: Int
    let retryLoading: () -> Void

    var body: some View {
        let dynamicColumnCount = ResponsiveGrid.columnCount(
            for: containerWidth,
            userSetting: settingStore.userSetting
        )
        let availableWidth = containerWidth - 24
        let waterfallWidth = availableWidth > 0 ? availableWidth : nil

        ScrollView {
            VStack(spacing: 0) {
                if !vm.isLoggedIn {
                    LoginBannerView {
                        NotificationCenter.default.post(name: .showLoginSheet, object: nil)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                if vm.isLoggedIn {
                    RecommendPeopleAndTags(
                        vm: vm,
                        accountStore: accountStore
                    )
                }

                HStack {
                    Text(vm.contentType == .manga
                         ? String(localized: "漫画")
                         : (vm.isLoggedIn ? String(localized: "插画") : String(localized: "热门")))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                RecommendIllustSection(
                    vm: vm,
                    settingStore: settingStore,
                    themeManager: themeManager,
                    prefetchTracker: prefetchTracker,
                    dynamicColumnCount: dynamicColumnCount,
                    waterfallWidth: waterfallWidth,
                    skeletonItemCount: skeletonItemCount,
                    retryLoading: retryLoading
                )
            }
        }
        .illustDetailNavigationSourceScope()
        .refreshable {
            await vm.refreshAll()
        }
    }
}

private struct RecommendPeopleAndTags: View {
    let vm: RecommendViewModel
    let accountStore: AccountStore

    var body: some View {
        VStack(spacing: 0) {
            RecommendedArtistsList(
                recommendedUsers: Binding(
                    get: { vm.recommendedUsersStore.users },
                    set: { vm.recommendedUsersStore.users = $0 }
                ),
                isLoadingRecommended: Binding(
                    get: { vm.recommendedUsersStore.isLoading },
                    set: { vm.recommendedUsersStore.isLoading = $0 }
                ),
                onRefresh: { await vm.recommendedUsersStore.fetchUsers(forceRefresh: true) }
            )
            Spacer().frame(height: 16)

            if accountStore.isWebLoggedIn {
                RecommendTagGroupList(
                    tagGroups: vm.searchStore.recommendByTagGroups,
                    isLoading: vm.searchStore.isLoadingRecommendedTags
                )
            }
            Spacer().frame(height: 8)
        }
    }
}

private struct RecommendIllustSection: View {
    let vm: RecommendViewModel
    let settingStore: UserSettingStore
    let themeManager: ThemeManager
    let prefetchTracker: PrefetchTracker
    let dynamicColumnCount: Int
    let waterfallWidth: CGFloat?
    let skeletonItemCount: Int
    let retryLoading: () -> Void

    var body: some View {
        if vm.filteredIllusts.isEmpty {
            RecommendEmptyState(
                error: vm.error,
                isLoading: vm.isLoading,
                dynamicColumnCount: dynamicColumnCount,
                waterfallWidth: waterfallWidth,
                skeletonItemCount: skeletonItemCount,
                retryLoading: retryLoading
            )
        } else {
            WaterfallGrid(
                data: vm.filteredIllusts,
                columnCount: dynamicColumnCount,
                width: waterfallWidth,
                aspectRatio: { $0.safeAspectRatio }
            ) { illust, columnWidth in
                IllustDetailNavigationLink(
                    illust: illust,
                    context: vm.filteredIllusts,
                    contextProvider: { vm.filteredIllusts },
                    hasMore: { vm.hasMoreData },
                    loadMore: { await vm.loadMoreData() }
                ) {
                    IllustCard(
                        illust: illust,
                        columnCount: dynamicColumnCount,
                        columnWidth: columnWidth,
                        expiration: DefaultCacheExpiration.recommend,
                        feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
                        shouldBlur: vm.shouldBlur(for: illust),
                        accentColor: themeManager.currentColor
                    )
                    .equatable()
                }
                .buttonStyle(.plain)
                .onAppear {
                    prefetchIllustsIfNeeded(
                        from: illust,
                        in: vm.filteredIllusts,
                        quality: settingStore.userSetting.feedPreviewQuality,
                        multiPagePrefetchCount: settingStore.userSetting.listMultiPagePrefetchCount,
                        tracker: prefetchTracker
                    )
                }
            }
            .padding(.horizontal, 12)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))

            RecommendPaginationFooter(
                vm: vm,
                retryLoading: retryLoading,
                settingStore: settingStore
            )
        }
    }
}

private struct RecommendEmptyState: View {
    let error: String?
    let isLoading: Bool
    let dynamicColumnCount: Int
    let waterfallWidth: CGFloat?
    let skeletonItemCount: Int
    let retryLoading: () -> Void

    var body: some View {
        if let error {
            ErrorStateView(message: error, retryAction: retryLoading)
                .frame(maxWidth: .infinity, minHeight: 360)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        } else if isLoading {
            SkeletonIllustWaterfallGrid(
                columnCount: dynamicColumnCount,
                itemCount: skeletonItemCount,
                width: waterfallWidth
            )
            .padding(.horizontal, 12)
            .frame(minHeight: 400)
            .transition(.opacity.animation(.easeInOut(duration: 0.25)))
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text(String(localized: "没有找到相关内容"))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 120)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct RecommendPaginationFooter: View {
    let vm: RecommendViewModel
    let retryLoading: () -> Void
    let settingStore: UserSettingStore

    var body: some View {
        if let error = vm.error {
            ErrorStateView(message: error, retryAction: retryLoading)
                .frame(maxWidth: .infinity, minHeight: 240)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
        } else if vm.hasMoreData && !vm.isLoading {
            LazyVStack {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #endif
                    .padding()
                    .id(vm.nextUrl)
                    .onAppear {
                        Task { await vm.loadMoreData() }
                    }
            }
            .onFilterSettingsChange(from: settingStore, perform: vm.recalculateFilteredIllusts)
        } else if !vm.filteredIllusts.isEmpty {
            Text(String(localized: "已经到底了"))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

/// 登录引导横幅（嵌入在推荐页顶部）
struct LoginBannerView: View {
    let onLogin: () -> Void
    @Environment(ThemeManager.self) var themeManager

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.clock")
                .font(.title2)
                .foregroundStyle(themeManager.currentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "游客模式"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(localized: "登录以保存收藏、关注画师"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(String(localized: "登录")) {
                onLogin()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
    }
}

#Preview {
    RecommendView()
}

#Preview("推荐空态") {
    RecommendEmptyState(
        error: nil,
        isLoading: false,
        dynamicColumnCount: 2,
        waterfallWidth: 320,
        skeletonItemCount: 4,
        retryLoading: {}
    )
}

#Preview("推荐分页") {
    let vm = RecommendViewModel()
    vm.isLoading = false
    vm.hasMoreData = false
    return RecommendPaginationFooter(
        vm: vm,
        retryLoading: {},
        settingStore: UserSettingStore.shared
    )
}

#Preview("Recommendation list") {
    let settings = UserSettingStore()
    let theme = ThemeManager(userSettingStore: settings)
    return RecommendMainList(
        vm: RecommendViewModel(settingStore: settings),
        accountStore: AccountStore.shared,
        settingStore: settings,
        themeManager: theme,
        prefetchTracker: PrefetchTracker(),
        containerWidth: 360,
        skeletonItemCount: 4,
        retryLoading: {}
    )
    .environment(theme)
}

#Preview("Recommended people and tags") {
    RecommendPeopleAndTags(vm: RecommendViewModel(), accountStore: AccountStore.shared)
}

#Preview("Recommendation grid") {
    let settings = UserSettingStore()
    return RecommendIllustSection(
        vm: RecommendViewModel(settingStore: settings),
        settingStore: settings,
        themeManager: ThemeManager(userSettingStore: settings),
        prefetchTracker: PrefetchTracker(),
        dynamicColumnCount: 2,
        waterfallWidth: 320,
        skeletonItemCount: 4,
        retryLoading: {}
    )
}
