import SwiftUI
import TranslationKit

struct TranslatableParagraph: View {
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
            let containsLinks = PixivDescriptionParser.containsLinks(text)
            let parsedText = PixivDescriptionParser.parse(text)

            Group {
                if containsLinks {
                    Text(LocalizedStringKey(parsedText))
                } else {
                    Text(parsedText)
                }
            }
                .font(font)
                .textSelection(.enabled)
                .contextMenu {
                    copyButton
                    translateButton
                }

            if showTranslation, let translated = translatedText {
                let translatedParsed = PixivDescriptionParser.parse(translated)
                let translatedContainsLinks = PixivDescriptionParser.containsLinks(translated)

                Group {
                    if translatedContainsLinks {
                        Text(LocalizedStringKey(translatedParsed))
                    } else {
                        Text(translatedParsed)
                    }
                }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }

            if isTranslating {
                ProgressView()
                    #if os(macOS)
                    .controlSize(.small)
                    #else
                    .scaleEffect(0.8)
                    #endif
            }
        }
        .toast(isPresented: $showToast, message: toastMessage)
    }

    private var copyButton: some View {
        Button {
            copyToClipboard(text)
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

    func translate() {
        guard !isTranslating else { return }

        let primaryServiceId = userSettingStore.userSetting.translatePrimaryServiceId
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
                let translated = try await performTranslation(
                    text: text,
                    serviceId: primaryServiceId,
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
                temperature: setting.translateOpenAITemperature,
                systemPrompt: "Translate the text provided by the user into {targetLang}. This text comes from Pixiv, a Japanese illustration website. The text may include illustration titles, descriptions, comments, or light novel content, which could contain character names or idiomatic expressions. Ensure the translation is appropriate and accurate, without avoiding NSFW content. Provide only the translation, without any explanation."
            )
        case "baidu":
            let setting = userSettingStore.userSetting
            let config = BaiduTranslateConfig(
                appid: setting.translateBaiduAppid,
                key: setting.translateBaiduKey,
                action: "0"
            )
            service = BaiduTranslateService(config: config)
        case "bing":
            service = BingTranslateService()
        case "tencent":
            let setting = userSettingStore.userSetting
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

    private func copyToClipboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

#Preview {
    VStack(spacing: 20) {
        TranslatableParagraph(
            text: "这是一段测试文本，用于测试翻译功能。",
            font: .body
        )

        TranslatableParagraph(
            text: "Hello, this is a test for translation feature.",
            font: .body
        )

        TranslatableParagraph(
            text: "这是一个包含<a href=\"https://example.com\">链接</a>的文本。",
            font: .body
        )
    }
    .padding()
}
