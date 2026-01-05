import Foundation

/// 小说信息
struct Novel: Codable, Identifiable, Hashable {
    var id: Int
    var title: String
    var caption: String
    var restrict: Int
    var xRestrict: Int
    var isOriginal: Bool
    var imageUrls: ImageUrls
    var createDate: String
    var tags: [NovelTag]
    var pageCount: Int
    var textLength: Int
    var user: User
    var series: NovelSeries?
    var isBookmarked: Bool
    var totalBookmarks: Int
    var totalView: Int
    var visible: Bool
    var isMuted: Bool
    var isMypixivOnly: Bool
    var isXRestricted: Bool
    var novelAIType: Int
    var totalComments: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case restrict
        case xRestrict = "x_restrict"
        case isOriginal = "is_original"
        case imageUrls = "image_urls"
        case createDate = "create_date"
        case tags
        case pageCount = "page_count"
        case textLength = "text_length"
        case user
        case series
        case isBookmarked = "is_bookmarked"
        case totalBookmarks = "total_bookmarks"
        case totalView = "total_view"
        case visible
        case isMuted = "is_muted"
        case isMypixivOnly = "is_mypixiv_only"
        case isXRestricted = "is_x_restricted"
        case novelAIType = "novel_ai_type"
        case totalComments = "total_comments"
    }
}

/// 系列信息
struct NovelSeries: Codable, Identifiable, Hashable {
    var id: Int?
    var title: String?
}

/// 标签
struct NovelTag: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var translatedName: String?
    var addedByUploadedUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
        case addedByUploadedUser = "added_by_uploaded_user"
    }
}

/// 小说列表响应
struct NovelResponse: Codable {
    var novels: [Novel]
    var nextUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case novels
        case nextUrl = "next_url"
    }
}

/// 小说详情响应
struct NovelDetailResponse: Codable {
    var novel: Novel
}
