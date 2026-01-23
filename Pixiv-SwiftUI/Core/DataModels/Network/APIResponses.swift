import Foundation

struct IllustsResponse: Codable {
    let illusts: [Illusts]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case illusts
        case nextUrl = "next_url"
    }
}

struct UserPreviewsResponse: Codable {
    let userPreviews: [UserPreviews]
    let nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case userPreviews = "user_previews"
        case nextUrl = "next_url"
    }
}

struct UserPreviews: Codable, Identifiable {
    var id: String { user.id.stringValue }
    let user: User
    let illusts: [Illusts]
    let novels: [UserPreviewsNovel]
    let isMuted: Bool

    enum CodingKeys: String, CodingKey {
        case user
        case illusts
        case novels
        case isMuted = "is_muted"
    }
}

struct UserPreviewsNovel: Codable, Identifiable {
    let id: Int
    let title: String
    let caption: String?
    let imageUrls: ImageUrls

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case caption
        case imageUrls = "image_urls"
    }
}

struct SearchAutoCompleteResponse: Codable {
    let tags: [SearchTag]
}

struct SearchTag: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let translatedName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case translatedName = "translated_name"
    }
}

struct TrendingTagsResponse: Codable {
    let trendTags: [TrendTag]

    enum CodingKeys: String, CodingKey {
        case trendTags = "trend_tags"
    }
}

struct TrendTag: Codable, Identifiable {
    var id: String { tag }
    let tag: String
    let translatedName: String?
    let illust: TrendTagIllust

    enum CodingKeys: String, CodingKey {
        case tag
        case translatedName = "translated_name"
        case illust
    }
}

struct TrendTagIllust: Codable {
    let id: Int
    let title: String
    let imageUrls: ImageUrls
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case imageUrls = "image_urls"
        case width
        case height
    }

    var aspectRatio: CGFloat? {
        guard let widthValue = width, let heightValue = height, heightValue > 0 else {
            return nil
        }
        return CGFloat(widthValue) / CGFloat(heightValue)
    }
}
