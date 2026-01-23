import Foundation
import SwiftData

/// 图片基础 URL 集合
@Model
final class ImageUrls: Codable {
    var squareMedium: String
    var medium: String
    var large: String

    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
    }

    init(squareMedium: String, medium: String, large: String) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.squareMedium = try container.decode(String.self, forKey: .squareMedium)
        self.medium = try container.decode(String.self, forKey: .medium)
        self.large = try container.decode(String.self, forKey: .large)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(squareMedium, forKey: .squareMedium)
        try container.encode(medium, forKey: .medium)
        try container.encode(large, forKey: .large)
    }
}
