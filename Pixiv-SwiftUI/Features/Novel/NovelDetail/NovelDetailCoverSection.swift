import SwiftUI

struct NovelDetailCoverSection: View {
    let novel: Novel

    @State private var navigateToReader = false

    var body: some View {
        VStack(spacing: 0) {
            coverImage

            startReadingButton
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .navigationDestination(isPresented: $navigateToReader) {
            NovelReaderView(novelId: novel.id)
        }
    }

    private var coverImage: some View {
        CachedAsyncImage(
            urlString: novel.imageUrls.medium,
            contentMode: .fit,
            expiration: DefaultCacheExpiration.novel
        )
    }

    private var startReadingButton: some View {
        Button(action: { navigateToReader = true }) {
            HStack {
                Image(systemName: "book.fill")
                Text("开始阅读")
            }
            .font(.headline)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

#Preview {
    NovelDetailCoverSection(
        novel: Novel(
            id: 123,
            title: "示例小说标题",
            caption: "这是一段小说简介",
            restrict: 0,
            xRestrict: 0,
            isOriginal: true,
            imageUrls: ImageUrls(
                squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg",
                medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
                large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
            ),
            createDate: "2023-12-15T00:00:00+09:00",
            tags: [
                NovelTag(name: "原创", translatedName: nil, addedByUploadedUser: true),
                NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true)
            ],
            pageCount: 1,
            textLength: 15000,
            user: User(
                profileImageUrls: ProfileImageUrls(px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg"),
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
            novelAIType: 0
        )
    )
    .frame(width: 400, height: 500)
}
