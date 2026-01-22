import SwiftUI

struct BookmarksPage: View {
    @StateObject private var store = BookmarksStore()
    @State private var showProfilePanel = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isPickerVisible: Bool = true
    @State private var path = NavigationPath()
    @State private var showAuthView = false
    @Environment(UserSettingStore.self) var settingStore
    var accountStore: AccountStore = AccountStore.shared
    
    var initialRestrict: String? = nil

    #if os(macOS)
    @State private var dynamicColumnCount: Int = 4
    #else
    @State private var dynamicColumnCount: Int = 2
    #endif

    private let cache = CacheManager.shared

    private var filteredBookmarks: [Illusts] {
        settingStore.filterIllusts(store.bookmarks)
    }

    private var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var body: some View {
        NavigationStack(path: $path) {
            if !isLoggedIn {
                BookmarksNotLoggedInView(onLogin: {
                    showAuthView = true
                })
            } else {
                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                Color.clear.frame(height: 60)

                                if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                                    SkeletonIllustWaterfallGrid(columnCount: dynamicColumnCount, itemCount: 12)
                                        .padding(.horizontal, 12)
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
                                    LazyVStack(spacing: 12) {
                                        WaterfallGrid(data: filteredBookmarks, columnCount: dynamicColumnCount, width: proxy.size.width - 24) { illust, columnWidth in
                                            NavigationLink(value: illust) {
                                                IllustCard(
                                                    illust: illust,
                                                    columnCount: dynamicColumnCount,
                                                    columnWidth: columnWidth,
                                                    expiration: DefaultCacheExpiration.bookmarks
                                                )
                                            }
                                            .buttonStyle(.plain)
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
                                        }
                                    }
                                    .padding(.horizontal, 12)
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

                        if isPickerVisible && initialRestrict == nil {
                            FloatingCapsulePicker(selection: $store.bookmarkRestrict, options: [
                                ("公开", "public"),
                                ("非公开", "private")
                            ])
                            .padding(.top, 8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(1)
                        }
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
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
            }
            #endif
        }
        .sheet(isPresented: $showProfilePanel) {
            #if os(iOS)
            ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            #endif
        }
        .onChange(of: store.bookmarkRestrict) { oldValue, newValue in
            let userId = accountStore.currentAccount?.userId ?? ""

            #if DEBUG
            print("[BookmarksPage] restrict改变: \(oldValue) -> \(newValue)")
            #endif

            store.cancelCurrentFetch()
            store.bookmarks = []
            store.nextUrlBookmarks = nil

            #if DEBUG
            print("[BookmarksPage] 发起新请求: restrict=\(newValue)")
            #endif
            Task {
                await store.fetchBookmarks(userId: userId)
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
            }
        }
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore, onGuestMode: nil)
        }
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
