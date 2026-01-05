import Foundation
import SwiftData

/// 插画系列信息
@Model
final class IllustSeries: Codable {
    var id: Int
    var title: String?
    
    init(id: Int, title: String? = nil) {
        self.id = id
        self.title = title
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
    }
}