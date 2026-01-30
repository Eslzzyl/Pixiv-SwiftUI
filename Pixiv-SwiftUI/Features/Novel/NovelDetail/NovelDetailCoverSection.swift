import SwiftUI

struct NovelDetailCoverSection: View {
    let novel: Novel
    var coverAspectRatio: CGFloat? = nil
    var onCoverSizeChange: ((CGSize) -> Void)? = nil
    var onStartReading: (() -> Void)? = nil

    @State private var savedProgress: Int?
    @Environment(ThemeManager.self) var themeManager

    private let progressKey = "novel_reader_progress_"

    var body: some View {
        VStack(spacing: 0) {
            coverImage

            startReadingButton
                .padding(.top, 24)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onAppear {
            loadProgress()
        }
    }

    private func loadProgress() {
        let key = "\(progressKey)\(novel.id)"
        savedProgress = UserDefaults.standard.object(forKey: key) as? Int
    }

    private var coverImage: some View {
        DynamicSizeCachedAsyncImage(
            urlString: novel.imageUrls.medium,
            placeholder: nil,
            aspectRatio: coverAspectRatio,
            contentMode: .fit,
            onSizeChange: { size in
                onCoverSizeChange?(size)
            },
            expiration: DefaultCacheExpiration.novel
        )
    }

    private var startReadingButton: some View {
        Button(action: { 
            onStartReading?()
        }) {
            HStack {
                Image(systemName: buttonIcon)
                Text(buttonText)
            }
            .font(.headline)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(themeManager.currentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var buttonText: String {
        if savedProgress != nil {
            return String(localized: "继续阅读")
        } else {
            return String(localized: "开始阅读")
        }
    }

    private var buttonIcon: String {
        if savedProgress != nil {
            return "book.open.fill"
        } else {
            return "book.fill"
        }
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
