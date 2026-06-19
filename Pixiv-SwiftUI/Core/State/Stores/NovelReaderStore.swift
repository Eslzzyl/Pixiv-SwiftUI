import Foundation
import SwiftUI
import os.log

extension Notification.Name {
    static let novelReaderShouldRestorePosition = Notification.Name("novelReaderShouldRestorePosition")
    static let novelReaderProgressDidSave = Notification.Name("novelReaderProgressDidSave")
}

@Observable
@MainActor
final class NovelReaderStore {
    let novelId: Int

    var content: NovelReaderContent?
    var resolvedSeriesNavigation: SeriesNavigation?
    var spans: [NovelSpan] = []
    var isLoading = false
    var error: AppError?
    var translationError: String?

    var translatedParagraphs: [Int: String] = [:]
    var isTranslationEnabled = false
    var isTranslatingAll = false
    var translatingIndices: Set<Int> = []

    var isBookmarked: Bool = false

    @ObservationIgnored
    var savedIndex: Int?

    @ObservationIgnored
    var hasRestoredPosition = false

    var savedTotalSpans: Int?

    var settings: NovelReaderSettings = NovelReaderSettings()

    @ObservationIgnored
    var visibleParagraphIndices: Set<Int> = []

    @ObservationIgnored
    private var debounceTask: Task<Void, Never>?

    private let cacheStore = NovelTranslationCacheStore.shared
    private let appSettings: AppSettingsProtocol
    private let progressKey = "novel_reader_progress_"
    private let settingsKey = "novel_reader_settings"

    private struct NovelTranslationBatchPlan: Sendable {
        let paragraphIndices: [Int]
        let inputs: [NovelBatchInput]
        let context: [String]
    }

    private enum NovelBatchTaskResult: Sendable {
        case success(indices: [Int], translations: [Int: String])
        case failed(indices: [Int], message: String)
    }

    var novel: NovelReaderContent? {
        content
    }

    var seriesNavigation: SeriesNavigation? {
        resolvedSeriesNavigation
    }

    var hasSeriesNavigation: Bool {
        resolvedSeriesNavigation?.hasAdjacentNovel == true
    }

    init(novelId: Int, appSettings: AppSettingsProtocol = UserSettingStore.shared) {
        self.novelId = novelId
        self.appSettings = appSettings
        loadSettings()
        loadProgress()
    }

    private func loadProgress() {
        let key = "\(progressKey)\(novelId)"
        if let data = UserDefaults.standard.dictionary(forKey: key),
           let index = data["index"] as? Int,
           let total = data["total"] as? Int {
            savedIndex = index
            savedTotalSpans = total
        } else if let progress = UserDefaults.standard.object(forKey: key) as? Int {
            // 向后兼容：旧格式只有索引
            savedIndex = progress
            savedTotalSpans = nil
        } else {
            savedIndex = nil
            savedTotalSpans = nil
        }
    }

    func paragraphAppeared(index: Int) {
        visibleParagraphIndices.insert(index)
        triggerDebouncedUpdate()
    }

    func paragraphDisappeared(index: Int) {
        visibleParagraphIndices.remove(index)
        triggerDebouncedUpdate()
    }

    private func triggerDebouncedUpdate() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            if isTranslationEnabled {
                await startTranslationForVisibleParagraphs()
            }
        }
    }

    func updateVisibleParagraphs(_ indices: Set<Int>) {
        visibleParagraphIndices = indices
        triggerDebouncedUpdate()
    }

    func isParagraphVisible(_ index: Int) -> Bool {
        visibleParagraphIndices.contains(index)
    }

    func fetch() async {
        guard !isLoading else { return }
        Logger.novel.debug("Fetching content for novelId=\(self.novelId, privacy: .public)")
        isLoading = true
        error = nil
        resolvedSeriesNavigation = nil

        do {
            let fetchedContent = try await PixivAPI.shared.novelAPI.getNovelContent(novelId: novelId)
            Logger.novel.debug("Fetched content, text length=\(fetchedContent.text.count)")
            content = fetchedContent
            isBookmarked = fetchedContent.isBookmarked ?? false
            resolvedSeriesNavigation = await resolveSeriesNavigation(for: fetchedContent)

            let cleanedText = NovelTextParser.shared.cleanHTML(fetchedContent.text)
            spans = NovelTextParser.shared.parse(cleanedText, illusts: fetchedContent.illusts, images: fetchedContent.images)
            Logger.novel.debug("Parsed into \(self.spans.count) spans")
            logImageDiagnostics(content: fetchedContent, spans: spans)

            isLoading = false

            await cacheStore.preloadCache(for: novelId)

            loadProgress()
            if let index = savedIndex {
                Logger.novel.debug("Restoring progress to index \(index)")
                NotificationCenter.default.post(name: .novelReaderShouldRestorePosition, object: nil)
            }
        } catch {
            Logger.novel.error("Fetch failed: \(error.localizedDescription, privacy: .public)")
            self.error = AppError.unknown(error)
            resolvedSeriesNavigation = nil
            isLoading = false
        }
    }

    private func resolveSeriesNavigation(for content: NovelReaderContent) async -> SeriesNavigation? {
        if let navigation = content.seriesNavigation, navigation.hasAdjacentNovel {
            Logger.novel.debug("Series navigation source: content")
            return navigation
        }

        guard let seriesId = content.seriesId else {
            return nil
        }

        if let navigation = await fetchSeriesNavigationFromSeries(seriesId: seriesId) {
            Logger.novel.debug("Series navigation source: series fallback")
            return navigation
        }

        return nil
    }

    private func fetchSeriesNavigationFromSeries(seriesId: Int) async -> SeriesNavigation? {
        let novelAPI = PixivAPI.shared.novelAPI

        do {
            var novels: [Novel] = []
            var visitedNextURLs = Set<String>()

            let firstResponse = try await novelAPI.getNovelSeries(seriesId: seriesId)
            novels.append(contentsOf: firstResponse.novels)

            var nextURL = firstResponse.nextUrl

            while true {
                if let navigation = buildSeriesNavigationIfPossible(from: novels, nextURL: nextURL) {
                    return navigation
                }

                guard let nextPageURL = nextURL, visitedNextURLs.insert(nextPageURL).inserted else {
                    break
                }

                let response = try await novelAPI.getNovelSeriesByURL(nextPageURL)
                novels.append(contentsOf: response.novels)
                nextURL = response.nextUrl
            }

            return buildSeriesNavigationIfPossible(from: novels, nextURL: nil)
        } catch {
            Logger.novel.error("Failed to resolve series navigation from series: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func buildSeriesNavigationIfPossible(from novels: [Novel], nextURL: String?) -> SeriesNavigation? {
        guard let currentIndex = novels.firstIndex(where: { $0.id == novelId }) else {
            return nil
        }

        if currentIndex == novels.count - 1 && nextURL != nil {
            return nil
        }

        return buildSeriesNavigation(from: novels, currentIndex: currentIndex)
    }

    private func buildSeriesNavigation(from novels: [Novel], currentIndex: Int) -> SeriesNavigation? {
        guard currentIndex >= 0, currentIndex < novels.count else {
            return nil
        }

        let prevNovel: PrevNextNovel?
        if currentIndex > 0 {
            let novel = novels[currentIndex - 1]
            prevNovel = PrevNextNovel(id: novel.id, title: novel.title)
        } else {
            prevNovel = nil
        }

        let nextNovel: PrevNextNovel?
        if currentIndex + 1 < novels.count {
            let novel = novels[currentIndex + 1]
            nextNovel = PrevNextNovel(id: novel.id, title: novel.title)
        } else {
            nextNovel = nil
        }

        let navigation = SeriesNavigation(prevNovel: prevNovel, nextNovel: nextNovel)
        return navigation.hasAdjacentNovel ? navigation : nil
    }

    private func logImageDiagnostics(content: NovelReaderContent, spans: [NovelSpan]) {
        let uploadedAssets = content.images ?? []
        let illustAssets = content.illusts ?? []
        let uploadedSpans = spans.filter { $0.type == .uploadedImage }
        let pixivSpans = spans.filter { $0.type == .pixivImage }
        let resolvedUploadedSpans = uploadedSpans.filter { span in
            let imageURL = span.metadata?["imageUrl"] as? String ?? ""
            return !imageURL.isEmpty
        }
        let resolvedPixivSpans = pixivSpans.filter { span in
            let imageURL = span.metadata?["imageUrl"] as? String ?? ""
            return !imageURL.isEmpty
        }

        Logger.novel.debug("Image diagnostics: uploadedAssets=\(uploadedAssets.count), illustAssets=\(illustAssets.count), uploadedSpans=\(uploadedSpans.count), resolvedUploadedSpans=\(resolvedUploadedSpans.count), pixivSpans=\(pixivSpans.count), resolvedPixivSpans=\(resolvedPixivSpans.count)")

        for image in uploadedAssets.prefix(5) {
            let preferredURL = image.preferredDisplayURL ?? "nil"
            let host = URL(string: preferredURL)?.host ?? "nil"
            Logger.novel.debug("Uploaded asset: id=\(image.id ?? "nil"), host=\(host), preferredURL=\(preferredURL)")
        }

        for illust in illustAssets.prefix(5) {
            let previewURL = [illust.illust.imageUrls.large, illust.illust.imageUrls.medium, illust.illust.imageUrls.squareMedium]
                .first(where: { !$0.isEmpty }) ?? "nil"
            let host = URL(string: previewURL)?.host ?? "nil"
            Logger.novel.debug("Pixiv asset: illustId=\(illust.illust.id), host=\(host), previewURL=\(previewURL)")
        }

        for span in uploadedSpans.prefix(5) {
            let imageKey = span.metadata?["imageKey"] as? String ?? "nil"
            let imageURL = span.metadata?["imageUrl"] as? String ?? "nil"
            let host = URL(string: imageURL)?.host ?? "nil"
            Logger.novel.debug("Uploaded span: spanId=\(span.id), imageKey=\(imageKey), host=\(host), imageURL=\(imageURL)")
        }

        let unresolvedUploadedKeys = uploadedSpans.prefix(20).compactMap { span -> String? in
            let imageURL = span.metadata?["imageUrl"] as? String ?? ""
            guard imageURL.isEmpty else { return nil }
            return span.metadata?["imageKey"] as? String
        }
        if !unresolvedUploadedKeys.isEmpty {
            Logger.novel.debug("Uploaded spans unresolved keys: \(unresolvedUploadedKeys.joined(separator: ", "))")
        }

        for span in pixivSpans.prefix(5) {
            let illustId = span.metadata?["illustId"] as? Int ?? -1
            let targetIndex = span.metadata?["targetIndex"] as? Int ?? -1
            let imageURL = span.metadata?["imageUrl"] as? String ?? "nil"
            let host = URL(string: imageURL)?.host ?? "nil"
            Logger.novel.debug("Pixiv span: spanId=\(span.id), illustId=\(illustId), targetIndex=\(targetIndex), host=\(host), imageURL=\(imageURL)")
        }
    }

    func translateParagraph(_ index: Int, text: String) async {
        guard !translatingIndices.contains(index) else { return }

        translatingIndices.insert(index)

        let serviceId = appSettings.translatePrimaryServiceId
        let targetLang = appSettings.resolveTargetLanguage(
            appSettings.translateTargetLanguage
        )

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
            translationError = "翻译失败，请检查服务配置"
            Logger.novel.error("Translation failed for paragraph \(index): \(error.localizedDescription, privacy: .public)")
        }

        translatingIndices.remove(index)
    }

    func toggleTranslation() async {
        isTranslationEnabled.toggle()
        if isTranslationEnabled {
            translationError = nil
            await startTranslationForVisibleParagraphs()
        }
    }

    func toggleTranslationForTranslationOnly() async {
        isTranslationEnabled.toggle()
        if isTranslationEnabled {
            translationError = nil
            await startTranslationForVisibleParagraphs()
        } else {
            translatedParagraphs.removeAll()
        }
    }

    private func startTranslationForVisibleParagraphs() async {
        let serviceId = appSettings.translatePrimaryServiceId
        let targetLanguage = appSettings.resolveTargetLanguage(appSettings.translateTargetLanguage)
        let setting = UserSettingStore.shared.userSetting
        let sortedIndices = visibleParagraphIndices.sorted()
        let pendingIndices = await collectPendingParagraphIndices(
            from: sortedIndices,
            serviceId: serviceId,
            targetLanguage: targetLanguage
        )

        guard !pendingIndices.isEmpty else { return }

        if shouldUseOpenAIBatchTranslation(serviceId: serviceId, setting: setting) {
            let plans = buildBatchPlans(indices: pendingIndices, setting: setting)
            if plans.isEmpty {
                return
            }
            await executeBatchPlans(
                plans,
                setting: setting,
                serviceId: serviceId,
                targetLanguage: targetLanguage
            )
        } else {
            for index in pendingIndices {
                await translateParagraph(index, text: spans[index].content)
            }
        }
    }

    private func shouldUseOpenAIBatchTranslation(serviceId: String, setting: UserSetting) -> Bool {
        serviceId == "openai" && setting.translateNovelBatchEnabled
    }

    private func collectPendingParagraphIndices(
        from indices: [Int],
        serviceId: String,
        targetLanguage: String
    ) async -> [Int] {
        var pending: [Int] = []

        for index in indices where index < spans.count {
            let span = spans[index]
            let text = span.content
            if span.type != .normal || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            if translatedParagraphs[index] != nil || translatingIndices.contains(index) {
                continue
            }

            if let cached = await cacheStore.get(
                novelId: novelId,
                paragraphIndex: index,
                originalText: text,
                serviceId: serviceId,
                targetLanguage: targetLanguage
            ) {
                translatedParagraphs[index] = cached
                continue
            }

            pending.append(index)
        }

        return pending
    }

    private func buildBatchPlans(indices: [Int], setting: UserSetting) -> [NovelTranslationBatchPlan] {
        let maxParagraphs = max(1, setting.translateNovelBatchMaxParagraphs)
        let maxCharacters = max(500, setting.translateNovelBatchMaxCharacters)
        let contextCount = max(0, setting.translateNovelContextParagraphs)

        var groups: [[Int]] = []
        var currentGroup: [Int] = []

        for index in indices {
            if let last = currentGroup.last, index != last + 1 {
                groups.append(currentGroup)
                currentGroup = [index]
            } else {
                currentGroup.append(index)
            }
        }
        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        var plans: [NovelTranslationBatchPlan] = []

        for group in groups {
            var currentIndices: [Int] = []
            var currentInputs: [NovelBatchInput] = []
            var currentCharacters = 0

            func flushCurrentBatch() {
                guard !currentIndices.isEmpty else { return }
                let context = contextParagraphs(before: currentIndices[0], count: contextCount)
                plans.append(
                    NovelTranslationBatchPlan(
                        paragraphIndices: currentIndices,
                        inputs: currentInputs,
                        context: context
                    )
                )
                currentIndices.removeAll(keepingCapacity: true)
                currentInputs.removeAll(keepingCapacity: true)
                currentCharacters = 0
            }

            for index in group {
                let text = spans[index].content
                let count = text.count

                if !currentIndices.isEmpty &&
                    (currentIndices.count >= maxParagraphs || currentCharacters + count > maxCharacters) {
                    flushCurrentBatch()
                }

                currentIndices.append(index)
                currentInputs.append(NovelBatchInput(id: index, text: text))
                currentCharacters += count
            }

            flushCurrentBatch()
        }

        return plans
    }

    private func contextParagraphs(before firstIndex: Int, count: Int) -> [String] {
        guard count > 0 else { return [] }

        var context: [String] = []
        var currentIndex = firstIndex - 1

        while currentIndex >= 0 && context.count < count {
            let span = spans[currentIndex]
            let text = span.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if span.type == .normal && !text.isEmpty {
                context.append(span.content)
            }
            currentIndex -= 1
        }

        return context.reversed()
    }

    private func executeBatchPlans(
        _ plans: [NovelTranslationBatchPlan],
        setting: UserSetting,
        serviceId: String,
        targetLanguage: String
    ) async {
        let maxConcurrent = min(max(1, setting.translateNovelMaxConcurrentBatches), 4)
        let baseURL = setting.translateOpenAIBaseURL.isEmpty ? "https://api.openai.com/v1" : setting.translateOpenAIBaseURL
        let model = setting.translateOpenAIModel.isEmpty ? "gpt-5.1-nano" : setting.translateOpenAIModel
        let apiKey = setting.translateOpenAIApiKey
        let temperature = setting.translateOpenAITemperature
        let novelSystemPrompt = setting.translateNovelSystemPrompt

        var iterator = plans.makeIterator()

        await withTaskGroup(of: NovelBatchTaskResult.self) { group in
            for _ in 0..<min(maxConcurrent, plans.count) {
                if let plan = iterator.next() {
                    for index in plan.paragraphIndices {
                        translatingIndices.insert(index)
                    }

                    group.addTask {
                        do {
                            let translations = try await NovelBatchTranslator.shared.translateBatch(
                                paragraphs: plan.inputs,
                                context: plan.context,
                                targetLanguage: targetLanguage,
                                baseURL: baseURL,
                                apiKey: apiKey,
                                model: model,
                                temperature: temperature,
                                baseSystemPrompt: novelSystemPrompt
                            )
                            return .success(indices: plan.paragraphIndices, translations: translations)
                        } catch {
                            return .failed(indices: plan.paragraphIndices, message: error.localizedDescription)
                        }
                    }
                }
            }

            while let result = await group.next() {
                switch result {
                case .success(let indices, let translations):
                    var missingIndices: [Int] = []

                    for index in indices {
                        if let translated = translations[index], !translated.isEmpty {
                            translatedParagraphs[index] = translated
                            await cacheStore.save(
                                novelId: novelId,
                                paragraphIndex: index,
                                originalText: spans[index].content,
                                translatedText: translated,
                                serviceId: serviceId,
                                targetLanguage: targetLanguage
                            )
                        } else {
                            missingIndices.append(index)
                        }
                        translatingIndices.remove(index)
                    }

                    for index in missingIndices {
                        await translateParagraph(index, text: spans[index].content)
                    }

                case .failed(let indices, let message):
                    translationError = "批量翻译失败，已回退单段翻译"
                    Logger.novel.error("Batch translation failed: \(message)")

                    for index in indices {
                        translatingIndices.remove(index)
                    }

                    for index in indices {
                        await translateParagraph(index, text: spans[index].content)
                    }
                }

                if let next = iterator.next() {
                    for index in next.paragraphIndices {
                        translatingIndices.insert(index)
                    }

                    group.addTask {
                        do {
                            let translations = try await NovelBatchTranslator.shared.translateBatch(
                                paragraphs: next.inputs,
                                context: next.context,
                                targetLanguage: targetLanguage,
                                baseURL: baseURL,
                                apiKey: apiKey,
                                model: model,
                                temperature: temperature,
                                baseSystemPrompt: novelSystemPrompt
                            )
                            return .success(indices: next.paragraphIndices, translations: translations)
                        } catch {
                            return .failed(indices: next.paragraphIndices, message: error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    func translateAllParagraphs() async {
        guard !isTranslatingAll else { return }
        translationError = nil
        isTranslatingAll = true
        defer { isTranslatingAll = false }

        for (index, span) in spans.enumerated() {
            if span.type == .normal && !span.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await translateParagraph(index, text: span.content)
            }
        }
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
                systemPrompt: setting.translateNovelSystemPrompt
            )
        case "baidu":
            let setting = UserSettingStore.shared.userSetting
            let config = BaiduTranslateConfig(
                appid: setting.translateBaiduAppid,
                key: setting.translateBaiduKey,
                action: "0"
            )
            service = BaiduTranslateService(config: config)
        case "bing":
            service = BingTranslateService()
        case "tencent":
            let setting = UserSettingStore.shared.userSetting
            let config = TencentTranslateConfig(
                secretId: setting.translateTencentSecretId,
                secretKey: setting.translateTencentSecretKey,
                region: setting.translateTencentRegion.isEmpty ? "ap-shanghai" : setting.translateTencentRegion,
                projectId: setting.translateTencentProjectId.isEmpty ? "0" : setting.translateTencentProjectId
            )
            service = TencentTranslateService(config: config)
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
        guard hasRestoredPosition else { return }

        savedIndex = index
        savedTotalSpans = spans.count
        let progress: [String: Int] = [
            "index": index,
            "total": spans.count
        ]
        UserDefaults.standard.set(progress, forKey: "\(progressKey)\(novelId)")

        NotificationCenter.default.post(
            name: .novelReaderProgressDidSave,
            object: nil,
            userInfo: ["novelId": novelId]
        )
    }

    func savePositionOnDisappear(firstVisible: Int) {
        saveProgress(index: firstVisible)
    }

    func updateSettings(_ newSettings: NovelReaderSettings) {
        settings = newSettings
        saveSettings()
    }

    func toggleBookmark() async {
        let defaultRestrict = appSettings.defaultPrivateLike ? "private" : "public"

        do {
            if isBookmarked {
                try await PixivAPI.shared.novelAPI.unbookmarkNovel(novelId: novelId)
            } else {
                try await PixivAPI.shared.novelAPI.bookmarkNovel(novelId: novelId, restrict: defaultRestrict)
            }
            isBookmarked.toggle()
        } catch {
            Logger.novel.error("Failed to toggle bookmark: \(error.localizedDescription, privacy: .public)")
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
