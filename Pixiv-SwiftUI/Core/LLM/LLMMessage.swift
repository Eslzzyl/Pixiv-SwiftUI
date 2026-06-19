import Foundation

struct LLMMessage: Codable, Sendable {
    let role: String
    let content: String
}
