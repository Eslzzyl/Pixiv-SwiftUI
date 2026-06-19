import Foundation
import CoreGraphics
import Kingfisher
import TranslationKit
import os.log
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor @Observable
final class ImageTranslationStore {
    enum Phase: Equatable {
        case idle
        case loadingImage
        case recognizingText
        case translating
        case completed
        case error(String)
    }

    struct TranslatedSegment: Identifiable {
        let id = UUID()
        let original: String
        let translated: String
    }

    var phase: Phase = .idle
    var segments: [TranslatedSegment] = []
    var progress: Double = 0

    private let cacheStore = TranslationCacheStore.shared

    func translateImage(urlString: String) async {
        switch phase {
        case .idle, .completed, .error: break
        default: return
        }

        phase = .loadingImage
        segments = []
        progress = 0

        do {
            Logger.general.debug("ImageTranslationStore: Loading image from \(urlString, privacy: .public)")

            let cgImage: CGImage = try await Task.detached {
                try await self.loadCGImage(from: urlString)
            }.value

            Logger.general.debug("ImageTranslationStore: Image loaded, size=\(cgImage.width)x\(cgImage.height)")

            phase = .recognizingText
            Logger.general.debug("ImageTranslationStore: Starting OCR")

            let ocrResults: [ImageOCRResult] = try await Task.detached {
                try await ImageOCRService.recognizeText(from: cgImage)
            }.value

            Logger.general.debug("ImageTranslationStore: OCR returned \(ocrResults.count) results")

            guard !ocrResults.isEmpty else {
                phase = .error("未识别到文字")
                return
            }

            phase = .translating
            let userSetting = UserSettingStore.shared
            let serviceId = userSetting.userSetting.translatePrimaryServiceId
            let rawTargetLang = userSetting.userSetting.translateTargetLanguage
            let targetLang = userSetting.resolveTargetLanguage(rawTargetLang)

            var results: [TranslatedSegment] = []
            let total = ocrResults.count

            for (index, result) in ocrResults.enumerated() {
                let translated: String

                if let cached = await cacheStore.get(
                    originalText: result.text,
                    serviceId: serviceId,
                    targetLanguage: targetLang
                ) {
                    translated = cached
                } else {
                    let raw = try await performTranslation(
                        text: result.text,
                        serviceId: serviceId,
                        targetLanguage: targetLang
                    )
                    await cacheStore.save(
                        originalText: result.text,
                        translatedText: raw,
                        serviceId: serviceId,
                        targetLanguage: targetLang
                    )
                    translated = raw
                }

                results.append(TranslatedSegment(original: result.text, translated: translated))
                progress = Double(index + 1) / Double(total)
            }

            segments = results
            phase = .completed
        } catch {
            Logger.general.error("ImageTranslationStore: Failed - \(error.localizedDescription, privacy: .public)")
            phase = .error(error.localizedDescription)
        }
    }

    func reset() {
        phase = .idle
        segments = []
        progress = 0
    }

    private func loadCGImage(from urlString: String) async throws -> CGImage {
        guard let url = URL(string: urlString) else {
            throw ImageTranslationError.invalidURL
        }

        let source: Source = shouldUseDirectConnection(url: url)
            ? .directNetwork(url)
            : .network(url)

        let downsamplingProcessor = DownsamplingImageProcessor(
            size: CGSize(width: 1500, height: 1500)
        )

        let result = try await KingfisherManager.shared.retrieveImage(
            with: source,
            options: [.processor(downsamplingProcessor)]
        )

        #if canImport(UIKit)
        guard let cgImage = result.image.cgImage else {
            throw ImageTranslationError.imageConversionFailed
        }
        return cgImage
        #elseif canImport(AppKit)
        guard let cgImage = result.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageTranslationError.imageConversionFailed
        }
        return cgImage
        #endif
    }

    private func shouldUseDirectConnection(url: URL) -> Bool {
        guard let host = url.host else { return false }
        return NetworkModeStore.shared.useDirectConnection
            && (host.contains("i.pximg.net") || host.contains("img-master.pixiv.net"))
    }

    private func performTranslation(text: String, serviceId: String, targetLanguage: String) async throws -> String {
        let service: any TranslateService

        let userSetting = UserSettingStore.shared

        switch serviceId {
        case "google":
            service = GoogleTranslateService()
        case "googleapi":
            service = GoogleAPITranslateService()
        case "openai":
            let setting = userSetting.userSetting
            service = OpenAITranslateService(
                baseURL: setting.translateOpenAIBaseURL.isEmpty ? "https://api.openai.com/v1" : setting.translateOpenAIBaseURL,
                apiKey: setting.translateOpenAIApiKey,
                model: setting.translateOpenAIModel.isEmpty ? "gpt-3.5-turbo" : setting.translateOpenAIModel,
                temperature: setting.translateOpenAITemperature
            )
        case "baidu":
            let setting = userSetting.userSetting
            let config = BaiduTranslateConfig(
                appid: setting.translateBaiduAppid,
                key: setting.translateBaiduKey,
                action: "0"
            )
            service = BaiduTranslateService(config: config)
        case "bing":
            service = BingTranslateService()
        case "tencent":
            let setting = userSetting.userSetting
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
}

enum ImageTranslationError: LocalizedError {
    case invalidURL
    case imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的图片 URL"
        case .imageConversionFailed:
            return "图片格式转换失败"
        }
    }
}
