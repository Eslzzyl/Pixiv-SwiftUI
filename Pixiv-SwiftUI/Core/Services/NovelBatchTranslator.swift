import Foundation

enum NovelBatchTranslationError: LocalizedError {
    case invalidPayload
    case invalidResponse
    case emptyTranslation

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "无法构建批量翻译请求"
        case .invalidResponse:
            return "批量翻译返回格式错误"
        case .emptyTranslation:
            return "批量翻译未返回有效结果"
        }
    }
}

struct NovelBatchInput: Codable, Sendable {
    let id: Int
    let text: String
}

actor NovelBatchTranslator {
    static let shared = NovelBatchTranslator()

    private struct NovelBatchContextItem: Codable {
        let text: String
    }

    private struct NovelBatchRequest: Codable {
        let targetLanguage: String
        let context: [NovelBatchContextItem]
        let items: [NovelBatchInput]
    }

    private struct NovelBatchResponseItem: Codable {
        let id: Int
        let translation: String
    }

    private struct NovelBatchResponse: Codable {
        let items: [NovelBatchResponseItem]
    }

    func translateBatch(
        paragraphs: [NovelBatchInput],
        context: [String],
        targetLanguage: String,
        baseURL: String,
        apiKey: String,
        model: String,
        temperature: Double,
        baseSystemPrompt: String? = nil
    ) async throws -> [Int: String] {
        let stylePrompt = baseSystemPrompt ?? "You are a professional literary translator for Pixiv Japanese novels. Ensure the translation is fluent and natural, maintaining the original meaning and style."

        let systemPrompt = """
        \(stylePrompt)
        Translate all `items[*].text` into {targetLang}.
        The `context` field is reference-only and must not be translated.
        Output must be strict JSON only, with this exact shape:
        {"items":[{"id":123,"translation":"..."}]}
        Return every input item exactly once with the same id.
        """

        let request = NovelBatchRequest(
            targetLanguage: targetLanguage,
            context: context.map { NovelBatchContextItem(text: $0) },
            items: paragraphs
        )

        let encoder = JSONEncoder()
        guard
            let requestData = try? encoder.encode(request),
            let requestText = String(data: requestData, encoding: .utf8)
        else {
            throw NovelBatchTranslationError.invalidPayload
        }

        let userPrompt = "Translate this JSON payload and return JSON only:\n{sourceText}"

        let service = OpenAITranslateService(
            baseURL: baseURL,
            apiKey: apiKey,
            model: model,
            temperature: temperature,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )

        var task = TranslateTask(
            raw: requestText,
            sourceLanguage: nil,
            targetLanguage: targetLanguage
        )

        try await service.translate(&task)
        let responseText = task.result
        let decoded = try decodeResponse(from: responseText)
        let expectedIds = Set(paragraphs.map(\.id))

        var result: [Int: String] = [:]
        for item in decoded.items where expectedIds.contains(item.id) {
            let value = item.translation.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                result[item.id] = value
            }
        }

        if result.isEmpty {
            throw NovelBatchTranslationError.emptyTranslation
        }

        return result
    }

    private func decodeResponse(from text: String) throws -> NovelBatchResponse {
        if let direct = tryDecodeJSON(text) {
            return direct
        }

        let cleaned = stripCodeFence(from: text)
        if let fenced = tryDecodeJSON(cleaned) {
            return fenced
        }

        guard
            let startIndex = cleaned.firstIndex(of: "{"),
            let endIndex = cleaned.lastIndex(of: "}")
        else {
            throw NovelBatchTranslationError.invalidResponse
        }

        let jsonSegment = String(cleaned[startIndex...endIndex])
        if let extracted = tryDecodeJSON(jsonSegment) {
            return extracted
        }

        throw NovelBatchTranslationError.invalidResponse
    }

    private func tryDecodeJSON(_ text: String) -> NovelBatchResponse? {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(NovelBatchResponse.self, from: data)
    }

    private func stripCodeFence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        var lines = trimmed.components(separatedBy: "\n")
        if !lines.isEmpty {
            lines.removeFirst()
        }
        if let last = lines.last, last.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }
}
