import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// 插画卡片组件
struct IllustCard: View {
    @Environment(UserSettingStore.self) var userSettingStore
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
    
    private var isR18: Bool {
        return illust.xRestrict >= 1
    }

    private var shouldBlur: Bool {
        return isR18 && userSettingStore.userSetting.r18DisplayMode == 1
    }

    private var shouldHide: Bool {
        return isR18 && userSettingStore.userSetting.r18DisplayMode == 2
    }
    
    private var isAI: Bool {
        return illust.illustAIType == 2
    }

    var body: some View {
        if shouldHide {
            Color.clear.frame(height: 0)
        } else {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    CachedAsyncImage(urlString: ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.feedPreviewQuality))
                        .frame(width: imageWidth, height: imageHeight)
                        .clipped()
                        .blur(radius: shouldBlur ? 20 : 0)
                    
                    if userSettingStore.userSetting.feedAIBadge && isAI {
                        Text("AI")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    
                    if illust.pageCount > 1 {
                        Text("\(illust.pageCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                            .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(illust.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(illust.user.name)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Button(action: toggleBookmark) {
                            Image(systemName: illust.isBookmarked ? "heart.fill" : "heart")
                                .foregroundColor(illust.isBookmarked ? .red : .secondary)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .background(Color(white: 0.97))
            .cornerRadius(16)
            .shadow(radius: 2)
        }
    }
    
    private func toggleBookmark() {
        let isBookmarked = illust.isBookmarked
        let illustId = illust.id
        
        // 乐观更新 UI
        illust.isBookmarked.toggle()
        if isBookmarked {
            illust.totalBookmarks -= 1
        } else {
            illust.totalBookmarks += 1
        }
        
        Task {
            do {
                if isBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId)
                }
            } catch {
                // 失败回滚
                await MainActor.run {
                    illust.isBookmarked = isBookmarked
                    if isBookmarked {
                        illust.totalBookmarks += 1
                    } else {
                        illust.totalBookmarks -= 1
                    }
                }
            }
        }
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
