import Foundation

struct Translate {
    static let google = GoogleTranslateService()
    static let googleAPI = GoogleAPITranslateService()
    static let openAI = OpenAITranslateService(baseURL: "https://api.openai.com/v1")

    static func baidu(appid: String, key: String, action: String = "0") -> BaiduTranslateService {
        BaiduTranslateService(config: BaiduTranslateConfig(appid: appid, key: key, action: action))
    }
}

func translate(
    text: String,
    from sourceLanguage: String? = nil,
    to targetLanguage: String,
    using service: (any TranslateService)? = nil
) async throws -> String {
    let selectedService: any TranslateService = service ?? Translate.openAI
    var task = TranslateTask(
        raw: text,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage
    )
    try await selectedService.translate(&task)
    return task.result
}
