import Foundation

final class OpenAITranslateService: BaseTranslateService, TranslateService, @unchecked Sendable {
    private let llmClient: LLMChatClient
    private let model: String
    private let temperature: Double
    private let systemPrompt: String
    private let userPrompt: String

    nonisolated private static let defaultSystemPrompt = """
    You are a professional translator. Translate the following text into {targetLang}. \
    Only output the translated text, nothing else.
    """

    nonisolated private static let defaultSystemPromptWithSource = """
    You are a professional translator. Translate the following text from {sourceLang} into {targetLang}. \
    Only output the translated text, nothing else.
    """

    nonisolated private static let defaultUserPrompt = "{sourceText}"

    nonisolated init(
        baseURL: String = "https://api.openai.com/v1",
        apiKey: String = "",
        model: String = "gpt-5.1-nano",
        temperature: Double = 0.3,
        systemPrompt: String? = nil,
        userPrompt: String? = nil
    ) {
        self.llmClient = LLMChatClient(baseURL: baseURL, apiKey: apiKey)
        self.model = model
        self.temperature = temperature
        self.systemPrompt = systemPrompt ?? Self.defaultSystemPrompt
        self.userPrompt = userPrompt ?? Self.defaultUserPrompt
        super.init()
    }

    static let id: String = "openai"
    static let name: String? = "OpenAI"
    static let type: ServiceType = .sentence
    static let requiresSecret: Bool = false
    static let defaultSecret: String? = nil
    static let secretValidator: (@Sendable (String?) -> SecretValidationResult)? = nil

    func translate(_ task: inout TranslateTask) async throws {
        task.status = .processing

        let messages = buildMessages(for: task)
        let response = try await llmClient.chatCompletion(
            model: model,
            messages: messages,
            temperature: temperature
        )

        guard let firstChoice = response.choices.first else {
            throw TranslateError.parsingError
        }

        task.result = firstChoice.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        task.status = .success
    }

    private func buildMessages(for task: TranslateTask) -> [LLMMessage] {
        let sourceLang = task.sourceLanguage ?? "auto"
        let targetLang = task.targetLanguage
        let sourceText = task.raw

        let resolvedUserPrompt = self.userPrompt
            .replacingOccurrences(of: "{sourceLang}", with: sourceLang)
            .replacingOccurrences(of: "{targetLang}", with: targetLang)
            .replacingOccurrences(of: "{sourceText}", with: sourceText)

        let resolvedSystemPromptFinal = self.systemPrompt
            .replacingOccurrences(of: "{sourceLang}", with: sourceLang)
            .replacingOccurrences(of: "{targetLang}", with: targetLang)
            .replacingOccurrences(of: "{sourceText}", with: sourceText)

        return [
            LLMMessage(role: "system", content: resolvedSystemPromptFinal),
            LLMMessage(role: "user", content: resolvedUserPrompt)
        ]
    }
}
