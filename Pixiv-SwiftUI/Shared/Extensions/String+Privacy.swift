import Foundation

extension String {
    func maskedMiddle(prefixLength: Int = 4, suffixLength: Int = 4) -> String {
        guard !isEmpty else { return self }

        let prefixLength = max(0, prefixLength)
        let suffixLength = max(0, suffixLength)
        guard count > prefixLength + suffixLength else {
            return String(repeating: "*", count: count)
        }

        return String(prefix(prefixLength)) + "**" + String(suffix(suffixLength))
    }

    func redactingSensitiveValues() -> String {
        let pattern = #"(?i)(\b(?:access_token|refresh_token|csrf_token|phpsessid|yuid_b|p_ab_d_id|p_ab_id_2|p_ab_id|authorization|cookie|token)\b\s*[:=]\s*(?:bearer\s+)?)(["']?)([^"',;&\s}]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }

        let matches = regex.matches(in: self, range: NSRange(startIndex..., in: self))
        guard !matches.isEmpty else { return self }

        let redacted = NSMutableString(string: self)
        for match in matches.reversed() {
            let valueRange = match.range(at: 3)
            let value = (self as NSString).substring(with: valueRange)
            redacted.replaceCharacters(in: valueRange, with: value.maskedMiddle())
        }
        return redacted as String
    }
}
