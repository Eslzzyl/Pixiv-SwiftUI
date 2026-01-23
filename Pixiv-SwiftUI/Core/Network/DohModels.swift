import Foundation

struct DohNetworkResponse: Codable, Sendable {
    let status: Int?
    let answer: [DohNetworkAnswer]?

    enum CodingKeys: String, CodingKey {
        case status
        case answer
    }

    nonisolated init(status: Int?, answer: [DohNetworkAnswer]?) {
        self.status = status
        self.answer = answer
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.status = try container.decodeIfPresent(Int.self, forKey: .status)
        self.answer = try container.decodeIfPresent([DohNetworkAnswer].self, forKey: .answer)
    }
}

struct DohNetworkAnswer: Codable, Sendable {
    let name: String
    let type: Int
    let data: String
    let TTL: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case data
        case TTL
    }

    nonisolated init(name: String, type: Int, data: String, TTL: Int?) {
        self.name = name
        self.type = type
        self.data = data
        self.TTL = TTL
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(Int.self, forKey: .type)
        self.data = try container.decode(String.self, forKey: .data)
        self.TTL = try container.decodeIfPresent(Int.self, forKey: .TTL)
    }

    nonisolated func checkIsValidIPv4() -> Bool {
        let parts = data.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part), num >= 0 && num <= 255 else { return false }
            return true
        }
    }
}
