import Foundation

final class BingTranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id: String = "bing"
    static let name: String? = "Bing Translate"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = false
    static let defaultSecret: String? = nil
    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = nil

    override init(networkClient: TranslationNetworkClient = TranslationNetworkClient()) {
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        let sourceLang = Self.mapLanguage(task.sourceLanguage)
        let targetLang = Self.mapLanguage(task.targetLanguage)

        var urlComponents = URLComponents(string: "https://edge.microsoft.com/translate/translatetext")
        let queryItems = [
            URLQueryItem(name: "from", value: sourceLang),
            URLQueryItem(name: "to", value: targetLang),
            URLQueryItem(name: "isEnterpriseClient", value: "false")
        ]

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw TranslateError.invalidURL
        }

        let requestBody = [task.raw]
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        let headers = [
            "Content-Type": "application/json",
            "Accept": "*/*",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36 Edg/113.0.1774.42"
        ]

        let (data, response) = try await networkClient.post(url: url, body: bodyData, headers: headers)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let result = try parseBingResponse(data)
        task.result = result
        task.status = .success
    }

    private func parseBingResponse(_ data: Data) throws -> String {
        struct Response: Decodable {
            let translations: [Translation]
        }

        struct Translation: Decodable {
            let text: String
        }

        let response = try JSONDecoder().decode([Response].self, from: data)

        guard let firstTranslation = response.first else {
            throw TranslateError.parsingError
        }

        guard let firstResult = firstTranslation.translations.first else {
            throw TranslateError.parsingError
        }

        return firstResult.text
    }

    private static func mapLanguage(_ language: String?) -> String {
        guard let language = language?.trimmingCharacters(in: .whitespacesAndNewlines),
              !language.isEmpty,
              language != "auto",
              language != "auto-detect" else {
            return ""
        }

        switch language {
        case "zh-CN", "zh-Hans", "zh-SG":
            return "zh-Hans"
        case "zh-TW", "zh-Hant", "zh-HK", "zh-MO":
            return "zh-Hant"
        case "pt":
            return "pt-BR"
        default:
            return language
        }
    }
}
