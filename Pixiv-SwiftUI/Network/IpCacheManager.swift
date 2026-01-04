import Foundation

final class IpCacheManager {
    static let shared = IpCacheManager()

    private let memoryCache = NSCache<NSString, NSString>()
    private let userDefaults = UserDefaults.standard
    private let dohClient = DohClient.shared

    private let kIPCachePrefix = "pixiv_ip_cache_"
    private let kRefreshCooldown: TimeInterval = 300

    private var lastRefreshTime: [String: Date] = [:]

    private init() {
        memoryCache.countLimit = 20
    }

    private func cacheKey(for host: String) -> String {
        return "\(kIPCachePrefix)\(host)"
    }

    func loadCachedIP(for host: String) -> String? {
        if let cached = memoryCache.object(forKey: cacheKey(for: host) as NSString) as String? {
            print("[IpCache] 内存缓存命中: \(host) -> \(cached)")
            return cached
        }

        if let userDefaultsIP = userDefaults.string(forKey: cacheKey(for: host)) {
            memoryCache.setObject(userDefaultsIP as NSString, forKey: cacheKey(for: host) as NSString)
            print("[IpCache] 磁盘缓存命中: \(host) -> \(userDefaultsIP)")
            return userDefaultsIP
        }

        print("[IpCache] 缓存未命中: \(host)")
        return nil
    }

    func cacheIP(_ ip: String, for host: String) {
        memoryCache.setObject(ip as NSString, forKey: cacheKey(for: host) as NSString)
        userDefaults.set(ip, forKey: cacheKey(for: host))
        print("[IpCache] 更新缓存: \(host) -> \(ip)")
    }

    func getIP(for host: String) -> String? {
        return loadCachedIP(for: host)
    }

    func shouldRefresh(for host: String) -> Bool {
        guard let lastTime = lastRefreshTime[host] else {
            return true
        }
        let should = Date().timeIntervalSince(lastTime) >= kRefreshCooldown
        if should {
            print("[IpCache] 缓存已过期: \(host)")
        } else {
            print("[IpCache] 缓存有效: \(host)")
        }
        return should
    }

    func queryAndCacheIP(for host: String) async -> String? {
        print("[IpCache] 发起 DoH 查询: \(host)")
        guard let ip = try? await dohClient.queryDNS(for: host) else {
            print("[IpCache] DoH 查询失败: \(host)")
            return nil
        }

        cacheIP(ip, for: host)
        lastRefreshTime[host] = Date()
        return ip
    }

    func getIPWithRefresh(for host: String) async -> String? {
        if let cached = loadCachedIP(for: host), !shouldRefresh(for: host) {
            return cached
        }

        return await queryAndCacheIP(for: host)
    }

    func refreshAllIfNeeded() async {
        print("[IpCache] 检查是否需要刷新 DNS 缓存")
        let hosts = PixivEndpoint.imageHosts
        for host in hosts {
            if shouldRefresh(for: host) {
                print("[IpCache] 需要刷新: \(host)")
                _ = await queryAndCacheIP(for: host)
            }
        }
    }

    func refreshAll() async {
        print("[IpCache] 刷新所有 DNS 缓存")
        let hosts = PixivEndpoint.imageHosts
        for host in hosts {
            _ = await queryAndCacheIP(for: host)
        }
    }

    func clearCache(for host: String) {
        memoryCache.removeObject(forKey: cacheKey(for: host) as NSString)
        userDefaults.removeObject(forKey: cacheKey(for: host))
        lastRefreshTime.removeValue(forKey: host)
        print("[IpCache] 清除缓存: \(host)")
    }

    func clearAllCache() {
        let hosts = PixivEndpoint.imageHosts
        for host in hosts {
            clearCache(for: host)
        }
    }
}

extension PixivEndpoint {
    static let imageHosts = ["i.pximg.net", "s.pximg.net"]

    var defaultIPs: [String] {
        switch self {
        case .image:
            return [
                "210.140.139.131",
                "210.140.139.132",
                "210.140.139.133",
                "210.140.139.134",
                "210.140.139.135",
                "210.140.139.136",
                "210.140.92.141",
                "210.140.92.142",
                "210.140.92.143",
                "210.140.92.144",
                "210.140.92.145",
                "210.140.92.146",
                "210.140.92.148",
                "210.140.92.149"
            ]
        default:
            return ips
        }
    }

    func getIPList() -> [String] {
        guard self == .image else {
            return ips
        }

        if let cachedIP = IpCacheManager.shared.getIP(for: host) {
            return [cachedIP] + defaultIPs
        }

        return defaultIPs
    }
}
