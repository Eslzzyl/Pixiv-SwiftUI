import SwiftUI

struct CommentPanelView<Preview: View>: View {
    let entityId: Int
    let preview: Preview
    let totalComments: Int?
    @Bindable var viewModel: CommentPanelBase
    @Binding var isPresented: Bool
    let onUserTapped: (String) -> Void
    @FocusState.Binding var isInputFocused: Bool

    init(
        entityId: Int,
        preview: Preview,
        totalComments: Int?,
        viewModel: CommentPanelBase,
        isPresented: Binding<Bool>,
        onUserTapped: @escaping (String) -> Void,
        isInputFocused: FocusState<Bool>.Binding
    ) {
        self.entityId = entityId
        self.preview = preview
        self.totalComments = totalComments
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onUserTapped = onUserTapped
        self._isInputFocused = isInputFocused
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                preview

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

                if let totalComments = totalComments, totalComments > 0 {
                    ToolbarItem(placement: .principal) {
                        Text("\(totalComments) 条评论")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("确认删除", isPresented: $viewModel.showDeleteAlert) {
                Button("取消", role: .cancel) {
                    viewModel.commentToDelete = nil
                }
                Button("删除", role: .destructive) {
                    Task {
                        await viewModel.confirmDeleteComment(entityId: entityId)
                    }
                }
            } message: {
                Text("删除后无法恢复，确定要删除这条评论吗？")
            }
            .task {
                await viewModel.loadComments(entityId: entityId)
            }
        }
    }

    private var commentInputBar: some View {
        CommentInputView(
            text: $viewModel.commentText,
            replyToUserName: viewModel.replyToUserName,
            isSubmitting: viewModel.isSubmitting,
            canSubmit: viewModel.canSubmit,
            maxCommentLength: viewModel.maxCommentLength,
            onCancelReply: { viewModel.cancelReply() },
            onSubmit: {
                Task {
                    await viewModel.submitComment(entityId: entityId)
                }
            }
        )
    }

    private var commentsListSection: some View {
        Group {
            if viewModel.isLoadingComments {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.commentsError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task {
                            await viewModel.loadComments(entityId: entityId)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.comments.isEmpty {
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
                    ForEach(viewModel.comments, id: \.id) { comment in
                        commentSection(for: comment)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func commentSection(for comment: Comment) -> some View {
        let isExpanded = viewModel.expandedCommentIds.contains(comment.id ?? 0)
        let replies = viewModel.repliesDict[comment.id ?? 0] ?? []
        let isLoading = viewModel.loadingReplyIds.contains(comment.id ?? 0)

        Section {
            CommentRowView(
                comment: comment,
                isReply: false,
                isExpanded: isExpanded,
                onToggleExpand: { viewModel.toggleExpand(for: comment.id ?? 0) },
                onUserTapped: onUserTapped,
                onReplyTapped: { tappedComment in
                    viewModel.replyToUserName = tappedComment.user?.name
                    viewModel.replyToCommentId = tappedComment.id
                    isInputFocused = true
                },
                onDeleteTapped: { commentToDelete in
                    viewModel.handleDeleteComment(commentToDelete)
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
                        viewModel.replyToUserName = tappedComment.user?.name
                        viewModel.replyToCommentId = tappedComment.id
                        isInputFocused = true
                    },
                            onDeleteTapped: { replyToDelete in
                                viewModel.handleDeleteComment(replyToDelete)
                            }
                        )
                    }
                }
            }
        }
    }
}
