import Foundation
import Kingfisher
import os.log

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
        usesSegmentedDownload: Bool
    ) async throws -> Data {
        Logger.network.debug("开始加载: \(url.absoluteString)")
        guard let host = url.host else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        guard PixivNetworkConfiguration.isPixivImageHost(host) else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        try Task.checkCancellation()
        let data: Data
        if usesSegmentedDownload {
            let concurrency = await MainActor.run {
                UserSettingStore.shared.userSetting.downloadConcurrency
            }
            data = try await NetworkClient.shared.concurrentDownloadData(
                from: url,
                headers: headers,
                concurrency: concurrency
            )
        } else {
            data = try await NetworkClient.shared.fetchImageData(from: url, headers: headers)
        }
        Logger.network.info("加载成功: \(url.absoluteString), bytes=\(data.count)")
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
