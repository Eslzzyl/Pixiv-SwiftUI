import Foundation
import Kingfisher
import os.log

enum PixivImageRequestLogContext {
    nonisolated static func kind(for url: URL) -> String {
        if PixivNetworkConfiguration.isOriginalImageURL(url) {
            return "original"
        }
        if url.path.contains("/c/250x250_") || url.path.contains("/c/540x540_") {
            return "thumbnail"
        }
        if url.path.contains("/c/") {
            return "list-large"
        }
        return "image"
    }

    nonisolated static func role(for priority: Float) -> String {
        if priority <= ImageRequestPriority.background {
            return "background"
        }
        if priority <= ImageRequestPriority.prefetch {
            return "prefetch"
        }
        if priority >= ImageRequestPriority.visible {
            return "visible"
        }
        return "default"
    }

    nonisolated static func key(for url: URL) -> String {
        String(url.absoluteString.hashValue, radix: 16)
    }

    nonisolated static func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError {
            return true
        }
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }
        return false
    }
}

final class DirectImageDataProvider: ImageDataProvider {
    let url: URL
    let cacheKey: String
    let priority: Float
    let usesSegmentedDownload: Bool

    init(
        url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority,
        usesSegmentedDownload: Bool = false
    ) {
        self.url = url
        self.cacheKey = cacheKey ?? url.absoluteString
        self.priority = priority
        self.usesSegmentedDownload = usesSegmentedDownload
    }

    var contentURL: URL? {
        url
    }

    func data() async throws -> Data {
        let url = self.url
        let headers = Self.requestHeaders(for: url)
        let priority = self.priority
        let usesSegmentedDownload = self.usesSegmentedDownload
        let taskPriority: TaskPriority = {
            if priority <= ImageRequestPriority.prefetch {
                return .background
            }
            if priority >= ImageRequestPriority.visible {
                return .userInitiated
            }
            return .utility
        }()

        let downloadTask = Task.detached(priority: taskPriority) {
            try await Self.downloadImageData(
                from: url,
                headers: headers,
                priority: priority,
                usesSegmentedDownload: usesSegmentedDownload
            )
        }
        return try await withTaskCancellationHandler {
            try await downloadTask.value
        } onCancel: {
            downloadTask.cancel()
        }
    }

    private static func requestHeaders(for url: URL) -> [String: String] {
        let request = URLRequest(url: url)
        return PixivImageLoader.shared.modified(for: request)?.allHTTPHeaderFields ?? [:]
    }

    private static func downloadImageData(
        from url: URL,
        headers: [String: String],
        priority: Float,
        usesSegmentedDownload: Bool
    ) async throws -> Data {
        let requestID = String(UUID().uuidString.prefix(8))
        guard let host = url.host else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        guard PixivNetworkConfiguration.isPixivImageHost(host) else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        try Task.checkCancellation()
        let requestKind = PixivImageRequestLogContext.kind(for: url)
        let requestRole = PixivImageRequestLogContext.role(for: priority)
        let imageKey = PixivImageRequestLogContext.key(for: url)
        let domain = PixivImageDomain.selected.rawValue
        let routedHost = PixivNetworkConfiguration.routedImageURL(from: url).host ?? host
        let configuredConcurrency: Int?
        if usesSegmentedDownload {
            configuredConcurrency = await MainActor.run {
                UserSettingStore.shared.userSetting.downloadConcurrency
            }
        } else {
            configuredConcurrency = nil
        }
        let queuedAt = DispatchTime.now().uptimeNanoseconds
        Logger.network.debug(
            "image request queued id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) domain=\(domain, privacy: .public) host=\(host, privacy: .public) routedHost=\(routedHost, privacy: .public) segmented=\(usesSegmentedDownload) configuredConcurrency=\(configuredConcurrency.map(String.init) ?? "1") priority=\(priority)"
        )

        let data: Data
        var activeAfter: Int?
        var networkStartedAt = queuedAt
        let tracksVisibleActivity = requestRole == "visible"
        if tracksVisibleActivity {
            await PixivVisibleImageActivity.shared.begin()
        } else if requestRole == "background" || requestRole == "prefetch" {
            await PixivVisibleImageActivity.shared.waitUntilIdle()
        }

        if usesSegmentedDownload {
            do {
                data = try await NetworkClient.shared.concurrentDownloadData(
                    from: url,
                    headers: headers,
                    concurrency: configuredConcurrency ?? 1
                )
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
            } catch {
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
                let durationMs = (DispatchTime.now().uptimeNanoseconds - queuedAt) / 1_000_000
                let outcome = PixivImageRequestLogContext.isCancellation(error) ? "cancelled" : "failed"
                Logger.network.error(
                    "image request \(outcome, privacy: .public) id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) segmented=true durationMs=\(durationMs) error=\(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        } else {
            let activeCount = await PixivImageRequestLimiter.shared.acquireWithCount()
            networkStartedAt = DispatchTime.now().uptimeNanoseconds
            let queueWaitMs = (networkStartedAt - queuedAt) / 1_000_000
            Logger.network.debug(
                "image request started id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) active=\(activeCount)/16 queueWaitMs=\(queueWaitMs)"
            )
            do {
                data = try await NetworkClient.shared.fetchImageData(from: url, headers: headers)
                activeAfter = await PixivImageRequestLimiter.shared.releaseWithCount()
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
            } catch {
                activeAfter = await PixivImageRequestLimiter.shared.releaseWithCount()
                if tracksVisibleActivity {
                    await PixivVisibleImageActivity.shared.end()
                }
                let durationMs = (DispatchTime.now().uptimeNanoseconds - networkStartedAt) / 1_000_000
                let outcome = PixivImageRequestLogContext.isCancellation(error) ? "cancelled" : "failed"
                Logger.network.error(
                    "image request \(outcome, privacy: .public) id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) segmented=false durationMs=\(durationMs) activeAfter=\(activeAfter ?? 0) error=\(error.localizedDescription, privacy: .public)"
                )
                throw error
            }
        }

        let completedAt = DispatchTime.now().uptimeNanoseconds
        let totalDurationMs = (completedAt - queuedAt) / 1_000_000
        let networkDurationMs = (completedAt - networkStartedAt) / 1_000_000
        Logger.network.info(
            "image request completed id=\(requestID, privacy: .public) imageKey=\(imageKey, privacy: .public) kind=\(requestKind, privacy: .public) role=\(requestRole, privacy: .public) domain=\(domain, privacy: .public) segmented=\(usesSegmentedDownload) bytes=\(data.count) totalDurationMs=\(totalDurationMs) networkDurationMs=\(networkDurationMs) activeAfter=\(activeAfter.map(String.init) ?? "child")"
        )
        return data
    }

}

extension ImageDataProvider where Self == DirectImageDataProvider {
    static func direct(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority,
        usesSegmentedDownload: Bool = false
    ) -> DirectImageDataProvider {
        DirectImageDataProvider(
            url: url,
            cacheKey: cacheKey,
            priority: priority,
            usesSegmentedDownload: usesSegmentedDownload
        )
    }
}

extension Source {
    nonisolated static func pixivNetwork(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) -> Source {
        guard let host = url.host,
              PixivNetworkConfiguration.isPixivImageHost(host) else {
            return .network(KF.ImageResource(downloadURL: url, cacheKey: cacheKey))
        }
        let usesSegmentedDownload = PixivNetworkConfiguration.isOriginalImageURL(url)
        guard usesSegmentedDownload || PixivNetworkConfiguration.isDirectMode else {
            return .network(KF.ImageResource(downloadURL: url, cacheKey: cacheKey))
        }
        return .provider(
            DirectImageDataProvider(
                url: url,
                cacheKey: cacheKey,
                priority: priority,
                usesSegmentedDownload: usesSegmentedDownload
            )
        )
    }

    nonisolated static func directNetwork(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) -> Source {
        .pixivNetwork(url, cacheKey: cacheKey, priority: priority)
    }
}
