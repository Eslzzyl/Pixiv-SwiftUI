import Foundation

struct CachedTranslation: Codable, Sendable {
    let key: String
    let originalText: String
    let translatedText: String
    let serviceId: String
    let targetLanguage: String
    let timestamp: Date

    nonisolated var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > Double(30 * 24 * 60 * 60)
    }
}

struct NovelTranslationCacheData: Codable, @unchecked Sendable {
    let novelId: Int
    var translations: [String: CachedTranslation]

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case translations
    }
}

enum NovelTranslationJSONHelper {
    static func decode(data: Data) -> NovelTranslationCacheData? {
        try? JSONDecoder().decode(NovelTranslationCacheData.self, from: data)
    }

    static func encode(_ cacheData: NovelTranslationCacheData) -> Data? {
        try? JSONEncoder().encode(cacheData)
    }
}
