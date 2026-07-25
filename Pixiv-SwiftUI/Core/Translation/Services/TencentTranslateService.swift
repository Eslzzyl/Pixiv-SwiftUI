import Foundation
import CryptoKit

struct TencentTranslateConfig: Sendable {
    var secretId: String
    var secretKey: String
    var region: String
    var projectId: String
    var termRepoIds: [String]
    var sentRepoIds: [String]

    nonisolated init(
        secretId: String,
        secretKey: String,
        region: String = "ap-shanghai",
        projectId: String = "0",
        termRepoIds: [String] = [],
        sentRepoIds: [String] = []
    ) {
        self.secretId = secretId
        self.secretKey = secretKey
        self.region = region
        self.projectId = projectId
        self.termRepoIds = termRepoIds
        self.sentRepoIds = sentRepoIds
    }

    nonisolated static func parse(from secret: String) -> TencentTranslateConfig? {
        let parts = secret.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            return nil
        }
        return TencentTranslateConfig(
            secretId: parts[0],
            secretKey: parts[1],
            region: parts.count >= 3 ? parts[2] : "ap-shanghai",
            projectId: parts.count >= 4 ? parts[3] : "0"
        )
    }
}

final class TencentTranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id: String = "tencent"
    static let name: String? = "Tencent Translate"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = true
    static let defaultSecret: String? = "secretId#secretKey#region(optional)#projectId(optional)"

    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = { secret in
        let defaultSecret = "secretId#secretKey#region(optional)#projectId(optional)"

        guard let secret = secret, !secret.isEmpty else {
            return SecretValidationResult(
                secret: defaultSecret,
                status: false,
                info: "未设置密钥。腾讯翻译需要 SecretId 和 SecretKey，格式为 secretId#secretKey#region(optional)#projectId(optional)"
            )
        }

        guard let config = TencentTranslateConfig.parse(from: secret) else {
            return SecretValidationResult(
                secret: secret,
                status: false,
                info: "密钥格式错误。应为 secretId#secretKey#region(optional)#projectId(optional)，使用 '#' 分隔"
            )
        }

        let partsInfo = "SecretId: \(config.secretId)\nSecretKey: \(String(config.secretKey.prefix(8)))...\nRegion: \(config.region)\nProjectId: \(config.projectId)"

        return SecretValidationResult(
            secret: secret,
            status: secret != defaultSecret,
            info: secret == defaultSecret ? "未设置密钥" : partsInfo
        )
    }

    private let config: TencentTranslateConfig?

    init(
        config: TencentTranslateConfig? = nil,
        secret: String? = nil,
        networkClient: TranslationNetworkClient = TranslationNetworkClient()
    ) {
        self.config = config ?? secret.flatMap { TencentTranslateConfig.parse(from: $0) }
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        guard let config = self.config else {
            if let secret = task.secret {
                guard let parsedConfig = TencentTranslateConfig.parse(from: secret) else {
                    throw TranslateError.invalidSecretFormat(
                        "腾讯翻译密钥格式应为 secretId#secretKey#region(optional)#projectId(optional)，使用 '#' 分隔"
                    )
                }
                return try await translateWithConfig(parsedConfig, task: &task)
            }
            throw TranslateError.missingSecret
        }
        try await translateWithConfig(config, task: &task)
    }

    private func translateWithConfig(_ config: TencentTranslateConfig, task: inout TranslateTask) async throws {
        let sourceLang = LanguageMap.mapForTencent(task.sourceLanguage)
        let targetLang = LanguageMap.mapForTencent(task.targetLanguage)

        let timestamp = String(String(Int(Date().timeIntervalSince1970)).prefix(10))
        let nonce = "9744"

        var params: [String: String] = [
            "Action": "TextTranslate",
            "Language": "zh-CN",
            "Nonce": nonce,
            "ProjectId": config.projectId,
            "Region": config.region,
            "SecretId": config.secretId,
            "Source": sourceLang,
            "SourceText": "#$#",
            "Target": targetLang,
            "Timestamp": timestamp,
            "Version": "2018-03-21"
        ]

        for (index, repoId) in config.termRepoIds.enumerated() {
            params["TermRepoIDList.\(index)"] = repoId
        }

        for (index, repoId) in config.sentRepoIds.enumerated() {
            params["SentRepoIDList.\(index)"] = repoId
        }

        let sortedKeys = params.keys.sorted()
        let rawStr = sortedKeys.map { key in
            "\(key)=\(params[key, default: ""])"
        }.joined(separator: "&")

        let stringToSign = "POST&%2F&\(encodeRFC3986URIComponent(rawStr))"
        let signature = generateSignature(stringToSign: stringToSign, secretKey: config.secretKey)

        let bodyString = rawStr.replacingOccurrences(of: "#$#", with: encodeRFC3986URIComponent(task.raw)) + "&Signature=\(encodeRFC3986URIComponent(signature))"
        let bodyData = bodyString.data(using: .utf8)

        guard let url = URL(string: "https://tmt.tencentcloudapi.com") else {
            throw TranslateError.invalidURL
        }

        let (responseData, response) = try await networkClient.post(url: url, body: bodyData, headers: ["Content-Type": "application/json"])

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let responseObj = try JSONDecoder().decode(TencentResponse.self, from: responseData)

        if let error = responseObj.Response.Error {
            throw TranslateError.apiError("\(error.Code): \(error.Message)")
        }

        task.result = responseObj.Response.TargetText
        task.status = .success
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

    private func generateSignature(stringToSign: String, secretKey: String) -> String {
        guard let keyData = (secretKey + "&").data(using: .utf8),
              let signData = stringToSign.data(using: .utf8) else {
            return ""
        }
        let key = SymmetricKey(data: keyData)
        let signature = HMAC<Insecure.SHA1>.authenticationCode(for: signData, using: key)
        return Data(signature).base64EncodedString()
    }
}

// swiftlint:disable identifier_name
private struct TencentResponse: Decodable {
    let Response: TencentResponseBody
}

private struct TencentResponseBody: Decodable {
    let TargetText: String
    let Error: TencentError?
}

private struct TencentError: Decodable {
    let Code: String
    let Message: String
}
// swiftlint:enable identifier_name
