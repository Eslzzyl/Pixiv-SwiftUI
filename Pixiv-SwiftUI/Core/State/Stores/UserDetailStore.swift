import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class UserDetailStore {
    var userDetail: UserDetailResponse?
    var illusts: [Illusts] = []
    var bookmarks: [Illusts] = []
    var novels: [Novel] = []

    var isLoadingDetail: Bool = false
    var isLoadingIllusts: Bool = false
    var isLoadingBookmarks: Bool = false
    var isLoadingNovels: Bool = false
    var isLoadingMore: Bool = false

    var errorMessage: String?

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
        let cacheKey = CacheManager.userDetailKey(userId: userId)

        if !forceRefresh, let cached: UserDetailResponse = cache.get(forKey: cacheKey) {
            self.userDetail = cached
            return
        }

        isLoadingDetail = true
        isLoadingIllusts = true
        isLoadingBookmarks = true
        isLoadingNovels = true
        errorMessage = nil

        do {
            async let detail = api.getUserDetail(userId: userId)
            async let illustsData = api.getUserIllusts(userId: userId)
            async let bookmarksData = api.getUserBookmarksIllusts(userId: userId)
            async let novelsData = api.getUserNovels(userId: userId)

            let (fetchedDetail, fetchedIllusts, fetchedBookmarksResult, fetchedNovelsResult) = try await (detail, illustsData, bookmarksData, novelsData)

            self.userDetail = fetchedDetail
            self.illusts = fetchedIllusts
            self.bookmarks = fetchedBookmarksResult.0
            self.novels = fetchedNovelsResult.0
            self.nextNovelsUrl = fetchedNovelsResult.1

            cache.set(fetchedDetail, forKey: cacheKey, expiration: expiration)
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching user detail: \(error)")
        }

        isLoadingDetail = false
        isLoadingIllusts = false
        isLoadingBookmarks = false
        isLoadingNovels = false
    }

    @MainActor
    func loadMoreNovels() async {
        guard let nextUrl = nextNovelsUrl, !isLoadingMore else { return }

        isLoadingMore = true

        do {
            let (newNovels, nextUrl) = try await api.loadMoreNovels(urlString: nextUrl)
            self.novels.append(contentsOf: newNovels)
            self.nextNovelsUrl = nextUrl
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error loading more novels: \(error)")
        }

        isLoadingMore = false
    }

    @MainActor
    func refresh() async {
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
            cache.set(newDetail, forKey: CacheManager.userDetailKey(userId: userId), expiration: expiration)
        } catch {
            self.errorMessage = "操作失败: \(error.localizedDescription)"
        }
    }
}
