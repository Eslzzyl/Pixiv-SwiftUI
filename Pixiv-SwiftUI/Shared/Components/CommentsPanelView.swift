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
    @State private var commentText: String = ""
    @State private var replyToUserName: String?
    @State private var replyToCommentId: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    let onUserTapped: (String) -> Void

    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(10)
    private let maxCommentLength = 140

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                illustPreviewSection

                Divider()

                commentsListSection

                Divider()

                commentInputBar
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

    private var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        commentText.count <= maxCommentLength &&
        !isSubmitting
    }

    private var commentInputBar: some View {
        CommentInputView(
            text: $commentText,
            replyToUserName: replyToUserName,
            isSubmitting: isSubmitting,
            canSubmit: canSubmit,
            maxCommentLength: maxCommentLength,
            onCancelReply: cancelReply,
            onSubmit: submitComment
        )
    }

    private func cancelReply() {
        replyToUserName = nil
        replyToCommentId = nil
    }

    private func submitComment() {
        guard canSubmit else { return }

        let trimmedComment = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await PixivAPI.shared.postIllustComment(
                    illustId: illust.id,
                    comment: trimmedComment,
                    parentCommentId: replyToCommentId
                )
                await MainActor.run {
                    commentText = ""
                    isSubmitting = false
                    cancelReply()
                    refreshComments()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "发送失败: \(error.localizedDescription)"
                    isSubmitting = false
                }
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
                onUserTapped: onUserTapped,
                onReplyTapped: { tappedComment in
                    replyToUserName = tappedComment.user?.name
                    replyToCommentId = tappedComment.id
                    isInputFocused = true
                }
            )

            if isExpanded {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            #if os(macOS)
                            .controlSize(.small)
                            #endif
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
                            onUserTapped: onUserTapped,
                            onReplyTapped: { tappedComment in
                                replyToUserName = tappedComment.user?.name
                                replyToCommentId = tappedComment.id
                                isInputFocused = true
                            }
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
        let cacheKey = CacheManager.commentsKey(illustId: illust.id)

        if let cached: CommentResponse = cache.get(forKey: cacheKey) {
            comments = cached.comments
            return
        }

        isLoadingComments = true
        commentsError = nil

        do {
            let response = try await PixivAPI.shared.getIllustComments(illustId: illust.id)
            comments = response.comments
            cache.set(response, forKey: cacheKey, expiration: expiration)
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
                _ = await MainActor.run {
                    loadingReplyIds.remove(commentId)
                }
            }
        }
    }

    private func refreshComments() {
        let cacheKey = CacheManager.commentsKey(illustId: illust.id)
        cache.remove(forKey: cacheKey)
        Task {
            await loadComments()
        }
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
