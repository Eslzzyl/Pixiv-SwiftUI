import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// 插画卡片组件
struct IllustCard: View, Equatable {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    @Environment(BookmarkActionService.self) private var bookmarkService
    @Environment(AccountStore.self) private var accountStore
    let illust: Illusts
    let columnCount: Int
    var columnWidth: CGFloat?
    var expiration: CacheExpiration?
    var showsBookmarkCount: Bool
    let feedPreviewQuality: Int
    let shouldBlur: Bool
    let accentColor: Color
    let seriesNumber: Int?

    /// Equatable：Illusts 是类，按 id 比较；expiration 非 Equatable，跳过（极少变化）。
    static func == (lhs: IllustCard, rhs: IllustCard) -> Bool {
        lhs.illust.id == rhs.illust.id &&
        lhs.columnCount == rhs.columnCount &&
        lhs.columnWidth == rhs.columnWidth &&
        lhs.showsBookmarkCount == rhs.showsBookmarkCount &&
        lhs.feedPreviewQuality == rhs.feedPreviewQuality &&
        lhs.shouldBlur == rhs.shouldBlur &&
        lhs.accentColor == rhs.accentColor &&
        lhs.seriesNumber == rhs.seriesNumber
    }

    init(
        illust: Illusts,
        columnCount: Int = 2,
        columnWidth: CGFloat? = nil,
        expiration: CacheExpiration? = nil,
        showsBookmarkCount: Bool = false,
        feedPreviewQuality: Int = 0,
        shouldBlur: Bool = false,
        accentColor: Color = .accentColor,
        seriesNumber: Int? = nil
    ) {
        self.illust = illust
        self.columnCount = columnCount
        self.columnWidth = columnWidth
        self.expiration = expiration
        self.showsBookmarkCount = showsBookmarkCount
        self.feedPreviewQuality = feedPreviewQuality
        self.shouldBlur = shouldBlur
        self.accentColor = accentColor
        self.seriesNumber = seriesNumber
    }

    private var isR18: Bool {
        return illust.xRestrict == 1
    }

    private var isR18G: Bool {
        return illust.xRestrict == 2
    }

    private var isSpoiler: Bool {
        return illust.isSpoiler
    }

    /// 获取收藏图标，根据收藏状态和类型返回不同的图标
    private var bookmarkIconName: String {
        if !illust.isBookmarked {
            return "heart"
        }
        return illust.bookmarkRestrict == "private" ? "heart.slash.fill" : "heart.fill"
    }

    private var isAI: Bool {
        return illust.illustAIType == 2
    }

    private var isUgoira: Bool {
        return illust.type == "ugoira"
    }

    private var isManga: Bool {
        return illust.type == "manga"
    }

    /// 条件化 blur：仅需要模糊时附加 blur 修饰符，避免 radius=0 时的无效渲染开销
    @ViewBuilder
    private var thumbnailImage: some View {
        // 给予显式 frame，确保 KFImage 在占位态和图片加载完成态之间
        // 容器尺寸完全一致，避免 LazyVStack 因内容尺寸变化而抖动
        let imageHeight = columnWidth.map { $0 / illust.safeAspectRatio }
        let image = CachedAsyncImage(
            urlString: ImageURLHelper.getImageURL(from: illust, quality: feedPreviewQuality),
            aspectRatio: illust.safeAspectRatio,
            idealWidth: columnWidth,
            expiration: expiration
        )
        .frame(width: columnWidth, height: imageHeight)
        .clipped()

        if shouldBlur {
            image.blur(radius: 20)
        } else {
            image
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                thumbnailImage
                    .clipped()

                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        if isManga {
                            Text("漫画").badgeStyle()
                        }

                        if isUgoira {
                            Text("动图").badgeStyle()
                        }

                        if isAI {
                            Text("AI").badgeStyle()
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                    if showsBookmarkCount {
                        Spacer(minLength: 0)

                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                            Text(NumberFormatter.formatCount(illust.totalBookmarks))
                        }
                        .badgeStyle()
                        .padding(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if illust.pageCount > 1 {
                    Text("\(illust.pageCount)")
                        .badgeStyle()
                        .padding(6)
                }
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    if let number = seriesNumber {
                        Text("#\(number) \(illust.title)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                    } else {
                        Text(illust.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .foregroundColor(.primary)
                    }

                    Text(illust.user.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if illust.isBookmarked {
                        Task { await bookmarkService.toggleBookmark(illust: illust, forceUnbookmark: true) }
                    } else {
                        Task { await bookmarkService.toggleBookmark(illust: illust, isPrivate: UserSettingStore.shared.userSetting.defaultPrivateLike) }
                    }
                } label: {
                    Image(systemName: bookmarkIconName)
                        .foregroundColor(illust.isBookmarked ? accentColor : .secondary)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .light), trigger: illust.isBookmarked)
            }
            .padding(8)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .frame(width: columnWidth)
        .cornerRadius(16)
        .background(
            CardShadowView(
                cornerRadius: 16,
                shadowColor: .black.opacity(0.2),
                shadowRadius: 2,
                shadowOffset: CGSize(width: 0, height: 2)
            )
        )
        .contextMenu {
            #if os(macOS)
            Button {
                openWindow(id: "illust-detail", value: illust.id)
            } label: {
                Label("在新窗口中打开", systemImage: "arrow.up.right.square")
            }

            Divider()
            #endif

            if illust.isBookmarked {
                if illust.bookmarkRestrict == "private" {
                    Button {
                        Task { await bookmarkService.toggleBookmark(illust: illust, isPrivate: false) }
                    } label: {
                        Label("切换为公开收藏", systemImage: "heart")
                    }
                } else {
                    Button {
                        Task { await bookmarkService.toggleBookmark(illust: illust, isPrivate: true) }
                    } label: {
                        Label("切换为非公开收藏", systemImage: "heart.slash")
                    }
                }
                Button(role: .destructive) {
                    Task { await bookmarkService.toggleBookmark(illust: illust, forceUnbookmark: true) }
                } label: {
                    Label("取消收藏", systemImage: "heart.slash")
                }
            } else {
                Button {
                    Task { await bookmarkService.toggleBookmark(illust: illust, isPrivate: false) }
                } label: {
                    Label("公开收藏", systemImage: "heart")
                }
                Button {
                    Task { await bookmarkService.toggleBookmark(illust: illust, isPrivate: true) }
                } label: {
                    Label("非公开收藏", systemImage: "heart.slash")
                }
            }

            Divider()

            Section("屏蔽") {
                Button(role: .destructive) {
                    try? UserSettingStore.shared.addBlockedIllustWithInfo(
                        illust.id,
                        title: illust.title,
                        authorId: illust.user.id.stringValue,
                        authorName: illust.user.name,
                        thumbnailUrl: illust.imageUrls.squareMedium
                    )
                } label: {
                    Label("屏蔽此作品", systemImage: "eye.slash")
                }

                Button(role: .destructive) {
                    try? UserSettingStore.shared.addBlockedUserWithInfo(
                        illust.user.id.stringValue,
                        name: illust.user.name,
                        account: illust.user.account,
                        avatarUrl: illust.user.profileImageUrls?.medium
                    )
                } label: {
                    Label("屏蔽此作者", systemImage: "person.slash")
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
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2, showsBookmarkCount: true)
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
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2, showsBookmarkCount: true)
        .padding()
        .frame(width: 390)
}
