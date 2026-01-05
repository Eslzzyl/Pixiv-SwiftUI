import Foundation
import SwiftData

@Model
final class TranslationCache {
    @Attribute(.unique) var key: String
    var originalText: String
    var translatedText: String
    var serviceId: String
    var targetLanguage: String
    var createdAt: Date
    var lastAccessedAt: Date
    
    init(
        key: String,
        originalText: String,
        translatedText: String,
        serviceId: String,
        targetLanguage: String
    ) {
        self.key = key
        self.originalText = originalText
        self.translatedText = translatedText
        self.serviceId = serviceId
        self.targetLanguage = targetLanguage
        self.createdAt = Date()
        self.lastAccessedAt = Date()
    }
}

extension TranslationCache {
    static let maxCacheCount = 100_000
    static let cleanupBatchSize = 1_000
}
