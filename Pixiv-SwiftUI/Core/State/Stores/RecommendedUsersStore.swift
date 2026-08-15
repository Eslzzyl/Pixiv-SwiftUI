import Observation
import Foundation
import SwiftUI
import Combine
import os.log

@MainActor
@Observable
class RecommendedUsersStore {
    var users: [UserPreviews] = []
    var isLoading = false
    var nextUrl: String?
    var error: AppError?

    private var loadingNextUrl: String?

    private let api = PixivAPI.shared
    private let authSession: AuthSessionProtocol
    private let cache: CacheStorageProtocol = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)
    private var requestGeneration: UInt = 0

    init(authSession: AuthSessionProtocol = AccountStore.shared) {
        self.authSession = authSession
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.requestGeneration &+= 1
                self?.users = []
                self?.nextUrl = nil
                self?.loadingNextUrl = nil
                self?.isLoading = false
                self?.error = nil
            }
        }
    }

    private func cacheKey(userId: String) -> String {
        "recommended_users_list_\(userId)"
    }

    func fetchUsers(forceRefresh: Bool = false) async {
        let requestGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        let requestCacheKey = cacheKey(userId: requestUserId)

        if !forceRefresh, let cached: ([UserPreviews], String?) = cache.get(forKey: requestCacheKey) {
            self.users = cached.0
            self.nextUrl = cached.1
            return
        }

        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer {
            if isCurrentRequest(generation: requestGeneration, userId: requestUserId) {
                isLoading = false
            }
        }

        do {
            let (users, nextUrl) = try await api.userAPI.getRecommendedUsers()
            guard isCurrentRequest(generation: requestGeneration, userId: requestUserId) else { return }
            self.users = users
            self.nextUrl = nextUrl
            cache.set((users, nextUrl), forKey: requestCacheKey, expiration: expiration)
        } catch {
            self.error = AppError.unknown(error)
            Logger.user.error("Failed to fetch recommended users: \(error.localizedDescription, privacy: .public)")
        }
    }

    func refreshUsers() async {
        await fetchUsers(forceRefresh: true)
    }

    func loadMoreUsers() async {
        guard let nextUrl = nextUrl, !isLoading else { return }
        if nextUrl == loadingNextUrl { return }

        let requestGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        loadingNextUrl = nextUrl
        isLoading = true
        defer {
            if isCurrentRequest(generation: requestGeneration, userId: requestUserId) {
                isLoading = false
            }
        }

        do {
            let response: UserPreviewsResponse = try await api.fetchNext(urlString: nextUrl)
            guard isCurrentRequest(generation: requestGeneration, userId: requestUserId) else { return }
            self.users.append(contentsOf: response.userPreviews)
            self.nextUrl = response.nextUrl
            loadingNextUrl = nil
        } catch {
            Logger.user.error("Failed to load more recommended users: \(error.localizedDescription, privacy: .public)")
            loadingNextUrl = nil
        }
    }

    private func isCurrentRequest(generation: UInt, userId: String) -> Bool {
        authSession.accountGeneration == generation && authSession.currentUserId == userId
    }
}
