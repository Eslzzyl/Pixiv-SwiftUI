import Foundation
import Kingfisher
import Network

enum CustomProxyProtocol: String, Codable, CaseIterable, Identifiable, Sendable {
    case httpConnect
    case socks5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .httpConnect:
            return String(localized: "HTTP CONNECT")
        case .socks5:
            return String(localized: "SOCKS5")
        }
    }
}

struct CustomProxyConfiguration: Codable, Equatable, Sendable {
    var protocolType: CustomProxyProtocol = .httpConnect
    var host = ""
    var port = 0
    var username = ""

    func validated() throws -> CustomProxyConfiguration {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty else {
            throw CustomProxyConfigurationError.emptyHost
        }

        guard (1...65535).contains(port) else {
            throw CustomProxyConfigurationError.invalidPort
        }

        return CustomProxyConfiguration(
            protocolType: protocolType,
            host: normalizedHost,
            port: port,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func makeNetworkProxy(password: String) -> ProxyConfiguration {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        var proxy: ProxyConfiguration
        switch protocolType {
        case .httpConnect:
            proxy = ProxyConfiguration(httpCONNECTProxy: endpoint)
        case .socks5:
            proxy = ProxyConfiguration(socksv5Proxy: endpoint)
        }

        if !username.isEmpty {
            proxy.applyCredential(username: username, password: password)
        }
        proxy.allowFailover = false
        proxy.matchDomains = PixivProxySessionConfiguration.proxiedDomains
        return proxy
    }
}

enum CustomProxyConfigurationError: LocalizedError {
    case emptyHost
    case invalidPort
    case incompleteCredentials

    var errorDescription: String? {
        switch self {
        case .emptyHost:
            return String(localized: "请输入代理服务器地址")
        case .invalidPort:
            return String(localized: "代理端口必须在 1 到 65535 之间")
        case .incompleteCredentials:
            return String(localized: "用户名和密码需要同时填写")
        }
    }
}

struct ActiveCustomProxy: Sendable {
    let configuration: CustomProxyConfiguration
    let password: String
}

enum PixivProxySessionConfiguration {
    static let proxiedDomains = [
        "oauth.secure.pixiv.net",
        "app-api.pixiv.net",
        "accounts.pixiv.net",
        "www.pixiv.net",
        "i.pximg.net",
        "s.pximg.net",
        "img-master.pixiv.net",
        "www.pixivision.net",
    ]

    static func apply(_ proxy: ActiveCustomProxy?, to configuration: URLSessionConfiguration) {
        guard let proxy else { return }
        configuration.proxyConfigurations = [
            proxy.configuration.makeNetworkProxy(password: proxy.password)
        ]
    }

    static func makeImageSessionConfiguration(proxy: ActiveCustomProxy?) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        apply(proxy, to: configuration)
        return configuration
    }

    @MainActor
    static func reconfigureKingfisherDownloader(proxy: ActiveCustomProxy?) {
        ImagePrefetchCoordinator.shared.stop()
        ImageDownloader.default.sessionConfiguration = makeImageSessionConfiguration(proxy: proxy)
    }
}

enum CustomProxyCredentialStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "Pixiv-SwiftUI") + ".custom-proxy"
    private static let account = "credentials"

    static func loadPassword() throws -> String {
        try KeychainHelper.load(service: service, account: account) ?? ""
    }

    static func savePassword(_ password: String) throws {
        if password.isEmpty {
            try KeychainHelper.delete(service: service, account: account)
        } else {
            try KeychainHelper.save(password, service: service, account: account)
        }
    }
}
