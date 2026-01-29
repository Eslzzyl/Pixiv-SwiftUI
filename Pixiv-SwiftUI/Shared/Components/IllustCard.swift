import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// 插画卡片组件
struct IllustCard: View {
    @Environment(UserSettingStore.self) var userSettingStore
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let illust: Illusts
    let columnCount: Int
    var columnWidth: CGFloat?
    var expiration: CacheExpiration?

    @State private var isBookmarked: Bool = false

    init(illust: Illusts, columnCount: Int = 2, columnWidth: CGFloat? = nil, expiration: CacheExpiration? = nil) {
        self.illust = illust
        self.columnCount = columnCount
        self.columnWidth = columnWidth
        self.expiration = expiration
        _isBookmarked = State(initialValue: illust.isBookmarked)
    }

    private var isR18: Bool {
        return illust.xRestrict >= 1
    }

    private var shouldBlur: Bool {
        return isR18 && userSettingStore.userSetting.r18DisplayMode == 1
    }

    /// 获取收藏图标，根据收藏状态和类型返回不同的图标
    private var bookmarkIconName: String {
        if !isBookmarked {
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

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(
                    urlString: ImageURLHelper.getImageURL(from: illust, quality: userSettingStore.userSetting.feedPreviewQuality),
                    aspectRatio: illust.safeAspectRatio,
                    idealWidth: columnWidth,
                    expiration: expiration
                )
                .clipped()
                .blur(radius: shouldBlur ? 20 : 0)

                HStack(spacing: 4) {
                    if isManga {
                        Text("漫画")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    if isUgoira {
                        Text("动图")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }

                    if isAI {
                        Text("AI")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                if illust.pageCount > 1 {
                    Text("\(illust.pageCount)P")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
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
                        Image(systemName: bookmarkIconName)
                            .foregroundColor(isBookmarked ? .red : .secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
                }
            }
            .padding(8)
        }
        #if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor))
        #else
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        #endif
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
        #if os(macOS)
        .contextMenu {
            Button {
                openWindow(id: "illust-detail", value: illust.id)
            } label: {
                Label("在新窗口中打开", systemImage: "alternate.window.badge.plus")
            }
        }
        #endif
    }

    private func toggleBookmark() {
        let wasBookmarked = isBookmarked
        let illustId = illust.id

        isBookmarked.toggle()
        if wasBookmarked {
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else {
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = "public"
        }

        Task {
            do {
                if wasBookmarked {
                    try await PixivAPI.shared.deleteBookmark(illustId: illustId)
                } else {
                    try await PixivAPI.shared.addBookmark(illustId: illustId, isPrivate: false)
                }
            } catch {
                await MainActor.run {
                    isBookmarked = wasBookmarked
                    if wasBookmarked {
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = "public"
                    } else {
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
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
        bookmarkRestrict: nil,
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
        bookmarkRestrict: nil,
        visible: true,
        isMuted: false,
        illustAIType: 0
    )

    IllustCard(illust: illust, columnCount: 2)
        .padding()
        .frame(width: 390)
}
