import Foundation
import Kingfisher

final class DirectImageDataProvider: ImageDataProvider {
    let url: URL
    let cacheKey: String

    private let loadingQueue = DispatchQueue(label: "com.pixiv.directImageProvider", qos: .userInitiated)

    init(url: URL, cacheKey: String? = nil) {
        self.url = url
        self.cacheKey = cacheKey ?? url.absoluteString
    }

    var contentURL: URL? {
        url
    }

    func data(handler: @escaping @Sendable (Result<Data, any Error>) -> Void) {
        loadingQueue.async {
            Task {
                do {
                    let data = try await self.downloadImageData()
                    handler(.success(data))
                } catch {
                    handler(.failure(error))
                }
            }
        }
    }

    private func downloadImageData() async throws -> Data {
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

        let path = url.path
        let query = url.query.map { "?\($0)" } ?? ""
        let fullPath = path + query

        var headers = [String: String]()
        headers["Referer"] = "https://www.pixiv.net/"
        headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15"

        let (data, response) = try await DirectConnection.shared.request(
            endpoint: endpoint,
            path: fullPath,
            method: "GET",
            headers: headers
        )

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
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
