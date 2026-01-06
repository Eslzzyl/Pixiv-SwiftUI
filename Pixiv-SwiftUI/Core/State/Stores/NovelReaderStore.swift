import Foundation
import SwiftUI
import TranslationKit

@Observable
final class NovelReaderStore {
    let novelId: Int

    var content: NovelReaderContent?
    var spans: [NovelSpan] = []
    var isLoading = false
    var errorMessage: String?

    var translatedParagraphs: [Int: String] = [:]
    var isTranslatingAll = false
    var translatingIndices: Set<Int> = []

    var currentOffset: CGFloat = 0
    var savedPosition: CGFloat?
    var isPositionBooked = false

    var settings: NovelReaderSettings = NovelReaderSettings()

    var visibleParagraphIndices: Set<Int> = []

    private let cacheStore = NovelTranslationCacheStore.shared
    private let userDefaultsKey = "novel_reader_position_"
    private let settingsKey = "novel_reader_settings"

    var novel: NovelReaderContent? {
        content
    }

    var seriesNavigation: SeriesNavigation? {
        content?.seriesNavigation
    }

    init(novelId: Int) {
        self.novelId = novelId
        loadSettings()
        loadPosition()
    }

    func updateVisibleParagraphs(_ indices: Set<Int>) {
        visibleParagraphIndices = indices
    }

    func isParagraphVisible(_ index: Int) -> Bool {
        visibleParagraphIndices.contains(index)
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        print("[NovelReader] 开始获取小说内容, novelId: \(novelId)")

        do {
            let fetchedContent = try await PixivAPI.shared.getNovelContent(novelId: novelId)
            content = fetchedContent

            let cleanedText = NovelTextParser.shared.cleanHTML(fetchedContent.text)
            spans = NovelTextParser.shared.parse(cleanedText, illusts: fetchedContent.illusts, images: fetchedContent.images)

            print("[NovelReader] 获取成功, spans 数量: \(spans.count)")
            print("[NovelReader] title: \(fetchedContent.title)")
            print("[NovelReader] text 前100字符: \(String(fetchedContent.text.prefix(100)))")

            isLoading = false

            if let savedOffset = savedPosition {
                try? await Task.sleep(for: .milliseconds(500))
                currentOffset = savedOffset
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[NovelReader] 获取失败: \(error.localizedDescription)")
            isLoading = false
        }
    }

    func translateParagraph(_ index: Int, text: String) async {
        guard !translatingIndices.contains(index) else { return }
        guard !translatedParagraphs.keys.contains(index) else { return }

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

    func translateAllParagraphs() async {
        guard !isTranslatingAll else { return }
        isTranslatingAll = true

        await withTaskGroup(of: Void.self) { [self] group in
            for (index, span) in spans.enumerated() {
                if span.type == .normal && !span.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    group.addTask {
                        await self.translateParagraph(index, text: span.content)
                    }
                }
            }
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
        currentOffset = offset
    }

    func savePosition() {
        guard currentOffset > 0 else { return }
        UserDefaults.standard.set(currentOffset, forKey: "\(userDefaultsKey)\(novelId)")
        isPositionBooked = true
    }

    func clearPosition() {
        UserDefaults.standard.removeObject(forKey: "\(userDefaultsKey)\(novelId)")
        isPositionBooked = false
    }

    private func loadPosition() {
        if let offset = UserDefaults.standard.object(forKey: "\(userDefaultsKey)\(novelId)") as? CGFloat {
            savedPosition = offset
            isPositionBooked = true
        }
    }

    func updateSettings(_ newSettings: NovelReaderSettings) {
        settings = newSettings
        saveSettings()
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
