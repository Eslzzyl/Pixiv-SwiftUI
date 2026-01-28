import Foundation
import SwiftData

@Model
final class MangaSeries: Codable, Identifiable {
    var id: Int
    var title: String
    var userId: String
    var userName: String
    var profileImageUrl: String
    var isFollowed: Bool
    var workCount: Int
    var lastPublishedDate: String
    var latestContentId: Int
    var maskText: String?
    var url: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case userId = "user_id"
        case userName = "user_name"
        case profileImageUrl = "profile_image_url"
        case isFollowed = "is_followed"
        case workCount = "published_content_count"
        case lastPublishedDate = "last_published_content_datetime"
        case latestContentId = "latest_content_id"
        case maskText = "mask_text"
        case url
    }

    init(id: Int, title: String, userId: String, userName: String, profileImageUrl: String, isFollowed: Bool, workCount: Int, lastPublishedDate: String, latestContentId: Int, maskText: String? = nil, url: String? = nil) {
        self.id = id
        self.title = title
        self.userId = userId
        self.userName = userName
        self.profileImageUrl = profileImageUrl
        self.isFollowed = isFollowed
        self.workCount = workCount
        self.lastPublishedDate = lastPublishedDate
        self.latestContentId = latestContentId
        self.maskText = maskText
        self.url = url
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.userName = try container.decode(String.self, forKey: .userName)
        self.profileImageUrl = try container.decode(String.self, forKey: .profileImageUrl)
        self.isFollowed = try container.decode(Bool.self, forKey: .isFollowed)
        self.workCount = try container.decode(Int.self, forKey: .workCount)
        self.lastPublishedDate = try container.decode(String.self, forKey: .lastPublishedDate)
        self.latestContentId = try container.decode(Int.self, forKey: .latestContentId)
        self.maskText = try container.decodeIfPresent(String.self, forKey: .maskText)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(userId, forKey: .userId)
        try container.encode(userName, forKey: .userName)
        try container.encode(profileImageUrl, forKey: .profileImageUrl)
        try container.encode(isFollowed, forKey: .isFollowed)
        try container.encode(workCount, forKey: .workCount)
        try container.encode(lastPublishedDate, forKey: .lastPublishedDate)
        try container.encode(latestContentId, forKey: .latestContentId)
        try container.encodeIfPresent(maskText, forKey: .maskText)
        try container.encodeIfPresent(url, forKey: .url)
    }
}
