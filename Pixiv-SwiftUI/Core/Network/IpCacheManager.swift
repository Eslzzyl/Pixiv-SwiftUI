import Foundation

actor IpCacheManager {
    static let shared = IpCacheManager()

    private let memoryCache = NSCache<NSString, NSString>()
    private let userDefaults = UserDefaults.standard
    private let dohClient = DohClient.shared

    private let kIPCachePrefix = "pixiv_ip_cache_"
    private let kTTLPrefix = "pixiv_ttl_cache_"
    private let kDefaultCooldown: TimeInterval = 300

    private var expiryTime: [String: Date] = [:]

    private init() {
        memoryCache.countLimit = 20
    }

    private func cacheKey(for host: String) -> String {
        return "\(kIPCachePrefix)\(host)"
    }

    private func ttlKey(for host: String) -> String {
        return "\(kTTLPrefix)\(host)"
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

    func cacheIP(_ ip: String, for host: String, ttl: Int) {
        memoryCache.setObject(ip as NSString, forKey: cacheKey(for: host) as NSString)
        userDefaults.set(ip, forKey: cacheKey(for: host))

        let expiry = Date().addingTimeInterval(TimeInterval(ttl))
        expiryTime[host] = expiry
        userDefaults.set(expiry.timeIntervalSince1970, forKey: ttlKey(for: host))

        print("[IpCache] 更新缓存: \(host) -> \(ip), TTL: \(ttl)s, 过期时间: \(expiry)")
    }

    func getIP(for host: String) -> String? {
        return loadCachedIP(for: host)
    }

    func shouldRefresh(for host: String) -> Bool {
        if let expiry = expiryTime[host] {
            let should = Date() >= expiry
            if should {
                print("[IpCache] 缓存已过期 (内存): \(host)")
            } else {
                print("[IpCache] 缓存有效 (内存): \(host), 剩余: \(expiry.timeIntervalSinceNow)s")
            }
            return should
        }

        // 尝试从磁盘读取过期时间
        let diskExpiryValue = userDefaults.double(forKey: ttlKey(for: host))
        if diskExpiryValue > 0 {
            let expiry = Date(timeIntervalSince1970: diskExpiryValue)
            expiryTime[host] = expiry
            let should = Date() >= expiry
            if should {
                print("[IpCache] 缓存已过期 (磁盘): \(host)")
            } else {
                print("[IpCache] 缓存有效 (磁盘): \(host), 剩余: \(expiry.timeIntervalSinceNow)s")
            }
            return should
        }

        return true
    }

    func queryAndCacheIP(for host: String) async -> String? {
        print("[IpCache] 发起 DoH 查询: \(host)")
        guard let result = try? await dohClient.queryDNS(for: host) else {
            print("[IpCache] DoH 查询失败: \(host)")
            return nil
        }

        cacheIP(result.ip, for: host, ttl: result.ttl)
        return result.ip
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
        userDefaults.removeObject(forKey: ttlKey(for: host))
        expiryTime.removeValue(forKey: host)
        print("[IpCache] 清除缓存: \(host)")
    }

    func clearAllCache() {
        let hosts = PixivEndpoint.imageHosts
        for host in hosts {
            clearCache(for: host)
        }
    }
}
