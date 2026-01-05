import Foundation
import SwiftUI
import Combine

@MainActor
class BookmarksStore: ObservableObject {
    @Published var bookmarks: [Illusts] = []
    @Published var isLoadingBookmarks = false
    @Published var bookmarkRestrict: String = "public"

    var nextUrlBookmarks: String?
    private var loadingNextUrl: String?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared

    private let expiration: CacheExpiration = .minutes(5)

    var hasCachedBookmarks: Bool {
        !bookmarks.isEmpty
    }

    func fetchBookmarks(userId: String, forceRefresh: Bool = false) async {
        let cacheKey = CacheManager.bookmarksKey(userId: userId, restrict: bookmarkRestrict)

        if !forceRefresh {
            if hasCachedBookmarks && cache.isValid(forKey: cacheKey) {
                return
            }
            
            // 尝试从缓存加载
            if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
                self.bookmarks = cached.0
                self.nextUrlBookmarks = cached.1
                return
            }
        }

        guard !isLoadingBookmarks else { return }
        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            let (illusts, nextUrl) = try await api.getUserBookmarksIllusts(userId: userId, restrict: bookmarkRestrict)
            self.bookmarks = illusts
            self.nextUrlBookmarks = nextUrl
            cache.set((illusts, nextUrl), forKey: cacheKey, expiration: expiration)
        } catch {
            print("Failed to fetch bookmarks: \(error)")
        }
    }

    func refreshBookmarks(userId: String) async {
        await fetchBookmarks(userId: userId, forceRefresh: true)
    }

    func loadMoreBookmarks() async {
        guard let nextUrl = nextUrlBookmarks, !isLoadingBookmarks else { return }
        if nextUrl == loadingNextUrl { return }
        
        loadingNextUrl = nextUrl
        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            let response: IllustsResponse = try await api.fetchNext(urlString: nextUrl)
            self.bookmarks.append(contentsOf: response.illusts)
            self.nextUrlBookmarks = response.nextUrl
            loadingNextUrl = nil
        } catch {
            print("Failed to load more bookmarks: \(error)")
            loadingNextUrl = nil
        }
    }
}
