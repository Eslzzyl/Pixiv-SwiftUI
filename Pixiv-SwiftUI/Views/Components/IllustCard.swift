import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// 插画卡片组件
struct IllustCard: View {
    let illust: Illusts
    let columnCount: Int

    init(illust: Illusts, columnCount: Int = 2) {
        self.illust = illust
        self.columnCount = columnCount
    }

    private var screenWidth: CGFloat {
        #if canImport(UIKit)
            if let windowScene = UIApplication.shared.connectedScenes.first
                as? UIWindowScene
            {
                return windowScene.screen.bounds.width
            }
            return UIScreen.main.bounds.width
        #else
            return NSScreen.main?.frame.width ?? 800
        #endif
    }

    private var imageWidth: CGFloat {
        let totalSpacing = CGFloat(columnCount + 1) * 12
        return (screenWidth - totalSpacing) / CGFloat(columnCount)
    }

    private var imageHeight: CGFloat {
        let ratio = CGFloat(illust.height) / CGFloat(illust.width)
        return imageWidth * ratio
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(urlString: illust.imageUrls.medium)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                
                if illust.pageCount > 1 {
                    Text("P\(illust.pageCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(4)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(illust.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .padding(6)
        }
        .background(Color(white: 0.97))
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

#Preview {
    let illust = Illusts(
        id: 123,
        title: "示例插画",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium:
                "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium:
                "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large:
                "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "示例作品",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16:
                    "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px50x50:
                    "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px170x170:
                    "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
            ),
            id: StringIntValue.string("1"),
            name: "示例用户",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 1,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 1000,
        totalBookmarks: 500,
        isBookmarked: false,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2)
        .padding()
        .frame(width: 390)
}

#Preview("多页插画") {
    let illust = Illusts(
        id: 124,
        title: "多页示例插画",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium:
                "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium:
                "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large:
                "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "多页示例",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16:
                    "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px50x50:
                    "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px170x170:
                    "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
            ),
            id: StringIntValue.string("1"),
            name: "示例用户",
            account: "test"
        ),
        tags: [],
        tools: [],
        createDate: "2023-12-15T00:00:00+09:00",
        pageCount: 5,
        width: 900,
        height: 1200,
        sanityLevel: 2,
        xRestrict: 0,
        metaSinglePage: nil,
        metaPages: [],
        totalView: 2000,
        totalBookmarks: 800,
        isBookmarked: false,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2)
        .padding()
        .frame(width: 390)
}
