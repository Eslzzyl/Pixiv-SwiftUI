import Foundation
import Kingfisher
import os.log

final class DirectImageDataProvider: ImageDataProvider {
    let url: URL
    let cacheKey: String

    init(url: URL, cacheKey: String? = nil) {
        self.url = url
        self.cacheKey = cacheKey ?? url.absoluteString
    }

    var contentURL: URL? {
        url
    }

    func data(handler: @escaping @Sendable (Result<Data, any Error>) -> Void) {
        let url = self.url
        Task.detached(priority: .userInitiated) {
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

        let endpoint: PixivEndpoint
        if host.contains("i.pximg.net") {
            endpoint = .image
        } else if host.contains("img-master.pixiv.net") {
            endpoint = .image
        } else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        let path = url.path(percentEncoded: true)
        let query = url.query(percentEncoded: true).map { "?\($0)" } ?? ""
        let fullPath = path + query

        var headers = [String: String]()
        headers["Referer"] = "https://www.pixiv.net/"
        headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15"

        let (data, httpResponse) = try await DirectConnection.shared.request(
            endpoint: endpoint,
            path: fullPath,
            method: "GET",
            headers: headers
        )

        guard (200...299).contains(httpResponse.statusCode) else {
            throw KingfisherError.imageSettingError(reason: .emptySource)
        }

        return data
    }
}

extension ImageDataProvider where Self == DirectImageDataProvider {
    static func direct(_ url: URL, cacheKey: String? = nil) -> DirectImageDataProvider {
        DirectImageDataProvider(url: url, cacheKey: cacheKey)
    }
}

extension Source {
    static func directNetwork(_ url: URL, cacheKey: String? = nil) -> Source {
        .provider(DirectImageDataProvider(url: url, cacheKey: cacheKey))
    }
}
