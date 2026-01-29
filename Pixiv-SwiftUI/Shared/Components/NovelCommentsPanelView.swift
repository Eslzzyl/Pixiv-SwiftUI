import SwiftUI

struct NovelCommentsPanelView: View {
    let novel: Novel
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
    @State private var showDeleteAlert = false
    @State private var commentToDelete: Comment?
    @FocusState private var isInputFocused: Bool
    @State private var navigateToUserId: String?

    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(10)
    private let maxCommentLength = 140

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                novelPreviewSection

                Divider()

                commentsListSection
            }
            .safeAreaInset(edge: .bottom) {
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

                if let totalComments = novel.totalComments, totalComments > 0 {
                    ToolbarItem(placement: .principal) {
                        Text("\(totalComments) 条评论")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
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
            .navigationDestination(item: $navigateToUserId) { userId in
                UserDetailView(userId: userId)
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
                try await PixivAPI.shared.postNovelComment(
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
                    isSubmitting = false
                }
            }
        }
    }

    private var novelPreviewSection: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 80, height: 80)
            .aspectRatio(contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(novel.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(novel.user.name)
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
                        novelCommentSection(for: comment)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func novelCommentSection(for comment: Comment) -> some View {
        let isExpanded = expandedCommentIds.contains(comment.id ?? 0)
        let replies = repliesDict[comment.id ?? 0] ?? []
        let isLoading = loadingReplyIds.contains(comment.id ?? 0)

        Section {
            CommentRowView(
                comment: comment,
                isReply: false,
                isExpanded: isExpanded,
                onToggleExpand: { toggleExpand(for: comment.id ?? 0) },
                onUserTapped: { userId in
                    navigateToUserId = userId
                },
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
                            onUserTapped: { userId in
                                navigateToUserId = userId
                            },
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
        let cacheKey = CacheManager.novelCommentsKey(novelId: novel.id)
        cache.remove(forKey: cacheKey)
        Task {
            await loadComments()
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
                try await PixivAPI.shared.deleteNovelComment(commentId: commentId)
                await MainActor.run {
                    comments.removeAll { $0.id == commentId }
                    for key in repliesDict.keys {
                        repliesDict[key] = repliesDict[key]?.filter { $0.id != commentId }
                    }
                    let cacheKey = CacheManager.novelCommentsKey(novelId: novel.id)
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

#Preview {
    NovelCommentsPanelView(
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
        isPresented: .constant(true)
    )
}
