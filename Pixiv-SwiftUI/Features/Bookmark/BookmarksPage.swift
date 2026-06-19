import SwiftUI

struct BookmarksPage: View {
    @State private var store = BookmarksStore()
    @State private var showProfilePanel = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isPickerVisible: Bool = true
    @State private var path = NavigationPath()
    @State private var showAuthView = false
    @State private var contentType: TypeFilterButton.ContentType = .all
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess
    @State private var cacheFilter: BookmarkCacheFilter = .all
    @Environment(UserSettingStore.self) var settingStore
    @Environment(ThemeManager.self) var themeManager
    var accountStore: AccountStore = AccountStore.shared
    @State private var bookmarkCacheStore = BookmarkCacheStore.shared

    var initialRestrict: String?
    @State private var prefetchTracker = PrefetchTracker()
    @State private var filteredBookmarksCache: [Illusts] = []
    @State private var shouldBlurFlags: [Bool] = []
    @State private var bookmarkCacheEnabledFlags: [Bool] = []

    private let cache = CacheManager.shared

    private var isCacheEnabled: Bool {
        settingStore.userSetting.bookmarkCacheEnabled
    }

    private func recalculateCaches() {
        let base = settingStore.filterIllusts(store.bookmarks)
        switch contentType {
        case .all:
            filteredBookmarksCache = base
        case .illust:
            filteredBookmarksCache = base.filter { $0.type != "manga" }
        case .manga:
            filteredBookmarksCache = base.filter { $0.type == "manga" }
        }
        shouldBlurFlags = filteredBookmarksCache.map { settingStore.userSetting.shouldBlurIllust($0) }
        bookmarkCacheEnabledFlags = filteredBookmarksCache.map { _ in settingStore.userSetting.bookmarkCacheEnabled }
    }

    private func shouldBlur(for illust: Illusts) -> Bool {
        guard let index = filteredBookmarksCache.firstIndex(where: { $0.id == illust.id }),
              index < shouldBlurFlags.count
        else { return false }
        return shouldBlurFlags[index]
    }

    private func isBookmarkCacheEnabled(for illust: Illusts) -> Bool {
        guard let index = filteredBookmarksCache.firstIndex(where: { $0.id == illust.id }),
              index < bookmarkCacheEnabledFlags.count
        else { return true }
        return bookmarkCacheEnabledFlags[index]
    }

    private var filteredBookmarks: [Illusts] {
        filteredBookmarksCache
    }

    private var deletedBookmarks: [BookmarkCache] {
        bookmarkCacheStore.cachedBookmarks.filter { $0.isDeleted }
    }

    private var displayItems: [BookmarkDisplayItem] {
        switch cacheFilter {
        case .all:
            var items = filteredBookmarks.map { BookmarkDisplayItem.normal($0) }
            let deletedItems = deletedBookmarks.compactMap { cache -> BookmarkDisplayItem? in
                guard let illust = cache.getIllust() else { return nil }
                return .deleted(illust, cache)
            }
            items.append(contentsOf: deletedItems)
            return items
        case .normal:
            return filteredBookmarks.map { .normal($0) }
        case .deleted:
            return deletedBookmarks.compactMap { cache -> BookmarkDisplayItem? in
                guard let illust = cache.getIllust() else { return nil }
                return .deleted(illust, cache)
            }
        }
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    private var restrictType: TypeFilterButton.RestrictType? {
        initialRestrict == nil ? .publicAccess : nil
    }

    private var skeletonItemCount: Int {
        #if os(macOS)
        32
        #else
        12
        #endif
    }

    @ViewBuilder
    private var filterButton: some View {
        if isCacheEnabled {
            TypeFilterButton(
                selectedType: $contentType,
                restrict: restrictType,
                selectedRestrict: $selectedRestrict,
                cacheFilter: Binding<BookmarkCacheFilter?>(
                    get: { self.cacheFilter },
                    set: { self.cacheFilter = $0 ?? .all }
                ),
                showRestrict: false
            )
            .menuIndicator(.hidden)
        } else {
            TypeFilterButton(
                selectedType: $contentType,
                restrict: restrictType,
                selectedRestrict: $selectedRestrict,
                cacheFilter: .constant(nil),
                showRestrict: false
            )
            .menuIndicator(.hidden)
        }
    }

    private var bookmarksContent: some View {
        GeometryReader { proxy in
            let dynamicColumnCount = ResponsiveGrid.columnCount(for: proxy.size.width, userSetting: settingStore.userSetting)
            let horizontalPadding: CGFloat = 24
            let availableWidth = proxy.size.width - horizontalPadding
            let waterfallWidth = availableWidth > 0 ? availableWidth : nil

            ZStack(alignment: .top) {
                ScrollView {
                        VStack(spacing: 12) {
                            if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                            SkeletonIllustWaterfallGrid(
                                columnCount: dynamicColumnCount,
                                itemCount: skeletonItemCount,
                                width: waterfallWidth
                            )
                            .padding(.horizontal, 12)
                            .frame(minHeight: 400)
                            .transition(.opacity)
                        } else if let error = store.error, store.bookmarks.isEmpty {
                            ErrorStateView(message: error.localizedDescription ?? "未知错误", retryAction: {
                                Task {
                                    await store.refreshBookmarks(userId: AccountStore.shared.currentUserId)
                                }
                            })
                            .frame(maxWidth: .infinity, minHeight: 200)
                        } else if store.bookmarks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bookmark.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text(String(localized: "暂无收藏"))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                        } else {
                            if isCacheEnabled && cacheFilter != .normal {
                                WaterfallGrid(data: displayItems, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.aspectRatio }) { item, columnWidth in
                                    bookmarkItemView(item: item, columnWidth: columnWidth, columnCount: dynamicColumnCount)
                                }
                                .padding(.horizontal, 12)
                                .transition(.opacity)
                            } else {
                                WaterfallGrid(data: filteredBookmarks, columnCount: dynamicColumnCount, width: waterfallWidth, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                                    bookmarkCardView(illust: illust, columnWidth: columnWidth, columnCount: dynamicColumnCount, isDeleted: false)
                                        .onTapGesture {
                                            path.append(illust)
                                        }
                                        .onAppear {
                                        prefetchIllustsIfNeeded(from: illust, in: filteredBookmarks, quality: settingStore.userSetting.feedPreviewQuality, tracker: prefetchTracker)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .transition(.opacity)
                            }

                            if store.nextUrlBookmarks != nil {
                                LazyVStack {
                                    ProgressView()
                                        .padding()
                                        .id(store.nextUrlBookmarks)
                                        .onAppear {
                                            Task {
                                                await store.loadMoreBookmarks()
                                            }
                                        }
                                }
                            } else if !displayItems.isEmpty {
                                Text(String(localized: "已经到底了"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: store.isLoadingBookmarks)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named("scroll")).minY
                            )
                        }
                    )
                }
                .coordinateSpace(name: "scroll")
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    if value >= 0 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isPickerVisible = true
                        }
                        lastScrollOffset = value
                        return
                    }

                    let delta = value - lastScrollOffset
                    if delta < -20 {
                        if isPickerVisible {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPickerVisible = false
                            }
                        }
                    } else if delta > 20 {
                        if !isPickerVisible {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isPickerVisible = true
                            }
                        }
                    }
                    lastScrollOffset = value
                }
                .refreshable {
                    await store.refreshBookmarks(userId: accountStore.currentAccount?.userId ?? "")
                }
            }
            .navigationTitle(initialRestrict == nil ? String(localized: "收藏") : (initialRestrict == "public" ? String(localized: "公开收藏") : String(localized: "非公开收藏")))
            .pixivNavigationDestinations()
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
                    Task {
                        await store.refreshBookmarks(userId: accountStore.currentAccount?.userId ?? "")
                    }
                }
            }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !isLoggedIn {
                    BookmarksNotLoggedInView(onLogin: {
                        showAuthView = true
                    })
                } else {
                    bookmarksContent
                }
            }
            .toolbar {
                ToolbarItem {
                    BookmarkVisibilityToggle(
                        selectedRestrict: $selectedRestrict,
                        isAvailable: restrictType != nil
                    )
                }
                #if os(iOS)
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }
                #endif
                ToolbarItem {
                    filterButton
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
                        await store.refreshBookmarks(userId: accountStore.currentAccount?.userId ?? "")
                    })
                }
                #endif
            }
            .sheet(isPresented: $showProfilePanel) {
                #if os(iOS)
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
                #endif
            }
            .onChange(of: contentType) { _, _ in
                store.cancelCurrentFetch()
                store.nextUrlBookmarks = nil
                let restrict = selectedRestrict == .publicAccess ? "public" : "private"
                store.bookmarkRestrict = restrict
                Task {
                    await store.fetchBookmarks(userId: accountStore.currentAccount?.userId ?? "", forceRefresh: false)
                }
            }
            .onChange(of: selectedRestrict) { _, newValue in
                let restrict = newValue == .publicAccess ? "public" : "private"
                store.cancelCurrentFetch()
                store.bookmarks = []
                store.nextUrlBookmarks = nil
                store.bookmarkRestrict = restrict
                Task {
                    await store.fetchBookmarks(userId: accountStore.currentAccount?.userId ?? "")
                }
            }
            .onChange(of: accountStore.currentUserId) { _, _ in
                if isLoggedIn {
                    store.cancelCurrentFetch()
                    store.bookmarks = []
                    store.nextUrlBookmarks = nil
                    Task {
                        await store.fetchBookmarks(userId: accountStore.currentAccount?.userId ?? "")
                    }
                }
            }
            .onChange(of: contentType) { _, _ in
                recalculateCaches()
            }
            .onChange(of: store.bookmarks) { _, _ in
                recalculateCaches()
            }
            .onAppear {
                recalculateCaches()
                if let initialRestrict = initialRestrict {
                    store.bookmarkRestrict = initialRestrict
                }
                if isLoggedIn, isCacheEnabled {
                    bookmarkCacheStore.loadCachedBookmarks(for: accountStore.currentUserId)
                }
            }
            .task {
                guard isLoggedIn else { return }
                guard store.bookmarks.isEmpty else { return }
                await store.fetchBookmarks(userId: accountStore.currentAccount?.userId ?? "")
            }
            .sheet(isPresented: $showAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
            }
            .navigationDestination(for: BookmarkCache.self) { cache in
                DeletedBookmarkDetailView(cache: cache)
            }
            .onFilterSettingsChange(from: settingStore, perform: recalculateCaches)
        }
    }

    @ViewBuilder
    private func bookmarkItemView(item: BookmarkDisplayItem, columnWidth: CGFloat, columnCount: Int) -> some View {
        switch item {
        case .normal(let illust):
            bookmarkCardView(illust: illust, columnWidth: columnWidth, columnCount: columnCount, isDeleted: false)
                .onTapGesture {
                    path.append(illust)
                }
        case .deleted(let illust, let cache):
            bookmarkCardView(illust: illust, columnWidth: columnWidth, columnCount: columnCount, isDeleted: true, cache: cache)
                .onTapGesture {
                    path.append(cache)
                }
        }
    }

    @ViewBuilder
    private func bookmarkCardView(illust: Illusts, columnWidth: CGFloat, columnCount: Int, isDeleted: Bool, cache: BookmarkCache? = nil) -> some View {
        let cacheStatus: BookmarkCacheStatus = {
            if let cache = cache ?? bookmarkCacheStore.getCacheRecord(illustId: illust.id) {
                if cache.imagePreloaded {
                    return .cached(cache.quality)
                } else {
                    return .notCached
                }
            }
            return .none
        }()

        BookmarkCard(
            illust: illust,
            columnCount: columnCount,
            columnWidth: columnWidth,
            expiration: DefaultCacheExpiration.bookmarks,
            isDeleted: isDeleted,
            cacheStatus: cacheStatus,
            feedPreviewQuality: settingStore.userSetting.feedPreviewQuality,
            shouldBlur: shouldBlur(for: illust),
            bookmarkCacheEnabled: isBookmarkCacheEnabled(for: illust),
            accentColor: themeManager.currentColor
        )
        .equatable()
    }
}

struct BookmarksNotLoggedInView: View {
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bookmark")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(String(localized: "登录后查看收藏"))
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(String(localized: "收藏喜欢的作品，随时随地浏览"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: onLogin) {
                Text(String(localized: "立即登录"))
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

/// 收藏展示项
enum BookmarkDisplayItem: Identifiable, Hashable {
    case normal(Illusts)
    case deleted(Illusts, BookmarkCache)

    var id: Int {
        switch self {
        case .normal(let illust):
            return illust.id
        case .deleted(let illust, _):
            return illust.id + 1_000_000_000
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .normal(let illust), .deleted(let illust, _):
            return illust.safeAspectRatio
        }
    }

    static func == (lhs: BookmarkDisplayItem, rhs: BookmarkDisplayItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
