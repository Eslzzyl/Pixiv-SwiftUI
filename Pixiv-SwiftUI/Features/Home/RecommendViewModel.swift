import Foundation
import os.log

@MainActor
@Observable
final class RecommendViewModel {
    var illusts: [Illusts] = []
    var filteredIllusts: [Illusts] = []
    var shouldBlurMap: [Int: Bool] = [:]
    var isLoading = true
    var nextUrl: String?
    var hasMoreData = true
    var error: String?
    var contentType: TypeFilterButton.ContentType = .illust

    let recommendedUsersStore = RecommendedUsersStore()
    let searchStore = SearchStore.shared

    var showToast: ((String) -> Void)?

    @ObservationIgnored private let cache: CacheStorageProtocol
    @ObservationIgnored private let settingStore: UserSettingStore
    @ObservationIgnored private let accountStore: AccountStore
    @ObservationIgnored private let expiration: CacheExpiration = .minutes(5)
    @ObservationIgnored private var requestGeneration: UInt = 0

    init(
        settingStore: UserSettingStore = .shared,
        accountStore: AccountStore = .shared,
        cache: CacheStorageProtocol = CacheManager.shared
    ) {
        self.settingStore = settingStore
        self.accountStore = accountStore
        self.cache = cache
    }

    // MARK: - Computed

    var isLoggedIn: Bool {
        accountStore.isLoggedIn
    }

    var cacheKey: String {
        let typeSuffix = contentType == .manga ? "_manga" : "_illust"
        return isLoggedIn ? "recommend\(typeSuffix)_0" : "walkthrough\(typeSuffix)_0"
    }

    // MARK: - Filtered Results

    func recalculateFilteredIllusts() {
        let base = settingStore.filterIllusts(illusts)
        switch contentType {
        case .all, .manga:
            filteredIllusts = base
        case .illust:
            filteredIllusts = base.filter { $0.type != "manga" }
        }
        shouldBlurMap = Dictionary(
            uniqueKeysWithValues: filteredIllusts.map {
                ($0.id, settingStore.userSetting.shouldBlurIllust($0))
            }
        )
    }

    func shouldBlur(for illust: Illusts) -> Bool {
        shouldBlurMap[illust.id] ?? false
    }

    // MARK: - Cache

    func loadCachedData() {
        error = nil
        if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
            illusts = cached.0
            recalculateFilteredIllusts()
            nextUrl = cached.1
            hasMoreData = cached.1 != nil
            isLoading = false
        } else {
            isLoading = true
        }
    }

    // MARK: - Refresh

    func refreshAll() async {
        if isLoggedIn {
            async let illustsTask = refreshIllusts()
            async let usersTask = recommendedUsersStore.refreshUsers()
            async let tagsTask: Void = accountStore.isWebLoggedIn ? searchStore.fetchRecommendedTags(forceRefresh: true) : ()
            _ = await (illustsTask, usersTask, tagsTask)
        } else {
            _ = await refreshIllusts()
        }
    }

    func refreshIllusts(forceRefresh: Bool = false) async {
        let requestGeneration = accountStore.accountGeneration
        let requestUserId = accountStore.currentUserId
        let requestIsLoggedIn = accountStore.isLoggedIn
        let requestContentType = contentType
        let requestCacheKey = requestIsLoggedIn
            ? "recommend\(requestContentType == .manga ? "_manga" : "_illust")_0"
            : "walkthrough\(requestContentType == .manga ? "_manga" : "_illust")_0"

        self.requestGeneration = requestGeneration
        error = nil
        isLoading = true

        do {
            let result: (illusts: [Illusts], nextUrl: String?)

            if !forceRefresh, let cached: ([Illusts], String?) = cache.get(forKey: requestCacheKey) {
                result = cached
            } else {
                if requestContentType == .manga {
                    if requestIsLoggedIn {
                        result = try await PixivAPI.shared.mangaAPI.getRecommendedManga()
                    } else {
                        result = try await PixivAPI.shared.mangaAPI.getRecommendedMangaNoLogin()
                    }
                } else {
                    if requestIsLoggedIn {
                        result = try await PixivAPI.shared.illustAPI.getRecommendedIllusts()
                    } else {
                        result = try await WalkthroughAPI().getWalkthroughIllusts()
                    }
                }
            }

            await MainActor.run {
                guard self.isCurrentRequest(
                    generation: requestGeneration,
                    userId: requestUserId,
                    isLoggedIn: requestIsLoggedIn,
                    contentType: requestContentType
                ) else { return }

                illusts = result.illusts
                recalculateFilteredIllusts()
                nextUrl = result.nextUrl
                hasMoreData = result.nextUrl != nil
                isLoading = false

                cache.set((illusts, result.nextUrl), forKey: requestCacheKey, expiration: expiration)
                ImageURLHelper.prefetchImages(from: illusts, quality: settingStore.userSetting.feedPreviewQuality, offset: 6)
            }
        } catch {
            await MainActor.run {
                guard self.isCurrentRequest(
                    generation: requestGeneration,
                    userId: requestUserId,
                    isLoggedIn: requestIsLoggedIn,
                    contentType: requestContentType
                ) else { return }

                self.error = "刷新失败: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Load More

    func loadMoreData() {
        guard !isLoading, hasMoreData else { return }

        let requestGeneration = accountStore.accountGeneration
        let requestUserId = accountStore.currentUserId
        let requestIsLoggedIn = accountStore.isLoggedIn
        let requestContentType = contentType
        let requestCacheKey = cacheKey

        isLoading = true
        error = nil

        Task {
            do {
                let result: (illusts: [Illusts], nextUrl: String?)
                if let next = nextUrl {
                    if requestIsLoggedIn {
                        result = try await PixivAPI.shared.illustAPI.getIllustsByURL(next)
                    } else {
                        result = try await WalkthroughAPI().getWalkthroughIllustsByURL(next)
                    }
                } else {
                    if requestContentType == .manga {
                        if requestIsLoggedIn {
                            result = try await PixivAPI.shared.mangaAPI.getRecommendedManga()
                        } else {
                            result = try await PixivAPI.shared.mangaAPI.getRecommendedMangaNoLogin()
                        }
                    } else {
                        if requestIsLoggedIn {
                            result = try await PixivAPI.shared.illustAPI.getRecommendedIllusts()
                        } else {
                            result = try await WalkthroughAPI().getWalkthroughIllusts()
                        }
                    }
                }

                await MainActor.run {
                    guard self.isCurrentRequest(
                        generation: requestGeneration,
                        userId: requestUserId,
                        isLoggedIn: requestIsLoggedIn,
                        contentType: requestContentType
                    ) else { return }

                    let newIllusts = result.illusts.filter { new in
                        !illusts.contains(where: { $0.id == new.id })
                    }
                    illusts.append(contentsOf: newIllusts)
                    recalculateFilteredIllusts()
                    nextUrl = result.nextUrl
                    hasMoreData = result.nextUrl != nil
                    isLoading = false

                    if nextUrl == nil {
                        cache.set((illusts, result.nextUrl), forKey: requestCacheKey, expiration: expiration)
                    }
                }
            } catch {
                await MainActor.run {
                    guard self.isCurrentRequest(
                        generation: requestGeneration,
                        userId: requestUserId,
                        isLoggedIn: requestIsLoggedIn,
                        contentType: requestContentType
                    ) else { return }

                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    func resetForAccountChange() {
        requestGeneration = accountStore.accountGeneration
        illusts = []
        filteredIllusts = []
        shouldBlurMap = [:]
        nextUrl = nil
        hasMoreData = true
        isLoading = true
        error = nil
        recommendedUsersStore.users = []
        recommendedUsersStore.nextUrl = nil
        recommendedUsersStore.error = nil
        recommendedUsersStore.isLoading = true
        searchStore.clearMemoryCache()
    }

    private func isCurrentRequest(
        generation: UInt,
        userId: String,
        isLoggedIn: Bool,
        contentType: TypeFilterButton.ContentType
    ) -> Bool {
        requestGeneration == generation &&
            accountStore.accountGeneration == generation &&
            accountStore.currentUserId == userId &&
            accountStore.isLoggedIn == isLoggedIn &&
            self.contentType == contentType
    }
}
