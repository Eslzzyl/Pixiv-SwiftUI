import Foundation
import Kingfisher
import UniformTypeIdentifiers
import os.log

@MainActor
@Observable
final class IllustDetailViewModel {
    let illust: Illusts

    var isFollowed: Bool
    var isBookmarked: Bool
    var totalComments: Int?
    var isBlockTriggered = false
    var showDeleteConfirmation = false
    var isDeleting = false
    var isSaving = false
    var ugoiraStore: UgoiraStore?
    var detailFetched = false

    var relatedIllusts: [Illusts] = []
    var isLoadingRelated = false
    var isFetchingMoreRelated = false
    var relatedNextUrl: String?
    var hasMoreRelated = true
    var relatedIllustError: String?

    var shouldLoadRelated = false

    @ObservationIgnored private let accountStore: AccountStore
    @ObservationIgnored private let userSettingStore: UserSettingStore
    @ObservationIgnored private let cache: CacheStorageProtocol
    @ObservationIgnored private let api: PixivAPI
    @ObservationIgnored private var requestGeneration: UInt = 0

    /// Toast closure — set by the View after environment injection.
    @ObservationIgnored var showToast: ((String) -> Void)?

    init(
        illust: Illusts,
        accountStore: AccountStore = .shared,
        userSettingStore: UserSettingStore = .shared,
        cache: CacheStorageProtocol = CacheManager.shared,
        api: PixivAPI = .shared
    ) {
        self.illust = illust
        self.accountStore = accountStore
        self.userSettingStore = userSettingStore
        self.cache = cache
        self.api = api
        self.isFollowed = illust.user.isFollowed ?? false
        self.isBookmarked = illust.isBookmarked
        self.totalComments = illust.totalComments
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetForAccountChange()
            }
        }
    }

    // MARK: - Computed Properties

    var isMultiPage: Bool {
        illust.pageCount > 1 || !illust.metaPages.isEmpty
    }

    var isUgoira: Bool {
        illust.type == "ugoira"
    }

    var isManga: Bool {
        illust.type == "manga"
    }

    var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var isOwnIllust: Bool {
        illust.user.id.stringValue == accountStore.currentUserId
    }

    var detailImageQuality: Int {
        isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
    }

    var zoomImageURLs: [String] {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.zoomQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    var zoomImageAspectRatios: [CGFloat] {
        if !illust.metaPages.isEmpty {
            return Array(repeating: illust.safeAspectRatio, count: illust.metaPages.count)
        }
        return [illust.safeAspectRatio]
    }

    var detailImageURLs: [String] {
        let quality = isManga ? userSettingStore.userSetting.mangaQuality : userSettingStore.userSetting.pictureQuality
        if !illust.metaPages.isEmpty {
            return illust.metaPages.indices.compactMap { index in
                ImageURLHelper.getPageImageURL(from: illust, page: index, quality: quality)
            }
        }
        return [ImageURLHelper.getImageURL(from: illust, quality: quality)]
    }

    // MARK: - Detail Fetching

    func fetchDetailIfNeeded() {
        guard !detailFetched else { return }
        detailFetched = true
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = accountStore.accountGeneration

        let cacheKey = CacheManager.illustDetailKey(illustId: illust.id)
        if let cached: Illusts = cache.get(forKey: cacheKey), let comments = cached.totalComments, comments > 0 {
            totalComments = comments
        }

        preloadAllImages()

        Task {
            do {
                let detail = try await api.illustAPI.getIllustDetail(illustId: illust.id)
                await MainActor.run {
                    guard self.isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration) else { return }
                    if let comments = detail.totalComments {
                        self.totalComments = comments
                    }
                    self.isBookmarked = detail.isBookmarked
                    self.illust.isBookmarked = detail.isBookmarked
                    self.illust.bookmarkRestrict = detail.bookmarkRestrict
                    self.isFollowed = detail.user.isFollowed ?? false
                    self.illust.user.isFollowed = detail.user.isFollowed
                    illust.metaPages = detail.metaPages
                    illust.metaSinglePage = detail.metaSinglePage
                    illust.caption = detail.caption
                }
                preloadAllImages()
            } catch {
                Logger.illust.debug("[fetchDetail] FAILED: \(error)")
            }
        }
    }

    // MARK: - Bookmark

    func bookmarkIllust(isPrivate: Bool = false, forceUnbookmark: Bool = false) {
        guard isLoggedIn else {
            showToast?(String(localized: "请先登录"))
            return
        }

        let wasBookmarked = isBookmarked
        let illustId = illust.id
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = accountStore.accountGeneration
        let ownerId = accountStore.currentUserId

        if forceUnbookmark && wasBookmarked {
            isBookmarked = false
            illust.isBookmarked = false
            illust.totalBookmarks -= 1
            illust.bookmarkRestrict = nil
        } else if wasBookmarked {
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        } else {
            isBookmarked = true
            illust.isBookmarked = true
            illust.totalBookmarks += 1
            illust.bookmarkRestrict = isPrivate ? "private" : "public"
        }

        Task {
            do {
                if forceUnbookmark && wasBookmarked {
                    try await api.bookmarkAPI.deleteBookmark(illustId: illustId)
                    await syncBookmarkCacheRemoval(illustId: illustId, ownerId: ownerId)
                } else if wasBookmarked {
                    try await api.bookmarkAPI.deleteBookmark(illustId: illustId)
                    try await api.bookmarkAPI.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    await syncBookmarkCacheUpdate(restrict: isPrivate ? "private" : "public", ownerId: ownerId)
                } else {
                    try await api.bookmarkAPI.addBookmark(illustId: illustId, isPrivate: isPrivate)
                    await syncBookmarkCacheAdd(restrict: isPrivate ? "private" : "public", ownerId: ownerId)
                }
            } catch {
                await MainActor.run {
                    guard self.isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration) else { return }
                    if forceUnbookmark && wasBookmarked {
                        isBookmarked = true
                        illust.isBookmarked = true
                        illust.totalBookmarks += 1
                        illust.bookmarkRestrict = isPrivate ? "private" : "public"
                    } else if wasBookmarked {
                        illust.bookmarkRestrict = isPrivate ? "public" : "private"
                    } else {
                        isBookmarked = false
                        illust.isBookmarked = false
                        illust.totalBookmarks -= 1
                        illust.bookmarkRestrict = nil
                    }
                }
            }
        }
    }

    // MARK: - Delete

    func deleteIllust() async {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        do {
            let type = isManga ? "manga" : "illust"
            try await api.illustAPI.deleteIllust(illustId: illust.id, type: type)
            await MainActor.run {
                self.showToast?(String(localized: "作品已删除"))
            }
        } catch {
            await MainActor.run {
                self.showToast?(String(localized: "删除失败"))
            }
        }
    }

    // MARK: - Image Preloading

    func preloadAllImages() {
        guard isMultiPage else { return }

        Task {
            await withTaskGroup(of: Void.self) { group in
                let urls: [String]
                if !illust.metaPages.isEmpty {
                    urls = illust.metaPages.indices.compactMap { index in
                        ImageURLHelper.getPageImageURL(from: illust, page: index, quality: detailImageQuality)
                    }
                } else {
                    urls = [ImageURLHelper.getImageURL(from: illust, quality: detailImageQuality)]
                }

                for urlString in urls {
                    group.addTask {
                        await self.preloadImage(urlString: urlString)
                    }
                }
            }
        }
    }

    func preloadImage(urlString: String) async {
        guard let url = URL(string: urlString) else { return }

        let source: Source
        if shouldUseDirectConnection(url: url) {
            source = .directNetwork(url)
        } else {
            source = .network(url)
        }

        let options: KingfisherOptionsInfo = [
            .requestModifier(PixivImageLoader.shared),
            .cacheOriginalImage
        ]

        _ = try? await KingfisherManager.shared.retrieveImage(with: source, options: options)
    }

    // MARK: - Save (iOS)

    func saveIllust() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if isUgoira {
            await saveUgoira()
        } else {
            let quality = userSettingStore.userSetting.downloadQuality
            await DownloadStore.shared.addTask(illust, quality: quality)
        }
        showToast?(String(localized: "已添加到下载队列"))
    }

    func saveUgoira() async {
        Logger.illust.debug("开始保存动图: \(self.illust.id)")
        await DownloadStore.shared.addUgoiraTask(illust)
    }

    // MARK: - Save (macOS)

    func performSave(to url: URL) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }

        if isUgoira {
            await DownloadStore.shared.addUgoiraTask(illust, customSaveURL: url)
        } else {
            let quality = userSettingStore.userSetting.downloadQuality
            await DownloadStore.shared.addTask(illust, quality: quality, customSaveURL: url)
        }
        showToast?(String(localized: "已添加到下载队列"))
    }

    func isMultiPageSave() -> Bool {
        !isUgoira && illust.pageCount > 1
    }

    func saveFilename(quality: Int) -> String {
        let safeTitle = ImageSaver.sanitizeFilename(illust.title)
        let safeAuthor = ImageSaver.sanitizeFilename(illust.user.name)
        let firstUrl = ImageURLHelper.getImageURL(from: illust, quality: quality)
        let ext = (firstUrl as NSString).pathExtension.lowercased()

        if ext == "png" {
            return "\(safeAuthor)_\(safeTitle).png"
        } else {
            return "\(safeAuthor)_\(safeTitle).jpg"
        }
    }

    func saveAllowedTypes(quality: Int) -> [UTType] {
        let firstUrl = ImageURLHelper.getImageURL(from: illust, quality: quality)
        let ext = (firstUrl as NSString).pathExtension.lowercased()
        return ext == "png" ? [.png, .jpeg] : [.jpeg, .png]
    }

    // MARK: - Network

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection &&
               (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    // MARK: - Bookmark Cache Sync

    private func syncBookmarkCacheUpdate(restrict: String, ownerId: String) async {
        guard userSettingStore.userSetting.bookmarkCacheEnabled else { return }
        await MainActor.run {
            BookmarkCacheStore.shared.addOrUpdateCache(
                illust: illust,
                ownerId: ownerId,
                bookmarkRestrict: restrict
            )
        }
    }

    private func syncBookmarkCacheRemoval(illustId: Int, ownerId: String) async {
        guard userSettingStore.userSetting.bookmarkCacheEnabled else { return }
        await MainActor.run {
            BookmarkCacheStore.shared.removeCache(
                illustId: illustId,
                ownerId: ownerId
            )
        }
    }

    private func syncBookmarkCacheAdd(restrict: String, ownerId: String) async {
        guard userSettingStore.userSetting.bookmarkCacheEnabled else { return }
        await MainActor.run {
            BookmarkCacheStore.shared.addOrUpdateCache(
                illust: illust,
                ownerId: ownerId,
                bookmarkRestrict: restrict
            )
        }

        if userSettingStore.userSetting.bookmarkAutoPreload {
            let settings = userSettingStore.userSetting
            let quality = BookmarkCacheQuality(rawValue: settings.bookmarkCacheQuality) ?? .large
            let allPages = settings.bookmarkCacheAllPages
            let urls = illust.getImageURLs(quality: quality, allPages: allPages)
            try? await BookmarkCacheService.shared.preloadImages(urls: urls)
            await MainActor.run {
                BookmarkCacheStore.shared.updatePreloadStatus(
                    illustId: illust.id,
                    ownerId: ownerId,
                    preloaded: true,
                    quality: quality,
                    allPages: allPages
                )
            }
        }
    }

    private func resetForAccountChange() {
        requestGeneration &+= 1
        detailFetched = false
        relatedIllusts = []
        relatedNextUrl = nil
        hasMoreRelated = true
        relatedIllustError = nil
        isBookmarked = false
        isFollowed = false
        if accountStore.isLoggedIn {
            fetchDetailIfNeeded()
        }
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt) -> Bool {
        self.requestGeneration == generation && accountStore.accountGeneration == accountGeneration
    }
}
