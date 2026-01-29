import Foundation
import SwiftUI
import Observation

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

    var errorMessage: String?

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
    private let api = PixivAPI.shared
    private let cache = CacheManager.shared

    private let expiration: CacheExpiration = .minutes(5)

    init(userId: String) {
        self.userId = userId
    }

    @MainActor
    func fetchAll(forceRefresh: Bool = false) async {
        let cacheKey = CacheManager.userDetailDataKey(userId: userId)
        let detailCacheKey = CacheManager.userDetailKey(userId: userId)

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
        errorMessage = nil

        do {
            async let detail = api.getUserDetail(userId: userId)
            async let illustsData = api.getUserIllusts(userId: userId, type: "illust")
            async let mangasData = api.getUserIllusts(userId: userId, type: "manga")
            async let bookmarksData = api.getUserBookmarksIllusts(userId: userId)
            async let novelsData = api.getUserNovels(userId: userId)

            let (fetchedDetail, fetchedIllusts, fetchedMangas, fetchedBookmarksResult, fetchedNovelsResult) = try await (detail, illustsData, mangasData, bookmarksData, novelsData)

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
            self.errorMessage = error.localizedDescription
            print("Error fetching user detail: \(error)")
        }

        isLoadingDetail = false
        isLoadingIllusts = false
        isLoadingMangas = false
        isLoadingBookmarks = false
        isLoadingNovels = false
    }

    @MainActor
    func loadMoreIllusts() async {
        guard let nextUrl = nextIllustsUrl, !isLoadingMoreIllusts else { return }

        isLoadingMoreIllusts = true

        do {
            let (newIllusts, nextUrl) = try await api.loadMoreIllusts(urlString: nextUrl)
            self.illusts.append(contentsOf: newIllusts)
            self.nextIllustsUrl = nextUrl
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error loading more illusts: \(error)")
        }

        isLoadingMoreIllusts = false
    }

    @MainActor
    func loadMoreMangas() async {
        guard let nextUrl = nextMangasUrl, !isLoadingMoreMangas else { return }

        isLoadingMoreMangas = true

        do {
            let (newMangas, nextUrl) = try await api.loadMoreIllusts(urlString: nextUrl)
            self.mangas.append(contentsOf: newMangas)
            self.nextMangasUrl = nextUrl
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error loading more mangas: \(error)")
        }

        isLoadingMoreMangas = false
    }

    @MainActor
    func loadMoreBookmarks() async {
        guard let nextUrl = nextBookmarksUrl, !isLoadingMoreBookmarks else { return }

        isLoadingMoreBookmarks = true

        do {
            let response: IllustsResponse = try await api.fetchNext(urlString: nextUrl)
            self.bookmarks.append(contentsOf: response.illusts)
            self.nextBookmarksUrl = response.nextUrl
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error loading more bookmarks: \(error)")
        }

        isLoadingMoreBookmarks = false
    }

    @MainActor
    func loadMoreNovels() async {
        guard let nextUrl = nextNovelsUrl, !isLoadingMoreNovels else { return }

        isLoadingMoreNovels = true

        do {
            let (newNovels, nextUrl) = try await api.loadMoreNovels(urlString: nextUrl)
            self.novels.append(contentsOf: newNovels)
            self.nextNovelsUrl = nextUrl
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error loading more novels: \(error)")
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

    @MainActor
    func toggleFollow() async {
        guard let detail = userDetail else { return }
        let isFollowed = detail.user.isFollowed

        do {
            if isFollowed {
                try await api.unfollowUser(userId: userId)
            } else {
                try await api.followUser(userId: userId)
            }
            let newDetail = try await api.getUserDetail(userId: userId)
            self.userDetail = newDetail
            let cacheKey = CacheManager.userDetailDataKey(userId: userId)
            let detailCacheKey = CacheManager.userDetailKey(userId: userId)

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
            self.errorMessage = "操作失败: \(error.localizedDescription)"
        }
    }
}
