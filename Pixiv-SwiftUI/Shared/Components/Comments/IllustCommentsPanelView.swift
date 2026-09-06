import SwiftUI

struct IllustCommentsPanelView: View {
    let illust: Illusts
    @Binding var isPresented: Bool
    let onUserTapped: (String) -> Void

    @State private var viewModel: CommentPanelBase
    @FocusState private var isInputFocused: Bool

    init(illust: Illusts, isPresented: Binding<Bool>, onUserTapped: @escaping (String) -> Void) {
        self.illust = illust
        self._isPresented = isPresented
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
        CommentPanelView(
            entityId: illust.id,
            preview: illustPreviewSection,
            totalComments: illust.totalComments,
            workAuthorId: illust.user.id.stringValue,
            viewModel: viewModel,
            isPresented: $isPresented,
            onUserTapped: onUserTapped,
            isInputFocused: $isInputFocused
        )
    }

    private var illustPreviewSection: some View {
        HStack(spacing: 12) {
            if let imageURL = getThumbnailURL() {
                CachedAsyncImage(urlString: imageURL)
                    .frame(width: 56, height: 56)
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(illust.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(illust.user.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }

    private func getThumbnailURL() -> String? {
        if let firstPage = illust.metaPages.first,
           let url = firstPage.imageUrls?.squareMedium {
            return url
        }
        return illust.imageUrls.squareMedium
    }
}

#Preview {
    let illust = Illusts(
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
    )

    IllustCommentsPanelView(
        illust: illust,
        isPresented: .constant(true),
        onUserTapped: { _ in }
    )
}
