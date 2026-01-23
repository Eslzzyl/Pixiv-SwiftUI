import Foundation

/// 依赖注入容器
class DIContainer {
    static let shared = DIContainer()

    private init() {}

    // MARK: - Network Services

    lazy var networkService: NetworkService = NetworkServiceImpl()
    lazy var authService: AuthService = AuthServiceImpl()

    // MARK: - Cache Services

    lazy var cacheService: CacheService = CacheServiceImpl()
}

// MARK: - Service Implementations

/// 网络服务实现
class NetworkServiceImpl: NetworkService {
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        preconditionFailure("NetworkServiceImpl.request not implemented")
    }
}

/// 认证服务实现
class AuthServiceImpl: AuthService {
    func loginWithCode(_ code: String, codeVerifier: String) async throws -> (accessToken: String, refreshToken: String, user: User) {
        return try await PixivAPI.shared.loginWithCode(code, codeVerifier: codeVerifier)
    }

    func refreshAccessToken(_ refreshToken: String) async throws -> (accessToken: String, refreshToken: String, user: User) {
        return try await PixivAPI.shared.refreshAccessToken(refreshToken)
    }
}

/// 缓存服务实现
class CacheServiceImpl: CacheService {
    private let cache = NSCache<NSString, AnyObject>()

    func get<T: Codable & Sendable>(_ key: String, type: T.Type) async throws -> T? {
        guard let object = cache.object(forKey: key as NSString) as? T else {
            return nil
        }
        return object
    }

    func set<T: Codable & Sendable>(_ value: T, forKey key: String) async throws {
        cache.setObject(value as AnyObject, forKey: key as NSString)
    }

    func remove(_ key: String) async throws {
        cache.removeObject(forKey: key as NSString)
    }

    func clearAll() async throws {
        cache.removeAllObjects()
    }
}
