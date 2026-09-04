import Foundation
import SwiftUI
import Combine
import Observation

enum NetworkMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case direct
    case customProxy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:
            return String(localized: "标准模式")
        case .direct:
            return String(localized: "直连模式")
        case .customProxy:
            return String(localized: "自定义代理")
        }
    }

    var description: String {
        switch self {
        case .normal:
            return String(localized: "依赖系统 VPN 连接 Pixiv。")
        case .direct:
            return String(localized: "通过绕过 SNI 嗅探来实现免代理直连 Pixiv。")
        case .customProxy:
            return String(localized: "仅通过指定的 HTTP CONNECT 或 SOCKS5 代理访问 Pixiv。")
        }
    }

    var iconName: String {
        switch self {
        case .normal:
            return "network"
        case .direct:
            return "wifi"
        case .customProxy:
            return "point.3.connected.trianglepath.dotted"
        }
    }
}

@Observable
final class NetworkModeStore {
    static let shared = NetworkModeStore()

    var currentMode: NetworkMode {
        didSet {
            guard currentMode != .customProxy || hasUsableCustomProxyConfiguration else {
                currentMode = oldValue
                return
            }
            UserDefaults.standard.set(currentMode.rawValue, forKey: networkModeKey)
            Task {
                await DirectConnectionPool.shared.removeAll()
            }
            CacheManager.shared.clearAll()
            PixivProxySessionConfiguration.reconfigureKingfisherDownloader(proxy: activeCustomProxy)
            NotificationCenter.default.post(name: .networkModeDidChange, object: nil)
            NotificationCenter.default.post(name: .refreshCurrentPage, object: nil)
        }
    }

    private(set) var customProxyConfiguration: CustomProxyConfiguration?

    private let networkModeKey = "networkMode"
    private let customProxyConfigurationKey = "customProxyConfiguration"
    private var customProxyPassword = ""

    init() {
        let savedConfiguration = Self.loadCustomProxyConfiguration()
        let savedPassword = (try? CustomProxyCredentialStore.loadPassword()) ?? ""
        let customProxyIsAvailable = savedConfiguration.map { configuration in
            configuration.username.isEmpty || !savedPassword.isEmpty
        } ?? false
        customProxyConfiguration = savedConfiguration
        customProxyPassword = savedPassword

        if let rawValue = UserDefaults.standard.string(forKey: networkModeKey),
           let mode = NetworkMode(rawValue: rawValue) {
            currentMode = mode == .customProxy && !customProxyIsAvailable ? .normal : mode
        } else {
            currentMode = .direct
        }
        UserDefaults.standard.set(currentMode.rawValue, forKey: networkModeKey)

        PixivProxySessionConfiguration.reconfigureKingfisherDownloader(proxy: activeCustomProxy)
    }

    func setMode(_ mode: NetworkMode) {
        currentMode = mode
    }

    func saveCustomProxyConfiguration(
        _ configuration: CustomProxyConfiguration,
        password: String
    ) throws {
        let validatedConfiguration = try configuration.validated()
        guard validatedConfiguration.username.isEmpty == password.isEmpty else {
            throw CustomProxyConfigurationError.incompleteCredentials
        }

        try CustomProxyCredentialStore.savePassword(password)
        let data = try JSONEncoder().encode(validatedConfiguration)
        UserDefaults.standard.set(data, forKey: customProxyConfigurationKey)
        customProxyConfiguration = validatedConfiguration
        customProxyPassword = password
        currentMode = .customProxy
    }

    func toggleMode() {
        currentMode = currentMode == .normal ? .direct : .normal
    }

    var useDirectConnection: Bool {
        currentMode == .direct
    }

    var activeCustomProxy: ActiveCustomProxy? {
        guard currentMode == .customProxy,
              hasUsableCustomProxyConfiguration,
              let customProxyConfiguration else {
            return nil
        }
        return ActiveCustomProxy(configuration: customProxyConfiguration, password: customProxyPassword)
    }

    var hasUsableCustomProxyConfiguration: Bool {
        guard let customProxyConfiguration else { return false }
        return customProxyConfiguration.username.isEmpty || !customProxyPassword.isEmpty
    }

    func loadCustomProxyPassword() -> String {
        customProxyPassword
    }

    private static func loadCustomProxyConfiguration() -> CustomProxyConfiguration? {
        guard let data = UserDefaults.standard.data(forKey: "customProxyConfiguration"),
              let configuration = try? JSONDecoder().decode(CustomProxyConfiguration.self, from: data),
              let validatedConfiguration = try? configuration.validated() else {
            return nil
        }
        return validatedConfiguration
    }
}

struct NetworkModeKey: EnvironmentKey {
    static let defaultValue: NetworkModeStore = .shared
}

extension EnvironmentValues {
    var networkModeStore: NetworkModeStore {
        get { self[NetworkModeKey.self] }
        set { self[NetworkModeKey.self] = newValue }
    }
}
