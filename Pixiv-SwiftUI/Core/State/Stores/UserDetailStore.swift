import Foundation
import SwiftUI
import Observation
import os.log

@MainActor
@Observable
final class UserDetailStore {
    var userDetail: UserDetailResponse?
    var illusts: [Illusts] = []
    var mangas: [Illusts] = []
    var bookmarks: [Illusts] = []
    var novels: [Novel] = []

    var isLoadingDetail: Bool = false
    var isLoadingIllusts: Bool = false
    var isLoadingMangas: Bool = false
    var isLoadingBookmarks: Bool = false
    var isLoadingNovels: Bool = false
    var isLoadingMoreIllusts: Bool = false
    var isLoadingMoreMangas: Bool = false
    var isLoadingMoreBookmarks: Bool = false
    var isLoadingMoreNovels: Bool = false

    var error: AppError?

    var isIllustsReachedEnd: Bool {
        !illusts.isEmpty && nextIllustsUrl == nil && !isLoadingMoreIllusts
    }

    var isMangasReachedEnd: Bool {
        !mangas.isEmpty && nextMangasUrl == nil && !isLoadingMoreMangas
    }

    var isBookmarksReachedEnd: Bool {
        !bookmarks.isEmpty && nextBookmarksUrl == nil && !isLoadingMoreBookmarks
    }

    var isNovelsReachedEnd: Bool {
        !novels.isEmpty && nextNovelsUrl == nil && !isLoadingMoreNovels
    }

    private var nextIllustsUrl: String?
    private var nextMangasUrl: String?
    private var nextBookmarksUrl: String?
    private var nextNovelsUrl: String?
    private let pageSize = 30

    private let userId: String
    private let authSession: AuthSessionProtocol
    private let api = PixivAPI.shared
    private let cache: CacheStorageProtocol = CacheManager.shared
    private var requestGeneration: UInt = 0

    private let expiration: CacheExpiration = .minutes(5)

    init(userId: String, authSession: AuthSessionProtocol = AccountStore.shared) {
        self.userId = userId
        self.authSession = authSession
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.invalidateForAccountChange()
            }
        }
    }

    @MainActor
    func fetchAll(forceRefresh: Bool = false) async {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        let cacheKey = CacheManager.userDetailDataKey(userId: userId, ownerId: requestUserId)
        let detailCacheKey = CacheManager.userDetailKey(userId: userId, ownerId: requestUserId)

        guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }

        if !forceRefresh, let cached: CachedUserDetailData = cache.get(forKey: cacheKey) {
            self.userDetail = cached.detail
            self.illusts = cached.illusts
            self.mangas = cached.mangas
            self.bookmarks = cached.bookmarks
            self.novels = cached.novels
            self.nextIllustsUrl = cached.nextIllustsUrl
            self.nextMangasUrl = cached.nextMangasUrl
            self.nextBookmarksUrl = cached.nextBookmarksUrl
            self.nextNovelsUrl = cached.nextNovelsUrl
            return
        }

        isLoadingDetail = true
        isLoadingIllusts = true
        isLoadingMangas = true
        isLoadingBookmarks = true
        isLoadingNovels = true
        error = nil

        do {
            let fetchedDetail = try await api.userAPI.getUserDetail(userId: userId)
            let fetchedIllusts = try await api.userAPI.getUserIllusts(userId: userId, type: "illust")
            let fetchedMangas = try await api.userAPI.getUserIllusts(userId: userId, type: "manga")
            let fetchedBookmarksResult = try await api.userAPI.getUserBookmarksIllusts(userId: userId)
            let fetchedNovelsResult = try await api.userAPI.getUserNovels(userId: userId)

            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }

            self.userDetail = fetchedDetail
            self.illusts = fetchedIllusts.0
            self.nextIllustsUrl = fetchedIllusts.1
            self.mangas = fetchedMangas.0
            self.nextMangasUrl = fetchedMangas.1
            self.bookmarks = fetchedBookmarksResult.0
            self.nextBookmarksUrl = fetchedBookmarksResult.1
            self.novels = fetchedNovelsResult.0
            self.nextNovelsUrl = fetchedNovelsResult.1

            let cachedData = CachedUserDetailData(
                detail: fetchedDetail,
                illusts: self.illusts,
                mangas: self.mangas,
                bookmarks: self.bookmarks,
                novels: self.novels,
                nextIllustsUrl: self.nextIllustsUrl,
                nextMangasUrl: self.nextMangasUrl,
                nextBookmarksUrl: self.nextBookmarksUrl,
                nextNovelsUrl: self.nextNovelsUrl,
                timestamp: Date()
            )
            cache.set(cachedData, forKey: cacheKey, expiration: expiration)
            cache.set(fetchedDetail, forKey: detailCacheKey, expiration: expiration)
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.user.error("Error fetching user detail: \(error.localizedDescription, privacy: .public)")
        }

        if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
            isLoadingDetail = false
            isLoadingIllusts = false
            isLoadingMangas = false
            isLoadingBookmarks = false
            isLoadingNovels = false
        }
    }

    @MainActor
    func loadMoreIllusts() async {
        guard let nextUrl = nextIllustsUrl, !isLoadingMoreIllusts else { return }

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        isLoadingMoreIllusts = true

        do {
            let (newIllusts, nextUrl) = try await api.userAPI.loadMoreIllusts(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.illusts.append(contentsOf: newIllusts)
            self.nextIllustsUrl = nextUrl
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.user.error("Error loading more illusts: \(error.localizedDescription, privacy: .public)")
        }

        isLoadingMoreIllusts = false
    }

    @MainActor
    func loadMoreMangas() async {
        guard let nextUrl = nextMangasUrl, !isLoadingMoreMangas else { return }

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        isLoadingMoreMangas = true

        do {
            let (newMangas, nextUrl) = try await api.userAPI.loadMoreIllusts(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.mangas.append(contentsOf: newMangas)
            self.nextMangasUrl = nextUrl
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.user.error("Error loading more mangas: \(error.localizedDescription, privacy: .public)")
        }

        isLoadingMoreMangas = false
    }

    @MainActor
    func loadMoreBookmarks() async {
        guard let nextUrl = nextBookmarksUrl, !isLoadingMoreBookmarks else { return }

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        isLoadingMoreBookmarks = true

        do {
            let response: IllustsResponseDTO = try await api.fetchNext(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.bookmarks.append(contentsOf: response.illusts.map { $0.toDomain() })
            self.nextBookmarksUrl = response.nextUrl
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.user.error("Error loading more bookmarks: \(error.localizedDescription, privacy: .public)")
        }

        isLoadingMoreBookmarks = false
    }

    @MainActor
    func loadMoreNovels() async {
        guard let nextUrl = nextNovelsUrl, !isLoadingMoreNovels else { return }

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        isLoadingMoreNovels = true

        do {
            let (newNovels, nextUrl) = try await api.userAPI.loadMoreNovels(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.novels.append(contentsOf: newNovels)
            self.nextNovelsUrl = nextUrl
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.user.error("Error loading more novels: \(error.localizedDescription, privacy: .public)")
        }

        isLoadingMoreNovels = false
    }

    @MainActor
    func refresh() async {
        nextIllustsUrl = nil
        nextMangasUrl = nil
        nextBookmarksUrl = nil
        nextNovelsUrl = nil
        await fetchAll(forceRefresh: true)
    }

    private func invalidateForAccountChange() {
        requestGeneration &+= 1
        error = nil
        isLoadingDetail = false
        isLoadingIllusts = false
        isLoadingMangas = false
        isLoadingBookmarks = false
        isLoadingNovels = false
        isLoadingMoreIllusts = false
        isLoadingMoreMangas = false
        isLoadingMoreBookmarks = false
        isLoadingMoreNovels = false
        nextIllustsUrl = nil
        nextMangasUrl = nil
        nextBookmarksUrl = nil
        nextNovelsUrl = nil
        Task { await fetchAll(forceRefresh: true) }
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt, userId: String) -> Bool {
        self.requestGeneration == generation &&
            authSession.accountGeneration == accountGeneration &&
            authSession.currentUserId == userId
    }

    @MainActor
    func toggleFollow() async {
        guard let detail = userDetail else { return }
        let isFollowed = detail.user.isFollowed
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        do {
            if isFollowed {
                try await api.userAPI.unfollowUser(userId: userId)
            } else {
                try await api.userAPI.followUser(userId: userId)
            }
            let newDetail = try await api.userAPI.getUserDetail(userId: userId)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                return
            }

            self.userDetail = newDetail

            let cacheKey = CacheManager.userDetailDataKey(userId: userId, ownerId: requestUserId)
            let detailCacheKey = CacheManager.userDetailKey(userId: userId, ownerId: requestUserId)

            let cachedData = CachedUserDetailData(
                detail: newDetail,
                illusts: self.illusts,
                mangas: self.mangas,
                bookmarks: self.bookmarks,
                novels: self.novels,
                nextIllustsUrl: self.nextIllustsUrl,
                nextMangasUrl: self.nextMangasUrl,
                nextBookmarksUrl: self.nextBookmarksUrl,
                nextNovelsUrl: self.nextNovelsUrl,
                timestamp: Date()
            )
            cache.set(cachedData, forKey: cacheKey, expiration: expiration)
            cache.set(newDetail, forKey: detailCacheKey, expiration: expiration)
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                return
            }
            self.error = AppError.unknown(error)
        }
    }
}
