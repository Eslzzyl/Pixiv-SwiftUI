import Foundation
import SwiftData

/// 屏蔽的标签信息
@Model
final class BlockedTagInfo {
    var name: String
    var translatedName: String?

    init(name: String, translatedName: String? = nil) {
        self.name = name
        self.translatedName = translatedName
    }
}

/// 屏蔽的作者信息
@Model
final class BlockedUserInfo {
    var userId: String
    var name: String?
    var account: String?
    var avatarUrl: String?

    init(userId: String, name: String? = nil, account: String? = nil, avatarUrl: String? = nil) {
        self.userId = userId
        self.name = name
        self.account = account
        self.avatarUrl = avatarUrl
    }
}

/// 屏蔽的插画信息
@Model
final class BlockedIllustInfo {
    var illustId: Int
    var title: String?
    var authorId: String?
    var authorName: String?
    var thumbnailUrl: String?

    init(illustId: Int, title: String? = nil, authorId: String? = nil, authorName: String? = nil, thumbnailUrl: String? = nil) {
        self.illustId = illustId
        self.title = title
        self.authorId = authorId
        self.authorName = authorName
        self.thumbnailUrl = thumbnailUrl
    }
}
