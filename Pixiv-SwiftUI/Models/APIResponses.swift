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
