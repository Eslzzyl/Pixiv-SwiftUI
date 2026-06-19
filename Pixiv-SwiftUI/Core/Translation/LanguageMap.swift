import Foundation

struct LanguageMap {
    static let mappings: [String: String] = [
        "pt-BR": "pt"
    ]

    static let baiduMappings: [String: String] = [
        "zh-CN": "zh",
        "zh-TW": "cht",
        "en": "en",
        "ja": "jp",
        "ko": "kor",
        "fr": "fra",
        "es": "spa",
        "ru": "ru",
        "de": "de",
        "it": "it",
        "vi": "vie",
        "pt": "pt",
        "pt-BR": "pt",
        "nl": "nl",
        "pl": "pl",
        "th": "th",
        "ar": "ar",
        "ms": "may"
    ]

    static let deepLMappings: [String: String] = [
        "pt-BR": "PT-BR",
        "pt-PT": "PT-PT",
        "zh-CN": "ZH-HANS",
        "zh-HK": "ZH-HANT",
        "zh-MO": "ZH-HANT",
        "zh-SG": "ZH-HANS",
        "zh-TW": "ZH-HANT"
    ]

    static let tencentMappings: [String: String] = [:]

    static let youdaoMappings: [String: String] = [
        "zh-CN": "ZH-CHS",
        "zh-TW": "ZH-CHT",
        "zh-HK": "ZH-CHT",
        "zh-MO": "ZH-CHT"
    ]

    static func map(_ code: String) -> String {
        mappings[code] ?? code
    }

    static func mapForBaidu(_ code: String?) -> String {
        guard let code = code, !code.isEmpty else { return "auto" }
        return baiduMappings[code] ?? code
    }

    static func mapForDeepL(_ code: String?) -> String {
        guard let code = code, !code.isEmpty else { return "auto" }
        let langCode = code.lowercased()
        if let mapped = deepLMappings[code] {
            return mapped
        }
        return langCode.split(separator: "-").map { $0.uppercased() }.joined(separator: "-")
    }

    static func mapForTencent(_ code: String?) -> String {
        guard let code = code, !code.isEmpty else { return "auto" }
        return code.split(separator: "-").map { $0.lowercased() }.joined(separator: "-")
    }

    static func mapForYoudao(_ code: String?) -> String {
        guard let code = code, !code.isEmpty else { return "auto" }
        if let mapped = youdaoMappings[code] {
            return mapped
        }
        return code.split(separator: "-").map { $0.lowercased() }.joined(separator: "-")
    }
}
