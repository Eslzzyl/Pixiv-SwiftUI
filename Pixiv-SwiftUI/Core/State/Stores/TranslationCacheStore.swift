import Foundation
import SwiftData
import CryptoKit
import os.log

@ModelActor
actor TranslationCacheStore {
    @MainActor
    static let shared = TranslationCacheStore(modelContainer: DataContainer.shared.modelContainer)

    private let maxCacheCount = 100_000
    private let cleanupBatchSize = 1_000
    private var lastCleanupCount: Int = 0

    func get(originalText: String, serviceId: String, targetLanguage: String) async -> String? {
        let key = generateKey(originalText: originalText, serviceId: serviceId, targetLanguage: targetLanguage)

        do {
            let descriptor = FetchDescriptor<TranslationCache>(
                predicate: #Predicate { $0.key == key }
            )

            guard let cache = try modelContext.fetch(descriptor).first else {
                return nil
            }

            cache.lastAccessedAt = Date()
            try modelContext.save()
            return cache.translatedText
        } catch {
            Logger.cache.warning("TranslationCacheStore: Failed to get cache - \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func save(
        originalText: String,
        translatedText: String,
        serviceId: String,
        targetLanguage: String
    ) async {
        let key = generateKey(originalText: originalText, serviceId: serviceId, targetLanguage: targetLanguage)

        do {
            let existingDescriptor = FetchDescriptor<TranslationCache>(
                predicate: #Predicate { $0.key == key }
            )
            let existing = try modelContext.fetch(existingDescriptor)

            if let existingCache = existing.first {
                existingCache.translatedText = translatedText
                existingCache.lastAccessedAt = Date()
            } else {
                let cache = TranslationCache(
                    key: key,
                    originalText: originalText,
                    translatedText: translatedText,
                    serviceId: serviceId,
                    targetLanguage: targetLanguage
                )
                modelContext.insert(cache)
            }

            try modelContext.save()

            let totalCount = (try? modelContext.fetch(FetchDescriptor<TranslationCache>()).count) ?? 0

            if totalCount >= maxCacheCount + cleanupBatchSize &&
               totalCount - lastCleanupCount >= cleanupBatchSize {
                lastCleanupCount = totalCount
                performCleanup()
            }
        } catch {
            Logger.cache.warning("TranslationCacheStore: Failed to save cache - \(error.localizedDescription, privacy: .public)")
        }
    }

    private func performCleanup() {
        do {
            let descriptor = FetchDescriptor<TranslationCache>(
                sortBy: [SortDescriptor(\.lastAccessedAt, order: .forward)]
            )
            let caches = try modelContext.fetch(descriptor)

            guard caches.count > maxCacheCount else { return }

            let toDelete = Array(caches.prefix(cleanupBatchSize))
            for cache in toDelete {
                modelContext.delete(cache)
            }

            try modelContext.save()
            Logger.cache.debug("TranslationCacheStore: Cleaned up \(toDelete.count) old cache entries")
        } catch {
            Logger.cache.warning("TranslationCacheStore: Failed to cleanup - \(error.localizedDescription, privacy: .public)")
        }
    }

    private func generateKey(originalText: String, serviceId: String, targetLanguage: String) -> String {
        let input = "\(originalText)|\(serviceId)|\(targetLanguage)"
        let data = Data(input.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
