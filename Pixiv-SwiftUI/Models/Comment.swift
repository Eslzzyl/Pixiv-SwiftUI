import Foundation

/// 评论用户头像 URL 集合
struct CommentProfileImageUrls: Codable {
    var medium: String?

    enum CodingKeys: String, CodingKey {
        case medium
    }
}

/// 评论用户信息
struct CommentUser: Codable {
    var id: Int?
    var name: String?
    var account: String?
    var profileImageUrls: CommentProfileImageUrls?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case profileImageUrls = "profile_image_urls"
    }
}

/// 评论表情贴纸
struct CommentStamp: Codable {
    var stampId: Int?
    var stampUrl: String?

    enum CodingKeys: String, CodingKey {
        case stampId = "stamp_id"
        case stampUrl = "stamp_url"
    }
}

/// 父评论信息（简化版，避免循环引用）
struct ParentComment: Codable {
    var id: Int?
    var user: CommentUser?
    var comment: String?

    enum CodingKeys: String, CodingKey {
        case id
        case user
        case comment
    }
}

/// 单条评论
struct Comment: Codable, Identifiable {
    var id: Int?
    var comment: String?
    var date: String?
    var user: CommentUser?
    var parentComment: ParentComment?
    var hasReplies: Bool?
    var replies: [Comment]?
    var stamp: CommentStamp?

    enum CodingKeys: String, CodingKey {
        case id
        case comment
        case date
        case user
        case parentComment = "parent_comment"
        case hasReplies = "has_replies"
        case stamp
    }
    
    var isExpanded: Bool = false
    var isLoadingReplies: Bool = false
}

/// 评论响应
struct CommentResponse: Codable {
    var totalComments: Int?
    var comments: [Comment]
    var nextUrl: String?

    enum CodingKeys: String, CodingKey {
        case totalComments = "total_comments"
        case comments
        case nextUrl = "next_url"
    }
}
