import Foundation

struct PixivDescriptionParser {
    /// 解析简介文本，将 HTML 转换为 Markdown（保留链接）
    static func parse(_ text: String) -> String {
        var result = text

        // 1. 替换换行符
        result = result.replacingOccurrences(of: "<br />", with: "\n")
        result = result.replacingOccurrences(of: "<br>", with: "\n")

        // 2. 将 <a href="...">text</a> 转换为 Markdown [text](url)
        let pattern = "<a[^>]+href=\"([^\"]+)\"[^>]*>(.*?)</a>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let nsRange = NSRange(result.startIndex..<result.endIndex, in: result)
            result = regex.stringByReplacingMatches(in: result, options: [], range: nsRange, withTemplate: "[$2]($1)")
        }

        // 3. 移除其他 HTML 标签
        result = TextCleaner.stripHTMLTags(result)

        // 4. 解码 HTML 实体
        result = TextCleaner.decodeHTMLEntities(result)

        return result
    }

    /// 检查文本是否包含 HTML 链接
    static func containsLinks(_ text: String) -> Bool {
        return text.range(of: "<a[^>]+href=", options: .regularExpression) != nil
    }
}
