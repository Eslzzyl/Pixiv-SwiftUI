import Foundation

struct LLMMessage: Codable, Sendable {
    let role: String
    let content: LLMMessageContent

    init(role: String, content: LLMMessageContent) {
        self.role = role
        self.content = content
    }

    init(role: String, content: String) {
        self.role = role
        self.content = .plain(content)
    }
}

enum LLMMessageContent: Sendable {
    case plain(String)
    case multimodal([LLMContentPart])

    var text: String {
        switch self {
        case .plain(let string):
            return string
        case .multimodal(let parts):
            return parts.compactMap { part in
                if case .text(let textContent) = part { return textContent }
                return nil
            }.joined(separator: "\n")
        }
    }
}

extension LLMMessageContent: Codable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .plain(let string):
            try container.encode(string)
        case .multimodal(let parts):
            try container.encode(parts)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .plain(string)
        } else {
            self = .multimodal(try container.decode([LLMContentPart].self))
        }
    }
}
