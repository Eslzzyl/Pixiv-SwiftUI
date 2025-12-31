import Foundation
import SwiftData

/// 禁用 ID 列表
@Model
final class BanIllustId: Codable {
    @Attribute(.unique) var illustId: Int
    var timestamp: Date = Date()
    
    init(illustId: Int) {
        self.illustId = illustId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.illustId = try container.decode(Int.self, forKey: .illustId)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(illustId, forKey: .illustId)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case illustId
        case timestamp
    }
}

/// 禁用用户 ID 列表
@Model
final class BanUserId: Codable {
    @Attribute(.unique) var userId: String
    var timestamp: Date = Date()
    
    init(userId: String) {
        self.userId = userId
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId
        case timestamp
    }
}

/// 禁用标签列表
@Model
final class BanTag: Codable {
    @Attribute(.unique) var name: String
    var timestamp: Date = Date()
    
    init(name: String) {
        self.name = name
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case timestamp
    }
}

/// 浏览历史记录
@Model
final class GlanceIllustPersist: Codable {
    @Attribute(.unique) var illustId: Int
    var viewedAt: Date = Date()
    
    init(illustId: Int) {
        self.illustId = illustId
        self.viewedAt = Date()
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.illustId = try container.decode(Int.self, forKey: .illustId)
        self.viewedAt = try container.decodeIfPresent(Date.self, forKey: .viewedAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(illustId, forKey: .illustId)
        try container.encode(viewedAt, forKey: .viewedAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case illustId
        case viewedAt
    }
}

/// 下载任务
@Model
final class TaskPersist: Codable {
    @Attribute(.unique) var taskId: String
    var illustId: Int
    var downloadPath: String
    var status: Int = 0 // 0: 待处理, 1: 下载中, 2: 已完成, 3: 失败
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(taskId: String, illustId: Int, downloadPath: String) {
        self.taskId = taskId
        self.illustId = illustId
        self.downloadPath = downloadPath
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.taskId = try container.decode(String.self, forKey: .taskId)
        self.illustId = try container.decode(Int.self, forKey: .illustId)
        self.downloadPath = try container.decode(String.self, forKey: .downloadPath)
        self.status = try container.decodeIfPresent(Int.self, forKey: .status) ?? 0
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(taskId, forKey: .taskId)
        try container.encode(illustId, forKey: .illustId)
        try container.encode(downloadPath, forKey: .downloadPath)
        try container.encode(status, forKey: .status)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case taskId
        case illustId
        case downloadPath
        case status
        case createdAt
        case updatedAt
    }
}
