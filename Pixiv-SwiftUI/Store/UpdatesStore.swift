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

    private let api = PixivAPI.shared

    func fetchUpdates() async {
        guard !isLoadingUpdates else { return }
        isLoadingUpdates = true
        defer { isLoadingUpdates = false }

        do {
            let (illusts, nextUrl) = try await api.getFollowIllusts()
            self.updates = illusts
            self.nextUrlUpdates = nextUrl
        } catch {
            print("Failed to fetch updates: \(error)")
        }
    }

    func loadMoreUpdates() async {
        guard let nextUrl = nextUrlUpdates, !isLoadingUpdates else { return }
        isLoadingUpdates = true
        defer { isLoadingUpdates = false }

        do {
            let response: IllustsResponse = try await api.fetchNext(urlString: nextUrl)
            self.updates.append(contentsOf: response.illusts)
            self.nextUrlUpdates = response.nextUrl
        } catch {
            print("Failed to load more updates: \(error)")
        }
    }

    func fetchFollowing(userId: String) async {
        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let (users, nextUrl) = try await api.getUserFollowing(userId: userId)
            self.following = users
            self.nextUrlFollowing = nextUrl
        } catch {
            print("Failed to fetch following: \(error)")
        }
    }

    func loadMoreFollowing() async {
        guard let nextUrl = nextUrlFollowing, !isLoadingFollowing else { return }
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }

        do {
            let response: UserPreviewsResponse = try await api.fetchNext(urlString: nextUrl)
            self.following.append(contentsOf: response.userPreviews)
            self.nextUrlFollowing = response.nextUrl
        } catch {
            print("Failed to load more following: \(error)")
        }
    }
}
