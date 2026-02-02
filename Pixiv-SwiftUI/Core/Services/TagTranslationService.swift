import Foundation
import os.log

/// 标签翻译服务单例
final class TagTranslationService {
    static let shared = TagTranslationService()
    
    private let logger = Logger(subsystem: "com.pixiv.app", category: "TagTranslation")
    
    private var translations: [String: String] = [:]
    private(set) var timestamp: String = ""
    private(set) var isLoaded: Bool = false
    
    private init() {
        loadTranslations()
    }
    
    /// 从 Bundle 加载翻译数据
    private func loadTranslations() {
        guard let url = Bundle.main.url(forResource: "tags", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.error("Failed to load tags.json from Bundle")
            return
        }
        
        do {
            let tagTranslations = try JSONDecoder().decode(TagTranslations.self, from: data)
            self.translations = tagTranslations.tags
            self.timestamp = tagTranslations.timestamp
            self.isLoaded = true
            logger.info("Successfully loaded \(self.translations.count) tag translations")
        } catch {
            logger.error("Failed to decode tags.json: \(error.localizedDescription)")
        }
    }
    
    /// 获取标签翻译
    /// - Parameter tagName: 标签名称
    /// - Returns: 中文翻译，如果不存在则返回 nil
    func getTranslation(for tagName: String) -> String? {
        return translations[tagName]
    }
    
    /// 获取显示的翻译（优先本地，其次官方）
    /// - Parameters:
    ///   - tagName: 标签名称
    ///   - officialTranslation: API 官方翻译
    /// - Returns: 优先返回本地翻译，如果不存在则返回官方翻译
    func getDisplayTranslation(for tagName: String, officialTranslation: String?) -> String? {
        if let localTranslation = getTranslation(for: tagName) {
            return localTranslation
        }
        return officialTranslation
    }
    
    /// 检查是否有本地翻译
    func hasTranslation(for tagName: String) -> Bool {
        return translations[tagName] != nil
    }
}