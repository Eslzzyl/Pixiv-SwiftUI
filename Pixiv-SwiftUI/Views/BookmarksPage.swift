import SwiftUI

struct BookmarksPage: View {
    @StateObject private var store = BookmarksStore()
    @State private var showProfilePanel = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var isPickerVisible: Bool = true
    @Environment(UserSettingStore.self) var settingStore
    var accountStore: AccountStore = AccountStore.shared

    private let cache = CacheManager.shared

    private var columnCount: Int {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? settingStore.userSetting.hCrossCount : settingStore.userSetting.crossCount
        #else
        settingStore.userSetting.hCrossCount
        #endif
    }

    private var filteredBookmarks: [Illusts] {
        settingStore.filterIllusts(store.bookmarks)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Color.clear.frame(height: 60)

                        if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                            VStack {
                                ProgressView()
                                Text("加载中...")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.top, 50)
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
                            WaterfallGrid(data: filteredBookmarks, columnCount: columnCount) { illust, columnWidth in
                                NavigationLink(value: illust) {
                                    IllustCard(
                                        illust: illust,
                                        columnCount: columnCount,
                                        columnWidth: columnWidth,
                                        expiration: DefaultCacheExpiration.bookmarks
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)

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

                if isPickerVisible {
                    FloatingCapsulePicker(selection: $store.bookmarkRestrict, options: [
                        ("公开", "public"),
                        ("非公开", "private")
                    ])
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationTitle("收藏")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ProfileButton(accountStore: accountStore, isPresented: $showProfilePanel)
                }
            }
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .sheet(isPresented: $showProfilePanel) {
                ProfilePanelView(accountStore: accountStore, isPresented: $showProfilePanel)
            }
        }
        .onChange(of: store.bookmarkRestrict) { oldValue, newValue in
            let userId = accountStore.currentAccount?.userId ?? ""
            let cacheKey = CacheManager.bookmarksKey(userId: userId, restrict: newValue)

            if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
                store.bookmarks = cached.0
                store.nextUrlBookmarks = cached.1
            } else {
                store.bookmarks = []
                Task {
                    await store.fetchBookmarks(userId: userId)
                }
            }
        }
        .onAppear {
            Task {
                await store.fetchBookmarks(userId: accountStore.currentAccount?.userId ?? "")
            }
        }
    }
}
