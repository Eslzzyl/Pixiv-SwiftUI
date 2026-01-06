import SwiftUI
import TranslationKit

struct NovelDetailView: View {
    @State private var novel: Novel
    @State private var isBookmarked: Bool
    @State private var isFollowed: Bool?
    @Environment(UserSettingStore.self) var settingStore
    @State private var showComments = false
    @State private var totalComments: Int?
    @State private var showCopyToast = false
    @State private var showBlockTagToast = false
    @State private var isLoadingFollow = false
    @State private var navigateToReader = false
    
    init(novel: Novel) {
        self._novel = State(initialValue: novel)
        self._isBookmarked = State(initialValue: novel.isBookmarked)
        self._isFollowed = State(initialValue: novel.user.isFollowed)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CachedAsyncImage(
                    urlString: novel.imageUrls.medium,
                    expiration: DefaultCacheExpiration.novel
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(1.0, contentMode: .fit)
                .cornerRadius(12)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(novel.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    authorSection
                    
                    actionButtons
                    
                    metadataSection
                    
                    Divider()
                    
                    if !novel.tags.isEmpty {
                        tagsSection
                    }
                    
                    if !novel.caption.isEmpty {
                        captionSection
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                    .frame(height: 50)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { copyToClipboard(String(novel.id)) }) {
                        Label("复制 ID", systemImage: "doc.on.doc")
                    }
                    
                    Button(action: { shareNovel() }) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                    
                    Button(action: {
                        if isBookmarked {
                            toggleBookmark(forceUnbookmark: true)
                        } else {
                            toggleBookmark(isPrivate: false)
                        }
                    }) {
                        Label(
                            isBookmarked ? "取消收藏" : "收藏",
                            systemImage: isBookmarked ? "heart.fill" : "heart"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .toast(isPresented: $showCopyToast, message: "已复制到剪贴板")
        .toast(isPresented: $showBlockTagToast, message: "已屏蔽 Tag")
        .sheet(isPresented: $showComments) {
            NovelCommentsPanelView(novel: novel, isPresented: $showComments)
        }
        .onAppear {
            fetchUserDetailIfNeeded()
            fetchTotalCommentsIfNeeded()
        }
        .navigationDestination(isPresented: $navigateToReader) {
            NovelReaderView(novelId: novel.id)
        }
    }
    
    private var authorSection: some View {
        HStack(spacing: 12) {
            NavigationLink(value: novel.user) {
                HStack(spacing: 12) {
                    CachedAsyncImage(
                        urlString: novel.user.profileImageUrls?.px50x50
                            ?? novel.user.profileImageUrls?.medium,
                        expiration: DefaultCacheExpiration.userAvatar
                    )
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(novel.user.name)
                            .font(.headline)
                        Text("@\(novel.user.account)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: toggleFollow) {
                ZStack {
                    Text(isFollowed == true ? "已关注" : "关注")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .frame(width: 95)
                        .opacity(isLoadingFollow ? 0 : 1)
                    
                    if isLoadingFollow {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .buttonStyle(GlassButtonStyle(color: isFollowed == true ? nil : .blue))
            .disabled(isLoadingFollow || isFollowed == nil)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { navigateToReader = true }) {
                HStack {
                    Image(systemName: "book")
                    Text("开始阅读")
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: navigateToReader)

            HStack(spacing: 12) {
                Button(action: { showComments = true }) {
                    HStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("查看评论")
                        if let total = totalComments, total > 0 {
                            Text("(\(total))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if isBookmarked {
                        toggleBookmark(forceUnbookmark: true)
                    } else {
                        toggleBookmark(isPrivate: false)
                    }
                }) {
                    HStack {
                        Image(systemName: isBookmarked ? "heart.fill" : "heart")
                            .foregroundColor(isBookmarked ? .red : .primary)
                        Text(isBookmarked ? "已收藏" : "收藏")
                            .foregroundColor(isBookmarked ? .red : .primary)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .contextMenu {
                    if isBookmarked {
                        Button(action: { toggleBookmark(isPrivate: true) }) {
                            Label("切换为非公开", systemImage: "heart.slash")
                        }
                        Button(role: .destructive, action: { toggleBookmark(forceUnbookmark: true) }) {
                            Label("取消收藏", systemImage: "heart.slash")
                        }
                    } else {
                        Button(action: { toggleBookmark(isPrivate: false) }) {
                            Label("公开收藏", systemImage: "heart")
                        }
                        Button(action: { toggleBookmark(isPrivate: true) }) {
                            Label("私密收藏", systemImage: "heart.slash")
                        }
                    }
                }
            }
        }
    }
    
    private var metadataSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "text.alignleft")
                    .font(.caption2)
                Text(formatTextLength(novel.textLength))
                    .font(.caption)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                Text(NumberFormatter.formatCount(novel.totalView))
                    .font(.caption)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                Text(NumberFormatter.formatCount(novel.totalBookmarks))
                    .font(.caption)
            }
            
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(formatDateTime(novel.createDate))
                    .font(.caption)
            }
            
            Spacer()
        }
        .foregroundColor(.secondary)
    }
    
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("标签")
                .font(.headline)
                .foregroundColor(.secondary)
            
            FlowLayout(spacing: 8) {
                ForEach(novel.tags, id: \.name) { tag in
                    Button(action: {}) {
                        TagChip(tag: tag)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(action: { copyToClipboard(tag.name) }) {
                            Label("复制 tag", systemImage: "doc.on.doc")
                        }
                        Button(action: {
                            try? settingStore.addBlockedTag(tag.name)
                            showBlockTagToast = true
                        }) {
                            Label("屏蔽 tag", systemImage: "eye.slash")
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("简介")
                .font(.headline)
                .foregroundColor(.secondary)

            TranslatableText(text: TextCleaner.cleanDescription(novel.caption), font: .body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        let wasBookmarked = isBookmarked
        let novelId = novel.id
        
        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            novel.isBookmarked = false
            novel.totalBookmarks -= 1
        } else if wasBookmarked {
            isBookmarked = isBookmarked
        } else {
            isBookmarked = true
            novel.isBookmarked = true
            novel.totalBookmarks += 1
        }
        
        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                } else {
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        novel.isBookmarked = true
                        novel.totalBookmarks += 1
                    } else if wasBookmarked {
                        isBookmarked = true
                    } else {
                        isBookmarked = false
                        novel.isBookmarked = false
                        novel.totalBookmarks -= 1
                    }
                }
            }
        }
    }
    
    private func toggleFollow() {
        guard isFollowed != nil else { return }
        
        isLoadingFollow = true
        let userId = novel.user.id.stringValue
        
        Task {
            do {
                if isFollowed == true {
                    try await PixivAPI.shared.unfollowUser(userId: userId)
                    isFollowed = false
                } else {
                    try await PixivAPI.shared.followUser(userId: userId)
                    isFollowed = true
                }
            } catch {
                print("Follow toggle failed: \(error)")
            }
            isLoadingFollow = false
        }
    }
    
    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
        showCopyToast = true
    }
    
    private func shareNovel() {
        guard let url = URL(string: "https://www.pixiv.net/novel/show.php?id=\(novel.id)") else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
    
    private func fetchUserDetailIfNeeded() {
        guard isFollowed == nil else { return }
        
        Task {
            do {
                let detail = try await PixivAPI.shared.getUserDetail(userId: novel.user.id.stringValue)
                await MainActor.run {
                    self.isFollowed = detail.user.isFollowed
                }
            } catch {
                print("Failed to fetch user detail: \(error)")
            }
        }
    }
    
    private func fetchTotalCommentsIfNeeded() {
        Task {
            do {
                let comments = try await PixivAPI.shared.getNovelComments(novelId: novel.id)
                await MainActor.run {
                    self.totalComments = comments.comments.count
                }
            } catch {
                print("Failed to fetch comments: \(error)")
            }
        }
    }
    
    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            return String(format: "%.1f万字", Double(length) / 10000)
        } else if length >= 1000 {
            return String(format: "%.1f千字", Double(length) / 1000)
        }
        return "\(length)字"
    }
    
    private func formatDateTime(_ dateString: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let parsedDate = formatter.date(from: dateString) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd"
            return displayFormatter.string(from: parsedDate)
        }
        
        return dateString
    }
}

#Preview {
    NavigationStack {
        NovelDetailView(novel: Novel(
            id: 123,
            title: "示例小说标题",
            caption: "这是一段小说简介，可以包含 HTML 标签。",
            restrict: 0,
            xRestrict: 0,
            isOriginal: true,
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            createDate: "2023-12-15T00:00:00+09:00",
            tags: [
                NovelTag(name: "原创", translatedName: nil, addedByUploadedUser: true),
                NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true),
                NovelTag(name: "長編", translatedName: "长篇", addedByUploadedUser: false)
            ],
            pageCount: 1,
            textLength: 15000,
            user: User(
                profileImageUrls: ProfileImageUrls(
                    px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                ),
                id: StringIntValue.string("1"),
                name: "示例作者",
                account: "test_user"
            ),
            series: nil,
            isBookmarked: false,
            totalBookmarks: 1234,
            totalView: 56789,
            visible: true,
            isMuted: false,
            isMypixivOnly: false,
            isXRestricted: false,
            novelAIType: 0
        ))
    }
}
