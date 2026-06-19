import Foundation
import CryptoKit

struct BaiduTranslateConfig: Sendable {
    var appid: String
    var key: String
    var action: String

    nonisolated init(appid: String, key: String, action: String = "0") {
        self.appid = appid
        self.key = key
        self.action = action
    }

    nonisolated static func parse(from secret: String) -> BaiduTranslateConfig? {
        let parts = secret.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }
        return BaiduTranslateConfig(
            appid: parts[0],
            key: parts[1],
            action: parts.count >= 3 ? parts[2] : "0"
        )
    }
}

final class BaiduTranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id: String = "baidu"
    static let name: String? = "Baidu Translate"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = true
    static let defaultSecret: String? = "appid#key"

    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = { secret in
        let defaultSecret = "appid#key"

        guard let secret = secret, !secret.isEmpty else {
            return SecretValidationResult(
                secret: defaultSecret,
                status: false,
                info: "未设置密钥。百度翻译需要 AppID 和 Key，格式为 AppID#Key"
            )
        }

        guard let config = BaiduTranslateConfig.parse(from: secret) else {
            return SecretValidationResult(
                secret: secret,
                status: false,
                info: "密钥格式错误。应为 AppID#Key#Action(optional)，使用 '#' 分隔"
            )
        }

        return SecretValidationResult(
            secret: secret,
            status: true,
            info: "AppID: \(config.appid)\nKey: \(config.key)\nAction: \(config.action)"
        )
    }

    private let config: BaiduTranslateConfig?

    init(
        config: BaiduTranslateConfig? = nil,
        secret: String? = nil,
        networkClient: TranslationNetworkClient = TranslationNetworkClient()
    ) {
        self.config = config ?? secret.flatMap { BaiduTranslateConfig.parse(from: $0) }
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        guard let config = self.config else {
            if let secret = task.secret {
                guard let parsedConfig = BaiduTranslateConfig.parse(from: secret) else {
                    throw TranslateError.invalidSecretFormat(
                        "百度翻译密钥格式应为 AppID#Key#Action(optional)，使用 '#' 分隔"
                    )
                }
                return try await translateWithConfig(parsedConfig, task: &task)
            }
            throw TranslateError.missingSecret
        }
        try await translateWithConfig(config, task: &task)
    }

    private func translateWithConfig(_ config: BaiduTranslateConfig, task: inout TranslateTask) async throws {
        let salt = String(Int(Date().timeIntervalSince1970 * 1000))
        let sign = generateMD5(config.appid + task.raw + salt + config.key)

        let sourceLang = normalizeLanguage(task.sourceLanguage)
        let targetLang = normalizeLanguage(task.targetLanguage)

        let url = URL(string: "https://fanyi-api.baidu.com/api/trans/vip/translate")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let encodedText = task.raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? task.raw
        let body = "q=\(encodedText)&appid=\(config.appid)&from=\(sourceLang)&to=\(targetLang)&salt=\(salt)&sign=\(sign)&action=\(config.action)&needIntervene=1"
        request.httpBody = body.data(using: .utf8)

        let (responseData, _) = try await networkClient.post(url: url, body: request.httpBody, headers: ["Content-Type": "application/x-www-form-urlencoded"])

        let response = try JSONDecoder().decode(BaiduResponse.self, from: responseData)

        if let errorCode = response.error_code {
            throw TranslateError.apiError("\(errorCode): \(response.error_msg ?? "Unknown error")")
        }

        guard let transResult = response.trans_result, !transResult.isEmpty else {
            throw TranslateError.parsingError
        }

        task.result = transResult.map { $0.dst }.joined()
    }

    private func generateMD5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func normalizeLanguage(_ code: String?) -> String {
        guard let code = code, !code.isEmpty else { return "auto" }
        return LanguageMap.mapForBaidu(code)
    }
}

// swiftlint:disable identifier_name
private struct BaiduResponse: Decodable {
    let from: String?
    let to: String?
    let trans_result: [BaiduTransResult]?
    let error_code: String?
    let error_msg: String?
}
// swiftlint:enable identifier_name

private struct BaiduTransResult: Decodable {
    let src: String
    let dst: String
}
