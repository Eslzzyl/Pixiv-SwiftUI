import Foundation

struct LLMChatRequest: Codable, Sendable {
    let model: String
    let messages: [LLMMessage]
    let temperature: Double
    let stream: Bool

    init(model: String, messages: [LLMMessage], temperature: Double, stream: Bool = false) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.stream = stream
    }
}

// swiftlint:disable identifier_name
struct LLMChoice: Codable, Sendable {
    let message: LLMMessage
    let finish_reason: String?
}
// swiftlint:enable identifier_name

struct LLMChatResponse: Codable, Sendable {
    let choices: [LLMChoice]
}

struct LLMErrorResponse: Codable {
    let error: LLMError?
}

struct LLMError: Codable {
    let message: String
    let type: String?
}
