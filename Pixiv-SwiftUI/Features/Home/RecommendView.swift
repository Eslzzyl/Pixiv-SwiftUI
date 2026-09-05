import SwiftUI

/// 推荐页面
struct RecommendView: View {
    @State private var vm = RecommendViewModel()
    @State private var isInitialLoadInProgress = false

    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false

    @Environment(UserSettingStore.self) var settingStore
    @Environment(AccountStore.self) var accountStore
    @Environment(ThemeManager.self) var themeManager

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
        let dynamicColumnCount = ResponsiveGrid.columnCount(for: containerWidth, userSetting: settingStore.userSetting)
        let horizontalPadding: CGFloat = 24
        let availableWidth = containerWidth - horizontalPadding
        let waterfallWidth = availableWidth > 0 ? availableWidth : nil

        return ScrollView {
            VStack(spacing: 0) {
                if !vm.isLoggedIn {
                    LoginBannerView(onLogin: {
                        showAuthView = true
                    })
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                if vm.isLoggedIn {
                    RecommendedArtistsList(
                        recommendedUsers: Binding(
                            get: { vm.recommendedUsersStore.users },
                            set: { vm.recommendedUsersStore.users = $0 }
                        ),
                        isLoadingRecommended: Binding(
                            get: { vm.recommendedUsersStore.isLoading },
                            set: { vm.recommendedUsersStore.isLoading = $0 }
                        ),
                        path: $path,
                        onRefresh: { await vm.recommendedUsersStore.fetchUsers(forceRefresh: true) }
                    )

                    Spacer()
                        .frame(height: 16)

                    if accountStore.isWebLoggedIn {
                        RecommendTagGroupList(
                            tagGroups: vm.searchStore.recommendByTagGroups,
                            isLoading: vm.searchStore.isLoadingRecommendedTags
                        )
                    }

                    Spacer()
                        .frame(height: 8)
                }

                HStack {
                    Text(vm.contentType == .manga ? String(localized: "漫画") : (vm.isLoggedIn ? String(localized: "插画") : String(localized: "热门")))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if vm.filteredIllusts.isEmpty && vm.isLoading {
                    SkeletonIllustWaterfallGrid(
                        columnCount: dynamicColumnCount,
                        itemCount: skeletonItemCount,
                        width: waterfallWidth
                    )
                    .padding(.horizontal, 12)
                    .frame(minHeight: 400)
                    .transition(.opacity)
                } else if vm.filteredIllusts.isEmpty {
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
                } else {
                    WaterfallGrid(data: vm.filteredIllusts, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
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
                        .onTapGesture {
                            path.append(illust)
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            path.append(illust)
                        }
                        .onAppear {
                            prefetchIfNeeded(from: illust)
                        }
                    }
                    .padding(.horizontal, 12)
                    .transition(.opacity)

                    if vm.hasMoreData && !vm.isLoading {
                        LazyVStack {
                            ProgressView()
                                #if os(macOS)
                                .controlSize(.small)
                                #endif
                                .padding()
                                .id(vm.nextUrl)
                                .onAppear {
                                    vm.loadMoreData()
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
        }
        .animation(.easeInOut(duration: 0.25), value: vm.isLoading)
        .refreshable {
            await vm.refreshAll()
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    mainList(containerWidth: proxy.size.width)
                    errorView
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
            .navigationDestination(for: String.self) { route in
                if route == "recommendedArtists" {
                    RecommendedUsersListView(store: vm.recommendedUsersStore)
                }
            }
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
            .sheet(isPresented: $showProfilePanel) {
                #if os(iOS)
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
                #endif
            }
            .sheet(isPresented: $showAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
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
                Task {
                    await vm.refreshAll()
                }
            }
            .onChange(of: accountStore.accountGeneration) { _, _ in
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
    }

    private var errorView: some View {
        Group {
            if let error = vm.error {
                ErrorStateView(message: error) {
                    vm.loadMoreData()
                }
            }
        }
    }

    /// 卡片出现时预取后续图片，保持始终领先视口约 6 张
    private func prefetchIfNeeded(from currentIllust: Illusts) {
        prefetchIllustsIfNeeded(
            from: currentIllust,
            in: vm.filteredIllusts,
            quality: settingStore.userSetting.feedPreviewQuality,
            multiPagePrefetchCount: settingStore.userSetting.listMultiPagePrefetchCount,
            tracker: prefetchTracker
        )
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
