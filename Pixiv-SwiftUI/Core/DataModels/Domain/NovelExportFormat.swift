import Foundation

enum NovelExportFormat: String, Codable, Sendable {
    case txt
    case epub

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .epub: return "epub"
        }
    }

    var displayName: String {
        switch self {
        case .txt: return String(localized: "纯文本 (TXT)")
        case .epub: return String(localized: "EPUB 电子书")
        }
    }

    var utType: String {
        switch self {
        case .txt: return "public.plain-text"
        case .epub: return "org.idpf.epub-container"
        }
    }
}
