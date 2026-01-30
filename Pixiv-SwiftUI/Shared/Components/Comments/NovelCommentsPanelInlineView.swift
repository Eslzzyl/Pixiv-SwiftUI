import SwiftUI

struct NovelCommentsPanelInlineView: View {
    let novel: Novel
    let onUserTapped: (String) -> Void

    @State private var comments: [Comment] = []
    @State private var isLoadingComments = false
    @State private var commentsError: String?
    @State private var navigateToUserId: String?

    @State private var commentText: String = ""
    @State private var replyToUserName: String?
    @State private var replyToCommentId: Int?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showErrorMessage = false
    @FocusState private var isInputFocused: Bool

    var hasInternalScroll: Bool = true
    var internalScrollMaxHeight: CGFloat? = .zero

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
        .navigationDestination(item: $navigateToUserId) { userId in
            UserDetailView(userId: userId)
        }
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

                if let totalComments = novel.totalComments, totalComments > 0 {
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
                                CommentRowView(
                                    comment: comment,
                                    isReply: false,
                                    onUserTapped: { userId in
                                        navigateToUserId = userId
                                    },
                                    onReplyTapped: { comment in
                                        replyToCommentId = comment.id
                                        replyToUserName = comment.user?.name
                                        isInputFocused = true
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: internalScrollMaxHeight ?? 300)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(comments, id: \.id) { comment in
                            CommentRowView(
                                comment: comment,
                                isReply: false,
                                onUserTapped: { userId in
                                    navigateToUserId = userId
                                },
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
        }
    }

    private func loadComments() async {
        let cacheKey = CacheManager.novelCommentsKey(novelId: novel.id)

        if let cached: CommentResponse = cache.get(forKey: cacheKey) {
            comments = cached.comments
            return
        }

        isLoadingComments = true
        commentsError = nil

        do {
            let response = try await PixivAPI.shared.getNovelComments(novelId: novel.id)
            comments = response.comments
            cache.set(response, forKey: cacheKey, expiration: expiration)
            isLoadingComments = false
        } catch {
            commentsError = "加载失败: \(error.localizedDescription)"
            isLoadingComments = false
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
                _ = try await PixivAPI.shared.postNovelComment(
                    novelId: novel.id,
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
        let cacheKey = CacheManager.novelCommentsKey(novelId: novel.id)
        cache.remove(forKey: cacheKey)
        Task {
            await loadComments()
        }
    }
}

#Preview {
    NavigationStack {
        NovelCommentsPanelInlineView(
            novel: Novel(
                id: 123,
                title: "示例小说标题",
                caption: "",
                restrict: 0,
                xRestrict: 0,
                isOriginal: true,
                imageUrls: ImageUrls(
                    squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                    medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                    large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
                ),
                createDate: "2023-12-15T00:00:00+09:00",
                tags: [],
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
                novelAIType: 0,
                totalComments: 5
            ),
            onUserTapped: { _ in }
        )
    }
}
