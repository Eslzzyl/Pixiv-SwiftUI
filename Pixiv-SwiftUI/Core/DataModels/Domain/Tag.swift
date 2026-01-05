import Foundation
import SwiftData

/// 标签信息
@Model
final class Tag: Codable {
    var name: String
    var translatedName: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
    
    init(name: String, translatedName: String? = nil) {
        self.name = name
        self.translatedName = translatedName
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.translatedName = try container.decodeIfPresent(String.self, forKey: .translatedName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(translatedName, forKey: .translatedName)
    }
}