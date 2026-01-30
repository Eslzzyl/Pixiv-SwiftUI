import SwiftUI

struct NovelCommentsPanelView: View {
    let novel: Novel
    @Binding var isPresented: Bool
    let onUserTapped: (String) -> Void

    @State private var viewModel: CommentPanelBase
    @State private var navigateToUserId: String?
    @FocusState private var isInputFocused: Bool

    init(novel: Novel, isPresented: Binding<Bool>, onUserTapped: @escaping (String) -> Void) {
        self.novel = novel
        self._isPresented = isPresented
        self.onUserTapped = onUserTapped
        self._viewModel = State(initialValue: CommentPanelBase(
            cacheKeyProvider: { CacheManager.novelCommentsKey(novelId: $0) },
            loadCommentsAPI: { try await PixivAPI.shared.getNovelComments(novelId: $0) },
            postCommentAPI: { id, text, parent in try await PixivAPI.shared.postNovelComment(novelId: id, comment: text, parentCommentId: parent) },
            deleteCommentAPI: { try await PixivAPI.shared.deleteNovelComment(commentId: $0) }
        ))
    }

    var body: some View {
        CommentPanelView(
            entityId: novel.id,
            preview: novelPreviewSection,
            totalComments: novel.totalComments,
            viewModel: viewModel,
            isPresented: $isPresented,
            onUserTapped: { userId in
                navigateToUserId = userId
            },
            isInputFocused: $isInputFocused
        )
        .navigationDestination(item: $navigateToUserId) { userId in
            UserDetailView(userId: userId)
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
}

#Preview {
    let novel = Novel(
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
    )

    NovelCommentsPanelView(
        novel: novel,
        isPresented: .constant(true),
        onUserTapped: { _ in }
    )
}
