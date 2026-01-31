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
    private var currentFetchTask: Task<Void, Never>?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared

    private let expiration: CacheExpiration = .minutes(5)

    var hasCachedBookmarks: Bool {
        !bookmarks.isEmpty
    }

    func cancelCurrentFetch() {
        #if DEBUG
        print("[BookmarksStore] 取消当前请求")
        #endif
        currentFetchTask?.cancel()
        currentFetchTask = nil
        isLoadingBookmarks = false
    }

    func fetchBookmarks(userId: String, forceRefresh: Bool = false) async {
        let capturedRestrict = self.bookmarkRestrict
        let cacheKey = CacheManager.bookmarksKey(userId: userId, restrict: capturedRestrict)

        #if DEBUG
        print("[BookmarksStore] fetchBookmarks: restrict=\(capturedRestrict), userId=\(userId), forceRefresh=\(forceRefresh)")
        #endif

        if !forceRefresh {
            if hasCachedBookmarks && cache.isValid(forKey: cacheKey) {
                #if DEBUG
                print("[BookmarksStore] 使用有效缓存: key=\(cacheKey), count=\(bookmarks.count)")
                #endif
                return
            }

            if let cached: ([Illusts], String?) = cache.get(forKey: cacheKey) {
                #if DEBUG
                print("[BookmarksStore] 从缓存加载: key=\(cacheKey), count=\(cached.0.count)")
                #endif
                self.bookmarks = cached.0
                self.nextUrlBookmarks = cached.1
                return
            }
        }

        guard !isLoadingBookmarks else {
            #if DEBUG
            print("[BookmarksStore] 跳过: 已在加载中")
            #endif
            return
        }

        isLoadingBookmarks = true
        defer { isLoadingBookmarks = false }

        do {
            #if DEBUG
            print("[BookmarksStore] 开始网络请求: restrict=\(capturedRestrict)")
            #endif
            let (illusts, nextUrl) = try await api.getUserBookmarksIllusts(userId: userId, restrict: capturedRestrict)

            guard capturedRestrict == self.bookmarkRestrict else {
                #if DEBUG
                print("[BookmarksStore] 丢弃结果: restrict已改变, captured=\(capturedRestrict), current=\(self.bookmarkRestrict)")
                #endif
                return
            }

            #if DEBUG
            print("[BookmarksStore] 请求完成: restrict=\(capturedRestrict), count=\(illusts.count)")
            #endif
            self.bookmarks = illusts
            self.nextUrlBookmarks = nextUrl
            cache.set((illusts, nextUrl), forKey: cacheKey, expiration: expiration)

            await syncToBookmarkCache(illusts: illusts, userId: userId, restrict: capturedRestrict)
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

            await syncToBookmarkCache(illusts: response.illusts, userId: AccountStore.shared.currentUserId, restrict: bookmarkRestrict)
        } catch {
            print("Failed to load more bookmarks: \(error)")
            loadingNextUrl = nil
        }
    }

    private func syncToBookmarkCache(illusts: [Illusts], userId: String, restrict: String) async {
        guard UserSettingStore.shared.userSetting.bookmarkCacheEnabled else { return }

        await MainActor.run {
            BookmarkCacheStore.shared.batchAddOrUpdateCache(
                illusts: illusts,
                ownerId: userId,
                bookmarkRestrict: restrict
            )
        }
    }
}
