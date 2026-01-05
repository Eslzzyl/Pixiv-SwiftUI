import Foundation
import SwiftUI
import Observation

@Observable
final class UserDetailStore {
    var userDetail: UserDetailResponse?
    var illusts: [Illusts] = []
    var bookmarks: [Illusts] = []

    var isLoadingDetail: Bool = false
    var isLoadingIllusts: Bool = false
    var isLoadingBookmarks: Bool = false

    var errorMessage: String?

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
        errorMessage = nil

        do {
            async let detail = api.getUserDetail(userId: userId)
            async let illustsData = api.getUserIllusts(userId: userId)
            async let bookmarksData = api.getUserBookmarksIllusts(userId: userId)

            let (fetchedDetail, fetchedIllusts, fetchedBookmarksResult) = try await (detail, illustsData, bookmarksData)

            self.userDetail = fetchedDetail
            self.illusts = fetchedIllusts
            self.bookmarks = fetchedBookmarksResult.0

            cache.set(fetchedDetail, forKey: cacheKey, expiration: expiration)
        } catch {
            self.errorMessage = error.localizedDescription
            print("Error fetching user detail: \(error)")
        }

        isLoadingDetail = false
        isLoadingIllusts = false
        isLoadingBookmarks = false
    }

    @MainActor
    func refresh() async {
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
