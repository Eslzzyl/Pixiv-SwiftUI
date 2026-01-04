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
            return "标准模式"
        case .direct:
            return "直连模式"
        }
    }

    var description: String {
        switch self {
        case .normal:
            return "使用系统网络，需要代理环境"
        case .direct:
            return "直接连接 Pixiv 服务器，无需代理"
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
