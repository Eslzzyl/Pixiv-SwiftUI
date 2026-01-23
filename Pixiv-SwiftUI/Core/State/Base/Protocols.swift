import Foundation

/// 网络服务协议
protocol NetworkService {
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T
}

/// 数据仓储协议
protocol Repository {
    func save<T: AnyObject>(_ entity: T) async throws
    func fetch<T: AnyObject>(_ predicate: Any?) async throws -> [T]
    func delete<T: AnyObject>(_ entity: T) async throws
}

/// 认证服务协议
protocol AuthService {
    func loginWithCode(_ code: String, codeVerifier: String) async throws -> (accessToken: String, refreshToken: String, user: User)
    func refreshAccessToken(_ refreshToken: String) async throws -> (accessToken: String, refreshToken: String, user: User)
}

/// 可观察对象协议
protocol ObservableService: Observable {
    func updateState(_ newState: Any)
}

/// 缓存服务协议
protocol CacheService {
    func get<T: Codable & Sendable>(_ key: String, type: T.Type) async throws -> T?
    func set<T: Codable & Sendable>(_ value: T, forKey key: String) async throws
    func remove(_ key: String) async throws
    func clearAll() async throws
}
