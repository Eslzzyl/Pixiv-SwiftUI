import Foundation
import SwiftData

/// 用户头像 URL 集合
@Model
final class ProfileImageUrls: Codable {
    var px16x16: String?
    var px50x50: String?
    var px170x170: String?
    var medium: String?
    
    enum CodingKeys: String, CodingKey {
        case px16x16 = "px_16x16"
        case px50x50 = "px_50x50"
        case px170x170 = "px_170x170"
        case medium
    }
    
    init(px16x16: String? = nil, px50x50: String? = nil, px170x170: String? = nil, medium: String? = nil) {
        self.px16x16 = px16x16
        self.px50x50 = px50x50
        self.px170x170 = px170x170
        self.medium = medium
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.px16x16 = try container.decodeIfPresent(String.self, forKey: .px16x16)
        self.px50x50 = try container.decodeIfPresent(String.self, forKey: .px50x50)
        self.px170x170 = try container.decodeIfPresent(String.self, forKey: .px170x170)
        self.medium = try container.decodeIfPresent(String.self, forKey: .medium)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(px16x16, forKey: .px16x16)
        try container.encodeIfPresent(px50x50, forKey: .px50x50)
        try container.encodeIfPresent(px170x170, forKey: .px170x170)
        try container.encodeIfPresent(medium, forKey: .medium)
    }
}

/// 用户信息
@Model
final class User: Codable {
    var profileImageUrls: ProfileImageUrls?
    var id: StringIntValue
    var name: String
    var account: String
    var mailAddress: String?
    var isPremium: Bool?
    var xRestrict: Int?
    var isMailAuthorized: Bool?
    var requirePolicyAgreement: Bool?
    var isAcceptRequest: Bool?
    var isFollowed: Bool?
    
    enum CodingKeys: String, CodingKey {
        case profileImageUrls = "profile_image_urls"
        case id
        case name
        case account
        case mailAddress = "mail_address"
        case isPremium = "is_premium"
        case xRestrict = "x_restrict"
        case isMailAuthorized = "is_mail_authorized"
        case requirePolicyAgreement = "require_policy_agreement"
        case isAcceptRequest = "is_accept_request"
        case isFollowed = "is_followed"
    }
    
    init(profileImageUrls: ProfileImageUrls? = nil, id: StringIntValue, name: String, account: String, mailAddress: String? = nil, isPremium: Bool? = nil, xRestrict: Int? = nil, isMailAuthorized: Bool? = nil, requirePolicyAgreement: Bool? = nil, isAcceptRequest: Bool? = nil, isFollowed: Bool? = nil) {
        self.profileImageUrls = profileImageUrls
        self.id = id
        self.name = name
        self.account = account
        self.mailAddress = mailAddress
        self.isPremium = isPremium
        self.xRestrict = xRestrict
        self.isMailAuthorized = isMailAuthorized
        self.requirePolicyAgreement = requirePolicyAgreement
        self.isAcceptRequest = isAcceptRequest
        self.isFollowed = isFollowed
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.profileImageUrls = try container.decodeIfPresent(ProfileImageUrls.self, forKey: .profileImageUrls)
        self.id = try container.decode(StringIntValue.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.account = try container.decode(String.self, forKey: .account)
        self.mailAddress = try container.decodeIfPresent(String.self, forKey: .mailAddress)
        self.isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium)
        self.xRestrict = try container.decodeIfPresent(Int.self, forKey: .xRestrict)
        self.isMailAuthorized = try container.decodeIfPresent(Bool.self, forKey: .isMailAuthorized)
        self.requirePolicyAgreement = try container.decodeIfPresent(Bool.self, forKey: .requirePolicyAgreement)
        self.isAcceptRequest = try container.decodeIfPresent(Bool.self, forKey: .isAcceptRequest)
        self.isFollowed = try container.decodeIfPresent(Bool.self, forKey: .isFollowed)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(profileImageUrls, forKey: .profileImageUrls)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(account, forKey: .account)
        try container.encodeIfPresent(mailAddress, forKey: .mailAddress)
        try container.encodeIfPresent(isPremium, forKey: .isPremium)
        try container.encodeIfPresent(xRestrict, forKey: .xRestrict)
        try container.encodeIfPresent(isMailAuthorized, forKey: .isMailAuthorized)
        try container.encodeIfPresent(requirePolicyAgreement, forKey: .requirePolicyAgreement)
        try container.encodeIfPresent(isAcceptRequest, forKey: .isAcceptRequest)
        try container.encodeIfPresent(isFollowed, forKey: .isFollowed)
    }
}

/// 账户登录响应
@Model
final class AccountResponse: Codable {
    var accessToken: String
    var expiresIn: Int
    var tokenType: String
    var scope: String
    var refreshToken: String
    var user: User
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
        case refreshToken = "refresh_token"
        case user
    }
    
    init(accessToken: String, expiresIn: Int, tokenType: String, scope: String, refreshToken: String, user: User) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
        self.scope = scope
        self.refreshToken = refreshToken
        self.user = user
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        self.tokenType = try container.decode(String.self, forKey: .tokenType)
        self.scope = try container.decode(String.self, forKey: .scope)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.user = try container.decode(User.self, forKey: .user)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(expiresIn, forKey: .expiresIn)
        try container.encode(tokenType, forKey: .tokenType)
        try container.encode(scope, forKey: .scope)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(user, forKey: .user)
    }
}

/// 持久化的账户信息（本地存储）
@Model
final class AccountPersist: Codable, Identifiable {
    @Attribute(.unique) var userId: String
    var id: String { userId }
    var userImage: String
    var accessToken: String
    var refreshToken: String
    var deviceToken: String
    var name: String
    var account: String
    var mailAddress: String
    var passWord: String
    var isPremium: Int
    var xRestrict: Int
    var isMailAuthorized: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userImage = "user_image"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case deviceToken = "device_token"
        case name
        case account
        case mailAddress = "mail_address"
        case passWord = "password"
        case isPremium = "is_premium"
        case xRestrict = "x_restrict"
        case isMailAuthorized = "is_mail_authorized"
    }
    
    init(userId: String, userImage: String, accessToken: String, refreshToken: String, deviceToken: String, name: String, account: String, mailAddress: String, passWord: String, isPremium: Int, xRestrict: Int, isMailAuthorized: Int) {
        self.userId = userId
        self.userImage = userImage
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.deviceToken = deviceToken
        self.name = name
        self.account = account
        self.mailAddress = mailAddress
        self.passWord = passWord
        self.isPremium = isPremium
        self.xRestrict = xRestrict
        self.isMailAuthorized = isMailAuthorized
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.userId = try container.decode(String.self, forKey: .userId)
        self.userImage = try container.decode(String.self, forKey: .userImage)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.deviceToken = try container.decode(String.self, forKey: .deviceToken)
        self.name = try container.decode(String.self, forKey: .name)
        self.account = try container.decode(String.self, forKey: .account)
        self.mailAddress = try container.decode(String.self, forKey: .mailAddress)
        self.passWord = try container.decode(String.self, forKey: .passWord)
        self.isPremium = try container.decode(Int.self, forKey: .isPremium)
        self.xRestrict = try container.decode(Int.self, forKey: .xRestrict)
        self.isMailAuthorized = try container.decode(Int.self, forKey: .isMailAuthorized)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(userImage, forKey: .userImage)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(deviceToken, forKey: .deviceToken)
        try container.encode(name, forKey: .name)
        try container.encode(account, forKey: .account)
        try container.encode(mailAddress, forKey: .mailAddress)
        try container.encode(passWord, forKey: .passWord)
        try container.encode(isPremium, forKey: .isPremium)
        try container.encode(xRestrict, forKey: .xRestrict)
        try container.encode(isMailAuthorized, forKey: .isMailAuthorized)
    }
}

// MARK: - AccountPersist 便利扩展
extension AccountPersist {
    /// 从 User 和 Token 创建新账户
    convenience init(user: User, accessToken: String, refreshToken: String, deviceToken: String) {
        self.init(
            userId: user.id.stringValue,
            userImage: user.profileImageUrls?.px170x170 ?? user.profileImageUrls?.medium ?? "",
            accessToken: accessToken,
            refreshToken: refreshToken,
            deviceToken: deviceToken,
            name: user.name,
            account: user.account,
            mailAddress: user.mailAddress ?? "",
            passWord: "",
            isPremium: (user.isPremium ?? false) ? 1 : 0,
            xRestrict: user.xRestrict ?? 0,
            isMailAuthorized: (user.isMailAuthorized ?? false) ? 1 : 0
        )
    }
}
