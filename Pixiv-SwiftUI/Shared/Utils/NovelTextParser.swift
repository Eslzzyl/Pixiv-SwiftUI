import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum NovelSpanType: String, Codable {
    case normal
    case newPage
    case chapter
    case pixivImage
    case uploadedImage
    case jumpUri
    case rubyText
}

struct NovelSpan: Identifiable {
    let id: Int
    let type: NovelSpanType
    let content: String
    let metadata: [String: Any]?

    init(id: Int, type: NovelSpanType, content: String, metadata: [String: Any]? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.metadata = metadata
    }
}

struct PixivImageMetadata {
    let illustId: Int
    let targetIndex: Int
    let imageUrl: String?
}

struct UploadedImageMetadata {
    let imageKey: String
    let imageUrl: String?
}

struct JumpUriMetadata {
    let title: String
    let url: String
}

struct RubyTextMetadata {
    let baseText: String
    let rubyText: String
}

final class NovelTextParser {

    static let shared = NovelTextParser()

    private init() {}

    func parse(_ text: String, illusts: [NovelIllustData]?, images: [NovelUploadedImage]?) -> [NovelSpan] {
        var spans: [NovelSpan] = []
        var currentText = ""
        var isCollectingTag = false
        var collectedTag = ""
        var spanId = 0

        for char in text {
            // 每个换行符创建一个新段落
            if char == "\n" {
                if !currentText.isEmpty {
                    spans.append(NovelSpan(
                        id: spanId,
                        type: .normal,
                        content: currentText
                    ))
                    spanId += 1
                    currentText = ""
                }
                continue
            }

            if char == "[" {
                if isCollectingTag {
                    collectedTag += String(char)
                } else {
                    if !currentText.isEmpty {
                        spans.append(NovelSpan(
                            id: spanId,
                            type: .normal,
                            content: currentText
                        ))
                        spanId += 1
                        currentText = ""
                    }
                    isCollectingTag = true
                    collectedTag = "["
                }
            } else if char == "]" {
                if isCollectingTag {
                    collectedTag += String(char)
                    if let span = parseTag(collectedTag, illusts: illusts, images: images) {
                        spans.append(span)
                        spanId += 1
                    }
                    isCollectingTag = false
                    collectedTag = ""
                } else {
                    currentText += String(char)
                }
            } else {
                if isCollectingTag {
                    collectedTag += String(char)
                } else {
                    currentText += String(char)
                }
            }
        }

        if !currentText.isEmpty {
            spans.append(NovelSpan(
                id: spanId,
                type: .normal,
                content: currentText
            ))
        }

        return spans
    }

    private func parseTag(_ tag: String, illusts: [NovelIllustData]?, images: [NovelUploadedImage]?) -> NovelSpan? {
        if tag == "[newpage]" {
            return NovelSpan(id: 0, type: .newPage, content: "")
        }

        if tag.hasPrefix("[chapter:") && tag.hasSuffix("]") {
            let title = String(tag.dropFirst(9).dropLast())
            return NovelSpan(id: 0, type: .chapter, content: title)
        }

        if tag.hasPrefix("[pixivimage:") && tag.hasSuffix("]") {
            let inner = String(tag.dropFirst(12).dropLast())
            let parts = inner.split(separator: "-", maxSplits: 1)
            guard let illustId = Int(parts[0]) else { return nil }
            let targetIndex = parts.count > 1 ? Int(parts[1]) ?? 0 : 0

            let metadata: [String: Any] = [
                "illustId": illustId,
                "targetIndex": targetIndex,
                "imageUrl": nil as Any?
            ]

            return NovelSpan(
                id: 0,
                type: .pixivImage,
                content: inner,
                metadata: metadata
            )
        }

        if tag.hasPrefix("[uploadedimage:") && tag.hasSuffix("]") {
            let imageKey = String(tag.dropFirst(14).dropLast())

            let metadata: [String: Any] = [
                "imageKey": imageKey,
                "imageUrl": nil as Any?
            ]

            return NovelSpan(
                id: 0,
                type: .uploadedImage,
                content: imageKey,
                metadata: metadata
            )
        }

        if tag.hasPrefix("[[jumpuri:") && tag.hasSuffix("]") {
            let inner = String(tag.dropFirst(9).dropLast())
            let parts = inner.split(separator: ">", maxSplits: 1)
            guard parts.count > 1 else {
                return NovelSpan(id: 0, type: .jumpUri, content: inner, metadata: ["url": inner])
            }

            let title = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let url = String(parts[1]).trimmingCharacters(in: .whitespaces)

            let metadata: [String: Any] = [
                "title": title,
                "url": url
            ]

            return NovelSpan(id: 0, type: .jumpUri, content: title, metadata: metadata)
        }

        if tag.hasPrefix("[[rb:") && tag.hasSuffix("]") {
            let inner = String(tag.dropFirst(4).dropLast())
            let parts = inner.split(separator: ">", maxSplits: 1)
            guard parts.count > 1 else {
                return NovelSpan(id: 0, type: .normal, content: inner)
            }

            let baseText = String(parts[0])
            let rubyText = String(parts[1])

            let metadata: [String: Any] = [
                "baseText": baseText,
                "rubyText": rubyText
            ]

            return NovelSpan(id: 0, type: .rubyText, content: "\(baseText)(\(rubyText))", metadata: metadata)
        }

        return nil
    }

    func cleanHTML(_ html: String) -> String {
        var result = html
        let patterns: [(String, String)] = [
            ("<br\\s*/?>", "\n"),
            ("</p>", "\n\n"),
            ("</div>", "\n"),
            ("</h[1-6]>", "\n"),
            ("&nbsp;", " "),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&"),
            ("&quot;", "\""),
            ("&#39;", "'")
        ]

        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    options: [],
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }

        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 保留所有换行符，不再折叠多个连续换行
        // while result.contains("\n\n\n") {
        //     result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        // }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
