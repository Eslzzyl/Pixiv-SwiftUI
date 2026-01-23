import Foundation
import SwiftUI
import Combine

@MainActor
class UpdatesStore: ObservableObject {
    @Published var updates: [Illusts] = []
    @Published var following: [UserPreviews] = []

    @Published var isLoadingUpdates = false
    @Published var isLoadingFollowing = false

    var nextUrlUpdates: String?
    var nextUrlFollowing: String?

    private var loadingNextUrlUpdates: String?
    private var loadingNextUrlFollowing: String?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared

    private let expiration: CacheExpiration = .minutes(5)

    var hasCachedUpdates: Bool {
        !updates.isEmpty
    }

    var hasCachedFollowing: Bool {
        !following.isEmpty
    }

    func fetchUpdates(forceRefresh: Bool = false) async {
        if !forceRefresh {
            if hasCachedUpdates && cache.isValid(forKey: cacheKeyUpdates) {
                return
            }

            // 尝试从缓存加载
            if let cached: ([Illusts], String?) = cache.get(forKey: cacheKeyUpdates) {
                self.updates = cached.0
                self.nextUrlUpdates = cached.1
                return
            }
        }

        guard !isLoadingUpdates else { return }
        isLoadingUpdates = true
        defer { isLoadingUpdates = false }

        do {
            let (illusts, nextUrl) = try await api.getFollowIllusts()
            self.updates = illusts
            self.nextUrlUpdates = nextUrl
            cache.set((illusts, nextUrl), forKey: cacheKeyUpdates, expiration: expiration)
        } catch {
            print("Failed to fetch updates: \(error)")
        }
    }

    func refreshUpdates() async {
        await fetchUpdates(forceRefresh: true)
    }

    func loadMoreUpdates() async {
        guard let nextUrl = nextUrlUpdates, !isLoadingUpdates else { return }
        if nextUrl == loadingNextUrlUpdates { return }

        loadingNextUrlUpdates = nextUrl
        isLoadingUpdates = true
        defer { isLoadingUpdates = false }

        do {
            let response: IllustsResponse = try await api.fetchNext(urlString: nextUrl)
            self.updates.append(contentsOf: response.illusts)
            self.nextUrlUpdates = response.nextUrl
            // 成功后清除，以便下次可以加载新的 nextUrl
            loadingNextUrlUpdates = nil
        } catch {
            print("Failed to load more updates: \(error)")
            // 失败也清除，以便可以重试
            loadingNextUrlUpdates = nil
        }
    }

    func fetchFollowing(userId: String, forceRefresh: Bool = false) async {
        let cacheKey = cacheKeyFollowing(userId: userId)
        if !forceRefresh {
            if hasCachedFollowing && cache.isValid(forKey: cacheKey) {
                return
            }

            // 尝试从缓存加载
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
            let (users, nextUrl) = try await api.getUserFollowing(userId: userId)
            self.following = users
            self.nextUrlFollowing = nextUrl
            cache.set((users, nextUrl), forKey: cacheKeyFollowing(userId: userId), expiration: expiration)
        } catch {
            print("Failed to fetch following: \(error)")
        }
    }

    func refreshFollowing(userId: String) async {
        await fetchFollowing(userId: userId, forceRefresh: true)
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

    var cacheKeyUpdates: String {
        CacheManager.updatesKey(userId: "follow")
    }

    func cacheKeyFollowing(userId: String) -> String {
        CacheManager.updatesKey(userId: userId)
    }
}
