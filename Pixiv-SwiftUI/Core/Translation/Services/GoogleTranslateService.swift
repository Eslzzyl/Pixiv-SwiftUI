import Foundation

final class GoogleTranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    static let id = "google"
    static let name: String? = "Google Translate"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = false
    static let defaultSecret: String? = nil
    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = nil

    override init(networkClient: TranslationNetworkClient = TranslationNetworkClient()) {
        super.init(networkClient: networkClient)
    }

    func translate(_ task: inout TranslateTask) async throws {
        let sourceLang = LanguageMap.map(task.sourceLanguage ?? "auto")
        let targetLang = LanguageMap.map(task.targetLanguage)

        let urlString = "https://translate.google.com/translate_a/single"
        guard let url = URL(string: urlString) else {
            throw TranslateError.invalidURL
        }

        let body = buildPostBody(
            text: task.raw,
            sourceLang: sourceLang,
            targetLang: targetLang
        )

        let bodyString = body.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "\(value)"
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        let bodyData = bodyString.data(using: .utf8)

        let (data, response) = try await networkClient.post(
            url: url,
            body: bodyData,
            headers: ["Content-Type": "application/x-www-form-urlencoded;charset=utf-8"]
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw TranslateError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let result = try parseResponse(data)
        task.result = result
        task.status = .success
    }
}
