import Foundation
import SwiftData

/// 禁用 ID 列表
@Model
final class BanIllustId: Codable {
    var illustId: Int
    var ownerId: String = "guest"
    var timestamp: Date = Date()
    
    init(illustId: Int, ownerId: String = "guest") {
        self.illustId = illustId
        self.ownerId = ownerId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.illustId = try container.decode(Int.self, forKey: .illustId)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(illustId, forKey: .illustId)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case illustId
        case ownerId
        case timestamp
    }
}

/// 禁用用户 ID 列表
@Model
final class BanUserId: Codable {
    var userId: String
    var ownerId: String = "guest"
    var timestamp: Date = Date()
    
    init(userId: String, ownerId: String = "guest") {
        self.userId = userId
        self.ownerId = ownerId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId
        case ownerId
        case timestamp
    }
}

/// 禁用标签列表
@Model
final class BanTag: Codable {
    var name: String
    var ownerId: String = "guest"
    var timestamp: Date = Date()
    
    init(name: String, ownerId: String = "guest") {
        self.name = name
        self.ownerId = ownerId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case ownerId
        case timestamp
    }
}

/// 浏览历史记录
@Model
final class GlanceIllustPersist: Codable {
    @Attribute(.unique) var illustId: Int
    var ownerId: String = "guest"
    var viewedAt: Date = Date()

    init(illustId: Int, ownerId: String = "guest") {
        self.illustId = illustId
        self.ownerId = ownerId
        self.viewedAt = Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.illustId = try container.decode(Int.self, forKey: .illustId)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.viewedAt = try container.decodeIfPresent(Date.self, forKey: .viewedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(illustId, forKey: .illustId)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(viewedAt, forKey: .viewedAt)
    }

    enum CodingKeys: String, CodingKey {
        case illustId
        case ownerId
        case viewedAt
    }
}

/// 浏览历史记录（小说版）
@Model
final class GlanceNovelPersist: Codable {
    @Attribute(.unique) var novelId: Int
    var ownerId: String = "guest"
    var viewedAt: Date = Date()

    init(novelId: Int, ownerId: String = "guest") {
        self.novelId = novelId
        self.ownerId = ownerId
        self.viewedAt = Date()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.novelId = try container.decode(Int.self, forKey: .novelId)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.viewedAt = try container.decodeIfPresent(Date.self, forKey: .viewedAt) ?? Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(novelId, forKey: .novelId)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(viewedAt, forKey: .viewedAt)
    }

    enum CodingKeys: String, CodingKey {
        case novelId
        case ownerId
        case viewedAt
    }
}

/// 小说数据缓存
@Model
final class CachedNovel: Codable {
    @Attribute(.unique) var id: Int
    var ownerId: String = "guest"
    var data: Data?

    init(id: Int, ownerId: String = "guest") {
        self.id = id
        self.ownerId = ownerId
        self.data = nil
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.data = try container.decodeIfPresent(Data.self, forKey: .data)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(data, forKey: .data)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case data
    }
}

/// 插画数据缓存（轻量级，仅包含浏览历史展示所需字段）
@Model
final class CachedIllust: Codable {
    @Attribute(.unique) var id: Int
    var ownerId: String = "guest"
    var title: String
    var imageUrlsData: Data?
    var userName: String
    var userAccount: String
    var userId: String
    var totalBookmarks: Int
    var isBookmarked: Bool
    var xRestrict: Int
    var type: String
    var pageCount: Int
    var illustAIType: Int
    var width: Int
    var height: Int

    init(illust: Illusts, ownerId: String = "guest") {
        self.id = illust.id
        self.ownerId = ownerId
        self.title = illust.title
        self.imageUrlsData = try? JSONEncoder().encode(illust.imageUrls)
        self.userName = illust.user.name
        self.userAccount = illust.user.account
        self.userId = illust.user.id.stringValue
        self.totalBookmarks = illust.totalBookmarks
        self.isBookmarked = illust.isBookmarked
        self.xRestrict = illust.xRestrict
        self.type = illust.type
        self.pageCount = illust.pageCount
        self.illustAIType = illust.illustAIType
        self.width = illust.width
        self.height = illust.height
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.title = try container.decode(String.self, forKey: .title)
        self.imageUrlsData = try container.decodeIfPresent(Data.self, forKey: .imageUrlsData)
        self.userName = try container.decode(String.self, forKey: .userName)
        self.userAccount = try container.decode(String.self, forKey: .userAccount)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.totalBookmarks = try container.decode(Int.self, forKey: .totalBookmarks)
        self.isBookmarked = try container.decode(Bool.self, forKey: .isBookmarked)
        self.xRestrict = try container.decode(Int.self, forKey: .xRestrict)
        self.type = try container.decode(String.self, forKey: .type)
        self.pageCount = try container.decode(Int.self, forKey: .pageCount)
        self.illustAIType = try container.decode(Int.self, forKey: .illustAIType)
        self.width = try container.decode(Int.self, forKey: .width)
        self.height = try container.decode(Int.self, forKey: .height)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(title, forKey: .title)
        try container.encode(imageUrlsData, forKey: .imageUrlsData)
        try container.encode(userName, forKey: .userName)
        try container.encode(userAccount, forKey: .userAccount)
        try container.encode(userId, forKey: .userId)
        try container.encode(totalBookmarks, forKey: .totalBookmarks)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encode(xRestrict, forKey: .xRestrict)
        try container.encode(type, forKey: .type)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(illustAIType, forKey: .illustAIType)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId
        case title
        case imageUrlsData
        case userName
        case userAccount
        case userId
        case totalBookmarks
        case isBookmarked
        case xRestrict
        case type
        case pageCount
        case illustAIType
        case width
        case height
    }

    var imageUrls: ImageUrls? {
        guard let data = imageUrlsData else { return nil }
        return try? JSONDecoder().decode(ImageUrls.self, from: data)
    }

    func toUser() -> User {
        User(
            profileImageUrls: ProfileImageUrls(px50x50: "", medium: ""),
            id: StringIntValue.string(userId),
            name: userName,
            account: userAccount
        )
    }

    func toIllusts() -> Illusts {
        Illusts(
            id: id,
            title: title,
            type: type,
            imageUrls: imageUrls ?? ImageUrls(squareMedium: "", medium: "", large: ""),
            caption: "",
            restrict: 0,
            user: toUser(),
            tags: [],
            tools: [],
            createDate: "",
            pageCount: pageCount,
            width: width,
            height: height,
            sanityLevel: 0,
            xRestrict: xRestrict,
            metaSinglePage: nil,
            metaPages: [],
            totalView: 0,
            totalBookmarks: totalBookmarks,
            isBookmarked: isBookmarked,
            bookmarkRestrict: nil,
            visible: true,
            isMuted: false,
            illustAIType: illustAIType,
            series: nil,
            illustBookStyle: nil,
            totalComments: nil,
            restrictionAttributes: []
        )
    }
}

/// 下载任务
@Model
final class TaskPersist: Codable {
    @Attribute(.unique) var taskId: String
    var ownerId: String = "guest"
    var illustId: Int
    var downloadPath: String
    var status: Int = 0 // 0: 待处理, 1: 下载中, 2: 已完成, 3: 失败
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(taskId: String, illustId: Int, downloadPath: String, ownerId: String = "guest") {
        self.taskId = taskId
        self.illustId = illustId
        self.downloadPath = downloadPath
        self.ownerId = ownerId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.taskId = try container.decode(String.self, forKey: .taskId)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.illustId = try container.decode(Int.self, forKey: .illustId)
        self.downloadPath = try container.decode(String.self, forKey: .downloadPath)
        self.status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 0
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(illustId, forKey: .illustId)
        try container.encode(downloadPath, forKey: .downloadPath)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case taskId
        case ownerId
        case illustId
        case downloadPath
        case status
        case createdAt
        case updatedAt
    }
}
