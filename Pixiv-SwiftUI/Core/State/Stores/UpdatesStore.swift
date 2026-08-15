import Observation
import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
@Observable
class UpdatesStore {
    var updates: [Illusts] = []
    var following: [UserPreviews] = []

    var isLoadingUpdates = false
    var isLoadingFollowing = false
    var hasFetchedUpdates = false
    var hasFetchedFollowing = false
    var error: AppError?

    var currentRestrict: String = "public"

    var nextUrlUpdates: String?
    var nextUrlFollowing: String?

    private var loadingNextUrlUpdates: String?
    private var loadingNextUrlFollowing: String?

    private let api = PixivAPI.shared
    private let authSession: AuthSessionProtocol
    private let cache: CacheStorageProtocol = CacheManager.shared
    private var requestGeneration: UInt = 0

    private let expiration: CacheExpiration = .minutes(5)

    init(authSession: AuthSessionProtocol = AccountStore.shared) {
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

    func fetchUpdates(forceRefresh: Bool = false, restrict: String? = nil) async {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        let effectiveRestrict = restrict ?? currentRestrict
        let requestCacheKey = cacheKeyUpdates(restrict: effectiveRestrict, userId: requestUserId)

        guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }

        if !forceRefresh {
            if let cached: ([Illusts], String?) = cache.get(forKey: requestCacheKey) {
                self.updates = cached.0
                self.nextUrlUpdates = cached.1
                hasFetchedUpdates = true
                return
            }
        }

        guard !isLoadingUpdates else { return }
        isLoadingUpdates = true
        error = nil
        defer {
            if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
                isLoadingUpdates = false
                hasFetchedUpdates = true
            }
        }

        do {
            let (illusts, nextUrl) = try await api.userAPI.getFollowIllusts(restrict: effectiveRestrict)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.updates = illusts
            self.nextUrlUpdates = nextUrl
            cache.set((illusts, nextUrl), forKey: requestCacheKey, expiration: expiration)
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.general.error("Failed to fetch updates: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshUpdates(restrict: String? = nil) async {
        let effectiveRestrict = restrict ?? currentRestrict
        currentRestrict = effectiveRestrict
        await fetchUpdates(forceRefresh: true, restrict: effectiveRestrict)
    }

    func loadMoreUpdates() async {
        guard let nextUrl = nextUrlUpdates, !isLoadingUpdates else { return }
        if nextUrl == loadingNextUrlUpdates { return }

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        loadingNextUrlUpdates = nextUrl
        isLoadingUpdates = true
        defer {
            if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
                isLoadingUpdates = false
            }
        }

        do {
            let response: IllustsResponseDTO = try await api.fetchNext(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else {
                loadingNextUrlUpdates = nil
                return
            }
            self.updates.append(contentsOf: response.illusts.map { $0.toDomain() })
            self.nextUrlUpdates = response.nextUrl
            loadingNextUrlUpdates = nil
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.general.error("Failed to load more updates: \(error.localizedDescription, privacy: .public)")
            loadingNextUrlUpdates = nil
        }
    }

    func fetchFollowing(userId: String, forceRefresh: Bool = false) async {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = userId
        let cacheKey = cacheKeyFollowing(userId: userId)
        guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
        if !forceRefresh {
            if let cached: ([UserPreviews], String?) = cache.get(forKey: cacheKey) {
                self.following = cached.0
                self.nextUrlFollowing = cached.1
                hasFetchedFollowing = true
                return
            }
        }

        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        error = nil
        defer {
            if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
                isLoadingFollowing = false
                hasFetchedFollowing = true
            }
        }

        do {
            let (users, nextUrl) = try await api.userAPI.getUserFollowing(userId: userId)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.following = users
            self.nextUrlFollowing = nextUrl
            cache.set((users, nextUrl), forKey: cacheKeyFollowing(userId: userId), expiration: expiration)
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.general.error("Failed to fetch following: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshFollowing(userId: String) async {
        await fetchFollowing(userId: userId, forceRefresh: true)
    }

    func loadMoreFollowing() async {
        guard let nextUrl = nextUrlFollowing, !isLoadingFollowing else { return }
        if nextUrl == loadingNextUrlFollowing { return }

        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        loadingNextUrlFollowing = nextUrl
        isLoadingFollowing = true
        defer {
            if isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) {
                isLoadingFollowing = false
            }
        }

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
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            Logger.general.error("Failed to load more following: \(error.localizedDescription, privacy: .public)")
            loadingNextUrlFollowing = nil
        }
    }

    var cacheKeyUpdates: String {
        cacheKeyUpdates(restrict: currentRestrict)
    }

    func cacheKeyUpdates(restrict: String, userId: String? = nil) -> String {
        let ownerId = userId ?? authSession.currentUserId
        return CacheManager.updatesKey(userId: "\(ownerId)_follow_\(restrict)")
    }

    func cacheKeyFollowing(userId: String) -> String {
        CacheManager.updatesKey(userId: userId)
    }

    private func invalidateForAccountChange() {
        requestGeneration &+= 1
        updates = []
        following = []
        nextUrlUpdates = nil
        nextUrlFollowing = nil
        loadingNextUrlUpdates = nil
        loadingNextUrlFollowing = nil
        isLoadingUpdates = false
        isLoadingFollowing = false
        hasFetchedUpdates = false
        hasFetchedFollowing = false
        error = nil
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt, userId: String) -> Bool {
        self.requestGeneration == generation &&
            authSession.accountGeneration == accountGeneration &&
            authSession.currentUserId == userId
    }
}
