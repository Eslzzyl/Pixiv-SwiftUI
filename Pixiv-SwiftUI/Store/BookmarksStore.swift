import Foundation
import SwiftUI
import Combine

@MainActor
class BookmarksStore: ObservableObject {
    @Published var bookmarks: [Illusts] = []
    @Published var isLoadingBookmarks = false
    @Published var bookmarkRestrict: String = "public"

    var nextUrlBookmarks: String?

    private let api = PixivAPI.shared

    func fetchBookmarks(userId: String) async {
        guard !isLoadingBookmarks else { return }
        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            let (illusts, nextUrl) = try await api.getUserBookmarksIllusts(userId: userId, restrict: bookmarkRestrict)
            self.bookmarks = illusts
            self.nextUrlBookmarks = nextUrl
        } catch {
            print("Failed to fetch bookmarks: \(error)")
        }
    }

    func loadMoreBookmarks() async {
        guard let nextUrl = nextUrlBookmarks, !isLoadingBookmarks else { return }
        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            let response: IllustsResponse = try await api.fetchNext(urlString: nextUrl)
            self.bookmarks.append(contentsOf: response.illusts)
            self.nextUrlBookmarks = response.nextUrl
        } catch {
            print("Failed to load more bookmarks: \(error)")
        }
    }
}
