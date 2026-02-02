import SwiftUI

struct BookmarksPage: View {
    @StateObject private var store = BookmarksStore()
    @State private var showProfilePanel = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isPickerVisible: Bool = true
    @State private var path = NavigationPath()
    @State private var showAuthView = false
    @State private var contentType: TypeFilterButton.ContentType = .all
    @State private var selectedRestrict: TypeFilterButton.RestrictType? = .publicAccess
    @State private var cacheFilter: BookmarkCacheFilter = .all
    @Environment(UserSettingStore.self) var settingStore
    var accountStore: AccountStore = AccountStore.shared
    @State private var bookmarkCacheStore = BookmarkCacheStore.shared

    var initialRestrict: String?

    @State private var dynamicColumnCount: Int = 4

    private let cache = CacheManager.shared

    private var isCacheEnabled: Bool {
        settingStore.userSetting.bookmarkCacheEnabled
    }

    private var filteredBookmarks: [Illusts] {
        let base = settingStore.filterIllusts(store.bookmarks)
        switch contentType {
        case .all:
            return base
        case .illust:
            return base.filter { $0.type != "manga" }
        case .manga:
            return base.filter { $0.type == "manga" }
        }
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
                )
            )
            .menuIndicator(.hidden)
        } else {
            TypeFilterButton(
                selectedType: $contentType,
                restrict: restrictType,
                selectedRestrict: $selectedRestrict,
                cacheFilter: .constant(nil)
            )
            .menuIndicator(.hidden)
        }
    }

    private var bookmarksContent: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
ScrollView {
                        LazyVStack(spacing: 12) {
                            if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                            SkeletonIllustWaterfallGrid(
                                columnCount: dynamicColumnCount,
                                itemCount: skeletonItemCount
                            )
                            .padding(.horizontal, 12)
                            .frame(minHeight: 400)
                        } else if store.bookmarks.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "bookmark.slash")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("暂无收藏")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
                        } else {
                            if isCacheEnabled && cacheFilter != .normal {
                                WaterfallGrid(data: displayItems, columnCount: dynamicColumnCount, aspectRatio: { $0.aspectRatio }) { item, columnWidth in
                                    bookmarkItemView(item: item, columnWidth: columnWidth)
                                }
                                .padding(.horizontal, 12)
                            } else {
                                WaterfallGrid(data: filteredBookmarks, columnCount: dynamicColumnCount, aspectRatio: { $0.safeAspectRatio }) { illust, columnWidth in
                                    NavigationLink(value: illust) {
                                        bookmarkCardView(illust: illust, columnWidth: columnWidth, isDeleted: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 12)
                            }

                            if store.nextUrlBookmarks != nil {
                                ProgressView()
                                    .padding()
                                    .id(store.nextUrlBookmarks)
                                    .onAppear {
                                        Task {
                                            await store.loadMoreBookmarks()
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
                .keyboardShortcut("r", modifiers: .command)
            }
            .navigationTitle(initialRestrict == nil ? "收藏" : (initialRestrict == "public" ? "公开收藏" : "非公开收藏"))
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
            .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
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
                    filterButton
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
            .onAppear {
                if let initialRestrict = initialRestrict {
                    store.bookmarkRestrict = initialRestrict
                }
                if isLoggedIn {
                    Task {
                        await store.fetchBookmarks(userId: accountStore.currentAccount?.userId ?? "")
                    }
                    if isCacheEnabled {
                        bookmarkCacheStore.loadCachedBookmarks(for: accountStore.currentUserId)
                    }
                }
            }
            .sheet(isPresented: $showAuthView) {
                AuthView(accountStore: accountStore, onGuestMode: nil)
            }
            .navigationDestination(for: BookmarkCache.self) { cache in
                DeletedBookmarkDetailView(cache: cache)
            }
        }
    }

    @ViewBuilder
    private func bookmarkItemView(item: BookmarkDisplayItem, columnWidth: CGFloat) -> some View {
        switch item {
        case .normal(let illust):
            NavigationLink(value: illust) {
                bookmarkCardView(illust: illust, columnWidth: columnWidth, isDeleted: false)
            }
            .buttonStyle(.plain)
        case .deleted(let illust, let cache):
            NavigationLink(value: cache) {
                bookmarkCardView(illust: illust, columnWidth: columnWidth, isDeleted: true, cache: cache)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func bookmarkCardView(illust: Illusts, columnWidth: CGFloat, isDeleted: Bool, cache: BookmarkCache? = nil) -> some View {
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
            columnCount: dynamicColumnCount,
            columnWidth: columnWidth,
            expiration: DefaultCacheExpiration.bookmarks,
            isDeleted: isDeleted,
            cacheStatus: cacheStatus
        )
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
                Text("登录后查看收藏")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("收藏喜欢的作品，随时随地浏览")
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
