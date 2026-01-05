import Foundation
import SwiftData

/// 多页面图片的页面元数据
@Model
final class MetaPages: Codable {
    var imageUrls: MetaPagesImageUrls?
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
    }
    
    init(imageUrls: MetaPagesImageUrls? = nil) {
        self.imageUrls = imageUrls
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.imageUrls = try container.decodeIfPresent(MetaPagesImageUrls.self, forKey: .imageUrls)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(imageUrls, forKey: .imageUrls)
    }
}