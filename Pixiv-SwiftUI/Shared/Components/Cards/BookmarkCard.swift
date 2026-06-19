import SwiftUI
import os.log

/// 收藏卡片组件（支持显示已删除标记和缓存状态）
struct BookmarkCard: View, Equatable {
    #if os(macOS)
    @Environment(\.openWindow) var openWindow
    #endif
    let illust: Illusts
    let columnCount: Int
    var columnWidth: CGFloat?
    var expiration: CacheExpiration?
    var isDeleted: Bool = false
    var cacheStatus: BookmarkCacheStatus = .none
    let feedPreviewQuality: Int
    let shouldBlur: Bool
    let bookmarkCacheEnabled: Bool
    let accentColor: Color

    static func == (lhs: BookmarkCard, rhs: BookmarkCard) -> Bool {
        lhs.illust.id == rhs.illust.id &&
        lhs.columnCount == rhs.columnCount &&
        lhs.columnWidth == rhs.columnWidth &&
        lhs.isDeleted == rhs.isDeleted &&
        lhs.cacheStatus == rhs.cacheStatus &&
        lhs.feedPreviewQuality == rhs.feedPreviewQuality &&
        lhs.shouldBlur == rhs.shouldBlur &&
        lhs.bookmarkCacheEnabled == rhs.bookmarkCacheEnabled &&
        lhs.accentColor == rhs.accentColor
    }

    init(
        illust: Illusts,
        columnCount: Int = 2,
        columnWidth: CGFloat? = nil,
        expiration: CacheExpiration? = nil,
        isDeleted: Bool = false,
        cacheStatus: BookmarkCacheStatus = .none,
        feedPreviewQuality: Int = 0,
        shouldBlur: Bool = false,
        bookmarkCacheEnabled: Bool = true,
        accentColor: Color = .accentColor
    ) {
        self.illust = illust
        self.columnCount = columnCount
        self.columnWidth = columnWidth
        self.expiration = expiration
        self.isDeleted = isDeleted
        self.cacheStatus = cacheStatus
        self.feedPreviewQuality = feedPreviewQuality
        self.shouldBlur = shouldBlur
        self.bookmarkCacheEnabled = bookmarkCacheEnabled
        self.accentColor = accentColor
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

    private var displayImageURL: String? {
        if case .cached(let quality) = cacheStatus {
            switch quality {
            case .original:
                return illust.metaSinglePage?.originalImageUrl ?? illust.imageUrls.large
            case .large:
                return illust.imageUrls.large
            case .medium:
                return illust.imageUrls.medium
            }
        }
        return ImageURLHelper.getImageURL(from: illust, quality: feedPreviewQuality)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CachedAsyncImage(
                    urlString: displayImageURL,
                    aspectRatio: illust.safeAspectRatio,
                    idealWidth: columnWidth,
                    expiration: expiration,
                    targetCache: {
                        if case .cached = cacheStatus {
                            return BookmarkCacheService.shared.getCache()
                        }
                        return nil
                    }()
                )
                .clipped()
                .blur(radius: shouldBlur ? 20 : 0)

                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        if isDeleted {
                            Text("已删除")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red)
                                .cornerRadius(8)
                        }

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

                    Spacer(minLength: 0)

                    if cacheStatus != .none && bookmarkCacheEnabled {
                        HStack {
                            cacheStatusLabel
                            Spacer()
                        }
                        .padding(6)
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
                    Text(illust.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)

                    Text(illust.user.name)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if !isDeleted {
                    Button(action: {
                        if illust.isBookmarked {
                            toggleBookmark(forceUnbookmark: true)
                        } else {
                            toggleBookmark(isPrivate: UserSettingStore.shared.userSetting.defaultPrivateLike)
                        }
                    }) {
                        Image(systemName: bookmarkIconName)
                            .foregroundColor(illust.isBookmarked ? accentColor : .secondary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.impact(weight: .light), trigger: illust.isBookmarked)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDeleted ? Color.red : Color.clear, lineWidth: 2)
        )
        .background(
            CardShadowView(
                cornerRadius: 16,
                shadowColor: .black.opacity(0.2),
                shadowRadius: 2,
                shadowOffset: CGSize(width: 0, height: 2)
            )
        )
        .contextMenu {
            if !isDeleted {
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

    @ViewBuilder
    private var cacheStatusLabel: some View {
        switch cacheStatus {
        case .none:
            EmptyView()
        case .notCached:
            Text("未缓存")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .badgeStyle()
        case .cached(let quality):
            Text(quality.displayName)
                .badgeStyle()
        }
    }

    private func toggleBookmark(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        let wasBookmarked = illust.isBookmarked
        let illustId = illust.id
        let originalTotalBookmarks = illust.totalBookmarks
        let originalBookmarkRestrict = illust.bookmarkRestrict

        if forceUnbookmark && wasBookmarked {
            illust.isBookmarked = false
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else if wasBookmarked {
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        } else {
            illust.isBookmarked = true
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await PixivAPI.shared.bookmarkAPI.deleteBookmark(illustId: illustId)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        BookmarkCacheStore.shared.removeCache(
                            illustId: illustId,
                            ownerId: AccountStore.shared.currentUserId
                        )
                    }
                } else if wasBookmarked {
                    try await PixivAPI.shared.bookmarkAPI.deleteBookmark(illustId: illustId)
                    try await PixivAPI.shared.bookmarkAPI.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        BookmarkCacheStore.shared.addOrUpdateCache(
                            illust: illust,
                            ownerId: AccountStore.shared.currentUserId,
                            bookmarkRestrict: isPrivate ? "private" : "public"
                        )

                        if UserSettingStore.shared.userSetting.bookmarkAutoPreload {
                            let settings = UserSettingStore.shared.userSetting
                            let quality = BookmarkCacheQuality(rawValue: settings.bookmarkCacheQuality) ?? .large
                            let allPages = settings.bookmarkCacheAllPages
                            let urls = illust.getImageURLs(quality: quality, allPages: allPages)
                            do {
                                try await BookmarkCacheService.shared.preloadImages(urls: urls)
                                await MainActor.run {
                                    BookmarkCacheStore.shared.updatePreloadStatus(
                                        illustId: illustId,
                                        ownerId: AccountStore.shared.currentUserId,
                                        preloaded: true,
                                        quality: quality,
                                        allPages: allPages
                                    )
                                }
                            } catch {
                                Logger.cache.warning("预取图片失败: \(error)")
                            }
                        }
                    }
                } else {
                    try await PixivAPI.shared.bookmarkAPI.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    if UserSettingStore.shared.userSetting.bookmarkCacheEnabled {
                        BookmarkCacheStore.shared.addOrUpdateCache(
                            illust: illust,
                            ownerId: AccountStore.shared.currentUserId,
                            bookmarkRestrict: isPrivate ? "private" : "public"
                        )

                        if UserSettingStore.shared.userSetting.bookmarkAutoPreload {
                            let settings = UserSettingStore.shared.userSetting
                            let quality = BookmarkCacheQuality(rawValue: settings.bookmarkCacheQuality) ?? .large
                            let allPages = settings.bookmarkCacheAllPages
                            let urls = illust.getImageURLs(quality: quality, allPages: allPages)
                            do {
                                try await BookmarkCacheService.shared.preloadImages(urls: urls)
                                await MainActor.run {
                                    BookmarkCacheStore.shared.updatePreloadStatus(
                                        illustId: illustId,
                                        ownerId: AccountStore.shared.currentUserId,
                                        preloaded: true,
                                        quality: quality,
                                        allPages: allPages
                                    )
                                }
                            } catch {
                                Logger.cache.warning("预取图片失败: \(error)")
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    illust.isBookmarked = wasBookmarked
                    illust.totalBookmarks = originalTotalBookmarks
                    illust.bookmarkRestrict = originalBookmarkRestrict
                }
            }
        }
    }
}

/// 缓存状态枚举
enum BookmarkCacheStatus: Equatable {
    case none
    case notCached
    case cached(BookmarkCacheQuality)
}
