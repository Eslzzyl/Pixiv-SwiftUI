import Foundation
import SwiftUI
import Combine

@MainActor
class FollowingListStore: ObservableObject {
    @Published var following: [UserPreviews] = []
    @Published var isLoadingFollowing = false

    var nextUrlFollowing: String?

    private let api = PixivAPI.shared

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
