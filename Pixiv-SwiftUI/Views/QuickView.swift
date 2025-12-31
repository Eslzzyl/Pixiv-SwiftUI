import SwiftUI

struct QuickView: View {
    @StateObject private var store = QuickViewStore()
    var accountStore: AccountStore = AccountStore.shared
    @State private var selectedTab = 0
    @Environment(UserSettingStore.self) var settingStore
    
    private var columnCount: Int {
        let screenWidth: CGFloat
        #if canImport(UIKit)
        screenWidth = UIScreen.main.bounds.width
        #else
        screenWidth = NSScreen.main?.frame.width ?? 800
        #endif
        let isPortrait = screenWidth < 800
        return isPortrait ? settingStore.userSetting.crossCount : settingStore.userSetting.hCrossCount
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tab", selection: $selectedTab) {
                    Text("动态").tag(0)
                    Text("收藏").tag(1)
                    Text("已关注").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
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
    
    private var filteredUpdates: [Illusts] {
        var result = store.updates
        if settingStore.userSetting.r18DisplayMode == 2 {
            result = result.filter { $0.xRestrict < 1 }
        }
        if settingStore.userSetting.blockAI {
            result = result.filter { $0.illustAIType != 2 }
        }
        return result
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
                WaterfallGrid(data: filteredUpdates, columnCount: columnCount, onLoadMore: checkLoadMore) { illust in
                    NavigationLink(destination: IllustDetailView(illust: illust)) {
                        IllustCard(illust: illust, columnCount: columnCount)
                    }
                    .buttonStyle(.plain)
                }
                
                if store.isLoadingUpdates {
                    ProgressView()
                        .padding()
                }
            }
        }
        .refreshable {
            await store.fetchUpdates()
        }
    }
    
    private func checkLoadMore(for illust: Illusts) {
        let list = filteredUpdates
        let thresholdIndex = list.index(list.endIndex, offsetBy: -5, limitedBy: list.startIndex) ?? 0
        
        if let illustIndex = list.firstIndex(where: { $0.id == illust.id }),
           illustIndex >= thresholdIndex {
            Task {
                await store.loadMoreUpdates()
            }
        }
    }
}

struct BookmarksView: View {
    @ObservedObject var store: QuickViewStore
    let userId: String
    let columnCount: Int
    @Environment(UserSettingStore.self) var settingStore
    
    private var filteredBookmarks: [Illusts] {
        var result = store.bookmarks
        if settingStore.userSetting.r18DisplayMode == 2 {
            result = result.filter { $0.xRestrict < 1 }
        }
        if settingStore.userSetting.blockAI {
            result = result.filter { $0.illustAIType != 2 }
        }
        return result
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
                    WaterfallGrid(data: filteredBookmarks, columnCount: columnCount, onLoadMore: checkLoadMore) { illust in
                        NavigationLink(destination: IllustDetailView(illust: illust)) {
                            IllustCard(illust: illust, columnCount: columnCount)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if store.isLoadingBookmarks {
                        ProgressView()
                            .padding()
                    }
                }
            }
            .refreshable {
                await store.fetchBookmarks(userId: userId)
            }
        }
        .onAppear {
            if store.bookmarks.isEmpty {
                Task {
                    await store.fetchBookmarks(userId: userId)
                }
            }
        }
    }
    
    private func checkLoadMore(for illust: Illusts) {
        let list = filteredBookmarks
        let thresholdIndex = list.index(list.endIndex, offsetBy: -5, limitedBy: list.startIndex) ?? 0
        
        if let illustIndex = list.firstIndex(where: { $0.id == illust.id }),
           illustIndex >= thresholdIndex {
            Task {
                await store.loadMoreBookmarks()
            }
        }
    }
}

struct FollowingView: View {
    @ObservedObject var store: QuickViewStore
    let userId: String
    
    var body: some View {
        ScrollView {
            if store.isLoadingFollowing && store.following.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 50)
            } else if store.following.isEmpty {
                VStack {
                    Image(systemName: "person.2.slash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无关注")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 50)
            } else {
                LazyVStack {
                    ForEach(store.following) { preview in
                        NavigationLink(destination: UserDetailView(userId: preview.user.id.stringValue)) {
                            HStack {
                                CachedAsyncImage(urlString: preview.user.profileImageUrls?.medium, placeholder: AnyView(Color.gray))
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                
                                Text(preview.user.name)
                                    .font(.headline)
                                
                                Spacer()
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if preview.id == store.following.last?.id {
                                Task {
                                    await store.loadMoreFollowing()
                                }
                            }
                        }
                        Divider()
                    }
                    
                    if store.isLoadingFollowing {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .refreshable {
            await store.fetchFollowing(userId: userId)
        }
        .onAppear {
            if store.following.isEmpty {
                Task {
                    await store.fetchFollowing(userId: userId)
                }
            }
        }
    }
}
