import Vision
import CoreImage
import os.log

struct ImageOCRResult: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

enum ImageOCRService {
    static func recognizeText(
        from cgImage: CGImage,
        languages: [String] = ["ja-JP", "en-US"]
    ) async throws -> [ImageOCRResult] {
        try await appleVisionRecognizeText(from: cgImage, languages: languages)
    }

    private static func appleVisionRecognizeText(
        from cgImage: CGImage,
        languages: [String]
    ) async throws -> [ImageOCRResult] {
        Logger.general.debug("ImageOCRService: Starting OCR, image size=\(cgImage.width)x\(cgImage.height), languages=\(languages.joined(separator: ","))")

        let results = try await visionRecognize(from: cgImage, languages: languages, level: .accurate)

        if results.isEmpty {
            Logger.general.debug("ImageOCRService: .accurate returned 0 results, falling back to .fast")
            return try await visionRecognize(from: cgImage, languages: languages, level: .fast)
        }

        return results
    }

    private static func visionRecognize(
        from cgImage: CGImage,
        languages: [String],
        level: VNRequestTextRecognitionLevel
    ) async throws -> [ImageOCRResult] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = level
                    request.recognitionLanguages = languages
                    request.usesLanguageCorrection = true

                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    try handler.perform([request])

                    let results = request.results?.compactMap { (observation: VNRecognizedTextObservation) -> ImageOCRResult? in
                        guard let topCandidate = observation.topCandidates(1).first else { return nil }
                        return ImageOCRResult(
                            text: topCandidate.string,
                            boundingBox: observation.boundingBox
                        )
                    } ?? []

                    Logger.general.debug("ImageOCRService: \(level == .accurate ? ".accurate" : ".fast") found \(results.count) text regions")
                    continuation.resume(returning: results)
                } catch {
                    Logger.general.error("ImageOCRService: OCR failed (\(level == .accurate ? "accurate" : "fast")) - \(error.localizedDescription, privacy: .public)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
