import Foundation
import SwiftUI
import Combine

@MainActor
class QuickViewStore: ObservableObject {
    @Published var updates: [Illusts] = []
    @Published var bookmarks: [Illusts] = []
    @Published var following: [UserPreviews] = []
    
    @Published var isLoadingUpdates = false
    @Published var isLoadingBookmarks = false
    @Published var isLoadingFollowing = false
    
    @Published var bookmarkRestrict: String = "public" // public or private
    
    private let api = PixivAPI.shared
    
    func fetchUpdates() async {
        guard !isLoadingUpdates else { return }
        isLoadingUpdates = true
        defer { isLoadingUpdates = false }
        
        do {
            let illusts = try await api.getFollowIllusts()
            self.updates = illusts
        } catch {
            print("Failed to fetch updates: \(error)")
        }
    }
    
    func fetchBookmarks(userId: String) async {
        guard !isLoadingBookmarks else { return }
        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }
        
        do {
            let illusts = try await api.getUserBookmarksIllusts(userId: userId, restrict: bookmarkRestrict)
            self.bookmarks = illusts
        } catch {
            print("Failed to fetch bookmarks: \(error)")
        }
    }
    
    func fetchFollowing(userId: String) async {
        guard !isLoadingFollowing else { return }
        isLoadingFollowing = true
        defer { isLoadingFollowing = false }
        
        do {
            let users = try await api.getUserFollowing(userId: userId)
            self.following = users
        } catch {
            print("Failed to fetch following: \(error)")
        }
    }
}
