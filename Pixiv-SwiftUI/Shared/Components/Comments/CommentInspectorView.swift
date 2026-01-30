import SwiftUI

struct CommentInspectorView<Header: View>: View {
    let entityId: Int
    let header: Header
    let totalComments: Int?
    @Bindable var viewModel: CommentPanelBase
    let onUserTapped: (String) -> Void
    @FocusState.Binding var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            commentsListSection
        }
        .safeAreaInset(edge: .bottom) {
            commentInputBar
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
            if viewModel.isLoadingComments && viewModel.comments.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.commentsError {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        Task {
                            await viewModel.loadComments(entityId: entityId)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if viewModel.comments.isEmpty {
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
