import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

/// 相关推荐插画卡片（简化版）
struct RelatedIllustCard: View, Equatable {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let illust: Illusts
    let showTitle: Bool
    let columnWidth: CGFloat?
    let onTap: (() -> Void)?
    let feedPreviewQuality: Int
    let shouldBlur: Bool
    let shouldHide: Bool

    static func == (lhs: RelatedIllustCard, rhs: RelatedIllustCard) -> Bool {
        lhs.illust.id == rhs.illust.id &&
        lhs.showTitle == rhs.showTitle &&
        lhs.columnWidth == rhs.columnWidth &&
        lhs.feedPreviewQuality == rhs.feedPreviewQuality &&
        lhs.shouldBlur == rhs.shouldBlur &&
        lhs.shouldHide == rhs.shouldHide
    }

    init(
        illust: Illusts,
        showTitle: Bool = true,
        columnWidth: CGFloat? = nil,
        onTap: (() -> Void)? = nil,
        feedPreviewQuality: Int = 0,
        shouldBlur: Bool = false,
        shouldHide: Bool = false
    ) {
        self.illust = illust
        self.showTitle = showTitle
        self.columnWidth = columnWidth
        self.onTap = onTap
        self.feedPreviewQuality = feedPreviewQuality
        self.shouldBlur = shouldBlur
        self.shouldHide = shouldHide
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

    private var isUgoira: Bool {
        return illust.type == "ugoira"
    }

    private var isAI: Bool {
        return illust.illustAIType == 2
    }

    private var isManga: Bool {
        return illust.type == "manga"
    }

    var body: some View {
        if shouldHide {
            Color.clear.frame(height: 0)
        } else {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    if let onTap = onTap {
                        CachedAsyncImage(
                            urlString: ImageURLHelper.getImageURL(from: illust, quality: feedPreviewQuality),
                            aspectRatio: illust.safeAspectRatio,
                            idealWidth: columnWidth
                        )
                        .clipped()
                        .blur(radius: shouldBlur ? 20 : 0)
                        .onTapGesture(perform: onTap)
                    } else {
                        CachedAsyncImage(
                            urlString: ImageURLHelper.getImageURL(from: illust, quality: feedPreviewQuality),
                            aspectRatio: illust.safeAspectRatio,
                            idealWidth: columnWidth
                        )
                        .clipped()
                        .blur(radius: shouldBlur ? 20 : 0)
                    }

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

                    if illust.pageCount > 1 {
                        Text("\(illust.pageCount)")
                            .badgeStyle()
                            .padding(6)
                    }
                }

                if showTitle {
                    Text(illust.title)
                        .font(.caption)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
            }
            #if os(macOS)
            .background(Color(nsColor: .controlBackgroundColor))
            #else
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            #endif
            .frame(width: columnWidth)
            .cornerRadius(12)
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
                            toggleBookmark(isPrivate: false)
                        } label: {
                            Label("切换为公开收藏", systemImage: "heart")
                        }
                    } else {
                        Button {
                            toggleBookmark(isPrivate: true)
                        } label: {
                            Label("切换为非公开收藏", systemImage: "heart.slash")
                        }
                    }
                    Button(role: .destructive) {
                        toggleBookmark(forceUnbookmark: true)
                    } label: {
                        Label("取消收藏", systemImage: "heart.slash")
                    }
                } else {
                    Button {
                        toggleBookmark(isPrivate: false)
                    } label: {
                        Label("公开收藏", systemImage: "heart")
                    }
                    Button {
                        toggleBookmark(isPrivate: true)
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

                    Menu {
                        ForEach(illust.tags, id: \.name) { tag in
                            Button {
                                try? UserSettingStore.shared.addBlockedTagWithInfo(tag.name, translatedName: tag.translatedName)
                            } label: {
                                Text(tag.translatedName ?? tag.name)
                            }
                        }
                    } label: {
                        Label("屏蔽此标签", systemImage: "tag.slash")
                    }
                }
            }
        }
    }

    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        Task {
            await BookmarkActionService.shared.toggleBookmark(
                illust: illust,
                isPrivate: isPrivate,
                forceUnbookmark: forceUnbookmark
            )
        }
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
        caption: "示例作品",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16: "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px170x170: "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
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

    RelatedIllustCard(illust: illust)
        .padding()
        .frame(width: 120)
        .environment(UserSettingStore())
}

#Preview("多页") {
    let illust = Illusts(
        id: 124,
        title: "多页示例",
        type: "illust",
        imageUrls: ImageUrls(
            squareMedium: "https://i.pximg.net/c/160x160_90_a2_g5.jpg/img-master/d/2023/12/15/12/34/56/999999_p0_square1200.jpg",
            medium: "https://i.pximg.net/c/540x540_90/img-master/d/2023/12/15/12/34/56/999999_p0.jpg",
            large: "https://i.pximg.net/img-master/d/2023/12/15/12/34/56/999999_p0_master1200.jpg"
        ),
        caption: "",
        restrict: 0,
        user: User(
            profileImageUrls: ProfileImageUrls(
                px16x16: "https://i.pximg.net/c/16x16/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px50x50: "https://i.pximg.net/c/50x50/profile/img/2024/01/01/00/00/00/123456_p0.jpg",
                px170x170: "https://i.pximg.net/c/170x170/profile/img/2024/01/01/00/00/00/123456_p0.jpg"
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

    RelatedIllustCard(illust: illust)
        .padding()
        .frame(width: 120)
        .environment(UserSettingStore())
}
