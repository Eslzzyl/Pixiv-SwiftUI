import Foundation

actor DohClient {
    static let shared = DohClient()

    private let dohBaseURL = "https://v.recipes/dns-query"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        ]
        self.session = URLSession(configuration: config)
    }

    func queryDNS(for host: String) async throws -> (ip: String, ttl: Int)? {
        print("[DoH] 查询域名: \(host)")

        guard let url = URL(string: "\(dohBaseURL)/resolve") else {
            print("[DoH] 无效的 URL: \(dohBaseURL)/resolve")
            return nil
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "name", value: host),
            URLQueryItem(name: "type", value: "1")
        ]

        guard let finalURL = components?.url else {
            print("[DoH] 无法构建查询 URL")
            return nil
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue("application/dns-json", forHTTPHeaderField: "accept")

        do {
            let (data, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            guard statusCode == 200 else {
                print("[DoH] 请求失败，状态码: \(statusCode)")
                return nil
            }

            let dohResponse = try JSONDecoder().decode(DohNetworkResponse.self, from: data)

            if let status = dohResponse.status, status != 0 {
                print("[DoH] DNS 查询返回错误状态码: \(status)")
                return nil
            }

            guard let answers = dohResponse.answer, !answers.isEmpty else {
                print("[DoH] 无 DNS 记录返回")
                return nil
            }

            let validAnswers = answers.filter { $0.checkIsValidIPv4() }

            let sortedAnswers = validAnswers.sorted { lhs, rhs in
                let lhsTTL = lhs.TTL ?? 0
                let rhsTTL = rhs.TTL ?? 0
                return lhsTTL > rhsTTL
            }

            guard let firstAnswer = sortedAnswers.first else {
                print("[DoH] 无有效 IP 地址")
                return nil
            }

            let ttl = firstAnswer.TTL ?? 300
            print("[DoH] 选择 IP: \(firstAnswer.data), TTL: \(ttl)")

            return (firstAnswer.data, ttl)
        } catch {
            print("[DoH] 查询失败: \(error.localizedDescription)")
            throw error
        }
    }
}
