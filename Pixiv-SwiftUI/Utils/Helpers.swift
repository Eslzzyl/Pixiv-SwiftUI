import Foundation

/// 图片 URL 工具函数
struct ImageURLHelper {
    /// 根据质量设置获取图片 URL
    static func getImageURL(
        from illusts: Illusts,
        quality: Int,
        isPicture: Bool = true
    ) -> String {
        let targetQuality = isPicture ? illusts.imageUrls.medium : illusts.imageUrls.large

        switch quality {
        case 0:  // 中等
            return illusts.imageUrls.medium
        case 1:  // 大
            return illusts.imageUrls.large
        case 2:  // 原始
            // 对于单页图片，使用 metaSinglePage；对于多页，使用 metaPages 第一页
            if let originalUrl = illusts.metaSinglePage?.originalImageUrl {
                return originalUrl
            }
            return illusts.metaPages.first?.imageUrls?.original ?? targetQuality
        default:
            return targetQuality
        }
    }

    /// 获取特定页面的图片 URL
    static func getPageImageURL(
        from illusts: Illusts,
        page: Int,
        quality: Int
    ) -> String? {
        guard page >= 0 && page < illusts.metaPages.count else { return nil }

        let metaPage = illusts.metaPages[page]
        guard let urls = metaPage.imageUrls else { return nil }

        switch quality {
        case 0:  // 中等
            return urls.medium
        case 1:  // 大
            return urls.large
        case 2:  // 原始
            return urls.original
        default:
            return urls.medium
        }
    }

    /// 修改图片 URL 以绕过防盗链（需要正确的 Referer）
    static func addRefererHeader(url: String) -> (url: String, referer: String) {
        return (url: url, referer: "https://www.pixiv.net/")
    }
}

/// 日期格式化工具
struct DateFormatterHelper {
    static func formatDate(_ date: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        if let parsedDate = formatter.date(from: date) {
            let displayFormatter = Foundation.DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: parsedDate)
        }

        return date
    }

    static func formatRelativeTime(_ date: String) -> String {
        let formatter = Foundation.DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        guard let parsedDate = formatter.date(from: date) else {
            return date
        }

        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day, .hour, .minute], from: parsedDate, to: now)

        if let day = components.day, day > 0 {
            return "\(day) 天前"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) 小时前"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) 分钟前"
        } else {
            return "刚刚"
        }
    }
}

/// 文本清理工具
struct TextCleaner {
    /// 清理 HTML 标签
    static func stripHTMLTags(_ text: String) -> String {
        let regex = try? NSRegularExpression(pattern: "<[^>]*>", options: [])
        let range = NSRange(text.startIndex..., in: text)
        let result = regex?.stringByReplacingMatches(
            in: text, options: [], range: range, withTemplate: "")
        return result ?? text
    }

    /// 解码 HTML 实体（简化版本，不需要 AppKit）
    static func decodeHTMLEntities(_ text: String) -> String {
        // 简化实现：只处理常见的 HTML 实体
        var result = text
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        return result
    }
}

/// 数值格式化工具
struct NumberFormatter {
    static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return String(count)
        }
    }

    static func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

/// 验证工具
struct Validator {
    /// 验证邮箱格式
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }

    /// 验证用户名格式
    static func isValidUsername(_ username: String) -> Bool {
        return !username.trimmingCharacters(in: .whitespaces).isEmpty && username.count >= 3
    }
}
