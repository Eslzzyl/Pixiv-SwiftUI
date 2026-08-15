import Foundation
import os.log

/// 统一的书签切换服务，供 IllustCard、IllustDetailInfoSection 等组件复用。
///
/// 通过 `@Environment` 注入，避免在纯展示组件中直接依赖 API/Cache 单例。
///
/// ```swift
/// @Environment(BookmarkActionService.self) var bookmarkService
/// Task { await bookmarkService.toggleBookmark(illust: illust, isPrivate: false) }
/// ```
@MainActor
@Observable
final class BookmarkActionService {
    static let shared = BookmarkActionService()

    @ObservationIgnored private let api: PixivAPI
    @ObservationIgnored private let authSession: AuthSessionProtocol
    @ObservationIgnored private let userSettingStore: UserSettingStore

    init(
        api: PixivAPI = .shared,
        authSession: AuthSessionProtocol = AccountStore.shared,
        userSettingStore: UserSettingStore = .shared
    ) {
        self.api = api
        self.authSession = authSession
        self.userSettingStore = userSettingStore
    }

    /// 切换插画书签状态（乐观更新 + API 调用 + 缓存同步 + 失败回滚）。
    ///
    /// - Parameters:
    ///   - illust: 要操作的插画对象（引用类型，乐观更新会直接修改其属性）。
    ///   - isPrivate: 是否设为非公开收藏。
    ///   - forceUnbookmark: 若为 `true` 且当前已收藏，则取消收藏。
    func toggleBookmark(
        illust: Illusts,
        isPrivate: Bool = false,
        forceUnbookmark: Bool = false
    ) async {
        let wasBookmarked = illust.isBookmarked
        let illustId = illust.id
        let originalTotalBookmarks = illust.totalBookmarks
        let originalBookmarkRestrict = illust.bookmarkRestrict
        let requestGeneration = authSession.accountGeneration
        let ownerId = authSession.currentUserId

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

        do {
            if forceUnbookmark && wasBookmarked {
                try await api.bookmarkAPI.deleteBookmark(illustId: illustId)
                guard authSession.isCurrentAccount(generation: requestGeneration, userId: ownerId) else { return }
                if userSettingStore.userSetting.bookmarkCacheEnabled {
                    BookmarkCacheStore.shared.removeCache(
                        illustId: illustId,
                        ownerId: ownerId
                    )
                }
            } else if wasBookmarked {
                try await api.bookmarkAPI.deleteBookmark(illustId: illustId)
                try await api.bookmarkAPI.addBookmark(illustId: illustId, isPrivate: isPrivate)
                guard authSession.isCurrentAccount(generation: requestGeneration, userId: ownerId) else { return }
                if userSettingStore.userSetting.bookmarkCacheEnabled {
                    BookmarkCacheStore.shared.addOrUpdateCache(
                        illust: illust,
                        ownerId: ownerId,
                        bookmarkRestrict: isPrivate ? "private" : "public"
                    )
                }
            } else {
                try await api.bookmarkAPI.addBookmark(illustId: illustId, isPrivate: isPrivate)
                guard authSession.isCurrentAccount(generation: requestGeneration, userId: ownerId) else { return }
                if userSettingStore.userSetting.bookmarkCacheEnabled {
                    BookmarkCacheStore.shared.addOrUpdateCache(
                        illust: illust,
                        ownerId: ownerId,
                        bookmarkRestrict: isPrivate ? "private" : "public"
                    )

                    if userSettingStore.userSetting.bookmarkAutoPreload {
                        let settings = userSettingStore.userSetting
                        let quality = BookmarkCacheQuality(rawValue: settings.bookmarkCacheQuality) ?? .large
                        let allPages = settings.bookmarkCacheAllPages
                        let urls = illust.getImageURLs(quality: quality, allPages: allPages)
                        try? await BookmarkCacheService.shared.preloadImages(urls: urls)
                        guard authSession.isCurrentAccount(generation: requestGeneration, userId: ownerId) else { return }
                        BookmarkCacheStore.shared.updatePreloadStatus(
                            illustId: illustId,
                            ownerId: ownerId,
                            preloaded: true,
                            quality: quality,
                            allPages: allPages
                        )
                    }
                }
            }
        } catch {
            guard authSession.isCurrentAccount(generation: requestGeneration, userId: ownerId) else { return }
            illust.isBookmarked = wasBookmarked
            illust.totalBookmarks = originalTotalBookmarks
            illust.bookmarkRestrict = originalBookmarkRestrict
        }
    }
}
