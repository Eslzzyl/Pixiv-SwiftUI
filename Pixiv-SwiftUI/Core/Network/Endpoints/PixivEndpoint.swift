import Foundation

enum PixivEndpoint {
    case oauth
    case api
    case accounts
    case image

    nonisolated var host: String {
        switch self {
        case .oauth:
            return "oauth.secure.pixiv.net"
        case .api:
            return "app-api.pixiv.net"
        case .accounts:
            return "accounts.pixiv.net"
        case .image:
            return "i.pximg.net"
        }
    }

    nonisolated var ips: [String] {
        switch self {
        case .oauth:
            return [
                "210.140.139.154",
                "210.140.139.155",
                "210.140.139.156",
                "210.140.139.157",
                "210.140.139.158",
                "210.140.139.159",
                "210.140.139.160",
                "210.140.139.161",
                "210.140.139.162"
            ]
        case .api:
            return [
                "210.140.139.154",
                "210.140.139.155",
                "210.140.139.156",
                "210.140.139.157",
                "210.140.139.158",
                "210.140.139.159",
                "210.140.139.160",
                "210.140.139.161",
                "210.140.139.162"
            ]
        case .accounts:
            return [
                "210.140.139.154",
                "210.140.139.155",
                "210.140.139.156",
                "210.140.139.157",
                "210.140.139.158",
                "210.140.139.159",
                "210.140.139.160",
                "210.140.139.161",
                "210.140.139.162"
            ]
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
        }
    }

    nonisolated var port: Int {
        return 443
    }

    nonisolated static let imageHosts = ["i.pximg.net", "s.pximg.net"]

    /// 获取可用的 IP 列表（优先使用缓存，失败则使用内置列表）
    func getIPList() async -> [String] {
        if self == .image {
            if let cached = await IpCacheManager.shared.getIP(for: host) {
                // 将缓存的 IP 放在第一位，后面跟着内置的 IPs 作为备选
                var list = [cached]
                for ip in ips {
                    if ip != cached {
                        list.append(ip)
                    }
                }
                return list
            }
        }
        return ips
    }
}
