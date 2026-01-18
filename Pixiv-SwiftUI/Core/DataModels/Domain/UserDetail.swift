import Foundation
import SwiftData

/// 用户详情响应
struct UserDetailResponse: Codable {
    var user: UserDetailUser
    let profile: UserDetailProfile
    let workspace: UserDetailWorkspace
}

/// 用户详情中的用户信息
struct UserDetailUser: Codable, Hashable {
    let id: Int
    var name: String
    let account: String
    let profileImageUrls: ProfileImageUrls
    let comment: String
    var isFollowed: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case account
        case profileImageUrls = "profile_image_urls"
        case comment
        case isFollowed = "is_followed"
    }
}

/// 用户详情中的 Profile 信息
struct UserDetailProfile: Codable {
    let webpage: String?
    let gender: String
    let birth: String
    let birthDay: String
    let birthYear: Int
    let region: String
    let addressId: Int
    let countryCode: String
    let job: String
    let jobId: Int
    let totalFollowUsers: Int
    let totalMypixivUsers: Int
    let totalIllusts: Int
    let totalManga: Int
    let totalNovels: Int
    let totalIllustBookmarksPublic: Int
    let totalIllustSeries: Int
    let totalNovelSeries: Int
    let backgroundImageUrl: String?
    let twitterAccount: String?
    let twitterUrl: String?
    let pawooUrl: String?
    let isPremium: Bool
    let isUsingCustomProfileImage: Bool
    
    enum CodingKeys: String, CodingKey {
        case webpage
        case gender
        case birth
        case birthDay = "birth_day"
        case birthYear = "birth_year"
        case region
        case addressId = "address_id"
        case countryCode = "country_code"
        case job
        case jobId = "job_id"
        case totalFollowUsers = "total_follow_users"
        case totalMypixivUsers = "total_mypixiv_users"
        case totalIllusts = "total_illusts"
        case totalManga = "total_manga"
        case totalNovels = "total_novels"
        case totalIllustBookmarksPublic = "total_illust_bookmarks_public"
        case totalIllustSeries = "total_illust_series"
        case totalNovelSeries = "total_novel_series"
        case backgroundImageUrl = "background_image_url"
        case twitterAccount = "twitter_account"
        case twitterUrl = "twitter_url"
        case pawooUrl = "pawoo_url"
        case isPremium = "is_premium"
        case isUsingCustomProfileImage = "is_using_custom_profile_image"
    }
}

/// 用户详情中的 Workspace 信息
struct UserDetailWorkspace: Codable {
    let pc: String
    let monitor: String
    let tool: String
    let scanner: String
    let tablet: String
    let mouse: String
    let printer: String
    let desktop: String
    let music: String
    let desk: String
    let chair: String
    let comment: String
    let workspaceImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case pc
        case monitor
        case tool
        case scanner
        case tablet
        case mouse
        case printer
        case desktop
        case music
        case desk
        case chair
        case comment
        case workspaceImageUrl = "workspace_image_url"
    }
}

/// 用户详情完整缓存数据（包含列表数据）
struct CachedUserDetailData: Codable {
    let detail: UserDetailResponse
    let illusts: [Illusts]
    let bookmarks: [Illusts]
    let novels: [Novel]
    let nextIllustsUrl: String?
    let nextBookmarksUrl: String?
    let nextNovelsUrl: String?
    let timestamp: Date
}
