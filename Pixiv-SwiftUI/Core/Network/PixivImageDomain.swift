import Foundation

enum PixivImageDomain: String, CaseIterable, Identifiable, Sendable {
    case pixivOrigin = "pixiv-origin"
    case http3Relay = "http3-relay"

    nonisolated static let userDefaultsKey = "pixivImageDomain"

    nonisolated static var selected: PixivImageDomain {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
        return rawValue.flatMap(PixivImageDomain.init(rawValue:)) ?? .pixivOrigin
    }

    var id: String { rawValue }

    nonisolated var host: String {
        switch self {
        case .pixivOrigin:
            "i.pximg.net"
        case .http3Relay:
            "i.pixiv.re"
        }
    }

    var displayName: String {
        switch self {
        case .pixivOrigin:
            String(localized: "Pixiv 官方源（i.pximg.net）")
        case .http3Relay:
            String(localized: "i.pixiv.re（HTTP/3 中转）")
        }
    }

    var description: String {
        switch self {
        case .pixivOrigin:
            String(localized: "沿用 Pixiv 官方图片连接路径。")
        case .http3Relay:
            String(localized: "直连模式通过 i.pixiv.re 使用 HTTP/3；图片请求经第三方中转。")
        }
    }
}
