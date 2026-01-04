import SwiftUI

struct QuickView: View {
    @StateObject private var store = QuickViewStore()
    var accountStore: AccountStore = AccountStore.shared
    @State private var selectedTab = 0
    @Environment(UserSettingStore.self) var settingStore
    @State private var path = NavigationPath()
    
    private var columnCount: Int {
        #if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad ? settingStore.userSetting.hCrossCount : settingStore.userSetting.crossCount
        #else
        settingStore.userSetting.hCrossCount
        #endif
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    Text("动态").tag(0)
                    Text("收藏").tag(1)
                    Text("已关注").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                TabView(selection: $selectedTab) {
                    UpdatesView(store: store, columnCount: columnCount)
                        .tag(0)
                    BookmarksView(store: store, userId: accountStore.currentAccount?.userId ?? "", columnCount: columnCount)
                        .tag(1)
                    FollowingView(store: store, userId: accountStore.currentAccount?.userId ?? "")
                        .tag(2)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("速览")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .navigationDestination(for: Illusts.self) { illust in
                IllustDetailView(illust: illust)
            }
            .navigationDestination(for: User.self) { user in
                UserDetailView(userId: user.id.stringValue)
            }
            .onAppear {
                Task {
                    await store.fetchUpdates()
                }
            }
        }
    }
}

struct UpdatesView: View {
    @ObservedObject var store: QuickViewStore
    let columnCount: Int
    @Environment(UserSettingStore.self) var settingStore
    @State private var isRefreshing: Bool = false
    
    private var filteredUpdates: [Illusts] {
        settingStore.filterIllusts(store.updates)
    }
    
    var body: some View {
        ScrollView {
            if store.isLoadingUpdates && store.updates.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
            } else if store.updates.isEmpty {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无动态")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 50)
            } else {
                WaterfallGrid(data: filteredUpdates, columnCount: columnCount) { illust, columnWidth in
                    NavigationLink(value: illust) {
                        IllustCard(illust: illust, columnCount: columnCount, columnWidth: columnWidth, expiration: DefaultCacheExpiration.updates)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                
                if store.nextUrlUpdates != nil {
                    ProgressView()
                        .padding()
                        .id(store.nextUrlUpdates)
                        .onAppear {
                            Task {
                                await store.loadMoreUpdates()
                            }
                        }
                }
            }
        }
        .refreshable {
            isRefreshing = true
            await store.fetchUpdates()
            isRefreshing = false
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
    }
}

struct BookmarksView: View {
    @ObservedObject var store: QuickViewStore
    let userId: String
    let columnCount: Int
    @Environment(UserSettingStore.self) var settingStore
    @State private var isRefreshing: Bool = false
    
    private var filteredBookmarks: [Illusts] {
        settingStore.filterIllusts(store.bookmarks)
    }
    
    var body: some View {
        VStack {
            Picker("Privacy", selection: $store.bookmarkRestrict) {
                Text("公开").tag("public")
                Text("非公开").tag("private")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: store.bookmarkRestrict) { _, _ in
                Task {
                    await store.fetchBookmarks(userId: userId)
                }
            }
            
            ScrollView {
                if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 50)
                } else if store.bookmarks.isEmpty {
                    VStack {
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
                            IllustCard(illust: illust, columnCount: columnCount, columnWidth: columnWidth, expiration: DefaultCacheExpiration.bookmarks)
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
            .refreshable {
                isRefreshing = true
                await store.fetchBookmarks(userId: userId)
                isRefreshing = false
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        }
        .onAppear {
            if store.bookmarks.isEmpty {
                Task {
                    await store.fetchBookmarks(userId: userId)
                }
            }
        }
    }
}

struct FollowingView: View {
    @ObservedObject var store: QuickViewStore
    let userId: String
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        List(store.following) { preview in
            NavigationLink(value: preview.user) {
                UserPreviewCard(userPreview: preview)
            }
            .buttonStyle(.plain)
            .onAppear {
                if preview.id == store.following.last?.id {
                    Task {
                        await store.loadMoreFollowing()
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            isRefreshing = true
            await store.fetchFollowing(userId: userId)
            isRefreshing = false
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: isRefreshing)
        .onAppear {
            if store.following.isEmpty {
                Task {
                    await store.fetchFollowing(userId: userId)
                }
            }
        }
    }
}
