import SwiftUI

struct UserDetailView: View {
    let userId: String
    @State private var store: UserDetailStore
    @State private var selectedTab: Int = 0
    
    init(userId: String) {
        self.userId = userId
        self._store = State(initialValue: UserDetailStore(userId: userId))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let detail = store.userDetail {
                    UserDetailHeaderView(detail: detail, onFollowTapped: {
                        Task {
                            await store.toggleFollow()
                        }
                    })
                    
                    // Tab Bar
                    Picker("", selection: $selectedTab) {
                        Text("作品").tag(0)
                        Text("收藏").tag(1)
                        Text("作者信息").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    switch selectedTab {
                    case 0:
                        if store.isLoadingIllusts && store.illusts.isEmpty {
                            ProgressView().padding()
                        } else {
                            IllustWaterfallView(illusts: store.illusts)
                        }
                    case 1:
                        if store.isLoadingBookmarks && store.bookmarks.isEmpty {
                            ProgressView().padding()
                        } else {
                            IllustWaterfallView(illusts: store.bookmarks)
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
        }
        .ignoresSafeArea(edges: .top)
        .task {
            if store.userDetail == nil {
                await store.fetchAll()
            }
        }
    }
}

struct UserDetailHeaderView: View {
    let detail: UserDetailResponse
    let onFollowTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 背景图
            if let bgUrl = detail.profile.backgroundImageUrl {
                CachedAsyncImage(urlString: bgUrl)
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
            }
            
            HStack(alignment: .bottom, spacing: 16) {
                // 头像
                if let avatarUrl = detail.user.profileImageUrls.medium {
                    CachedAsyncImage(urlString: avatarUrl)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(radius: 4)
                        .offset(y: -40)
                        .padding(.bottom, -40)
                }
                
                Spacer()
                
                // 关注按钮
                Button(action: onFollowTapped) {
                    Text(detail.user.isFollowed ? "已关注" : "关注")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(detail.user.isFollowed ? .secondary : .white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(detail.user.isFollowed ? Color.gray.opacity(0.2) : Color.blue)
                        .cornerRadius(20)
                }
                .padding(.bottom, 8)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                // 昵称
                Text(detail.user.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
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
                    Text(detail.user.comment)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding(.top, 4)
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
            }
        }
    }
}

struct IllustWaterfallView: View {
    let illusts: [Illusts]
    
    var body: some View {
        WaterfallGrid(data: illusts, columnCount: 2) { illust in
            NavigationLink(destination: IllustDetailView(illust: illust)) {
                IllustCard(illust: illust)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    NavigationStack {
        UserDetailView(userId: "11")
    }
}
