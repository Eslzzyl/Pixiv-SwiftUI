import SwiftUI

struct NovelCommentsInspectorView: View {
    let novel: Novel
    let onUserTapped: (String) -> Void

    @State private var viewModel: CommentPanelBase
    @FocusState private var isInputFocused: Bool

    init(novel: Novel, onUserTapped: @escaping (String) -> Void) {
        self.novel = novel
        self.onUserTapped = onUserTapped
        self._viewModel = State(initialValue: CommentPanelBase(
            cacheKeyProvider: { CacheManager.novelCommentsKey(novelId: $0) },
            loadCommentsAPI: { try await PixivAPI.shared.getNovelComments(novelId: $0) },
            postCommentAPI: { id, text, parent in try await PixivAPI.shared.postNovelComment(novelId: id, comment: text, parentCommentId: parent) },
            deleteCommentAPI: { try await PixivAPI.shared.deleteNovelComment(commentId: $0) }
        ))
    }

    var body: some View {
        CommentInspectorView(
            entityId: novel.id,
            header: headerSection,
            totalComments: novel.totalComments,
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

                if let totalComments = novel.totalComments, totalComments > 0 {
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
