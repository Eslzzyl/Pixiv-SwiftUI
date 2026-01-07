import Foundation

/// 系列详情
struct NovelSeriesDetail: Codable, Identifiable, Hashable {
    var id: Int
    var title: String
    var caption: String?
    var isOriginal: Bool
    var isConcluded: Bool
    var contentCount: Int
    var totalCharacterCount: Int
    var user: NovelSeriesUser
    var displayText: String
    var novelAIType: Int
    var watchlistAdded: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case isOriginal = "is_original"
        case isConcluded = "is_concluded"
        case contentCount = "content_count"
        case totalCharacterCount = "total_character_count"
        case user
        case displayText = "display_text"
        case novelAIType = "novel_ai_type"
        case watchlistAdded = "watchlist_added"
    }
}

/// 系列用户信息
struct NovelSeriesUser: Codable, Hashable {
    var id: Int
    var name: String
    var account: String
    var profileImageUrls: ProfileImageUrls
    var isFollowed: Bool
    var isAccessBlockingUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case profileImageUrls = "profile_image_urls"
        case isFollowed = "is_followed"
        case isAccessBlockingUser = "is_access_blocking_user"
    }
}

/// 系列响应
struct NovelSeriesResponse: Codable {
    var novelSeriesDetail: NovelSeriesDetail
    var novels: [Novel]
    var nextUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case novelSeriesDetail = "novel_series_detail"
        case novels
        case nextUrl = "next_url"
    }
}
