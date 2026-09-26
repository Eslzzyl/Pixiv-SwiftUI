import Foundation
import Kingfisher

final class PixivImageLoader: ImageDownloadRequestModifier {
    func modified(for request: URLRequest) -> URLRequest? {
        var req = request
        req.setValue("https://www.pixiv.net", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        if PixivNetworkConfiguration.isDirectMode,
           let host = req.url?.host,
           PixivNetworkConfiguration.isPixivHost(host) {
            req.assumesHTTP3Capable = true
        }
        return req
    }

    static let shared = PixivImageLoader()
}

extension KingfisherOptionsInfoItem {
    static let pixivModifier = KingfisherOptionsInfoItem.requestModifier(PixivImageLoader.shared)
}
