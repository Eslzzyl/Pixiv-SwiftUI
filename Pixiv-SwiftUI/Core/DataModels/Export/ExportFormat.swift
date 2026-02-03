import Foundation

struct ExportHeader: Codable {
    let version: Int
    let type: ExportDataType
    let exportedAt: Date

    enum CodingKeys: String, CodingKey {
        case version
        case type
        case exportedAt = "exported_at"
    }
}

enum ExportDataType: String, Codable {
    case searchHistory
    case glanceHistory
    case muteData
    case crashReport
}

struct SearchHistoryExport: Codable {
    let tagHistory: [TagHistoryItem]
    let bookTags: [String]

    enum CodingKeys: String, CodingKey {
        case tagHistory = "tag_history"
        case bookTags = "book_tags"
    }
}

struct TagHistoryItem: Codable {
    let name: String
    let translatedName: String?
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
        case type
    }
}

struct GlanceHistoryExport: Codable {
    let illustHistory: [IllustHistoryItem]
    let novelHistory: [NovelHistoryItem]

    enum CodingKeys: String, CodingKey {
        case illustHistory = "illust_history"
        case novelHistory = "novel_history"
    }
}

struct IllustHistoryItem: Codable, Sendable {
    let illustId: Int
    let viewedAt: Int64
    let title: String?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case illustId = "illust_id"
        case viewedAt = "viewed_at"
        case title
        case userName = "user_name"
    }
}

struct NovelHistoryItem: Codable, Sendable {
    let novelId: Int
    let viewedAt: Int64
    let title: String?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case novelId = "novel_id"
        case viewedAt = "viewed_at"
        case title
        case userName = "user_name"
    }
}

struct MuteDataExport: Codable {
    let banTags: [BanTagItem]
    let banUserIds: [BanUserIdItem]
    let banIllustIds: [BanIllustIdItem]

    enum CodingKeys: String, CodingKey {
        case banTags = "ban_tags"
        case banUserIds = "ban_user_ids"
        case banIllustIds = "ban_illust_ids"
    }
}

struct BanTagItem: Codable, Sendable {
    let name: String
    let translatedName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
}

struct BanUserIdItem: Codable, Sendable {
    let userId: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
    }
}

struct BanIllustIdItem: Codable, Sendable {
    let illustId: Int
    let name: String?

    enum CodingKeys: String, CodingKey {
        case illustId = "illust_id"
        case name
    }
}

enum ImportConflictStrategy: String, Identifiable {
    case merge
    case replace
    case cancel

    var id: String { rawValue }
}
