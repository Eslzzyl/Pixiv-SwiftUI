import Foundation

final class BingTranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id: String = "bing"
    static let name: String? = "Bing Translate"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = false
    static let defaultSecret: String? = nil
    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = nil

    private let tokenCache: BingTokenCache

    override init(networkClient: TranslationNetworkClient = TranslationNetworkClient()) {
        self.tokenCache = BingTokenCache()
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        let sourceLang = task.sourceLanguage
        let targetLang = task.targetLanguage

        let token = try await tokenCache.getToken(networkClient: networkClient)

        var urlComponents = URLComponents(string: "https://api-edge.cognitive.microsofttranslator.com/translate")
        var queryItems = [
            URLQueryItem(name: "to", value: targetLang),
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "includeSentenceLength", value: "true")
        ]

        if let sourceLang = sourceLang, !sourceLang.isEmpty {
            queryItems.append(URLQueryItem(name: "from", value: sourceLang))
        }

        urlComponents?.queryItems = queryItems

        guard let url = urlComponents?.url else {
            throw TranslateError.invalidURL
        }

        let requestBody = [[ "text": task.raw ]]
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.36 Edg/113.0.1774.42"
        ]

        let (data, response) = try await networkClient.post(url: url, body: bodyData, headers: headers)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw TranslateError.tokenExpired
            }
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
}

private actor BingTokenCache {
    private var cachedToken: String?
    private var expiresAt: Date?
    private let tokenExpTime: TimeInterval = 5 * 60

    func getToken(networkClient: TranslationNetworkClient) async throws -> String {
        let now = Date()

        if let cachedToken = cachedToken, let expiresAt = expiresAt, now < expiresAt {
            return cachedToken
        }

        let newToken = try await fetchToken(networkClient: networkClient)
        cachedToken = newToken
        expiresAt = now.addingTimeInterval(tokenExpTime)
        return newToken
    }

    private func fetchToken(networkClient: TranslationNetworkClient) async throws -> String {
        let url = URL(string: "https://edge.microsoft.com/translate/auth")!

        let (data, response) = try await networkClient.get(url: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        guard let token = String(data: data, encoding: .utf8) else {
            throw TranslateError.parsingError
        }

        return token
    }
}
