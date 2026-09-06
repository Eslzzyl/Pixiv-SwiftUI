import SwiftUI

struct IllustCommentsInspectorView: View {
    let illust: Illusts
    let onUserTapped: (String) -> Void

    @State private var viewModel: CommentPanelBase
    @FocusState private var isInputFocused: Bool

    init(illust: Illusts, onUserTapped: @escaping (String) -> Void) {
        self.illust = illust
        self.onUserTapped = onUserTapped
        self._viewModel = State(initialValue: CommentPanelBase(
            cacheKeyProvider: { CacheManager.commentsKey(illustId: $0) },
            loadCommentsAPI: { try await PixivAPI.shared.illustAPI.getIllustComments(illustId: $0) },
            loadRepliesAPI: { try await PixivAPI.shared.illustAPI.getIllustCommentsReplies(commentId: $0) },
            postCommentAPI: { id, text, parent in try await PixivAPI.shared.illustAPI.postIllustComment(illustId: id, comment: text, parentCommentId: parent) },
            deleteCommentAPI: { try await PixivAPI.shared.illustAPI.deleteIllustComment(commentId: $0) }
        ))
    }

    var body: some View {
        CommentInspectorView(
            entityId: illust.id,
            header: headerSection,
            totalComments: illust.totalComments,
            workAuthorId: illust.user.id.stringValue,
            viewModel: viewModel,
            onUserTapped: onUserTapped,
            isInputFocused: $isInputFocused
        )
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

            if viewModel.isLoadingComments {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
    }
}
