import SwiftUI

struct NovelSeriesCard: View {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let novel: Novel
    let index: Int

    @State private var isBookmarked: Bool = false

    init(novel: Novel, index: Int) {
        self.novel = novel
        self.index = index
        _isBookmarked = State(initialValue: novel.isBookmarked)
    }

    var body: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(
                urlString: novel.imageUrls.medium,
                expiration: DefaultCacheExpiration.novel
            )
            .frame(width: 80, height: 80)
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text("#\(index + 1) \(novel.title)")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(novel.user.name)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Text(formatTextLength(novel.textLength))
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 4) {
                        Image(systemName: isBookmarked ? "heart.fill" : "heart")
                            .font(.caption2)
                            .foregroundColor(isBookmarked ? .red : .secondary)
                        Text(NumberFormatter.formatCount(novel.totalBookmarks))
                            .font(.caption)
                    }

                    Spacer()
                }
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
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
    VStack(spacing: 8) {
        NovelSeriesCard(
            novel: Novel(
                id: 123,
                title: "测试小说标题",
                caption: "测试简介",
                restrict: 0,
                xRestrict: 0,
                isOriginal: true,
                imageUrls: ImageUrls(
                    squareMedium: "",
                    medium: "",
                    large: ""
                ),
                createDate: "2023-12-15T00:00:00+09:00",
                tags: [],
                pageCount: 1,
                textLength: 15000,
                user: User(
                    profileImageUrls: ProfileImageUrls(px50x50: ""),
                    id: StringIntValue.string("1"),
                    name: "测试作者",
                    account: "test"
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
            ),
            index: 1
        )

        NovelSeriesCard(
            novel: Novel(
                id: 124,
                title: "测试小说标题比较长比较长比较长比较长比较长比较长",
                caption: "测试简介",
                restrict: 0,
                xRestrict: 0,
                isOriginal: true,
                imageUrls: ImageUrls(
                    squareMedium: "",
                    medium: "",
                    large: ""
                ),
                createDate: "2023-12-15T00:00:00+09:00",
                tags: [],
                pageCount: 1,
                textLength: 15000,
                user: User(
                    profileImageUrls: ProfileImageUrls(px50x50: ""),
                    id: StringIntValue.string("1"),
                    name: "测试作者",
                    account: "test"
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
            ),
            index: 2
        )
    }
    .padding()
}
