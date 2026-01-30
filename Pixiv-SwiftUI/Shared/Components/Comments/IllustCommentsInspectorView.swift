import SwiftUI

struct IllustCommentsInspectorView: View {
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
    @State private var showDeleteAlert = false
    @State private var commentToDelete: Comment?
    @FocusState private var isInputFocused: Bool

    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(10)
    private let maxCommentLength = 140

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()

            commentsListSection
        }
        .safeAreaInset(edge: .bottom) {
            commentInputBar
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {
                commentToDelete = nil
            }
            Button("删除", role: .destructive) {
                confirmDeleteComment()
            }
        } message: {
            Text("删除后无法恢复，确定要删除这条评论吗？")
        }
        .task {
            await loadComments()
        }
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                List {
                    ForEach(comments, id: \.id) { comment in
                        commentSection(for: comment)
                    }
                }
                .listStyle(.plain)
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
                },
                onDeleteTapped: { commentToDelete in
                    handleDeleteComment(commentToDelete)
                }
            )

            if isExpanded {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
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
                            },
                            onDeleteTapped: { replyToDelete in
                                handleDeleteComment(replyToDelete)
                            }
                        )
                    }
                }
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

    private func refreshComments() {
        let cacheKey = CacheManager.commentsKey(illustId: illust.id)
        cache.remove(forKey: cacheKey)
        Task {
            await loadComments()
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

    private func handleDeleteComment(_ comment: Comment) {
        guard comment.id != nil else { return }

        guard let commentUserId = comment.user?.id,
              String(commentUserId) == AccountStore.shared.currentUserId else {
            errorMessage = "只能删除自己的评论"
            return
        }

        commentToDelete = comment
        showDeleteAlert = true
    }

    private func confirmDeleteComment() {
        guard let comment = commentToDelete, let commentId = comment.id else { return }

        showDeleteAlert = false

        Task {
            do {
                try await PixivAPI.shared.deleteIllustComment(commentId: commentId)
                await MainActor.run {
                    comments.removeAll { $0.id == commentId }
                    for key in repliesDict.keys {
                        repliesDict[key] = repliesDict[key]?.filter { $0.id != commentId }
                    }
                    let cacheKey = CacheManager.commentsKey(illustId: illust.id)
                    cache.remove(forKey: cacheKey)
                    commentToDelete = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "删除失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
