import Foundation
import SwiftUI
import Combine

enum NetworkMode: String, Codable, CaseIterable, Identifiable {
    case normal
    case direct

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .normal:
            return String(localized: "标准模式")
        case .direct:
            return String(localized: "直连模式")
        }
    }

    var description: String {
        switch self {
        case .normal:
            return String(localized: "依赖系统 VPN 连接 Pixiv。")
        case .direct:
            return String(localized: "通过绕过 SNI 嗅探来实现免代理直连 Pixiv。")
        }
    }

    var iconName: String {
        switch self {
        case .normal:
            return "network"
        case .direct:
            return "wifi"
        }
    }
}

final class NetworkModeStore: ObservableObject {
    static let shared = NetworkModeStore()

    @Published var currentMode: NetworkMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: networkModeKey)
        }
    }

    private let networkModeKey = "networkMode"

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: networkModeKey),
           let mode = NetworkMode(rawValue: rawValue) {
            self.currentMode = mode
        } else {
            self.currentMode = .normal
        }
    }

    func setMode(_ mode: NetworkMode) {
        currentMode = mode
    }

    func toggleMode() {
        currentMode = currentMode == .normal ? .direct : .normal
    }

    var useDirectConnection: Bool {
        currentMode == .direct
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
