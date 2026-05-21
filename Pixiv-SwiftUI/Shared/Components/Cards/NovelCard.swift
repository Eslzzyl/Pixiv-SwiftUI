import SwiftUI

struct NovelCard: View {
    private enum Layout {
        static let contentWidth: CGFloat = 100
        static let cardWidth: CGFloat = 120
        static let imageSize: CGFloat = 100
    }

    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let novel: Novel

    @State private var isBookmarked: Bool = false

    init(novel: Novel) {
        self.novel = novel
        _isBookmarked = State(initialValue: novel.isBookmarked)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: Layout.imageSize, height: Layout.imageSize)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(novel.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2, reservesSpace: true)
                    .frame(width: Layout.contentWidth, alignment: .leading)
                    .multilineTextAlignment(.leading)

                Text(novel.user.name)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(width: Layout.contentWidth, alignment: .leading)

                HStack(spacing: 2) {
                    Text(formatTextLength(novel.textLength))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Image(systemName: isBookmarked ? "heart.fill" : "heart")
                        .foregroundColor(isBookmarked ? .red : .secondary)
                        .font(.system(size: 10))
                    Text(NumberFormatter.formatCount(novel.totalBookmarks))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(width: Layout.contentWidth)
            }
        }
        .frame(width: Layout.cardWidth)
        .contextMenu {
            #if os(macOS)
            Button {
                openWindow(id: "novel-detail", value: novel.id)
            } label: {
                Label("在新窗口中打开", systemImage: "arrow.up.right.square")
            }

            Divider()
            #endif

            if isBookmarked {
                if novel.bookmarkRestrict == "private" {
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
                    try? UserSettingStore.shared.addBlockedNovelWithInfo(
                        novel.id,
                        title: novel.title,
                        authorId: novel.user.id.stringValue,
                        authorName: novel.user.name,
                        thumbnailUrl: novel.imageUrls.squareMedium
                    )
                } label: {
                    Label("屏蔽此作品", systemImage: "eye.slash")
                }

                Button(role: .destructive) {
                    try? UserSettingStore.shared.addBlockedUserWithInfo(
                        novel.user.id.stringValue,
                        name: novel.user.name,
                        account: novel.user.account,
                        avatarUrl: novel.user.profileImageUrls?.medium
                    )
                } label: {
                    Label("屏蔽此作者", systemImage: "person.slash")
                }

                Menu {
                    ForEach(novel.tags, id: \.name) { tag in
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

    private func formatTextLength(_ length: Int) -> String {
        if length >= 10000 {
            return String(format: "%.1f万字", Double(length) / 10000)
        } else if length >= 1000 {
            return String(format: "%.1f千字", Double(length) / 1000)
        }
        return "\(length)字"
    }

    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        let wasBookmarked = isBookmarked
        let novelId = novel.id

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
        } else if wasBookmarked {
        } else {
            isBookmarked = true
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                } else if wasBookmarked {
                    try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                } else {
                    try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId, restrict: isPrivate ? "private" : "public")
                }
            } catch {
                await MainActor.run {
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                    } else if wasBookmarked {
                    } else {
                        isBookmarked = false
                    }
                }
            }
        }
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
        tags: [
            NovelTag(name: "原创", translatedName: nil, addedByUploadedUser: true),
            NovelTag(name: "ファンタジー", translatedName: "奇幻", addedByUploadedUser: true)
        ],
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
        novelAIType: 0
    )

    NovelCard(novel: novel)
        .frame(width: 120)
        .padding()
}
