import Foundation

enum PixivNetworkConfiguration {
    nonisolated static var isDirectMode: Bool {
        let rawValue = UserDefaults.standard.string(forKey: "networkMode") ?? NetworkMode.direct.rawValue
        return rawValue == NetworkMode.direct.rawValue
    }

    nonisolated static func isPixivHost(_ host: String) -> Bool {
        hostMatchesDomain(host, domain: "pixiv.net")
            || hostMatchesDomain(host, domain: "pximg.net")
            || hostMatchesDomain(host, domain: "pixivision.net")
    }

    nonisolated static func isPixivImageHost(_ host: String) -> Bool {
        hostMatchesDomain(host, domain: "pximg.net")
            || hostMatchesDomain(host, domain: "img-master.pixiv.net")
    }

    nonisolated static func isPixivArtworkHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return normalized == "i.pximg.net"
            || normalized.hasSuffix(".i.pximg.net")
            || normalized == "img-master.pixiv.net"
    }

    nonisolated static func isHTTP3ImageRelayHost(_ host: String) -> Bool {
        host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() == PixivImageDomain.http3Relay.host
    }

    nonisolated static func supportsHTTP3DirectConnection(host: String) -> Bool {
        (isPixivHost(host) && !isPixivImageHost(host)) || isHTTP3ImageRelayHost(host)
    }

    nonisolated static func routedImageURL(from sourceURL: URL) -> URL {
        guard PixivImageDomain.selected == .http3Relay,
              let sourceHost = sourceURL.host,
              isPixivArtworkHost(sourceHost),
              var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else {
            return sourceURL
        }

        components.host = PixivImageDomain.http3Relay.host
        return components.url ?? sourceURL
    }

    private nonisolated static func hostMatchesDomain(_ host: String, domain: String) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return normalizedHost == domain || normalizedHost.hasSuffix(".\(domain)")
    }
}
