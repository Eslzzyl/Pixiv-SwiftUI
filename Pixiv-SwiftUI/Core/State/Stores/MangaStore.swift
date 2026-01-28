import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class MangaStore {
    static let shared = MangaStore()

    var recommendedManga: [Illusts] = []
    var watchlistSeries: [MangaSeries] = []

    var isLoadingRecommended: Bool = false
    var isLoadingWatchlist: Bool = false

    var nextUrlRecommended: String?
    var nextUrlWatchlist: String?

    private var loadingNextUrlRecommended: String?
    private var loadingNextUrlWatchlist: String?

    private let api = PixivAPI.shared
    private let cache = CacheManager.shared
    private let expiration: CacheExpiration = .minutes(5)

    var cacheKeyRecommended: String { "manga_recommended" }
    var cacheKeyWatchlist: String { "manga_watchlist" }

    func clearMemoryCache() {
        self.recommendedManga = []
        self.watchlistSeries = []
        self.nextUrlRecommended = nil
        self.nextUrlWatchlist = nil
    }

    func loadRecommended(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: ([Illusts], String?) = cache.get(forKey: cacheKeyRecommended) {
            self.recommendedManga = cached.0
            self.nextUrlRecommended = cached.1
            return
        }

        guard !isLoadingRecommended else { return }
        isLoadingRecommended = true
        defer { isLoadingRecommended = false }

        do {
            let result: (illusts: [Illusts], nextUrl: String?)
            if AccountStore.shared.isLoggedIn {
                result = try await api.getRecommendedManga()
            } else {
                result = try await api.getRecommendedMangaNoLogin()
            }
            self.recommendedManga = result.illusts
            self.nextUrlRecommended = result.nextUrl
            cache.set((result.illusts, result.nextUrl), forKey: cacheKeyRecommended, expiration: expiration)
        } catch {
            print("Failed to load recommended manga: \(error)")
        }
    }

    func loadMoreRecommended() async {
        guard let nextUrl = nextUrlRecommended, !isLoadingRecommended else { return }
        if nextUrl == loadingNextUrlRecommended { return }

        loadingNextUrlRecommended = nextUrl
        isLoadingRecommended = true
        defer { isLoadingRecommended = false }

        do {
            let response: IllustsResponse = try await api.fetchNext(urlString: nextUrl)
            self.recommendedManga.append(contentsOf: response.illusts)
            self.nextUrlRecommended = response.nextUrl
            loadingNextUrlRecommended = nil
        } catch {
            loadingNextUrlRecommended = nil
        }
    }

    func loadWatchlist(forceRefresh: Bool = false) async {
        if !forceRefresh, let cached: ([MangaSeries], String?) = cache.get(forKey: cacheKeyWatchlist) {
            self.watchlistSeries = cached.0
            self.nextUrlWatchlist = cached.1
            return
        }

        guard !isLoadingWatchlist else { return }
        isLoadingWatchlist = true
        defer { isLoadingWatchlist = false }

        do {
            let result = try await api.getWatchlistManga()
            self.watchlistSeries = result.series
            self.nextUrlWatchlist = result.nextUrl
            cache.set((result.series, result.nextUrl), forKey: cacheKeyWatchlist, expiration: expiration)
        } catch {
            print("Failed to load watchlist manga: \(error)")
        }
    }

    func loadMoreWatchlist() async {
        guard let nextUrl = nextUrlWatchlist, !isLoadingWatchlist else { return }
        if nextUrl == loadingNextUrlWatchlist { return }

        loadingNextUrlWatchlist = nextUrl
        isLoadingWatchlist = true
        defer { isLoadingWatchlist = false }

        do {
            let result = try await api.getMangaSeriesByURL(nextUrl)
            self.watchlistSeries.append(contentsOf: result.series)
            self.nextUrlWatchlist = result.nextUrl
            loadingNextUrlWatchlist = nil
        } catch {
            loadingNextUrlWatchlist = nil
        }
    }

    func addSeries(_ seriesId: Int) async {
        do {
            try await api.addMangaSeries(seriesId: seriesId)
            if let index = watchlistSeries.firstIndex(where: { $0.id == seriesId }) {
                watchlistSeries[index].isFollowed = true
            }
        } catch {
            print("Failed to add series: \(error)")
        }
    }

    func removeSeries(_ seriesId: Int) async {
        do {
            try await api.removeMangaSeries(seriesId: seriesId)
            if let index = watchlistSeries.firstIndex(where: { $0.id == seriesId }) {
                watchlistSeries[index].isFollowed = false
            }
        } catch {
            print("Failed to remove series: \(error)")
        }
    }
}
