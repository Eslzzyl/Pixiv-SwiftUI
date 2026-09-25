import Foundation
import Kingfisher
import os.log

final class DirectImageDataProvider: ImageDataProvider {
    let url: URL
    let cacheKey: String
    let priority: Float

    init(
        url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) {
        self.url = url
        self.cacheKey = cacheKey ?? url.absoluteString
        self.priority = priority
    }

    var contentURL: URL? {
        url
    }

    func data(handler: @escaping @Sendable (Result<Data, any Error>) -> Void) {
        let url = self.url
        let priority = self.priority
        let taskPriority: TaskPriority = {
            if priority <= ImageRequestPriority.prefetch {
                return .background
            }
            if priority >= ImageRequestPriority.visible {
                return .userInitiated
            }
            return .utility
        }()

        Task.detached(priority: taskPriority) {
            do {
                Logger.network.debug("开始加载: \(url.absoluteString)")
                let data = try await Self.downloadImageData(from: url)
                Logger.network.info("加载成功: \(url.absoluteString), bytes=\(data.count)")
                handler(.success(data))
            } catch {
                Logger.network.error("加载失败: \(url.absoluteString), error=\(error.localizedDescription)")
                handler(.failure(error))
            }
        }
    }

    private static func downloadImageData(from url: URL) async throws -> Data {
        guard let host = url.host else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        guard PixivNetworkConfiguration.isPixivImageHost(host) else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        let headers = [
            "Referer": "https://www.pixiv.net/",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15",
        ]

        let data: Data = try await NetworkClient.shared.get(
            from: url,
            headers: headers,
            responseType: Data.self,
            isLongContent: true
        )

        return data
    }
}

extension ImageDataProvider where Self == DirectImageDataProvider {
    static func direct(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) -> DirectImageDataProvider {
        DirectImageDataProvider(url: url, cacheKey: cacheKey, priority: priority)
    }
}

extension Source {
    static func directNetwork(
        _ url: URL,
        cacheKey: String? = nil,
        priority: Float = URLSessionTask.defaultPriority
    ) -> Source {
        .provider(DirectImageDataProvider(url: url, cacheKey: cacheKey, priority: priority))
    }
}
