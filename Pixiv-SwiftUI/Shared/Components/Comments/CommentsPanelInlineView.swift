import SwiftUI

struct CommentsPanelInlineView: View {
    let illust: Illusts
    let onUserTapped: (String) -> Void

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
    @State private var showErrorMessage = false
    @FocusState private var isInputFocused: Bool

    var hasInternalScroll: Bool = true
    var internalScrollMaxHeight: CGFloat? = nil

    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(10)
    private let maxCommentLength = 140

    private var canSubmit: Bool {
        !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        commentText.count <= maxCommentLength &&
        !isSubmitting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            Divider()

            commentInputSection

            Divider()

            commentsListSection
        }
        .toast(isPresented: $showErrorMessage, message: errorMessage ?? "")
        .task {
            await loadComments()
        }
    }

    private var commentInputSection: some View {
        CommentInputView(
            text: $commentText,
            replyToUserName: replyToUserName,
            isSubmitting: isSubmitting,
            canSubmit: canSubmit,
            maxCommentLength: maxCommentLength,
            onCancelReply: cancelReply,
            onSubmit: submitComment
        )
        .focused($isInputFocused)
    }

    private var headerSection: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.subheadline)
                Text("评论")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let totalComments = illust.totalComments, totalComments > 0 {
                    Text("(\(totalComments))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isLoadingComments {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }

    private var commentsListSection: some View {
        Group {
            if isLoadingComments && comments.isEmpty {
                ProgressView()
                    .padding(.vertical, 40)
            } else if let error = commentsError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task {
                            await loadComments()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("暂无评论")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                if hasInternalScroll {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(comments, id: \.id) { comment in
                                commentRow(for: comment)
                            }
                        }
                    }
                    .frame(maxHeight: internalScrollMaxHeight ?? 400)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(comments, id: \.id) { comment in
                            commentRow(for: comment)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func commentRow(for comment: Comment) -> some View {
        let isExpanded = expandedCommentIds.contains(comment.id ?? 0)
        let replies = repliesDict[comment.id ?? 0] ?? []
        let isLoading = loadingReplyIds.contains(comment.id ?? 0)

        VStack(alignment: .leading, spacing: 0) {
            CommentRowView(
                comment: comment,
                isReply: false,
                isExpanded: isExpanded,
                onToggleExpand: { toggleExpand(for: comment.id ?? 0) },
                onUserTapped: onUserTapped,
                onReplyTapped: { comment in
                    replyToCommentId = comment.id
                    replyToUserName = comment.user?.name
                    isInputFocused = true
                }
            )

            if isExpanded {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .padding()
                        Spacer()
                    }
                } else if replies.isEmpty {
                    Text("暂无回复")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.leading, 52)
                        .padding(.vertical, 4)
                } else {
                    ForEach(replies, id: \.id) { reply in
                        CommentRowView(
                            comment: reply,
                            isReply: true,
                            onUserTapped: onUserTapped,
                            onReplyTapped: { comment in
                                replyToCommentId = comment.id
                                replyToUserName = comment.user?.name
                                isInputFocused = true
                            }
                        )
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if (comment.id ?? 0) > 0 {
                toggleExpand(for: comment.id ?? 0)
            }
        }
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
                _ = try await PixivAPI.shared.postIllustComment(
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
                    showErrorMessage = true
                    isSubmitting = false
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
    CommentsPanelInlineView(
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
        onUserTapped: { _ in }
    )
}

