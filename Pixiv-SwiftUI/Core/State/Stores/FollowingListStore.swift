import Foundation
import SwiftUI
import Combine

@MainActor
class FollowingListStore: ObservableObject {
    @Published var following: [UserPreviews] = []
    @Published var isLoadingFollowing = false

    @Published var currentRestrict: String = "public"

    var nextUrlFollowing: String?

    private var loadingNextUrlFollowing: String?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)

    var hasCachedFollowing: Bool {
        !following.isEmpty
    }

    func fetchFollowing(userId: String, restrict: String? = nil, forceRefresh: Bool = false) async {
        let effectiveRestrict = restrict ?? currentRestrict

        let cacheKey = "user_following_\(userId)_\(effectiveRestrict)"

        if !forceRefresh {
            if hasCachedFollowing && cache.isValid(forKey: cacheKey) {
                return
            }

            if let cached: ([UserPreviews], String?) = cache.get(forKey: cacheKey) {
                self.following = cached.0
                self.nextUrlFollowing = cached.1
                return
            }
        }

        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let (users, nextUrl) = try await api.getUserFollowing(userId: userId, restrict: effectiveRestrict)
            self.following = users
            self.nextUrlFollowing = nextUrl
            cache.set((users, nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            print("Failed to fetch following: \(error)")
        }
    }

    func refreshFollowing(userId: String, restrict: String? = nil) async {
        let effectiveRestrict = restrict ?? currentRestrict
        currentRestrict = effectiveRestrict
        await fetchFollowing(userId: userId, restrict: effectiveRestrict, forceRefresh: true)
    }

    func loadMoreFollowing() async {
        guard let nextUrl = nextUrlFollowing, !isLoadingFollowing else { return }
        if nextUrl == loadingNextUrlFollowing { return }

        loadingNextUrlFollowing = nextUrl
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let response: UserPreviewsResponse = try await api.fetchNext(urlString: nextUrl)
            self.following.append(contentsOf: response.userPreviews)
            self.nextUrlFollowing = response.nextUrl
            loadingNextUrlFollowing = nil
        } catch {
            print("Failed to load more following: \(error)")
            loadingNextUrlFollowing = nil
        }
    }
}
