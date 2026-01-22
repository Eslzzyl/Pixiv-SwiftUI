import SwiftUI
import TranslationKit

struct UserDetailView: View {
    let userId: String
    @State private var store: UserDetailStore
    @State private var selectedTab: Int = 0
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var showCopyToast = false
    @State private var showBlockUserToast = false
    @State private var isFollowLoading = false
    @State private var isFollowed: Bool = false
    @State private var isBlockTriggered: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    init(userId: String) {
        self.userId = userId
        self._store = State(initialValue: UserDetailStore(userId: userId))
    }
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    if let detail = store.userDetail {
                        UserDetailHeaderView(detail: detail, isFollowed: $isFollowed, onFollowTapped: {
                            Task {
                                await toggleFollow()
                            }
                        })
                        
                        // Tab Bar
                        Picker("", selection: $selectedTab) {
                            Text("插画").tag(0)
                            Text("收藏").tag(1)
                            Text("小说").tag(3)
                            Text("作者信息").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .padding()
                        
                        // Content
                        switch selectedTab {
                        case 0:
                            if store.isLoadingIllusts && store.illusts.isEmpty {
                                SkeletonIllustWaterfallGrid(columnCount: 2, itemCount: 6)
                                    .padding(.horizontal, 12)
                            } else if store.illusts.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "paintbrush")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("暂无插画作品")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("该作者还没有发布插画")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .padding()
                            } else {
                                IllustWaterfallView(
                                    illusts: store.illusts,
                                    isLoadingMore: store.isLoadingMoreIllusts,
                                    hasReachedEnd: store.isIllustsReachedEnd,
                                    onLoadMore: {
                                        Task {
                                            await store.loadMoreIllusts()
                                        }
                                    },
                                    width: proxy.size.width
                                )
                            }
                        case 1:
                            if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                                SkeletonIllustWaterfallGrid(columnCount: 2, itemCount: 6)
                                    .padding(.horizontal, 12)
                            } else if store.bookmarks.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "heart.slash")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("暂无收藏")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Text("该用户还没有收藏任何作品")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 200)
                                .padding()
                            } else {
                                IllustWaterfallView(
                                    illusts: store.bookmarks,
                                    isLoadingMore: store.isLoadingMoreBookmarks,
                                    hasReachedEnd: store.isBookmarksReachedEnd,
                                    onLoadMore: {
                                        Task {
                                            await store.loadMoreBookmarks()
                                        }
                                    },
                                    width: proxy.size.width
                                )
                            }
                        case 3:
                        if store.isLoadingNovels && store.novels.isEmpty {
                            SkeletonNovelWaterfallGrid(columnCount: 2, itemCount: 4)
                                .padding(.horizontal, 12)
                        } else if store.novels.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("暂无小说作品")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("该作者还没有发布小说")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .padding()
                        } else {
                            NovelWaterfallView(
                                novels: store.novels,
                                isLoadingMore: store.isLoadingMoreNovels,
                                hasReachedEnd: store.isNovelsReachedEnd,
                                onLoadMore: {
                                    Task {
                                        await store.loadMoreNovels()
                                    }
                                }
                            )
                        }
                    case 2:
                        UserProfileInfoView(profile: detail.profile, workspace: detail.workspace)
                        default:
                            EmptyView()
                        }
                    } else if store.isLoadingDetail {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = store.errorMessage {
                        VStack {
                            Text("加载失败")
                            Text(error).font(.caption).foregroundColor(.gray)
                            Button("重试") {
                                Task {
                                    await store.fetchAll()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let detail = store.userDetail {
                Menu {
                    Button(action: { copyToClipboard(String(detail.user.id)) }) {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }
                        
                        Button(action: shareUser) {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: {
                            Task {
                                await toggleFollow()
                            }
                        }) {
                            Label(
                                isFollowed ? "取消关注" : "关注",
                                systemImage: isFollowed ? "heart.slash.fill" : "heart.fill"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: {
                            isBlockTriggered = true
                            if let detail = store.userDetail {
                                try? userSettingStore.addBlockedUserWithInfo(
                                    String(detail.user.id),
                                    name: detail.user.name,
                                    account: detail.user.account,
                                    avatarUrl: detail.user.profileImageUrls.medium
                                )
                            }
                            showBlockUserToast = true
                            dismiss()
                        }) {
                            Label("屏蔽此作者", systemImage: "eye.slash")
                        }
                        .sensoryFeedback(.impact(weight: .medium), trigger: isBlockTriggered)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            if store.userDetail == nil {
                await store.fetchAll()
            }
            if let detail = store.userDetail {
                isFollowed = detail.user.isFollowed
            }
        }
        .toast(isPresented: $showCopyToast, message: "已复制到剪贴板")
        .toast(isPresented: $showBlockUserToast, message: "已屏蔽作者")
    }
    
    private func toggleFollow() async {
        guard store.userDetail != nil else { return }
        
        isFollowLoading = true
        defer { isFollowLoading = false }
        
        do {
            if isFollowed {
                try await PixivAPI.shared.unfollowUser(userId: userId)
                isFollowed = false
                store.userDetail?.user.isFollowed = false
            } else {
                try await PixivAPI.shared.followUser(userId: userId)
                isFollowed = true
                store.userDetail?.user.isFollowed = true
            }
        } catch {
            print("Follow toggle failed: \(error)")
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #else
        let pasteBoard = NSPasteboard.general
        pasteBoard.clearContents()
        pasteBoard.setString(text, forType: .string)
        #endif
        showCopyToast = true
    }
    
    private func shareUser() {
        guard let url = URL(string: "https://www.pixiv.net/users/\(userId)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

struct UserDetailHeaderView: View {
    let detail: UserDetailResponse
    @Binding var isFollowed: Bool
    let onFollowTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 背景图
            if let bgUrl = detail.profile.backgroundImageUrl {
                CachedAsyncImage(urlString: bgUrl, expiration: DefaultCacheExpiration.userHeader)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
            
            HStack(alignment: .bottom, spacing: 16) {
                // 头像
                if let avatarUrl = detail.user.profileImageUrls.medium {
                    CachedAsyncImage(urlString: avatarUrl, expiration: DefaultCacheExpiration.userAvatar)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                        .offset(y: -40)
                        .padding(.bottom, -40)
                }
                
                Spacer()
                
                // 关注按钮
                Button(action: onFollowTapped) {
                    Text(isFollowed ? "已关注" : "关注")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .frame(width: 95)
                }
                .buttonStyle(GlassButtonStyle(color: isFollowed ? nil : .blue))
                .padding(.bottom, 8)
                .sensoryFeedback(.impact(weight: .medium), trigger: isFollowed)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                // 昵称
                Text(detail.user.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)
                
                // 关注数
                HStack {
                    Text("已关注")
                        .foregroundColor(.secondary)
                    Text("\(detail.profile.totalFollowUsers)")
                        .fontWeight(.bold)
                    Text("名用户")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                
                // 简介
                if !detail.user.comment.isEmpty {
                    TranslatableText(text: detail.user.comment, font: .body)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct UserProfileInfoView: View {
    let profile: UserDetailProfile
    let workspace: UserDetailWorkspace
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
                InfoRow(label: "性别", value: profile.gender)
                InfoRow(label: "生日", value: profile.birth)
                InfoRow(label: "地区", value: profile.region)
                InfoRow(label: "职业", value: profile.job)
                if let twitter = profile.twitterUrl {
                    InfoRow(label: "Twitter", value: twitter)
                }
                if let webpage = profile.webpage {
                    InfoRow(label: "个人主页", value: webpage)
                }
            }
            
            Divider()
            
            Text("工作环境")
                .font(.headline)
                .padding(.top)
            
            Group {
                InfoRow(label: "电脑", value: workspace.pc)
                InfoRow(label: "显示器", value: workspace.monitor)
                InfoRow(label: "软件", value: workspace.tool)
                InfoRow(label: "扫描仪", value: workspace.scanner)
                InfoRow(label: "数位板", value: workspace.tablet)
                InfoRow(label: "鼠标", value: workspace.mouse)
                InfoRow(label: "打印机", value: workspace.printer)
                InfoRow(label: "桌面", value: workspace.desktop)
                InfoRow(label: "音乐", value: workspace.music)
                InfoRow(label: "桌子", value: workspace.desk)
                InfoRow(label: "椅子", value: workspace.chair)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        if !value.isEmpty {
            HStack(alignment: .top) {
                Text(label)
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)
                Text(value)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct IllustWaterfallView: View {
    let illusts: [Illusts]
    let isLoadingMore: Bool
    let hasReachedEnd: Bool
    let onLoadMore: () -> Void
    let width: CGFloat?
    @Environment(UserSettingStore.self) var settingStore

    #if os(macOS)
    @State private var dynamicColumnCount: Int = 4
    #else
    @State private var dynamicColumnCount: Int = 2
    #endif

    private var filteredIllusts: [Illusts] {
        settingStore.filterIllusts(illusts)
    }

    var body: some View {
        if filteredIllusts.isEmpty && !illusts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("已根据您的设置过滤掉所有插画")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("尝试调整过滤设置以查看更多内容")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
            .padding()
        } else {
            VStack(spacing: 12) {
                WaterfallGrid(data: filteredIllusts, columnCount: dynamicColumnCount, width: width.map { $0 - 24 }) { illust, columnWidth in
                    NavigationLink(value: illust) {
                        IllustCard(illust: illust, columnCount: dynamicColumnCount, columnWidth: columnWidth)
                    }
                    .buttonStyle(.plain)
                }

                if !hasReachedEnd {
                    ProgressView()
                        #if os(macOS)
                        .controlSize(.small)
                        #endif
                        .padding()
                        .onAppear {
                            onLoadMore()
                        }
                } else {
                    Text("已经到底了")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .padding(.horizontal, 12)
            .responsiveGridColumnCount(userSetting: settingStore.userSetting, columnCount: $dynamicColumnCount)
        }
    }
}

#Preview {
    NavigationStack {
        UserDetailView(userId: "11")
    }
}
