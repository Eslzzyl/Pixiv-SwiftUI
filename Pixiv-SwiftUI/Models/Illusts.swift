import Foundation
import SwiftData

/// 标签信息
@Model
final class Tag: Codable {
    var name: String
    var translatedName: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
    
    init(name: String, translatedName: String? = nil) {
        self.name = name
        self.translatedName = translatedName
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.translatedName = try container.decodeIfPresent(String.self, forKey: .translatedName)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(translatedName, forKey: .translatedName)
    }
}

/// 图片基础 URL 集合
@Model
final class ImageUrls: Codable {
    var squareMedium: String
    var medium: String
    var large: String
    
    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
    }
    
    init(squareMedium: String, medium: String, large: String) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.squareMedium = try container.decode(String.self, forKey: .squareMedium)
        self.medium = try container.decode(String.self, forKey: .medium)
        self.large = try container.decode(String.self, forKey: .large)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(squareMedium, forKey: .squareMedium)
        try container.encode(medium, forKey: .medium)
        try container.encode(large, forKey: .large)
    }
}

/// 单个图片页面的元数据（主要用于获取原始图片 URL）
@Model
final class MetaSinglePage: Codable {
    var originalImageUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case originalImageUrl = "original_image_url"
    }
    
    init(originalImageUrl: String? = nil) {
        self.originalImageUrl = originalImageUrl
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.originalImageUrl = try container.decodeIfPresent(String.self, forKey: .originalImageUrl)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(originalImageUrl, forKey: .originalImageUrl)
    }
}

/// 多页面图片的页面元数据中的 URL 集合
@Model
final class MetaPagesImageUrls: Codable {
    var squareMedium: String
    var medium: String
    var large: String
    var original: String
    
    enum CodingKeys: String, CodingKey {
        case squareMedium = "square_medium"
        case medium
        case large
        case original
    }
    
    init(squareMedium: String, medium: String, large: String, original: String) {
        self.squareMedium = squareMedium
        self.medium = medium
        self.large = large
        self.original = original
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.squareMedium = try container.decode(String.self, forKey: .squareMedium)
        self.medium = try container.decode(String.self, forKey: .medium)
        self.large = try container.decode(String.self, forKey: .large)
        self.original = try container.decode(String.self, forKey: .original)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(squareMedium, forKey: .squareMedium)
        try container.encode(medium, forKey: .medium)
        try container.encode(large, forKey: .large)
        try container.encode(original, forKey: .original)
    }
}

/// 多页面图片的页面元数据
@Model
final class MetaPages: Codable {
    var imageUrls: MetaPagesImageUrls?
    
    enum CodingKeys: String, CodingKey {
        case imageUrls = "image_urls"
    }
    
    init(imageUrls: MetaPagesImageUrls? = nil) {
        self.imageUrls = imageUrls
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.imageUrls = try container.decodeIfPresent(MetaPagesImageUrls.self, forKey: .imageUrls)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(imageUrls, forKey: .imageUrls)
    }
}

/// 插画系列信息
@Model
final class IllustSeries: Codable {
    var id: Int
    var title: String?
    
    init(id: Int, title: String? = nil) {
        self.id = id
        self.title = title
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
    }
}

/// 插画信息
@Model
final class Illusts: Codable {
    @Attribute(.unique) var id: Int
    var title: String
    var type: String
    var imageUrls: ImageUrls
    var caption: String
    var restrict: Int
    var user: User
    var tags: [Tag]
    var tools: [String]
    var createDate: String
    var pageCount: Int
    var width: Int
    var height: Int
    var sanityLevel: Int
    var xRestrict: Int
    var metaSinglePage: MetaSinglePage?
    var metaPages: [MetaPages]
    var totalView: Int
    var totalBookmarks: Int
    var isBookmarked: Bool
    var bookmarkRestrict: String? // "public" 或 "private"
    var visible: Bool
    var isMuted: Bool
    var illustAIType: Int
    var series: IllustSeries?
    var illustBookStyle: Int?
    var totalComments: Int?
    var restrictionAttributes: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case imageUrls = "image_urls"
        case caption
        case restrict
        case user
        case tags
        case tools
        case createDate = "create_date"
        case pageCount = "page_count"
        case width
        case height
        case sanityLevel = "sanity_level"
        case xRestrict = "x_restrict"
        case metaSinglePage = "meta_single_page"
        case metaPages = "meta_pages"
        case totalView = "total_view"
        case totalBookmarks = "total_bookmarks"
        case isBookmarked = "is_bookmarked"
        case bookmarkRestrict = "bookmark_restrict"
        case visible
        case isMuted = "is_muted"
        case illustAIType = "illust_ai_type"
        case series
        case illustBookStyle = "illust_book_style"
        case totalComments = "total_comments"
        case restrictionAttributes = "restriction_attributes"
    }
    
    init(id: Int, title: String, type: String, imageUrls: ImageUrls, caption: String, restrict: Int, user: User, tags: [Tag], tools: [String], createDate: String, pageCount: Int, width: Int, height: Int, sanityLevel: Int, xRestrict: Int, metaSinglePage: MetaSinglePage?, metaPages: [MetaPages], totalView: Int, totalBookmarks: Int, isBookmarked: Bool, bookmarkRestrict: String?, visible: Bool, isMuted: Bool, illustAIType: Int, series: IllustSeries? = nil, illustBookStyle: Int? = nil, totalComments: Int? = nil, restrictionAttributes: [String] = []) {
        self.id = id
        self.title = title
        self.type = type
        self.imageUrls = imageUrls
        self.caption = caption
        self.restrict = restrict
        self.user = user
        self.tags = tags
        self.tools = tools
        self.createDate = createDate
        self.pageCount = pageCount
        self.width = width
        self.height = height
        self.sanityLevel = sanityLevel
        self.xRestrict = xRestrict
        self.metaSinglePage = metaSinglePage
        self.metaPages = metaPages
        self.totalView = totalView
        self.totalBookmarks = totalBookmarks
        self.isBookmarked = isBookmarked
        self.bookmarkRestrict = bookmarkRestrict
        self.visible = visible
        self.isMuted = isMuted
        self.illustAIType = illustAIType
        self.series = series
        self.illustBookStyle = illustBookStyle
        self.totalComments = totalComments
        self.restrictionAttributes = restrictionAttributes
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.type = try container.decode(String.self, forKey: .type)
        self.imageUrls = try container.decode(ImageUrls.self, forKey: .imageUrls)
        self.caption = try container.decode(String.self, forKey: .caption)
        self.restrict = try container.decode(Int.self, forKey: .restrict)
        self.user = try container.decode(User.self, forKey: .user)
        self.tags = try container.decode([Tag].self, forKey: .tags)
        self.tools = try container.decode([String].self, forKey: .tools)
        self.createDate = try container.decode(String.self, forKey: .createDate)
        self.pageCount = try container.decode(Int.self, forKey: .pageCount)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
        self.sanityLevel = try container.decode(Int.self, forKey: .sanityLevel)
        self.xRestrict = try container.decode(Int.self, forKey: .xRestrict)
        self.metaSinglePage = try container.decodeIfPresent(MetaSinglePage.self, forKey: .metaSinglePage)
        self.metaPages = try container.decode([MetaPages].self, forKey: .metaPages)
        self.totalView = try container.decode(Int.self, forKey: .totalView)
        self.totalBookmarks = try container.decode(Int.self, forKey: .totalBookmarks)
        self.isBookmarked = try container.decode(Bool.self, forKey: .isBookmarked)
        self.bookmarkRestrict = try container.decodeIfPresent(String.self, forKey: .bookmarkRestrict)
        self.visible = try container.decode(Bool.self, forKey: .visible)
        self.isMuted = try container.decode(Bool.self, forKey: .isMuted)
        self.illustAIType = try container.decode(Int.self, forKey: .illustAIType)
        self.series = try container.decodeIfPresent(IllustSeries.self, forKey: .series)
        self.illustBookStyle = try container.decodeIfPresent(Int.self, forKey: .illustBookStyle)
        self.totalComments = try container.decodeIfPresent(Int.self, forKey: .totalComments)
        self.restrictionAttributes = try container.decodeIfPresent([String].self, forKey: .restrictionAttributes) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(imageUrls, forKey: .imageUrls)
        try container.encode(caption, forKey: .caption)
        try container.encode(restrict, forKey: .restrict)
        try container.encode(user, forKey: .user)
        try container.encode(tags, forKey: .tags)
        try container.encode(tools, forKey: .tools)
        try container.encode(createDate, forKey: .createDate)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(sanityLevel, forKey: .sanityLevel)
        try container.encode(xRestrict, forKey: .xRestrict)
        try container.encodeIfPresent(metaSinglePage, forKey: .metaSinglePage)
        try container.encode(metaPages, forKey: .metaPages)
        try container.encode(totalView, forKey: .totalView)
        try container.encode(totalBookmarks, forKey: .totalBookmarks)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encodeIfPresent(bookmarkRestrict, forKey: .bookmarkRestrict)
        try container.encode(visible, forKey: .visible)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(illustAIType, forKey: .illustAIType)
        try container.encodeIfPresent(series, forKey: .series)
        try container.encodeIfPresent(illustBookStyle, forKey: .illustBookStyle)
        try container.encodeIfPresent(totalComments, forKey: .totalComments)
        try container.encode(restrictionAttributes, forKey: .restrictionAttributes)
    }
}
