import Foundation
import CryptoKit

struct WebDAVSyncConfiguration: Codable, Equatable, Sendable {
    var serverURLString: String = ""
    var username: String = ""
    var remoteDirectory: String = "Pixiv-SwiftUI"

    var normalizedRemoteDirectory: String {
        remoteDirectory
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .map(String.init)
            .joined(separator: "/")
    }

    func makeCredentials(password: String) throws -> WebDAVSyncCredentials {
        let trimmedURL = serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let serverURL = URL(string: trimmedURL), let scheme = serverURL.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            throw WebDAVSyncError.invalidServerURL
        }

        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUsername.isEmpty else {
            throw WebDAVSyncError.emptyUsername
        }

        guard !password.isEmpty else {
            throw WebDAVSyncError.emptyPassword
        }

        return WebDAVSyncCredentials(
            serverURL: serverURL,
            username: trimmedUsername,
            password: password,
            remoteDirectory: normalizedRemoteDirectory
        )
    }
}

struct WebDAVSyncCredentials: Sendable {
    let serverURL: URL
    let username: String
    let password: String
    let remoteDirectory: String
}

enum WebDAVSyncOperationKind: String, Codable, Sendable {
    case upload
    case restore
}

struct WebDAVSyncOperationRecord: Codable, Sendable {
    let kind: WebDAVSyncOperationKind
    let date: Date
}

enum WebDAVSyncDataset: String, Codable, CaseIterable, Sendable {
    case safeSettings = "safe_settings"
    case muteData = "mute_data"
    case searchHistory = "search_history"
    case novelReader = "novel_reader"

    var fileName: String {
        switch self {
        case .safeSettings:
            return "settings.json"
        case .muteData:
            return "mute_data.json"
        case .searchHistory:
            return "search_history.json"
        case .novelReader:
            return "novel_reader.json"
        }
    }
}

struct WebDAVSyncManifestItem: Codable, Sendable {
    let dataset: WebDAVSyncDataset
    let fileName: String
    let sha256: String
    let byteCount: Int
}

struct WebDAVSyncManifest: Codable, Sendable {
    let version: Int
    let ownerId: String
    let exportedAt: Date
    let appVersion: String
    let datasets: [WebDAVSyncManifestItem]
}

struct WebDAVSyncSafeSettingsPayload: Codable, Sendable {
    let pictureQuality: Int
    let mangaQuality: Int
    let feedPreviewQuality: Int
    let zoomQuality: Int
    let languageNum: Int
    let crossCount: Int
    let hCrossCount: Int
    let crossAdaptWidth: Int
    let crossAdapt: Bool
    let hCrossAdaptWidth: Int
    let hCrossAdapt: Bool
    let colorSchemeMode: Int
    let isTopMode: Bool
    let novelFontSize: Int
    let seedColor: Int
    let isCustomTheme: Bool
    let customThemeColor: Int
    let aiDisplayMode: Int
    let r18DisplayMode: Int
    let r18gDisplayMode: Int
    let showXVIIIRankingGroups: Bool?
    let enabledHiddenIllustRankingModes: [String]?
    let enabledIllustRankingModes: [String]?
    let illustRankingModeOrder: [String]?
    let spoilerDisplayMode: Int
    let blurAppPreviewInBackground: Bool?
    let autoPlayUgoira: Bool
    let showGifAvatar: Bool
    let copyInfoText: String
    let animContainer: Bool
    let translateServiceId: String
    let translateTargetLanguage: String
    let translatePrimaryServiceId: String
    let translateTapToTranslate: Bool
    let translateNovelBatchEnabled: Bool
    let translateNovelBatchMaxParagraphs: Int
    let translateNovelBatchMaxCharacters: Int
    let translateNovelContextParagraphs: Int
    let translateNovelMaxConcurrentBatches: Int
    let vlmEnabled: Bool
    let vlmModel: String
    let vlmTemperature: Double
    let vlmDetail: String
    let tagTranslationDisplayMode: Int
    let defaultTab: String
    let checkUpdateOnLaunch: Bool

    init(setting: UserSetting) {
        self.pictureQuality = setting.pictureQuality
        self.mangaQuality = setting.mangaQuality
        self.feedPreviewQuality = setting.feedPreviewQuality
        self.zoomQuality = setting.zoomQuality
        self.languageNum = setting.languageNum
        self.crossCount = setting.crossCount
        self.hCrossCount = setting.hCrossCount
        self.crossAdaptWidth = setting.crossAdaptWidth
        self.crossAdapt = setting.crossAdapt
        self.hCrossAdaptWidth = setting.hCrossAdaptWidth
        self.hCrossAdapt = setting.hCrossAdapt
        self.colorSchemeMode = setting.colorSchemeMode
        self.isTopMode = setting.isTopMode
        self.novelFontSize = setting.novelFontSize
        self.seedColor = setting.seedColor
        self.isCustomTheme = setting.isCustomTheme
        self.customThemeColor = setting.customThemeColor
        self.aiDisplayMode = setting.aiDisplayMode
        self.r18DisplayMode = setting.r18DisplayMode
        self.r18gDisplayMode = setting.r18gDisplayMode
        self.showXVIIIRankingGroups = setting.showXVIIIRankingGroups
        self.enabledHiddenIllustRankingModes = setting.enabledHiddenIllustRankingModes
        self.enabledIllustRankingModes = setting.enabledIllustRankingModes
        self.illustRankingModeOrder = setting.illustRankingModeOrder
        self.spoilerDisplayMode = setting.spoilerDisplayMode
        self.blurAppPreviewInBackground = setting.blurAppPreviewInBackground
        self.autoPlayUgoira = setting.autoPlayUgoira
        self.showGifAvatar = setting.showGifAvatar
        self.copyInfoText = setting.copyInfoText
        self.animContainer = setting.animContainer
        self.translateServiceId = setting.translateServiceId
        self.translateTargetLanguage = setting.translateTargetLanguage
        self.translatePrimaryServiceId = setting.translatePrimaryServiceId
        self.translateTapToTranslate = setting.translateTapToTranslate
        self.translateNovelBatchEnabled = setting.translateNovelBatchEnabled
        self.translateNovelBatchMaxParagraphs = setting.translateNovelBatchMaxParagraphs
        self.translateNovelBatchMaxCharacters = setting.translateNovelBatchMaxCharacters
        self.translateNovelContextParagraphs = setting.translateNovelContextParagraphs
        self.translateNovelMaxConcurrentBatches = setting.translateNovelMaxConcurrentBatches
        self.vlmEnabled = setting.vlmEnabled
        self.vlmModel = setting.vlmModel
        self.vlmTemperature = setting.vlmTemperature
        self.vlmDetail = setting.vlmDetail
        self.tagTranslationDisplayMode = setting.tagTranslationDisplayMode
        self.defaultTab = setting.defaultTab
        self.checkUpdateOnLaunch = setting.checkUpdateOnLaunch
    }
}

struct WebDAVBlockedTagInfoPayload: Codable, Sendable {
    let name: String
    let translatedName: String?

    init(info: BlockedTagInfo) {
        self.name = info.name
        self.translatedName = info.translatedName
    }
}

struct WebDAVBlockedUserInfoPayload: Codable, Sendable {
    let userId: String
    let name: String?
    let account: String?
    let avatarUrl: String?

    init(info: BlockedUserInfo) {
        self.userId = info.userId
        self.name = info.name
        self.account = info.account
        self.avatarUrl = info.avatarUrl
    }
}

struct WebDAVBlockedIllustInfoPayload: Codable, Sendable {
    let illustId: Int
    let title: String?
    let authorId: String?
    let authorName: String?
    let thumbnailUrl: String?

    init(info: BlockedIllustInfo) {
        self.illustId = info.illustId
        self.title = info.title
        self.authorId = info.authorId
        self.authorName = info.authorName
        self.thumbnailUrl = info.thumbnailUrl
    }
}

struct WebDAVBlockedNovelInfoPayload: Codable, Sendable {
    let novelId: Int
    let title: String?
    let authorId: String?
    let authorName: String?
    let thumbnailUrl: String?

    init(info: BlockedNovelInfo) {
        self.novelId = info.novelId
        self.title = info.title
        self.authorId = info.authorId
        self.authorName = info.authorName
        self.thumbnailUrl = info.thumbnailUrl
    }
}

struct WebDAVSyncMutePayload: Codable, Sendable {
    let blockedTags: [String]
    let blockedUsers: [String]
    let blockedIllusts: [Int]
    let blockedNovels: [Int]
    let blockedNovelTitleKeywords: [String]
    let blockedNovelSeriesKeywords: [String]
    let blockedNovelCaptionKeywords: [String]
    let blockedTagInfos: [WebDAVBlockedTagInfoPayload]
    let blockedUserInfos: [WebDAVBlockedUserInfoPayload]
    let blockedIllustInfos: [WebDAVBlockedIllustInfoPayload]
    let blockedNovelInfos: [WebDAVBlockedNovelInfoPayload]

    init(
        blockedTags: [String],
        blockedUsers: [String],
        blockedIllusts: [Int],
        blockedNovels: [Int],
        blockedNovelTitleKeywords: [String] = [],
        blockedNovelSeriesKeywords: [String] = [],
        blockedNovelCaptionKeywords: [String] = [],
        blockedTagInfos: [WebDAVBlockedTagInfoPayload],
        blockedUserInfos: [WebDAVBlockedUserInfoPayload],
        blockedIllustInfos: [WebDAVBlockedIllustInfoPayload],
        blockedNovelInfos: [WebDAVBlockedNovelInfoPayload]
    ) {
        self.blockedTags = blockedTags
        self.blockedUsers = blockedUsers
        self.blockedIllusts = blockedIllusts
        self.blockedNovels = blockedNovels
        self.blockedNovelTitleKeywords = blockedNovelTitleKeywords
        self.blockedNovelSeriesKeywords = blockedNovelSeriesKeywords
        self.blockedNovelCaptionKeywords = blockedNovelCaptionKeywords
        self.blockedTagInfos = blockedTagInfos
        self.blockedUserInfos = blockedUserInfos
        self.blockedIllustInfos = blockedIllustInfos
        self.blockedNovelInfos = blockedNovelInfos
    }

    enum CodingKeys: String, CodingKey {
        case blockedTags
        case blockedUsers
        case blockedIllusts
        case blockedNovels
        case blockedNovelTitleKeywords
        case blockedNovelSeriesKeywords
        case blockedNovelCaptionKeywords
        case blockedTagInfos
        case blockedUserInfos
        case blockedIllustInfos
        case blockedNovelInfos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.blockedTags = try container.decodeIfPresent([String].self, forKey: .blockedTags) ?? []
        self.blockedUsers = try container.decodeIfPresent([String].self, forKey: .blockedUsers) ?? []
        self.blockedIllusts = try container.decodeIfPresent([Int].self, forKey: .blockedIllusts) ?? []
        self.blockedNovels = try container.decodeIfPresent([Int].self, forKey: .blockedNovels) ?? []
        self.blockedNovelTitleKeywords = try container.decodeIfPresent([String].self, forKey: .blockedNovelTitleKeywords) ?? []
        self.blockedNovelSeriesKeywords = try container.decodeIfPresent([String].self, forKey: .blockedNovelSeriesKeywords) ?? []
        self.blockedNovelCaptionKeywords = try container.decodeIfPresent([String].self, forKey: .blockedNovelCaptionKeywords) ?? []
        self.blockedTagInfos = try container.decodeIfPresent([WebDAVBlockedTagInfoPayload].self, forKey: .blockedTagInfos) ?? []
        self.blockedUserInfos = try container.decodeIfPresent([WebDAVBlockedUserInfoPayload].self, forKey: .blockedUserInfos) ?? []
        self.blockedIllustInfos = try container.decodeIfPresent([WebDAVBlockedIllustInfoPayload].self, forKey: .blockedIllustInfos) ?? []
        self.blockedNovelInfos = try container.decodeIfPresent([WebDAVBlockedNovelInfoPayload].self, forKey: .blockedNovelInfos) ?? []
    }
}

struct WebDAVSyncSearchHistoryPayload: Codable, Sendable {
    let tags: [SearchTag]
}

struct WebDAVNovelReaderProgressPayload: Codable, Sendable {
    let novelId: Int
    let index: Int
    let totalSpans: Int?
}

struct WebDAVSyncNovelReaderPayload: Codable, Sendable {
    let settings: NovelReaderSettings?
    let progresses: [WebDAVNovelReaderProgressPayload]
}

struct WebDAVRemoteItem: Sendable {
    let href: String
    let fileName: String
    let isDirectory: Bool
    let etag: String?
    let lastModified: Date?
    let contentLength: Int64?
}

enum WebDAVSyncError: LocalizedError {
    case invalidServerURL
    case emptyUsername
    case emptyPassword
    case invalidResponse
    case authenticationFailed
    case httpStatus(Int)
    case remoteFileNotFound(String)
    case invalidManifest
    case payloadIntegrityMismatch(String)
    case xmlParsingFailed
    case fileOperationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "请输入有效的 WebDAV 地址"
        case .emptyUsername:
            return "请输入 WebDAV 用户名"
        case .emptyPassword:
            return "请输入 WebDAV 密码或应用专用密码"
        case .invalidResponse:
            return "WebDAV 服务返回了无效响应"
        case .authenticationFailed:
            return "WebDAV 认证失败，请检查用户名或密码"
        case .httpStatus(let statusCode):
            return "WebDAV 请求失败（HTTP \(statusCode)）"
        case .remoteFileNotFound(let fileName):
            return "远端缺少文件：\(fileName)"
        case .invalidManifest:
            return "远端备份清单无效或版本不受支持"
        case .payloadIntegrityMismatch(let fileName):
            return "远端文件校验失败：\(fileName)"
        case .xmlParsingFailed:
            return "无法解析 WebDAV 响应"
        case .fileOperationFailed(let message):
            return "文件操作失败：\(message)"
        }
    }
}

enum WebDAVSyncPreferences {
    private static let configurationKey = "webdav_sync_configuration"
    private static let lastOperationKeyPrefix = "webdav_sync_last_operation_"
    private static let keychainService = (Bundle.main.bundleIdentifier ?? "Pixiv-SwiftUI") + ".webdav-sync"
    private static let keychainAccount = "default"

    static func loadConfiguration() -> WebDAVSyncConfiguration {
        guard let data = UserDefaults.standard.data(forKey: configurationKey),
              let configuration = try? JSONDecoder().decode(WebDAVSyncConfiguration.self, from: data) else {
            return WebDAVSyncConfiguration()
        }
        return configuration
    }

    static func saveConfiguration(_ configuration: WebDAVSyncConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        UserDefaults.standard.set(data, forKey: configurationKey)
    }

    static func loadPassword() throws -> String? {
        try KeychainHelper.load(service: keychainService, account: keychainAccount)
    }

    static func savePassword(_ password: String) throws {
        if password.isEmpty {
            try KeychainHelper.delete(service: keychainService, account: keychainAccount)
        } else {
            try KeychainHelper.save(password, service: keychainService, account: keychainAccount)
        }
    }

    static func loadLastOperation(ownerId: String) -> WebDAVSyncOperationRecord? {
        let key = lastOperationKeyPrefix + ownerId
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(WebDAVSyncOperationRecord.self, from: data)
    }

    static func saveLastOperation(_ operation: WebDAVSyncOperationRecord, ownerId: String) throws {
        let key = lastOperationKeyPrefix + ownerId
        let data = try JSONEncoder().encode(operation)
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum WebDAVSyncHashing {
    static func sha256Hex(for data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
