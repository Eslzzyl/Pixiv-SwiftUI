import Foundation

struct DeepLConfig: Sendable {
    var apiKey: String
    var glossaryId: String?

    nonisolated init(apiKey: String, glossaryId: String? = nil) {
        self.apiKey = apiKey
        self.glossaryId = glossaryId
    }

    nonisolated static func parse(from secret: String) -> DeepLConfig? {
        let parts = secret.split(separator: "#", omittingEmptySubsequences: false).map(String.init)
        guard !parts[0].isEmpty else { return nil }
        return DeepLConfig(
            apiKey: parts[0],
            glossaryId: parts.count >= 2 ? parts[1] : nil
        )
    }
}

final class DeepLTranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id: String = "deepl"
    static let name: String? = "DeepL Translate"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = true
    static let defaultSecret: String? = "apiKey#glossaryId(optional)"

    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = { secret in
        let defaultSecret = "apiKey#glossaryId(optional)"

        guard let secret = secret, !secret.isEmpty else {
            return SecretValidationResult(
                secret: defaultSecret,
                status: false,
                info: "未设置密钥。DeepL 需要 API Key，格式为 apiKey#glossaryId(optional)"
            )
        }

        guard let config = DeepLConfig.parse(from: secret) else {
            return SecretValidationResult(
                secret: secret,
                status: false,
                info: "密钥格式错误。应为 apiKey#glossaryId(optional)，使用 '#' 分隔"
            )
        }

        guard config.apiKey.count >= 36 else {
            return SecretValidationResult(
                secret: secret,
                status: false,
                info: "API Key 长度必须 >= 36，当前长度：\(config.apiKey.count)"
            )
        }

        return SecretValidationResult(
            secret: secret,
            status: true,
            info: "API Key: \(String(config.apiKey.prefix(8)))...\nGlossary ID: \(config.glossaryId ?? "未设置")"
        )
    }

    private let config: DeepLConfig?
    private let serviceType: DeepLServiceType

    init(
        config: DeepLConfig? = nil,
        secret: String? = nil,
        networkClient: TranslationNetworkClient = TranslationNetworkClient()
    ) {
        self.config = config ?? secret.flatMap { DeepLConfig.parse(from: $0) }
        let apiKey = self.config?.apiKey ?? ""
        self.serviceType = apiKey.hasSuffix("dp") ? .pro : .free
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        guard let config = self.config else {
            if let secret = task.secret {
                guard let parsedConfig = DeepLConfig.parse(from: secret) else {
                    throw TranslateError.invalidSecretFormat(
                        "DeepL 密钥格式应为 apiKey#glossaryId(optional)，使用 '#' 分隔"
                    )
                }
                return try await translateWithConfig(parsedConfig, task: &task)
            }
            throw TranslateError.missingSecret
        }
        try await translateWithConfig(config, task: &task)
    }

    private func translateWithConfig(_ config: DeepLConfig, task: inout TranslateTask) async throws {
        let endpoint = self.serviceType.endpoint

        let sourceLang = LanguageMap.mapForDeepL(task.sourceLanguage)
        let targetLang = LanguageMap.mapForDeepL(task.targetLanguage)

        guard let url = URL(string: endpoint) else {
            throw TranslateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(config.apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "text": [task.raw],
            "source_lang": sourceLang,
            "target_lang": targetLang
        ]

        if let glossaryId = config.glossaryId {
            var bodyWithGlossary = body
            bodyWithGlossary["glossary_id"] = glossaryId
            request.httpBody = try JSONSerialization.data(withJSONObject: bodyWithGlossary)
        } else {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (responseData, response) = try await networkClient.post(url: url, body: request.httpBody, headers: request.allHTTPHeaderFields ?? [:])

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 403 {
                throw TranslateError.unauthorized
            }
            throw TranslateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let responseObj = try JSONDecoder().decode(DeepLResponse.self, from: responseData)
        guard let translation = responseObj.translations.first else {
            throw TranslateError.parsingError
        }

        task.result = translation.text
        task.status = .success
    }
}

private enum DeepLServiceType {
    case free
    case pro

    var endpoint: String {
        switch self {
        case .free:
            return "https://api-free.deepl.com/v2/translate"
        case .pro:
            return "https://api.deepl.com/v2/translate"
        }
    }
}

private struct DeepLResponse: Decodable {
    let translations: [DeepLTranslation]
}

// swiftlint:disable identifier_name
private struct DeepLTranslation: Decodable {
    let text: String
    let detected_source_language: String?
}
// swiftlint:enable identifier_name
