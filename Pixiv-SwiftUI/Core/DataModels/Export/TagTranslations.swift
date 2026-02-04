import Foundation

/// 标签翻译数据模型
struct TagTranslations: Codable {
    let timestamp: String
    let tags: [String: String]

    enum CodingKeys: String, CodingKey {
        case timestamp
        case tags
    }
}
