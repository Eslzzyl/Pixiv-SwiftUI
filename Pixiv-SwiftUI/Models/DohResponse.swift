import Foundation

struct DohResponse: Codable {
    let Status: Int?
    let Answer: [DnsAnswer]?
}

struct DnsAnswer: Codable {
    let name: String
    let type: Int
    let data: String
    let TTL: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case data
        case TTL = "TTL"
    }
}

extension DnsAnswer {
    var isValidIPv4: Bool {
        let parts = data.split(separator: ".")
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let num = Int(part), num >= 0 && num <= 255 else { return false }
            return true
        }
    }
}
