import Foundation
import SwiftUI
import TranslationKit

extension Notification.Name {
    static let novelReaderShouldRestorePosition = Notification.Name("novelReaderShouldRestorePosition")
}

@Observable
@MainActor
final class NovelReaderStore {
    let novelId: Int

    var content: NovelReaderContent?
    var spans: [NovelSpan] = []
    var isLoading = false
    var errorMessage: String?

    var translatedParagraphs: [Int: String] = [:]
    var isTranslationEnabled = false
    var isTranslatingAll = false
    var translatingIndices: Set<Int> = []

    var isBookmarked: Bool = false
    var savedIndex: Int?
    var hasRestoredPosition = false

    var settings: NovelReaderSettings = NovelReaderSettings()

    var visibleParagraphIndices: Set<Int> = []

    private let cacheStore = NovelTranslationCacheStore.shared
    private let progressKey = "novel_reader_progress_"
    private let settingsKey = "novel_reader_settings"

    var novel: NovelReaderContent? {
        content
    }

    var seriesNavigation: SeriesNavigation? {
        content?.seriesNavigation
    }

    init(novelId: Int) {
        self.novelId = novelId
        print("[NovelReaderStore] 初始化 - novelId: \(novelId)")
        loadSettings()
        loadProgress()
    }

    private func loadProgress() {
        let key = "\(progressKey)\(novelId)"
        print("[NovelReaderStore] 开始加载进度 - key: \(key)")
        
        if let progress = UserDefaults.standard.object(forKey: key) as? Int {
            savedIndex = progress
            print("[NovelReaderStore] 成功加载保存的进度 - savedIndex: \(progress)")
        } else {
            savedIndex = nil
            print("[NovelReaderStore] 未找到保存的进度")
        }
    }

    func updateVisibleParagraphs(_ indices: Set<Int>) {
        visibleParagraphIndices = indices

        if isTranslationEnabled {
            Task {
                for index in indices.sorted() {
                    if index < spans.count {
                        let span = spans[index]
                        if span.type == .normal && 
                           !span.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                           translatedParagraphs[index] == nil && 
                           !translatingIndices.contains(index) {
                            await translateParagraph(index, text: span.content)
                        }
                    }
                }
            }
        }
    }

    func isParagraphVisible(_ index: Int) -> Bool {
        visibleParagraphIndices.contains(index)
    }

    func fetch() async {
        print("[NovelReaderStore] 开始获取小说内容 - novelId: \(novelId)")
        isLoading = true
        errorMessage = nil

        do {
            let fetchedContent = try await PixivAPI.shared.getNovelContent(novelId: novelId)
            content = fetchedContent
            isBookmarked = fetchedContent.isBookmarked ?? false

            let cleanedText = NovelTextParser.shared.cleanHTML(fetchedContent.text)
            spans = NovelTextParser.shared.parse(cleanedText, illusts: fetchedContent.illusts, images: fetchedContent.images)
            
            print("[NovelReaderStore] 内容解析完成 - spans数量: \(spans.count)")

            isLoading = false

            await cacheStore.preloadCache(for: novelId)

            loadProgress()
            print("[NovelReaderStore] fetch结束 - savedIndex: \(savedIndex?.description ?? "nil"), hasRestoredPosition: \(hasRestoredPosition)")
            
            if savedIndex != nil {
                print("[NovelReaderStore] 发送恢复位置通知")
                NotificationCenter.default.post(name: .novelReaderShouldRestorePosition, object: nil)
            }
        } catch {
            print("[NovelReaderStore] 获取内容失败 - error: \(error)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func translateParagraph(_ index: Int, text: String) async {
        guard !translatingIndices.contains(index) else { return }

        translatingIndices.insert(index)

        let serviceId = UserSettingStore.shared.userSetting.translatePrimaryServiceId
        let targetLang = UserSettingStore.shared.userSetting.translateTargetLanguage.isEmpty
            ? "zh-CN"
            : UserSettingStore.shared.userSetting.translateTargetLanguage

        if let cached = await cacheStore.get(
            novelId: novelId,
            paragraphIndex: index,
            originalText: text,
            serviceId: serviceId,
            targetLanguage: targetLang
        ) {
            translatedParagraphs[index] = cached
            translatingIndices.remove(index)
            return
        }

        do {
            let translated = try await performTranslation(text: text, serviceId: serviceId, targetLanguage: targetLang)
            translatedParagraphs[index] = translated
            await cacheStore.save(
                novelId: novelId,
                paragraphIndex: index,
                originalText: text,
                translatedText: translated,
                serviceId: serviceId,
                targetLanguage: targetLang
            )
        } catch {
            print("Translation failed for paragraph \(index): \(error)")
        }

        translatingIndices.remove(index)
    }

    func toggleTranslation() async {
        isTranslationEnabled.toggle()
        if isTranslationEnabled {
            await startTranslationForVisibleParagraphs()
        }
    }

    func toggleTranslationForTranslationOnly() async {
        isTranslationEnabled.toggle()
        if isTranslationEnabled {
            await startTranslationForVisibleParagraphs()
        } else {
            translatedParagraphs.removeAll()
        }
    }

    private func startTranslationForVisibleParagraphs() async {
        for index in visibleParagraphIndices.sorted() {
            if index < spans.count {
                let span = spans[index]
                if span.type == .normal &&
                   !span.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   translatedParagraphs[index] == nil &&
                   !translatingIndices.contains(index) {
                    await translateParagraph(index, text: span.content)
                }
            }
        }
    }

    func translateAllParagraphs() async {
        guard !isTranslatingAll else { return }
        isTranslatingAll = true

        let maxConcurrent = 4
        var activeTasks: [Int: Task<Void, Never>] = [:]

        for (index, span) in spans.enumerated() {
            if span.type == .normal && !span.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                while activeTasks.count >= maxConcurrent {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }

                if translatedParagraphs[index] == nil && !translatingIndices.contains(index) {
                    let task = Task {
                        await translateParagraph(index, text: span.content)
                    }
                    activeTasks[index] = task
                }
            }
        }

        for (_, task) in activeTasks {
            await task.value
        }

        isTranslatingAll = false
    }

    private func performTranslation(text: String, serviceId: String, targetLanguage: String) async throws -> String {
        let service: any TranslateService

        switch serviceId {
        case "google":
            service = GoogleTranslateService()
        case "googleapi":
            service = GoogleAPITranslateService()
        case "openai":
            let setting = UserSettingStore.shared.userSetting
            service = OpenAITranslateService(
                baseURL: setting.translateOpenAIBaseURL.isEmpty ? "https://api.openai.com/v1" : setting.translateOpenAIBaseURL,
                apiKey: setting.translateOpenAIApiKey,
                model: setting.translateOpenAIModel.isEmpty ? "gpt-3.5-turbo" : setting.translateOpenAIModel,
                temperature: setting.translateOpenAITemperature,
                systemPrompt: "Translate the text provided by the user into {targetLang}. This text comes from Pixiv, a Japanese novel. Ensure the translation is fluent and natural, maintaining the original meaning and style. Provide only the translation, without any explanation."
            )
        case "baidu":
            let setting = UserSettingStore.shared.userSetting
            let config = BaiduTranslateConfig(
                appid: setting.translateBaiduAppid,
                key: setting.translateBaiduKey,
                action: "0"
            )
            service = BaiduTranslateService(config: config)
        default:
            service = GoogleTranslateService()
        }

        var task = TranslateTask(
            raw: text,
            sourceLanguage: nil,
            targetLanguage: targetLanguage
        )

        try await service.translate(&task)
        return task.result
    }

    func updatePosition(_ offset: CGFloat) {
    }

    func saveProgress(index: Int) {
        print("[NovelReaderStore] 尝试保存进度 - index: \(index), hasRestoredPosition: \(hasRestoredPosition)")
        
        // 只有在已经恢复过位置后，才允许保存新进度
        // 这可以防止初始加载时滚动位置回零导致的误覆盖
        guard hasRestoredPosition else { 
            print("[NovelReaderStore] 已阻止保存 - 尚未恢复位置")
            return 
        }
        
        savedIndex = index
        let key = "\(progressKey)\(novelId)"
        UserDefaults.standard.set(index, forKey: key)
        print("[NovelReaderStore] 成功保存进度 - index: \(index), key: \(key)")
    }

    func savePositionOnDisappear(firstVisible: Int) {
        print("[NovelReaderStore] savePositionOnDisappear调用 - firstVisible: \(firstVisible)")
        saveProgress(index: firstVisible)
    }

    func updateSettings(_ newSettings: NovelReaderSettings) {
        settings = newSettings
        saveSettings()
    }

    func toggleBookmark() async {
        do {
            if isBookmarked {
                try await PixivAPI.shared.novelAPI?.unbookmarkNovel(novelId: novelId)
            } else {
                try await PixivAPI.shared.novelAPI?.bookmarkNovel(novelId: novelId)
            }
            isBookmarked.toggle()
        } catch {
            print("Failed to toggle bookmark: \(error)")
        }
    }

    func updateFontSize(_ size: CGFloat) {
        settings.fontSize = size
        saveSettings()
    }

    func updateLineHeight(_ height: CGFloat) {
        settings.lineHeight = height
        saveSettings()
    }

    func updateTheme(_ theme: ReaderTheme) {
        settings.theme = theme
        saveSettings()
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let saved = try? JSONDecoder().decode(NovelReaderSettings.self, from: data) {
            settings = saved
        }
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    func scrollToChapter(title: String) {
    }

    func scrollToParagraph(_ index: Int) {
    }
}
