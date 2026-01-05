import Foundation
import SwiftData

/// 单个图片页面的元数据（主要用于获取原始图片 URL）
@Model
final class MetaSinglePage: Codable {
    var originalImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case originalImageUrl = "original_image_url"
    }
    
    init(originalImageUrl: String? = nil) {
        self.originalImageUrl = originalImageUrl
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originalImageUrl = try container.decodeIfPresent(String.self, forKey: .originalImageUrl)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(originalImageUrl, forKey: .originalImageUrl)
    }
}