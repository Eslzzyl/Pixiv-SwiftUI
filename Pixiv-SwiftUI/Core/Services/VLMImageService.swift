import CoreGraphics
import os.log
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum VLMImageService {
    struct ExplanationResult: Sendable {
        let text: String
    }

    static func explain(
        cgImage: CGImage,
        prompt: String,
        client: LLMChatClient,
        model: String,
        temperature: Double,
        detail: String = "auto"
    ) async throws -> ExplanationResult {
        let base64Image = try encodeImageToBase64(cgImage)
        let dataURL = "data:image/jpeg;base64,\(base64Image)"

        let messages: [LLMMessage] = [
            LLMMessage(role: "system", content: .plain(
                "You are an image analysis assistant for Pixiv, a Japanese illustration website. " +
                "Analyze the image and respond in the target language specified by the user."
            )),
            LLMMessage(role: "user", content: .multimodal([
                .text(prompt),
                .imageURL(dataURL, detail: detail)
            ]))
        ]

        Logger.general.debug("VLMImageService: Sending image to VLM, model=\(model, privacy: .public), detail=\(detail, privacy: .public)")

        let response = try await client.chatCompletion(
            model: model,
            messages: messages,
            temperature: temperature
        )

        guard let firstChoice = response.choices.first else {
            throw LLMChatClientError.emptyResponse
        }

        let text = firstChoice.message.content.text
        guard !text.isEmpty else {
            throw LLMChatClientError.emptyResponse
        }

        Logger.general.debug("VLMImageService: Received response, \(text.count, privacy: .public) characters")

        return ExplanationResult(text: text)
    }

    private static func encodeImageToBase64(_ cgImage: CGImage) throws -> String {
        #if canImport(UIKit)
        let uiImage = UIImage(cgImage: cgImage)
        guard let data = uiImage.jpegData(compressionQuality: 0.85) else {
            throw VLMImageError.imageEncodingFailed
        }
        #elseif canImport(AppKit)
        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            throw VLMImageError.imageEncodingFailed
        }
        #else
        throw VLMImageError.imageEncodingFailed
        #endif
        return data.base64EncodedString()
    }
}

enum VLMImageError: LocalizedError {
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "图片编码失败"
        }
    }
}
