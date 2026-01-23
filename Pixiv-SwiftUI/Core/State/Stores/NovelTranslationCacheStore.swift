import Foundation
actor NovelTranslationCacheStore {
    static let shared = NovelTranslationCacheStore()
    private let fileManager = FileManager.default
    private var cacheDirectory: URL?
    private var memoryCache: [String: CachedTranslation] = [:]
    private let maxMemoryCacheCount = 100
    private init() {
        Task {
            await setupCacheDirectory()
        }
    }
    private func setupCacheDirectory() async {
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        cacheDirectory = cachesDirectory.appendingPathComponent("NovelTranslations", isDirectory: true)
        if let directory = cacheDirectory, !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    private func cacheKey(for novelId: Int, paragraphIndex: Int, serviceId: String, targetLanguage: String) -> String {
        "\(novelId)_\(paragraphIndex)_\(serviceId)_\(targetLanguage)"
    }
    private func cacheFileURL(for novelId: Int) -> URL? {
        cacheDirectory?.appendingPathComponent("\(novelId).json")
    }
    func get(novelId: Int, paragraphIndex: Int, originalText: String, serviceId: String, targetLanguage: String) async -> String? {
        let key = cacheKey(for: novelId, paragraphIndex: paragraphIndex, serviceId: serviceId, targetLanguage: targetLanguage)
        if let cached = memoryCache[key] {
            if !cached.isExpired {
                return cached.translatedText
            } else {
                memoryCache.removeValue(forKey: key)
            }
        }
        if let cached = await loadFromDisk(novelId: novelId, paragraphIndex: paragraphIndex, serviceId: serviceId, targetLanguage: targetLanguage) {
            updateMemoryCache(key: key, value: cached)
            return cached.translatedText
        }
        return nil
    }
    func save(novelId: Int, paragraphIndex: Int, originalText: String, translatedText: String, serviceId: String, targetLanguage: String) async {
        let key = cacheKey(for: novelId, paragraphIndex: paragraphIndex, serviceId: serviceId, targetLanguage: targetLanguage)
        let cached = CachedTranslation(
            key: key,
            originalText: originalText,
            translatedText: translatedText,
            serviceId: serviceId,
            targetLanguage: targetLanguage,
            timestamp: Date()
        )
        updateMemoryCache(key: key, value: cached)
        await saveToDisk(novelId: novelId, cached: cached)
    }
    private func updateMemoryCache(key: String, value: CachedTranslation) {
        memoryCache[key] = value
        if memoryCache.count > maxMemoryCacheCount {
            let sortedKeys = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let keysToRemove = sortedKeys.prefix(memoryCache.count - maxMemoryCacheCount).map(\.key)
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
    }
    private func loadFromDisk(novelId: Int, paragraphIndex: Int, serviceId: String, targetLanguage: String) async -> CachedTranslation? {
        guard let fileURL = cacheFileURL(for: novelId) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let cacheData = await NovelTranslationJSONHelper.decode(data: data) else { return nil }
        let key = cacheKey(for: novelId, paragraphIndex: paragraphIndex, serviceId: serviceId, targetLanguage: targetLanguage)
        return cacheData.translations[key]
    }
    private func saveToDisk(novelId: Int, cached: CachedTranslation) async {
        guard let fileURL = cacheFileURL(for: novelId) else { return }
        var cacheData: NovelTranslationCacheData
        if let data = try? Data(contentsOf: fileURL),
           let existing = await NovelTranslationJSONHelper.decode(data: data) {
            cacheData = existing
        } else {
            cacheData = NovelTranslationCacheData(novelId: novelId, translations: [:])
        }
        cacheData.translations[cached.key] = cached
        if let data = await NovelTranslationJSONHelper.encode(cacheData) {
            try? data.write(to: fileURL)
        }
    }
    func clearCache(for novelId: Int? = nil) async {
        if let novelId = novelId {
            memoryCache = memoryCache.filter { !$0.key.hasPrefix("\(novelId)_") }
            if let fileURL = cacheFileURL(for: novelId) {
                try? fileManager.removeItem(at: fileURL)
            }
        } else {
            memoryCache.removeAll()
            if let directory = cacheDirectory {
                try? fileManager.removeItem(at: directory)
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }
    func getCacheSize(for novelId: Int? = nil) -> Int64 {
        if let novelId = novelId {
            guard let fileURL = cacheFileURL(for: novelId),
                  let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let size = attributes[.size] as? Int64 else {
                return 0
            }
            return size
        }
        guard let directory = cacheDirectory else { return 0 }
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }
    func preloadCache(for novelId: Int) async {
        guard let fileURL = cacheFileURL(for: novelId) else { return }
        guard let data = try? Data(contentsOf: fileURL),
              let cacheData = await NovelTranslationJSONHelper.decode(data: data) else {
            return
        }
        for (_, cached) in cacheData.translations where !cached.isExpired {
            memoryCache[cached.key] = cached
        }
        if memoryCache.count > maxMemoryCacheCount {
            let sortedKeys = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let keysToRemove = sortedKeys.prefix(memoryCache.count - maxMemoryCacheCount).map(\.key)
            for key in keysToRemove {
                memoryCache.removeValue(forKey: key)
            }
        }
    }
}
