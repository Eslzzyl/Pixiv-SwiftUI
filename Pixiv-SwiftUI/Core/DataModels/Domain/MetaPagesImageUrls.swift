import Foundation
import SwiftData

/// 多页面图片的页面元数据中的 URL 集合
@Model
final class MetaPagesImageUrls: Codable {
    var squareMedium: String
    var medium: String
    var large: String
    var original: String

    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
        case original
    }

    init(squareMedium: String, medium: String, large: String, original: String) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
        self.original = original
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.squareMedium = try container.decode(String.self, forKey: .squareMedium)
        self.medium = try container.decode(String.self, forKey: .medium)
        self.large = try container.decode(String.self, forKey: .large)
        self.original = try container.decode(String.self, forKey: .original)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(squareMedium, forKey: .squareMedium)
        try container.encode(medium, forKey: .medium)
        try container.encode(large, forKey: .large)
        try container.encode(original, forKey: .original)
    }
}
