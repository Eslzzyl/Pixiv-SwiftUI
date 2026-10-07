import Foundation
import os.log

/// Pixiv Ajax API 实现
/// 
/// Pixiv Web 端接口，提供了一些 App API 不具备的功能。
/// 该 API 基于 Cookie 认证 (PHPSESSID) 和 CSRF Token (X-CSRF-Token)。
@MainActor
final class AjaxAPI {
    private let client = NetworkClient.shared
    private var csrfToken: String?
    private var phpSessId: String?
    private var yuidB: String?
    private var pAbDId: String?
    private var pAbId: String?
    private var pAbId2: String?

    // 使用桌面版 User-Agent 以确保与桌面端 Ajax 接口结构一致
    private let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    private var ajaxHeaders: [String: String] {
        var headers = [
            "User-Agent": userAgent,
            "Referer": "https://www.pixiv.net/",
            "Accept": "application/json",
            "X-Requested-With": "XMLHttpRequest"
        ]

        if let cookieHeaderValue {
            headers["Cookie"] = cookieHeaderValue
        }

        if let token = csrfToken {
            headers["X-CSRF-Token"] = token
        }
        return headers
    }

    /// 设置当前 Ajax 会话的 PHPSESSID
    func setPHPSESSID(_ phpsessid: String?) {
        setSessionCookies(phpSessId: phpsessid, yuidB: nil, pAbDId: nil, pAbId: nil, pAbId2: nil)
    }

    /// 设置当前 Ajax 会话 cookies
    func setSessionCookies(
        phpSessId: String?,
        yuidB: String?,
        pAbDId: String?,
        pAbId: String?,
        pAbId2: String?
    ) {
        self.phpSessId = normalizeCookieValue(phpSessId)
        self.yuidB = normalizeCookieValue(yuidB)
        self.pAbDId = normalizeCookieValue(pAbDId)
        self.pAbId = normalizeCookieValue(pAbId)
        self.pAbId2 = normalizeCookieValue(pAbId2)
        csrfToken = nil
    }

    /// 获取或刷新 CSRF Token
    /// 从 Pixiv 首页的 HTML 或脚本数据中提取
    func refreshCSRFToken() async throws {
        guard let url = URL(string: "https://www.pixiv.net/") else { throw NetworkError.invalidURL }

        let htmlData = try await client.get(
            from: url,
            headers: csrfFetchHeaders,
            responseType: Data.self
        )
        guard let html = String(data: htmlData, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }

        // 尝试方法 1: 从 __NEXT_DATA__ 中提取
        let nextDataPattern = #"<script id="__NEXT_DATA__" type="application/json">(.*?)</script>"#
        if let regex = try? NSRegularExpression(pattern: nextDataPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {

            let nextDataJson = String(html[range])
            let decoder = JSONDecoder()

            if let data = nextDataJson.data(using: .utf8),
               let nextData = try? decoder.decode(JSONValue.self, from: data) {
                let pageProps = nextData["props"]["pageProps"]

                // 路径 1: props.pageProps.serverSerializedPreloadedState
                if let stateStr = pageProps["serverSerializedPreloadedState"].stringValue,
                   let stateData = stateStr.data(using: .utf8),
                   let decodedState = try? decoder.decode(JSONValue.self, from: stateData),
                   let token = decodedState["api"]["token"].stringValue {
                    self.csrfToken = token
                    return
                }

                // 路径 2: props.pageProps.preloadedState
                if let token = pageProps["preloadedState"]["api"]["token"].stringValue {
                    self.csrfToken = token
                    return
                }
            }
        }

        // 尝试方法 2: 直接在 HTML 中搜索 "token":"..."
        // token 长度在不同版本/页面结构下可能变化，这里放宽为 32~128 位 hex。
        let tokenPattern = #""token":"([0-9a-fA-F]{32,128})""#
        if let regex = try? NSRegularExpression(pattern: tokenPattern, options: []),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let range = Range(match.range(at: 1), in: html) {
            self.csrfToken = String(html[range])
            return
        }

        let prefix = String(html.prefix(240))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        Logger.network.debug("Failed to extract CSRF token. htmlLength=\(html.count), hasNextData=\(html.contains("__NEXT_DATA__")), prefix=\(prefix.redactingSensitiveValues())")

        throw NetworkError.invalidResponse
    }

    private var csrfFetchHeaders: [String: String] {
        var headers = [
            "User-Agent": userAgent,
            "Accept": "text/html",
            "Referer": "https://www.pixiv.net/"
        ]

        if let cookieHeaderValue {
            headers["Cookie"] = cookieHeaderValue
        }

        return headers
    }

    /// 获取搜索建议 (Ajax 版)
    /// 包含热门标签、推荐标签及其图标等
    func getSearchSuggestion(mode: String = "all", lang: String = "zh") async throws -> SearchSuggestionResponse {
        var components = URLComponents(string: APIEndpoint.ajaxBaseURL + "/search/suggestion")
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode),
            URLQueryItem(name: "lang", value: lang)
        ]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        let maskedCookieValue = cookieHeaderValue.map(Self.maskCookieHeader) ?? "None"
        Logger.network.debug("Fetching search suggestion with cookies: \(maskedCookieValue, privacy: .public)")

        let response = try await client.get(
            from: url,
            headers: ajaxHeaders,
            responseType: SearchSuggestionResponse.self
        )

        return response
    }

    func validateSession() async -> Bool {
        guard let url = URL(string: APIEndpoint.ajaxBaseURL + "/settings/self") else { return false }

        do {
            let data = try await client.get(
                from: url,
                headers: ajaxHeaders,
                responseType: Data.self
            )

            guard
                let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let errorFlag = jsonObject["error"] as? Bool
            else {
                return false
            }

            if errorFlag {
                return false
            }

            return true
        } catch {
            return false
        }
    }

    private var cookieHeaderValue: String? {
        var pairs: [String] = []

        if let phpSessId {
            pairs.append("PHPSESSID=\(phpSessId)")
        }
        if let yuidB {
            pairs.append("yuid_b=\(yuidB)")
        }
        if let pAbDId {
            pairs.append("p_ab_d_id=\(pAbDId)")
        }
        if let pAbId {
            pairs.append("p_ab_id=\(pAbId)")
        }
        if let pAbId2 {
            pairs.append("p_ab_id_2=\(pAbId2)")
        }

        if pairs.isEmpty {
            return nil
        }
        return pairs.joined(separator: "; ")
    }

    private static func maskCookieHeader(_ cookieHeader: String) -> String {
        cookieHeader
            .split(separator: ";", omittingEmptySubsequences: true)
            .map { pair in
                let cookie = String(pair).trimmingCharacters(in: .whitespaces)
                guard let separator = cookie.firstIndex(of: "=") else {
                    return cookie.maskedMiddle()
                }

                let name = cookie[..<separator]
                let valueStart = cookie.index(after: separator)
                let value = cookie[valueStart...].trimmingCharacters(in: .whitespaces)
                return "\(name)=\(value.maskedMiddle())"
            }
            .joined(separator: "; ")
    }

    private func normalizeCookieValue(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalized, !normalized.isEmpty {
            return normalized
        }
        return nil
    }

}

// MARK: - Models for Search Suggestion

/// 用于灵活解析不确定结构的 JSON
enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
        } else if let x = try? container.decode(Double.self) {
            self = .number(x)
        } else if let x = try? container.decode(Bool.self) {
            self = .bool(x)
        } else if let x = try? container.decode([String: JSONValue].self) {
            self = .object(x)
        } else if let x = try? container.decode([JSONValue].self) {
            self = .array(x)
        } else {
            self = .null
        }
    }

    subscript(key: String) -> JSONValue {
        if case .object(let dict) = self {
            return dict[key] ?? .null
        }
        return .null
    }

    var stringValue: String? {
        if case .string(let str) = self {
            return str
        }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }
}

struct SearchSuggestionResponse: Decodable {
    let error: Bool
    let body: SuggestionBody
}

struct SuggestionBody: Decodable {
    let popularTags: SuggestionTagGroup
    let recommendTags: SuggestionTagGroup?
    let recommendByTags: SuggestionTagGroup?
    let myFavoriteTags: [String]?
    let tagTranslation: [String: TagTranslation]?
    let thumbnails: [SuggestionThumbnail]?
}

struct SuggestionTagGroup: Decodable {
    let illust: [SuggestionTag]
    let novel: [SuggestionTag]?
}

struct SuggestionTag: Decodable {
    /// 这里的 IDs 可能是 Int(插画ID) 也可能是 String(插画ID)
    let ids: [SuggestionValue]
    let tag: String
}

// swiftlint:disable identifier_name
struct TagTranslation: Decodable {
    let en: String?
    let ko: String?
    let zh: String?
    let zh_tw: String?
    let romaji: String?
}
// swiftlint:enable identifier_name

struct SuggestionThumbnail: Decodable {
    let id: String
    let title: String
    let url: String
    let userId: String
    let userName: String
}

/// 兼容 Int 和 String 的 Codable 模型
enum SuggestionValue: Decodable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        if let x = try? container.decode(Int.self) {
            self = .int(x)
            return
        }
        throw DecodingError.typeMismatch(SuggestionValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for SuggestionValue"))
    }
}
