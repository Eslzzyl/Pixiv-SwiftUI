import Foundation

enum LLMContentPart: Codable, Sendable {
    case text(String)
    case imageURL(String, detail: String?)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    private struct ImageURLPayload: Codable, Sendable {
        let url: String
        let detail: String?
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let url, let detail):
            try container.encode("image_url", forKey: .type)
            try container.encode(ImageURLPayload(url: url, detail: detail), forKey: .imageURL)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "image_url":
            let payload = try container.decode(ImageURLPayload.self, forKey: .imageURL)
            self = .imageURL(payload.url, detail: payload.detail)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unexpected content part type: \(type)"
            )
        }
    }
}
