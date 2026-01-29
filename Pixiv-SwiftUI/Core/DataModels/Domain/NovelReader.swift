import Foundation

struct NovelReaderContent: Codable {
    let id: Int
    let title: String
    let seriesId: Int?
    let seriesTitle: String?
    let seriesIsWatched: Bool?
    let userId: Int
    let coverUrl: String?
    let tags: [String]
    let caption: String
    let createDate: String
    let totalView: Int
    let totalBookmarks: Int
    let isBookmarked: Bool?
    let xRestrict: Int?
    let novelAIType: Int?
    let marker: String?
    let text: String
    let illusts: [NovelIllustData]?
    let images: [NovelUploadedImage]?
    let seriesNavigation: SeriesNavigation?

    enum CodingKeys: String, CodingKey {
        case id, title, seriesId, seriesTitle, seriesIsWatched, userId, coverUrl, tags, caption, marker, text, illusts, images, seriesNavigation, rating
        case createDate = "cdate"
        case isBookmarked
        case xRestrict = "x_restrict"
        case novelAIType = "aiType"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        seriesTitle = try container.decodeIfPresent(String.self, forKey: .seriesTitle)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        caption = try container.decode(String.self, forKey: .caption)
        createDate = try container.decode(String.self, forKey: .createDate)
        xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict)
        marker = try container.decodeIfPresent(String.self, forKey: .marker)
        text = try container.decode(String.self, forKey: .text)

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        seriesIsWatched = try container.decodeIfPresent(Bool.self, forKey: .seriesIsWatched)
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked)
        illusts = try container.decodeIfPresent([NovelIllustData].self, forKey: .illusts)
        images = try container.decodeIfPresent([NovelUploadedImage].self, forKey: .images)
        seriesNavigation = try container.decodeIfPresent(SeriesNavigation.self, forKey: .seriesNavigation)

        id = try Self.decodeIntFromStringOrInt(container: container, key: .id)
        seriesId = try Self.decodeOptionalIntFromStringOrInt(container: container, key: .seriesId)
        userId = try Self.decodeIntFromStringOrInt(container: container, key: .userId)
        novelAIType = try container.decodeIfPresent(Int.self, forKey: .novelAIType)

        if let rating = try container.decodeIfPresent(Rating.self, forKey: .rating) {
            totalView = rating.view
            totalBookmarks = rating.bookmark
        } else {
            totalView = 0
            totalBookmarks = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(seriesId, forKey: .seriesId)
        try container.encodeIfPresent(seriesTitle, forKey: .seriesTitle)
        try container.encodeIfPresent(seriesIsWatched, forKey: .seriesIsWatched)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
        try container.encode(tags, forKey: .tags)
        try container.encode(caption, forKey: .caption)
        try container.encode(createDate, forKey: .createDate)
        try container.encodeIfPresent(isBookmarked, forKey: .isBookmarked)
        try container.encodeIfPresent(xRestrict, forKey: .xRestrict)
        try container.encodeIfPresent(novelAIType, forKey: .novelAIType)
        try container.encodeIfPresent(marker, forKey: .marker)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(illusts, forKey: .illusts)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(seriesNavigation, forKey: .seriesNavigation)

        let rating = Rating(like: 0, bookmark: totalBookmarks, view: totalView)
        try container.encode(rating, forKey: .rating)
    }

    struct Rating: Codable {
        let like: Int
        let bookmark: Int
        let view: Int
    }

    static func decodeIntFromStringOrInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? container.decode(String.self, forKey: key) {
            return Int(stringValue) ?? 0
        } else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Expected Int or String")
        }
    }

    static func decodeOptionalIntFromStringOrInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        } else {
            return nil
        }
    }
}

struct NovelReaderInfo: Codable {
    let id: Int
    let title: String
    let seriesId: Int?
    let seriesTitle: String?
    let seriesIsWatched: Bool?
    let userId: Int
    let coverUrl: String?
    let tags: [String]
    let caption: String
    let createDate: String
    let totalView: Int
    let totalBookmarks: Int
    let isBookmarked: Bool?
    let xRestrict: Int?
    let novelAIType: Int?
    let marker: String?

    enum CodingKeys: String, CodingKey {
        case id, title, seriesId, seriesTitle, seriesIsWatched, userId, coverUrl, tags, caption, marker, rating
        case createDate = "cdate"
        case isBookmarked
        case xRestrict = "x_restrict"
        case novelAIType = "aiType"
    }

    struct Rating: Codable {
        let like: Int
        let bookmark: Int
        let view: Int
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        seriesTitle = try container.decodeIfPresent(String.self, forKey: .seriesTitle)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        caption = try container.decode(String.self, forKey: .caption)
        createDate = try container.decode(String.self, forKey: .createDate)
        xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict)
        marker = try container.decodeIfPresent(String.self, forKey: .marker)

        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        seriesIsWatched = try container.decodeIfPresent(Bool.self, forKey: .seriesIsWatched)
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked)

        id = try Self.decodeIntFromStringOrInt(container: container, key: .id)
        seriesId = try Self.decodeOptionalIntFromStringOrInt(container: container, key: .seriesId)
        userId = try Self.decodeIntFromStringOrInt(container: container, key: .userId)
        novelAIType = try container.decodeIfPresent(Int.self, forKey: .novelAIType)

        if let rating = try container.decodeIfPresent(Rating.self, forKey: .rating) {
            totalView = rating.view
            totalBookmarks = rating.bookmark
        } else {
            totalView = 0
            totalBookmarks = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(seriesId, forKey: .seriesId)
        try container.encodeIfPresent(seriesTitle, forKey: .seriesTitle)
        try container.encodeIfPresent(seriesIsWatched, forKey: .seriesIsWatched)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
        try container.encode(tags, forKey: .tags)
        try container.encode(caption, forKey: .caption)
        try container.encode(createDate, forKey: .createDate)
        try container.encodeIfPresent(isBookmarked, forKey: .isBookmarked)
        try container.encodeIfPresent(xRestrict, forKey: .xRestrict)
        try container.encodeIfPresent(novelAIType, forKey: .novelAIType)
        try container.encodeIfPresent(marker, forKey: .marker)

        let rating = Rating(like: 0, bookmark: totalBookmarks, view: totalView)
        try container.encode(rating, forKey: .rating)
    }

    static func decodeIntFromStringOrInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Int {
        if let intValue = try? container.decode(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? container.decode(String.self, forKey: key) {
            return Int(stringValue) ?? 0
        } else {
            throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "Expected Int or String")
        }
    }

    static func decodeOptionalIntFromStringOrInt(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Int? {
        if let intValue = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intValue
        } else if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        } else {
            return nil
        }
    }
}

struct NovelIllustData: Codable {
    let illust: IllustMini
}

struct NovelUploadedImage: Codable {
    let urls: NovelImageUrls
}

struct NovelImageUrls: Codable {
    let the128X128: String?
    let the1200X1200: String?
    let original: String?

    enum CodingKeys: String, CodingKey {
        case the128X128 = "128x128"
        case the1200X1200 = "1200x1200"
        case original
    }
}

struct SeriesNavigation: Codable {
    let prevNovel: PrevNextNovel?
    let nextNovel: PrevNextNovel?

    enum CodingKeys: String, CodingKey {
        case prevNovel = "prev_novel"
        case nextNovel = "next_novel"
    }
}

struct PrevNextNovel: Codable {
    let id: Int
    let title: String
    let order: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case order
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        order = try container.decodeIfPresent(Int.self, forKey: .order)

        if let intValue = try? container.decode(Int.self, forKey: .id) {
            id = intValue
        } else if let stringValue = try? container.decode(String.self, forKey: .id) {
            id = Int(stringValue) ?? 0
        } else {
            id = 0
        }
    }
}

struct IllustMini: Codable {
    let id: Int
    let title: String
    let type: String
    let imageUrls: ImageUrls

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case imageUrls = "image_urls"
    }
}

struct NovelReaderSettings: Codable {
    var fontSize: CGFloat = 16
    var lineHeight: CGFloat = 1.8
    var theme: ReaderTheme = .system
    var fontFamily: ReaderFontFamily = .default
    var horizontalPadding: CGFloat = 16
    var translationDisplayMode: TranslationDisplayMode = .translationOnly
    var firstLineIndent: Bool = true

    enum CodingKeys: String, CodingKey {
        case fontSize
        case lineHeight
        case theme
        case fontFamily
        case horizontalPadding
        case translationDisplayMode
        case firstLineIndent
    }
}

enum ReaderFontFamily: String, Codable, CaseIterable {
    case `default`
    case serif

    var displayName: String {
        switch self {
        case .default: return "系统默认"
        case .serif: return "宋体 / 衬线"
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .default:
            return .system(size: size, weight: weight, design: .default)
        case .serif:
            #if os(iOS)
            // iOS .serif design 不支持 CJK，需要手动指定系统衬线字体
            return .custom("Songti SC", size: size).weight(weight)
            #else
            return .system(size: size, weight: weight, design: .serif)
            #endif
        }
    }
}

enum ReaderTheme: String, Codable, CaseIterable {
    case light
    case dark
    case system
    case sepia

    var displayName: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        case .sepia: return "护眼"
        }
    }

    var backgroundColor: ColorValue {
        switch self {
        case .light: return .white
        case .dark: return ColorValue(red: 0.11, green: 0.11, blue: 0.11)
        case .system: return Color.clear
        case .sepia: return ColorValue(red: 0.96, green: 0.94, blue: 0.88)
        }
    }

    var textColor: ColorValue {
        switch self {
        case .light, .sepia: return .black
        case .dark, .system: return .white
        }
    }
}

enum TranslationDisplayMode: String, Codable, CaseIterable {
    case translationOnly
    case bilingual

    var displayName: String {
        switch self {
        case .translationOnly: return "仅译文"
        case .bilingual: return "原文对照"
        }
    }

    var description: String {
        switch self {
        case .translationOnly: return "只显示译文，译文使用与原文相同的样式"
        case .bilingual: return "同时显示原文和译文，译文使用稍次级的样式"
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

typealias ColorValue = Color
#else
typealias ColorValue = String
#endif
