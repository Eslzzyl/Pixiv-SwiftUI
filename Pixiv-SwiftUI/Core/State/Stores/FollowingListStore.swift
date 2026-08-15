import Observation
import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
@Observable
class FollowingListStore {
    var following: [UserPreviews] = []
    var isLoadingFollowing = false
    var error: AppError?

    var currentRestrict: String = "public"

    var nextUrlFollowing: String?

    private var loadingNextUrlFollowing: String?
    private var requestGeneration: UInt = 0

    private let api = PixivAPI.shared
    private let cache: CacheStorageProtocol = CacheManager.shared
    private let authSession: AuthSessionProtocol
    private let expiration: CacheExpiration = .minutes(5)

    init(authSession: AuthSessionProtocol = AccountStore.shared) {
        self.authSession = authSession
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

    func fetchFollowing(userId: String, restrict: String? = nil, forceRefresh: Bool = false) async {
        let effectiveRestrict = restrict ?? currentRestrict
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        let cacheKey = "user_following_\(userId)_\(effectiveRestrict)"

        if !forceRefresh, let cached: ([UserPreviews], String?) = cache.get(forKey: cacheKey) {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                return
            }
            self.following = cached.0
            self.nextUrlFollowing = cached.1
            return
        }

        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        error = nil
        defer { isLoadingFollowing = false }

        do {
            let (users, nextUrl) = try await api.userAPI.getUserFollowing(userId: userId, restrict: effectiveRestrict)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                return
            }
            self.following = users
            self.nextUrlFollowing = nextUrl
            cache.set((users, nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                return
            }
            self.error = AppError.unknown(error)
            Logger.user.error("Failed to fetch following: \(error.localizedDescription, privacy: .public)")
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

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        loadingNextUrlFollowing = nextUrl
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let response: UserPreviewsResponse = try await api.fetchNext(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                loadingNextUrlFollowing = nil
                return
            }
            self.following.append(contentsOf: response.userPreviews)
            self.nextUrlFollowing = response.nextUrl
            loadingNextUrlFollowing = nil
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                loadingNextUrlFollowing = nil
                return
            }
            self.error = AppError.unknown(error)
            Logger.user.error("Failed to load more following: \(error.localizedDescription, privacy: .public)")
            loadingNextUrlFollowing = nil
        }
    }

    func resetForAccountChange() {
        requestGeneration &+= 1
        following = []
        nextUrlFollowing = nil
        loadingNextUrlFollowing = nil
        isLoadingFollowing = false
        error = nil
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt, userId: String) -> Bool {
        self.requestGeneration == generation &&
            authSession.accountGeneration == accountGeneration &&
            authSession.currentUserId == userId
    }
}
