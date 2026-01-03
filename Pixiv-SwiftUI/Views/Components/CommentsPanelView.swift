import SwiftUI

/// 评论面板视图
struct CommentsPanelView: View {
    let illust: Illusts
    @Binding var isPresented: Bool
    @State private var comments: [Comment] = []
    @State private var isLoadingComments = false
    @State private var commentsError: String?
    @State private var expandedCommentIds = Set<Int>()
    @State private var loadingReplyIds = Set<Int>()
    @State private var repliesDict = [Int: [Comment]]()
    let onUserTapped: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                illustPreviewSection
                
                Divider()
                
                commentsListSection
            }
            .navigationTitle("评论")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                #endif
                
                if let totalComments = illust.totalComments, totalComments > 0 {
                    ToolbarItem(placement: .principal) {
                        Text("\(totalComments) 条评论")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .task {
                await loadComments()
            }
        }
    }
    
    private var illustPreviewSection: some View {
        HStack(spacing: 12) {
            if let imageURL = getThumbnailURL() {
                CachedAsyncImage(urlString: imageURL)
                    .frame(width: 80, height: 80)
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(illust.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(illust.user.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.primary.opacity(0.05))
    }
    
    private var commentsListSection: some View {
        Group {
            if isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = commentsError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task {
                            await loadComments()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if comments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无评论")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(comments, id: \.id) { comment in
                        commentSection(for: comment)
                    }
                }
                .listStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func commentSection(for comment: Comment) -> some View {
        let isExpanded = expandedCommentIds.contains(comment.id ?? 0)
        let replies = repliesDict[comment.id ?? 0] ?? []
        let isLoading = loadingReplyIds.contains(comment.id ?? 0)
        
        Section {
            CommentRowView(
                comment: comment,
                isReply: false,
                isExpanded: isExpanded,
                onToggleExpand: { toggleExpand(for: comment.id ?? 0) },
                onUserTapped: onUserTapped
            )
            
            if isExpanded {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                    .listRowInsets(EdgeInsets())
                } else if replies.isEmpty {
                    Text("暂无回复")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 52)
                        .listRowInsets(EdgeInsets())
                } else {
                    ForEach(replies, id: \.id) { reply in
                        CommentRowView(
                            comment: reply,
                            isReply: true,
                            isExpanded: false,
                            onToggleExpand: {},
                            onUserTapped: onUserTapped
                        )
                    }
                }
            }
        }
    }
    
    private func getThumbnailURL() -> String? {
        if let firstPage = illust.metaPages.first,
           let url = firstPage.imageUrls?.squareMedium {
            return url
        }
        return illust.imageUrls.squareMedium
    }
    
    private func loadComments() async {
        isLoadingComments = true
        commentsError = nil
        
        do {
            let response = try await PixivAPI.shared.getIllustComments(illustId: illust.id)
            comments = response.comments
            isLoadingComments = false
        } catch {
            commentsError = "加载失败: \(error.localizedDescription)"
            isLoadingComments = false
        }
    }
    
    private func toggleExpand(for commentId: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCommentIds.contains(commentId) {
                expandedCommentIds.remove(commentId)
            } else {
                expandedCommentIds.insert(commentId)
                if repliesDict[commentId] == nil {
                    loadReplies(for: commentId)
                }
            }
        }
    }
    
    private func loadReplies(for commentId: Int) {
        guard commentId > 0 else { return }
        
        loadingReplyIds.insert(commentId)
        
        Task {
            do {
                let response = try await PixivAPI.shared.getIllustCommentsReplies(commentId: commentId)
                await MainActor.run {
                    repliesDict[commentId] = response.comments
                    loadingReplyIds.remove(commentId)
                }
            } catch {
                await MainActor.run {
                    loadingReplyIds.remove(commentId)
                }
            }
        }
    }
}

/// 单条评论视图
struct CommentRowView: View {
    let comment: Comment
    let isReply: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onUserTapped: (String) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isReply {
                Rectangle()
                    .frame(width: 24)
                    .foregroundColor(.clear)
            }
            
            userAvatar
            
            VStack(alignment: .leading, spacing: 4) {
                userInfoRow
                
                if let parent = comment.parentComment {
                    parentCommentHint(parent)
                }
                
                commentContent
            }
        }
        .padding(.vertical, 8)
    }
    
    private var userAvatar: some View {
        Group {
            if let user = comment.user,
               let avatarURL = user.profileImageUrls?.medium {
                Button(action: {
                    if let userId = user.id {
                        onUserTapped(String(userId))
                    }
                }) {
                    CachedAsyncImage(urlString: avatarURL)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
            }
        }
    }
    
    private var userInfoRow: some View {
        HStack(spacing: 8) {
            if let user = comment.user, let name = user.name {
                Button(action: {
                    if let userId = user.id {
                        onUserTapped(String(userId))
                    }
                }) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
            }
            
            if let date = comment.date {
                Text("· \(formatDate(date))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if comment.hasReplies == true && !isReply {
                expandButton
            }
        }
    }
    
    private var expandButton: some View {
        Button(action: onToggleExpand) {
            HStack(spacing: 4) {
                Text(isExpanded ? "收起" : "回复")
                    .font(.caption)
                    .foregroundColor(.blue)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func parentCommentHint(_ parent: ParentComment) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.caption2)
                .foregroundColor(.secondary)
            if let parentUser = parent.user?.name {
                Text("@\(parentUser)")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            Text("的回复")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 8)
    }
    
    private var commentContent: some View {
        Group {
            if let stamp = comment.stamp,
               let stampUrl = stamp.stampUrl {
                CachedAsyncImage(urlString: stampUrl)
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
            } else if let commentText = comment.comment {
                TranslatableCommentTextView(text: TextCleaner.decodeHTMLEntities(commentText), font: .subheadline)
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        if let parsedDate = formatter.date(from: dateString) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = .current
            return displayFormatter.string(from: parsedDate)
        }
        
        return dateString
    }
}

#Preview {
    CommentsPanelView(
        illust: Illusts(
            id: 123,
            title: "示例插画",
            type: "illust",
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            caption: "这是一段示例描述",
            restrict: 0,
            user: User(
                profileImageUrls: ProfileImageUrls(
                    px16x16: "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                    px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                    px170x170: "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
                ),
                id: StringIntValue.string("1"),
                name: "示例用户",
                account: "test_user"
            ),
            tags: [],
            tools: [],
            createDate: "2023-12-15T00:00:00+09:00",
            pageCount: 1,
            width: 1200,
            height: 1600,
            sanityLevel: 2,
            xRestrict: 0,
            metaSinglePage: nil,
            metaPages: [],
            totalView: 12345,
            totalBookmarks: 999,
            isBookmarked: false,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: 0,
            totalComments: 5
        ),
        isPresented: .constant(true),
        onUserTapped: { _ in }
    )
}
