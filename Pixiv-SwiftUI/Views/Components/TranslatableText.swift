import SwiftUI
import TranslationKit

struct TranslatableText: View {
    let text: String
    var font: Font = .body

    @State private var translatedText: String?
    @State private var isTranslating: Bool = false
    @State private var showTranslation: Bool = false
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false

    @Environment(UserSettingStore.self) var userSettingStore
    @State private var cacheStore = TranslationCacheStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(font)
                .textSelection(.enabled)
                .contextMenu {
                    copyButton
                    translateButton
                }
                .onLongPressGesture(minimumDuration: 0.5, pressing: nil) {
                }

            if showTranslation, let translated = translatedText {
                Text(translated)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }

            if isTranslating {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .toast(isPresented: $showToast, message: toastMessage)
    }

    private var copyButton: some View {
        Button {
            copyToClipboard(text)
            toastMessage = "已复制到剪贴板"
            showToast = true
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }
    }

    private var translateButton: some View {
        if showTranslation {
            Button {
                withAnimation {
                    showTranslation = false
                }
            } label: {
                Label("收起翻译", systemImage: "chevron.up")
            }
        } else {
            Button {
                translate()
            } label: {
                Label("翻译", systemImage: "text.bubble")
            }
        }
    }

    private func translate() {
        guard !isTranslating else { return }

        let primaryServiceId = userSettingStore.userSetting.translatePrimaryServiceId
        let backupServiceId = userSettingStore.userSetting.translateBackupServiceId
        let targetLang = userSettingStore.userSetting.translateTargetLanguage
        let resolvedTargetLang = targetLang.isEmpty ? "zh-CN" : targetLang

        isTranslating = true
        translatedText = nil
        showTranslation = false

        Task {
            if let cached = await cacheStore.get(
                originalText: text,
                serviceId: primaryServiceId,
                targetLanguage: resolvedTargetLang
            ) {
                await MainActor.run {
                    isTranslating = false
                    translatedText = cached
                    showTranslation = true
                }
                return
            }

            do {
                let translated = try await performTranslationWithFallback(
                    text: text,
                    primaryServiceId: primaryServiceId,
                    backupServiceId: backupServiceId,
                    targetLanguage: resolvedTargetLang
                )

                await MainActor.run {
                    isTranslating = false
                    translatedText = translated
                    showTranslation = true
                }

                await cacheStore.save(
                    originalText: text,
                    translatedText: translated,
                    serviceId: primaryServiceId,
                    targetLanguage: resolvedTargetLang
                )
            } catch {
                await MainActor.run {
                    isTranslating = false
                    toastMessage = "翻译失败，请检查服务配置"
                    showToast = true
                }
            }
        }
    }

    private func performTranslationWithFallback(
        text: String,
        primaryServiceId: String,
        backupServiceId: String,
        targetLanguage: String
    ) async throws -> String {
        do {
            let translated = try await performTranslation(
                text: text,
                serviceId: primaryServiceId,
                targetLanguage: targetLanguage
            )
            return translated
        } catch {
            await MainActor.run {
                toastMessage = "首选服务失败，尝试备选服务..."
                showToast = true
            }

            let backupTranslated = try await performTranslation(
                text: text,
                serviceId: backupServiceId,
                targetLanguage: targetLanguage
            )
            return backupTranslated
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
            let setting = userSettingStore.userSetting
            service = OpenAITranslateService(
                baseURL: setting.translateOpenAIBaseURL.isEmpty ? "https://api.openai.com/v1" : setting.translateOpenAIBaseURL,
                apiKey: setting.translateOpenAIApiKey,
                model: setting.translateOpenAIModel.isEmpty ? "gpt-3.5-turbo" : setting.translateOpenAIModel,
                temperature: setting.translateOpenAITemperature
            )
        case "baidu":
            let setting = userSettingStore.userSetting
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

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

struct TranslatableCommentTextView: View {
    let text: String
    var font: Font = .subheadline

    @State private var translatedText: String?
    @State private var isTranslating: Bool = false
    @State private var showTranslation: Bool = false
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false

    @Environment(UserSettingStore.self) var userSettingStore
    @State private var cacheStore = TranslationCacheStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CommentTextView(text)
                .font(font)
                .textSelection(.enabled)
                .contextMenu {
                    copyButton
                    translateButton
                }

            if showTranslation, let translated = translatedText {
                CommentTextView(translated, color: .secondary)
                    .font(.caption2)
                    .transition(.opacity)
            }

            if isTranslating {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .toast(isPresented: $showToast, message: toastMessage)
    }

    private var copyButton: some View {
        Button {
            copyToClipboard(text)
            toastMessage = "已复制到剪贴板"
            showToast = true
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }
    }

    private var translateButton: some View {
        if showTranslation {
            Button {
                withAnimation {
                    showTranslation = false
                }
            } label: {
                Label("收起翻译", systemImage: "chevron.up")
            }
        } else {
            Button {
                translate()
            } label: {
                Label("翻译", systemImage: "text.bubble")
            }
        }
    }

    private func translate() {
        guard !isTranslating else { return }

        let primaryServiceId = userSettingStore.userSetting.translatePrimaryServiceId
        let backupServiceId = userSettingStore.userSetting.translateBackupServiceId
        let targetLang = userSettingStore.userSetting.translateTargetLanguage
        let resolvedTargetLang = targetLang.isEmpty ? "zh-CN" : targetLang

        isTranslating = true
        translatedText = nil
        showTranslation = false

        Task {
            if let cached = await cacheStore.get(
                originalText: text,
                serviceId: primaryServiceId,
                targetLanguage: resolvedTargetLang
            ) {
                await MainActor.run {
                    isTranslating = false
                    translatedText = cached
                    showTranslation = true
                }
                return
            }

            do {
                let (protectedText, emojiMap) = protectEmojis(in: text)

                let translated = try await performTranslationWithFallback(
                    text: protectedText,
                    primaryServiceId: primaryServiceId,
                    backupServiceId: backupServiceId,
                    targetLanguage: resolvedTargetLang
                )

                let restoredText = restoreEmojis(in: translated, from: emojiMap)

                await MainActor.run {
                    isTranslating = false
                    translatedText = restoredText
                    showTranslation = true
                }

                await cacheStore.save(
                    originalText: text,
                    translatedText: restoredText,
                    serviceId: primaryServiceId,
                    targetLanguage: resolvedTargetLang
                )
            } catch {
                await MainActor.run {
                    isTranslating = false
                    toastMessage = "翻译失败，请检查服务配置"
                    showToast = true
                }
            }
        }
    }

    private func protectEmojis(in text: String) -> (protectedText: String, emojiMap: [String: String]) {
        var emojiMap: [String: String] = [:]
        var protectedText = text
        var counter = 0

        var index = protectedText.startIndex
        while index < protectedText.endIndex {
            if protectedText[index] == "(" {
                let startIndex = index
                var endIndex = protectedText.index(after: index)
                var foundValidEmoji = false

                while endIndex < protectedText.endIndex && protectedText[endIndex] != "(" {
                    if protectedText[endIndex] == ")" {
                        let emoji = String(protectedText[startIndex...endIndex])
                        if EmojiHelper.getEmojiImageName(for: emoji) != nil {
                            let placeholder = "{EMOJI_\(counter)}"
                            emojiMap[placeholder] = emoji
                            protectedText.replaceSubrange(startIndex...endIndex, with: placeholder)
                            index = protectedText.index(startIndex, offsetBy: placeholder.count)
                            counter += 1
                            foundValidEmoji = true
                        }
                        break
                    }
                    endIndex = protectedText.index(after: endIndex)
                }

                if !foundValidEmoji {
                    index = protectedText.index(after: index)
                }
            } else {
                index = protectedText.index(after: index)
            }
        }

        return (protectedText, emojiMap)
    }

    private func restoreEmojis(in text: String, from emojiMap: [String: String]) -> String {
        var result = text
        for (placeholder, emoji) in emojiMap {
            result = result.replacingOccurrences(of: placeholder, with: emoji)
        }
        return result
    }

    private func performTranslationWithFallback(
        text: String,
        primaryServiceId: String,
        backupServiceId: String,
        targetLanguage: String
    ) async throws -> String {
        do {
            let translated = try await performTranslation(
                text: text,
                serviceId: primaryServiceId,
                targetLanguage: targetLanguage
            )
            return translated
        } catch {
            await MainActor.run {
                toastMessage = "首选服务失败，尝试备选服务..."
                showToast = true
            }

            let backupTranslated = try await performTranslation(
                text: text,
                serviceId: backupServiceId,
                targetLanguage: targetLanguage
            )
            return backupTranslated
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
            let setting = userSettingStore.userSetting
            service = OpenAITranslateService(
                baseURL: setting.translateOpenAIBaseURL.isEmpty ? "https://api.openai.com/v1" : setting.translateOpenAIBaseURL,
                apiKey: setting.translateOpenAIApiKey,
                model: setting.translateOpenAIModel.isEmpty ? "gpt-3.5-turbo" : setting.translateOpenAIModel,
                temperature: setting.translateOpenAITemperature
            )
        case "baidu":
            let setting = userSettingStore.userSetting
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

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

#Preview {
    VStack(spacing: 20) {
        TranslatableText(
            text: "这是一段测试文本，用于测试翻译功能。",
            font: .body
        )

        TranslatableText(
            text: "Hello, this is a test for translation feature.",
            font: .body
        )
    }
    .padding()
}
