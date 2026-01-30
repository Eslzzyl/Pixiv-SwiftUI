import SwiftUI

/// 推荐页面
struct RecommendView: View {
    @State private var illusts: [Illusts] = []
    @State private var isLoading = false
    @State private var nextUrl: String?
    @State private var hasMoreData = true
    @State private var error: String?

    @State private var recommendedUsers: [UserPreviews] = []
    @State private var isLoadingRecommended = false
    @State private var hasCachedUsers = false

    @State private var contentType: TypeFilterButton.ContentType = .illust

    @Environment(UserSettingStore.self) var settingStore
    @State private var path = NavigationPath()
    @State private var showProfilePanel = false
    @State private var showAuthView = false
    @Environment(AccountStore.self) var accountStore

    #if os(macOS)
    @State private var dynamicColumnCount: Int = 4
    #else
    @State private var dynamicColumnCount: Int = 2
    #endif

    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)
    private let usersCacheKey = "recommend_users_0"

    private var filteredIllusts: [Illusts] {
        let base = settingStore.filterIllusts(illusts)
        let result: [Illusts]
        switch contentType {
        case .all:
            result = base
        case .illust:
            result = base.filter { $0.type != "manga" }
        case .manga:
            result = base
        }
        return result
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var cacheKey: String {
        let typeSuffix = contentType == .manga ? "_manga" : "_illust"
        return isLoggedIn ? "recommend\(typeSuffix)_0" : "walkthrough\(typeSuffix)_0"
    }

    private var mainList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if !isLoggedIn {
                    LoginBannerView(onLogin: {
                        showAuthView = true
                    })
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                }

                if isLoggedIn {
                    RecommendedArtistsList(
                        recommendedUsers: $recommendedUsers,
                        isLoadingRecommended: $isLoadingRecommended,
                        onRefresh: loadRecommendedUsers
                    )

                    Spacer()
                        .frame(height: 8)
                }

                HStack {
                    Text(contentType == .manga ? String(localized: "漫画") : (isLoggedIn ? String(localized: "插画") : String(localized: "热门")))
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                if filteredIllusts.isEmpty && isLoading {
                    SkeletonIllustWaterfallGrid(columnCount: dynamicColumnCount, itemCount: 12)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 400)
                } else if filteredIllusts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text(String(localized: "没有加载到推荐内容"))
                            .foregroundColor(.gray)
                        Button(action: loadMoreData) {
                            Text(String(localized: "重新加载"))
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    WaterfallGrid(data: filteredIllusts, columnCount: dynamicColumnCount, heightProvider: { $0.safeAspectRatio }) { illust, columnWidth in
                        NavigationLink(value: illust) {
                            IllustCard(illust: illust, columnCount: dynamicColumnCount, columnWidth: columnWidth, expiration: DefaultCacheExpiration.recommend)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)

                    if hasMoreData && !isLoading {
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
                            .padding()
                            .id(nextUrl)
                            .onAppear {
                                loadMoreData()
                            }
                    }
                }
            }
        }
        .refreshable {
            await refreshAll()
        }
        .keyboardShortcut("r", modifiers: .command)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                mainList
                errorView
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
                        selectedType: $contentType,
                        restrict: nil,
                        selectedRestrict: .constant(nil as TypeFilterButton.RestrictType?),
                        showAll: false
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
                    RefreshButton(refreshAction: { await refreshAll() })
                }
                #endif
            }
            .pixivNavigationDestinations()
            .onAppear {
                loadCachedData()
                if isLoggedIn {
                    loadCachedUsers()
                    loadRecommendedUsers()
                }
                if illusts.isEmpty && !isLoading {
                    loadMoreData()
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
            .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
            .onChange(of: accountStore.currentUserId) { _, _ in
                Task {
                    illusts = []
                    nextUrl = nil
                    hasMoreData = true
                    recommendedUsers = []
                    hasCachedUsers = false
                    isLoadingRecommended = true
                    await refreshIllusts()
                    if accountStore.isLoggedIn {
                        loadRecommendedUsers()
                    }
                }
            }
            .onChange(of: contentType) { _, _ in
                Task {
                    illusts = []
                    nextUrl = nil
                    hasMoreData = true
                    await refreshIllusts(forceRefresh: false)
                }
            }
        }
    }

    private var errorView: some View {
        Group {
            if let error = error {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundColor(.red)

                    Button(action: loadMoreData) {
                        Text("重试")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
        }
    }

    private func loadCachedData() {
        if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
            illusts = cached.0
            nextUrl = cached.1
            hasMoreData = cached.1 != nil
        }
    }

    private func loadCachedUsers() {
        if let cached: [UserPreviews] = cache.get(forKey: usersCacheKey) {
            recommendedUsers = cached
            hasCachedUsers = true
        }
    }

    private func loadMoreData() {
        guard !isLoading, hasMoreData else { return }

        isLoading = true
        error = nil

        Task {
            do {
                let result: (illusts: [Illusts], nextUrl: String?)
                if let next = nextUrl {
                    if isLoggedIn {
                        result = try await PixivAPI.shared.getIllustsByURL(next)
                    } else {
                        result = try await WalkthroughAPI().getWalkthroughIllustsByURL(next)
                    }
                } else {
                    if contentType == .manga {
                        if isLoggedIn {
                            result = try await PixivAPI.shared.getRecommendedManga()
                        } else {
                            result = try await PixivAPI.shared.getRecommendedMangaNoLogin()
                        }
                    } else {
                        if isLoggedIn {
                            result = try await PixivAPI.shared.getRecommendedIllusts()
                        } else {
                            result = try await WalkthroughAPI().getWalkthroughIllusts()
                        }
                    }
                }

                await MainActor.run {
                    let newIllusts = result.illusts.filter { new in
                        !self.illusts.contains(where: { $0.id == new.id })
                    }

                    if newIllusts.isEmpty && result.nextUrl != nil {
                        self.nextUrl = result.nextUrl
                        self.isLoading = false
                        loadMoreData()
                    } else {
                        self.illusts.append(contentsOf: newIllusts)
                        self.nextUrl = result.nextUrl
                        self.hasMoreData = result.nextUrl != nil
                        self.isLoading = false
                        cache.set((illusts, result.nextUrl), forKey: cacheKey, expiration: expiration)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "加载失败: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    private func refreshIllusts(forceRefresh: Bool = true) async {
        isLoading = true
        error = nil

        do {
            let result: (illusts: [Illusts], nextUrl: String?)

            if !forceRefresh {
                if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
                    await MainActor.run {
                        illusts = cached.0
                        nextUrl = cached.1
                        hasMoreData = cached.1 != nil
                        isLoading = false
                    }
                    return
                }
            }

            if contentType == .manga {
                if isLoggedIn {
                    result = try await PixivAPI.shared.getRecommendedManga()
                } else {
                    result = try await PixivAPI.shared.getRecommendedMangaNoLogin()
                }
            } else {
                if isLoggedIn {
                    result = try await PixivAPI.shared.getRecommendedIllusts()
                } else {
                    result = try await WalkthroughAPI().getWalkthroughIllusts()
                }
            }

            await MainActor.run {
                illusts = result.illusts
                nextUrl = result.nextUrl
                hasMoreData = result.nextUrl != nil
                isLoading = false

                cache.set((illusts, result.nextUrl), forKey: cacheKey, expiration: expiration)
            }
        } catch {
            await MainActor.run {
                self.error = "刷新失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    private func loadRecommendedUsers() {
        guard !isLoadingRecommended, !hasCachedUsers else { return }

        isLoadingRecommended = true

        Task {
            do {
                let (users, _) = try await PixivAPI.shared.getRecommendedUsers()

                await MainActor.run {
                    recommendedUsers = users
                    isLoadingRecommended = false
                    hasCachedUsers = true

                    cache.set(users, forKey: usersCacheKey, expiration: expiration)
                }
            } catch {
                await MainActor.run {
                    isLoadingRecommended = false
                }
            }
        }
    }

    private func refreshRecommendedUsers() async {
        isLoadingRecommended = true

        do {
            let (users, _) = try await PixivAPI.shared.getRecommendedUsers()

            await MainActor.run {
                recommendedUsers = users
                isLoadingRecommended = false

                cache.set(users, forKey: usersCacheKey, expiration: expiration)
            }
} catch {
                await MainActor.run {
                    isLoadingRecommended = false
                }
            }
    }

    private func refreshAll() async {
        await refreshIllusts()
        await refreshRecommendedUsers()
    }
}

/// 登录引导横幅（嵌入在推荐页顶部）
struct LoginBannerView: View {
    let onLogin: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.badge.clock")
                .font(.title2)
                .foregroundStyle(.blue)

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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    RecommendView()
}
