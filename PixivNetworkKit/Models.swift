import Foundation

public struct TokenResponse: Codable {
    public let response: TokenData
    
    public init(response: TokenData) {
        self.response = response
    }
}

public struct TokenData: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let tokenType: String
    public let scope: String?
    public let user: UserData?
    public let deviceToken: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case scope
        case user
        case deviceToken = "device_token"
    }
    
    public init(accessToken: String, refreshToken: String, expiresIn: Int, tokenType: String, scope: String?, user: UserData?, deviceToken: String?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
        self.scope = scope
        self.user = user
        self.deviceToken = deviceToken
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        tokenType = try container.decode(String.self, forKey: .tokenType)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        user = try container.decodeIfPresent(UserData.self, forKey: .user)
        deviceToken = try container.decodeIfPresent(String.self, forKey: .deviceToken)
    }
}

public struct UserData: Codable {
    public let id: String
    public let account: String
    public let email: String?
    public let isMailAuthorized: Bool
    public let isPremium: Bool
    public let xRestrict: Int
    public let name: String
    public let image: String?
    public let imageBig: String?
    public let profileImageUrls: ProfileImageUrls?
    public let comment: String?
    public let commentHtml: String?
    public let following: Int?
    public let followedBack: Bool?
    public let followSfwStatus: String?
    public let allowRated: Bool?
    public let allowNotification: Bool?
    public let externalServices: ExternalServices?
    
    enum CodingKeys: String, CodingKey {
        case id
        case account
        case email = "mail_address"
        case isMailAuthorized = "is_mail_authorized"
        case isPremium = "is_premium"
        case xRestrict = "x_restrict"
        case name
        case image
        case imageBig = "image_big"
        case profileImageUrls = "profile_image_urls"
        case comment
        case commentHtml = "comment_html"
        case following
        case followedBack = "followed_back"
        case followSfwStatus = "follow_sfw_status"
        case allowRated = "allow_rated"
        case allowNotification = "allow_notification"
        case externalServices = "external_services"
    }
    
    public init(id: String, account: String, email: String?, isMailAuthorized: Bool, isPremium: Bool, xRestrict: Int, name: String, image: String?, imageBig: String?, profileImageUrls: ProfileImageUrls?, comment: String?, commentHtml: String?, following: Int?, followedBack: Bool?, followSfwStatus: String?, allowRated: Bool?, allowNotification: Bool?, externalServices: ExternalServices?) {
        self.id = id
        self.account = account
        self.email = email
        self.isMailAuthorized = isMailAuthorized
        self.isPremium = isPremium
        self.xRestrict = xRestrict
        self.name = name
        self.image = image
        self.imageBig = imageBig
        self.profileImageUrls = profileImageUrls
        self.comment = comment
        self.commentHtml = commentHtml
        self.following = following
        self.followedBack = followedBack
        self.followSfwStatus = followSfwStatus
        self.allowRated = allowRated
        self.allowNotification = allowNotification
        self.externalServices = externalServices
    }
}

public struct ProfileImageUrls: Codable {
    public let px16x16: String?
    public let px170x170: String?
    public let px50x50: String?
    
    enum CodingKeys: String, CodingKey {
        case px16x16 = "px_16x16"
        case px170x170 = "px_170x170"
        case px50x50 = "px_50x50"
    }
    
    public init(px16x16: String?, px170x170: String?, px50x50: String?) {
        self.px16x16 = px16x16
        self.px170x170 = px170x170
        self.px50x50 = px50x50
    }
}

public struct ExternalServices: Codable {
    public let twitter: TwitterService?
    public let tumblr: TumblrService?
    
    public init(twitter: TwitterService?, tumblr: TumblrService?) {
        self.twitter = twitter
        self.tumblr = tumblr
    }
}

public struct TwitterService: Codable {
    public let url: String?
    
    public init(url: String?) {
        self.url = url
    }
}

public struct TumblrService: Codable {
    public let url: String?
    
    public init(url: String?) {
        self.url = url
    }
}
