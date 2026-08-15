import Foundation
import Observation

@Observable
@MainActor
final class IllustSeriesStore {
    let seriesId: Int

    var seriesDetail: IllustSeriesDetail?
    var illusts: [Illusts] = []
    var isLoading = false
    var isLoadingMore = false
    var error: AppError?
    var nextUrl: String?
    private let authSession: AuthSessionProtocol
    private var requestGeneration: UInt = 0

    init(seriesId: Int, authSession: AuthSessionProtocol = AccountStore.shared) {
        self.seriesId = seriesId
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

    func fetch() async {
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId
        isLoading = true
        error = nil

        do {
            let illustAPI = PixivAPI.shared.illustAPI

            let response = try await illustAPI.getIllustSeries(seriesId: seriesId)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }

            seriesDetail = response.illustSeriesDetail
            illusts = response.illusts.map { $0.toDomain() }
            nextUrl = response.nextUrl

            isLoading = false
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            isLoading = false
        }
    }

    func loadMore() async {
        guard !isLoadingMore, let nextUrl = nextUrl else { return }
        let requestGeneration = self.requestGeneration
        let requestAccountGeneration = authSession.accountGeneration
        let requestUserId = authSession.currentUserId

        isLoadingMore = true

        do {
            let illustAPI = PixivAPI.shared.illustAPI

            let response = try await illustAPI.getIllustSeriesByURL(nextUrl)
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }

            illusts.append(contentsOf: response.illusts.map { $0.toDomain() })
            self.nextUrl = response.nextUrl

            isLoadingMore = false
        } catch {
            guard isCurrentRequest(generation: requestGeneration, accountGeneration: requestAccountGeneration, userId: requestUserId) else { return }
            self.error = AppError.unknown(error)
            isLoadingMore = false
        }
    }

    private func resetForAccountChange() {
        requestGeneration &+= 1
        seriesDetail = nil
        illusts = []
        nextUrl = nil
        error = nil
        isLoading = false
        isLoadingMore = false
        Task { await fetch() }
    }

    private func isCurrentRequest(generation: UInt, accountGeneration: UInt, userId: String) -> Bool {
        self.requestGeneration == generation &&
            authSession.accountGeneration == accountGeneration &&
            authSession.currentUserId == userId
    }
}
