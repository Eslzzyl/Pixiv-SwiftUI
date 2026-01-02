import Foundation
import SwiftData
import CryptoKit

final class TranslationCacheStore {
    static let shared = TranslationCacheStore()
    
    private let context: ModelContext
    private let backgroundContext: ModelContext
    private let backgroundQueue = DispatchQueue(label: "com.pixiv.translationcache", qos: .utility)
    private let maxCacheCount = 100_000
    private let cleanupBatchSize = 1_000
    private var lastCleanupCount: Int = 0
    
    private init() {
        let container = DataContainer.shared
        self.context = container.mainContext
        self.backgroundContext = container.createBackgroundContext()
    }
    
    func get(originalText: String, serviceId: String, targetLanguage: String) async -> String? {
        let key = generateKey(originalText: originalText, serviceId: serviceId, targetLanguage: targetLanguage)
        
        return await withCheckedContinuation { continuation in
            backgroundQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let descriptor = FetchDescriptor<TranslationCache>(
                        predicate: #Predicate { $0.key == key }
                    )
                    
                    if let cache = try self.backgroundContext.fetch(descriptor).first {
                        cache.lastAccessedAt = Date()
                        try self.backgroundContext.save()
                        continuation.resume(returning: cache.translatedText)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    print("TranslationCacheStore: Failed to get cache - \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func save(
        originalText: String,
        translatedText: String,
        serviceId: String,
        targetLanguage: String
    ) async {
        let key = generateKey(originalText: originalText, serviceId: serviceId, targetLanguage: targetLanguage)
        
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let existingDescriptor = FetchDescriptor<TranslationCache>(
                    predicate: #Predicate { $0.key == key }
                )
                let existing = try self.backgroundContext.fetch(existingDescriptor)
                
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
                    self.backgroundContext.insert(cache)
                }
                
                try self.backgroundContext.save()
                
                let totalCount = (try? self.backgroundContext.fetch(FetchDescriptor<TranslationCache>()).count) ?? 0
                
                if totalCount >= self.maxCacheCount + self.cleanupBatchSize && 
                   totalCount - self.lastCleanupCount >= self.cleanupBatchSize {
                    self.lastCleanupCount = totalCount
                    self.performCleanup()
                }
            } catch {
                print("TranslationCacheStore: Failed to save cache - \(error)")
            }
        }
    }
    
    private func performCleanup() {
        backgroundQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let descriptor = FetchDescriptor<TranslationCache>(
                    sortBy: [SortDescriptor(\.lastAccessedAt, order: .forward)]
                )
                let caches = try self.backgroundContext.fetch(descriptor)
                
                guard caches.count > self.maxCacheCount else { return }
                
                let toDelete = Array(caches.prefix(self.cleanupBatchSize))
                for cache in toDelete {
                    self.backgroundContext.delete(cache)
                }
                
                try self.backgroundContext.save()
                print("TranslationCacheStore: Cleaned up \(toDelete.count) old cache entries")
            } catch {
                print("TranslationCacheStore: Failed to cleanup - \(error)")
            }
        }
    }
    
    private func generateKey(originalText: String, serviceId: String, targetLanguage: String) -> String {
        let input = "\(originalText)|\(serviceId)|\(targetLanguage)"
        let data = Data(input.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
