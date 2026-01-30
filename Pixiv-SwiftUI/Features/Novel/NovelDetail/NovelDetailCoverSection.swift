import SwiftUI

struct NovelDetailCoverSection: View {
    let novel: Novel
    var coverAspectRatio: CGFloat? = nil
    var onCoverSizeChange: ((CGSize) -> Void)? = nil
    var onStartReading: (() -> Void)? = nil

    @State private var savedIndex: Int?
    @State private var savedTotal: Int?
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
        .onReceive(NotificationCenter.default.publisher(for: .novelReaderProgressDidSave)) { notification in
            if let novelId = notification.userInfo?["novelId"] as? Int, novelId == novel.id {
                loadProgress()
            }
        }
    }

    private func loadProgress() {
        let key = "\(progressKey)\(novel.id)"
        if let data = UserDefaults.standard.dictionary(forKey: key),
           let index = data["index"] as? Int,
           let total = data["total"] as? Int {
            savedIndex = index
            savedTotal = total
        } else if let progress = UserDefaults.standard.object(forKey: key) as? Int {
            // 向后兼容：旧格式只有索引
            savedIndex = progress
            savedTotal = nil
        } else {
            savedIndex = nil
            savedTotal = nil
        }
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
        if let index = savedIndex, let total = savedTotal, total > 0 {
            let percentage = Int(Double(index) / Double(total) * 100)
            return String(localized: "继续阅读（\(percentage)%）")
        } else if savedIndex != nil {
            return String(localized: "继续阅读")
        } else {
            return String(localized: "开始阅读")
        }
    }

    private var buttonIcon: String {
        if savedIndex != nil {
            return "book.pages"
        } else {
            return "book.closed"
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
