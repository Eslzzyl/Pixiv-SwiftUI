import Foundation

enum NovelExportFormat: String, Codable, Sendable {
    case txt

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        }
    }

    var displayName: String {
        switch self {
        case .txt: return String(localized: "纯文本 (TXT)")
        }
    }

    var utType: String {
        switch self {
        case .txt: return "public.plain-text"
        }
    }
}
