import Foundation
import CryptoKit

struct YoudaoZhiyunConfig: Sendable {
    var appid: String
    var appKey: String
    var vocabId: String?
    var domain: String

    nonisolated init(appid: String, appKey: String, vocabId: String? = nil, domain: String = "general") {
        self.appid = appid
        self.appKey = appKey
        self.vocabId = vocabId
        self.domain = domain
    }

    nonisolated static func parse(from secret: String) -> YoudaoZhiyunConfig? {
        let parts = secret.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }
        return YoudaoZhiyunConfig(
            appid: parts[0],
            appKey: parts[1],
            vocabId: parts.count >= 3 ? parts[2] : nil
        )
    }
}

final class YoudaoZhiyunService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id: String = "youdaozhiyun"
    static let name: String? = "Youdao Zhiyun"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = true
    static let defaultSecret: String? = "appid#appKey#vocabId(optional)"

    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = { secret in
        let defaultSecret = "appid#appKey#vocabId(optional)"

        guard let secret = secret, !secret.isEmpty else {
            return SecretValidationResult(
                secret: defaultSecret,
                status: false,
                info: "未设置密钥。有道智云需要 AppID 和 AppKey，格式为 appid#appKey#vocabId(optional)"
            )
        }

        guard let config = YoudaoZhiyunConfig.parse(from: secret) else {
            return SecretValidationResult(
                secret: secret,
                status: false,
                info: "密钥格式错误。应为 appid#appKey#vocabId(optional)，使用 '#' 分隔"
            )
        }

        let partsInfo = "AppID: \(config.appid)\nAppKey: \(String(config.appKey.prefix(8)))...\nVocabID: \(config.vocabId ?? "未设置")"

        return SecretValidationResult(
            secret: secret,
            status: secret != defaultSecret,
            info: secret == defaultSecret ? "未设置密钥" : partsInfo
        )
    }

    private let config: YoudaoZhiyunConfig?

    init(
        config: YoudaoZhiyunConfig? = nil,
        secret: String? = nil,
        networkClient: TranslationNetworkClient = TranslationNetworkClient()
    ) {
        self.config = config ?? secret.flatMap { YoudaoZhiyunConfig.parse(from: $0) }
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        guard let config = self.config else {
            if let secret = task.secret {
                guard let parsedConfig = YoudaoZhiyunConfig.parse(from: secret) else {
                    throw TranslateError.invalidSecretFormat(
                        "有道智云密钥格式应为 appid#appKey#vocabId(optional)，使用 '#' 分隔"
                    )
                }
                return try await translateWithConfig(parsedConfig, task: &task)
            }
            throw TranslateError.missingSecret
        }
        try await translateWithConfig(config, task: &task)
    }

    private func translateWithConfig(_ config: YoudaoZhiyunConfig, task: inout TranslateTask) async throws {
        let sourceLang = LanguageMap.mapForYoudao(task.sourceLanguage)
        let targetLang = LanguageMap.mapForYoudao(task.targetLanguage)

        let salt = String(Int(Date().timeIntervalSince1970 * 1000))
        let curtime = String(Int(Date().timeIntervalSince1970))
        let truncatedQuery = truncate(task.raw)

        let signInput = config.appid + truncatedQuery + salt + curtime + config.appKey
        let sign = generateSHA256(signInput)

        guard var urlComponents = URLComponents(string: "https://openapi.youdao.com/api") else {
            throw TranslateError.invalidURL
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: encodeRFC3986URIComponent(task.raw)),
            URLQueryItem(name: "appKey", value: config.appid),
            URLQueryItem(name: "salt", value: salt),
            URLQueryItem(name: "from", value: sourceLang),
            URLQueryItem(name: "to", value: targetLang),
            URLQueryItem(name: "sign", value: sign),
            URLQueryItem(name: "signType", value: "v3"),
            URLQueryItem(name: "curtime", value: curtime),
            URLQueryItem(name: "vocabId", value: config.vocabId),
            URLQueryItem(name: "domain", value: config.domain)
        ]

        guard let url = urlComponents.url else {
            throw TranslateError.invalidURL
        }

        let (responseData, response) = try await networkClient.get(url: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let responseObj = try JSONDecoder().decode(YoudaoResponse.self, from: responseData)

        let errorCode = Int(responseObj.errorCode) ?? 0
        guard errorCode == 0 else {
            throw TranslateError.apiError("有道智云错误 \(errorCode)")
        }

        guard let translations = responseObj.translation, !translations.isEmpty else {
            throw TranslateError.parsingError
        }

        task.result = translations.joined()
        task.status = .success
    }

    private func truncate(_ query: String) -> String {
        guard query.count > 20 else { return query }
        return String(query.prefix(10)) + String(query.count) + String(query.suffix(10))
    }

    private func generateSHA256(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func encodeRFC3986URIComponent(_ str: String) -> String {
        return str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)?
            .replacingOccurrences(of: "!", with: "%21")
            .replacingOccurrences(of: "'", with: "%27")
            .replacingOccurrences(of: "(", with: "%28")
            .replacingOccurrences(of: ")", with: "%29")
            .replacingOccurrences(of: "*", with: "%2A")
            .replacingOccurrences(of: "%20", with: "+") ?? str
    }
}

private struct YoudaoResponse: Decodable {
    let errorCode: String
    let translation: [String]?
}
