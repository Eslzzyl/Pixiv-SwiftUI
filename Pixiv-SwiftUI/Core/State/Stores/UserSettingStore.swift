import Foundation
import SwiftData
import Observation

/// 用户设置管理
@Observable
final class UserSettingStore {
    static let shared = UserSettingStore()

    var userSetting: UserSetting = UserSetting()
    var isLoading: Bool = false
    var error: AppError?
    var isLoaded: Bool = false

    var blockedTags: [String] = []
    var blockedUsers: [String] = []
    var blockedIllusts: [Int] = []

    var blockedTagInfos: [BlockedTagInfo] = []
    var blockedUserInfos: [BlockedUserInfo] = []
    var blockedIllustInfos: [BlockedIllustInfo] = []

    private let dataContainer = DataContainer.shared

    init() {
    }

    @MainActor
    func loadUserSetting() {
        let context = dataContainer.mainContext
        let currentUserId = AccountStore.shared.currentUserId

        do {
            let descriptor = FetchDescriptor<UserSetting>(
                predicate: #Predicate { $0.ownerId == currentUserId }
            )
            if let setting = try context.fetch(descriptor).first {
                applySetting(setting)
            } else {
                // 如果不存在，创建默认设置
                let newSetting = UserSetting(ownerId: currentUserId)
                context.insert(newSetting)
                try context.save()
                applySetting(newSetting)
            }
        } catch {
            self.error = AppError.databaseError("无法加载用户设置: \(error)")
            self.userSetting = UserSetting()
            self.isLoaded = true
        }
    }

    func loadUserSettingAsync() async {
        let backgroundContext = dataContainer.createBackgroundContext()
        let currentUserId = await MainActor.run { AccountStore.shared.currentUserId }

        do {
            let descriptor = FetchDescriptor<UserSetting>(
                predicate: #Predicate { $0.ownerId == currentUserId }
            )
            let fetched = try backgroundContext.fetch(descriptor)

            if let setting = fetched.first {
                let id = setting.persistentModelID
                await MainActor.run {
                    if let mainSetting = dataContainer.mainContext.model(for: id) as? UserSetting {
                        applySetting(mainSetting)
                    }
                }
            } else {
                await MainActor.run {
                    loadUserSetting() // 回退到主线程进行创建
                }
            }
        } catch {
            await MainActor.run {
                self.error = AppError.databaseError("无法加载用户设置: \(error)")
                self.isLoaded = true
            }
        }
    }

    @MainActor
    private func applySetting(_ setting: UserSetting) {
        self.userSetting = setting
        // 同步 macOS 退出设置
        self.userSetting.quitAfterWindowClosed = UserDefaults.standard.bool(forKey: "quit_after_window_closed")

        // 同步到直接属性
        self.blockedTags = setting.blockedTags
        self.blockedUsers = setting.blockedUsers
        self.blockedIllusts = setting.blockedIllusts
        self.blockedTagInfos = setting.blockedTagInfos
        self.blockedUserInfos = setting.blockedUserInfos
        self.blockedIllustInfos = setting.blockedIllustInfos
        self.isLoaded = true
    }

    /// 保存用户设置
    func saveSetting() throws {
        try dataContainer.save()
    }

    // MARK: - 图片质量设置

    func setPictureQuality(_ quality: Int) throws {
        userSetting.pictureQuality = quality
        try saveSetting()
    }

    func setMangaQuality(_ quality: Int) throws {
        userSetting.mangaQuality = quality
        try saveSetting()
    }

    func setFeedPreviewQuality(_ quality: Int) throws {
        userSetting.feedPreviewQuality = quality
        try saveSetting()
    }

    func setZoomQuality(_ quality: Int) throws {
        userSetting.zoomQuality = quality
        try saveSetting()
    }

    // MARK: - 布局设置

    func setCrossCount(_ count: Int) throws {
        userSetting.crossCount = count
        try saveSetting()
    }

    func setHCrossCount(_ count: Int) throws {
        userSetting.hCrossCount = count
        try saveSetting()
    }

    func setCrossAdapt(_ adapt: Bool, width: Int? = nil) throws {
        userSetting.crossAdapt = adapt
        if let width = width {
            userSetting.crossAdaptWidth = width
        }
        try saveSetting()
    }

    func setHCrossAdapt(_ adapt: Bool, width: Int? = nil) throws {
        userSetting.hCrossAdapt = adapt
        if let width = width {
            userSetting.hCrossAdaptWidth = width
        }
        try saveSetting()
    }

    // MARK: - macOS 平台设置

    func setQuitAfterWindowClosed(_ enabled: Bool) throws {
        userSetting.quitAfterWindowClosed = enabled
        UserDefaults.standard.set(enabled, forKey: "quit_after_window_closed")
        try saveSetting()
    }

    // MARK: - 主题设置

    func setColorSchemeMode(_ mode: Int) throws {
        userSetting.colorSchemeMode = mode
        try saveSetting()
        Task { @MainActor in
            ThemeManager.shared.applyThemeMode()
        }
    }

    func setTopMode(_ enabled: Bool) throws {
        userSetting.isTopMode = enabled
        try saveSetting()
    }

    func setSeedColor(_ color: Int) throws {
        userSetting.seedColor = color
        try saveSetting()
    }

    // MARK: - 语言设置

    func setLanguage(_ languageNum: Int) throws {
        userSetting.languageNum = languageNum
        try saveSetting()
    }

    // MARK: - 保存设置

    func setSingleFolder(_ enabled: Bool) throws {
        userSetting.singleFolder = enabled
        try saveSetting()
    }

    func setOverSanityLevelFolder(_ enabled: Bool) throws {
        userSetting.overSanityLevelFolder = enabled
        try saveSetting()
    }

    func setStorePath(_ path: String?) throws {
        userSetting.storePath = path
        try saveSetting()
    }

    func setSaveMode(_ mode: Int) throws {
        userSetting.saveMode = mode
        try saveSetting()
    }

    func setMaxRunningTask(_ count: Int) throws {
        userSetting.maxRunningTask = count
        try saveSetting()
    }

    // MARK: - 收藏设置

    func setFollowAfterStar(_ enabled: Bool) throws {
        userSetting.followAfterStar = enabled
        try saveSetting()
    }

    func setSaveAfterStar(_ enabled: Bool) throws {
        userSetting.saveAfterStar = enabled
        try saveSetting()
    }

    func setStarAfterSave(_ enabled: Bool) throws {
        userSetting.starAfterSave = enabled
        try saveSetting()
    }

    func setDefaultPrivateLike(_ enabled: Bool) throws {
        userSetting.defaultPrivateLike = enabled
        try saveSetting()
    }

    // MARK: - 其他设置

    func setAIDisplayMode(_ mode: Int) throws {
        userSetting.aiDisplayMode = mode
        try saveSetting()
    }

    func setR18DisplayMode(_ mode: Int) throws {
        userSetting.r18DisplayMode = mode
        try saveSetting()
    }

    func setAutoPlayUgoira(_ autoPlay: Bool) throws {
        userSetting.autoPlayUgoira = autoPlay
        try saveSetting()
    }

    func setDisableBypassSni(_ disabled: Bool) throws {
        userSetting.disableBypassSni = disabled
        try saveSetting()
    }

    func setCopyInfoText(_ text: String) throws {
        userSetting.copyInfoText = text
        try saveSetting()
    }

    func setNovelFontSize(_ size: Int) throws {
        userSetting.novelFontSize = size
        try saveSetting()
    }

    func setIllustDetailSaveSkipLongPress(_ skip: Bool) throws {
        userSetting.illustDetailSaveSkipLongPress = skip
        try saveSetting()
    }

    func setDownloadQuality(_ quality: Int) throws {
        userSetting.downloadQuality = quality
        try saveSetting()
    }

    func setCreateAuthorFolder(_ enabled: Bool) throws {
        userSetting.createAuthorFolder = enabled
        try saveSetting()
    }

    func setShowSaveCompleteToast(_ enabled: Bool) throws {
        userSetting.showSaveCompleteToast = enabled
        try saveSetting()
    }

    // MARK: - 屏蔽设置

    func addBlockedTag(_ tag: String) throws {
        if !blockedTags.contains(tag) {
            blockedTags.append(tag)
            userSetting.blockedTags = blockedTags
            try saveSetting()
        }
    }

    func addBlockedTagWithInfo(_ name: String, translatedName: String?) throws {
        if !blockedTags.contains(name) {
            blockedTags.append(name)
            userSetting.blockedTags = blockedTags

            let info = BlockedTagInfo(name: name, translatedName: translatedName)
            blockedTagInfos.append(info)
            userSetting.blockedTagInfos = blockedTagInfos

            try saveSetting()
        }
    }

    func removeBlockedTag(_ tag: String) throws {
        blockedTags.removeAll { $0 == tag }
        userSetting.blockedTags = blockedTags

        blockedTagInfos.removeAll { $0.name == tag }
        userSetting.blockedTagInfos = blockedTagInfos

        try saveSetting()
    }

    func addBlockedUser(_ userId: String) throws {
        if !blockedUsers.contains(userId) {
            blockedUsers.append(userId)
            userSetting.blockedUsers = blockedUsers
            try saveSetting()
        }
    }

    func addBlockedUserWithInfo(_ userId: String, name: String?, account: String?, avatarUrl: String?) throws {
        if !blockedUsers.contains(userId) {
            blockedUsers.append(userId)
            userSetting.blockedUsers = blockedUsers

            let info = BlockedUserInfo(userId: userId, name: name, account: account, avatarUrl: avatarUrl)
            blockedUserInfos.append(info)
            userSetting.blockedUserInfos = blockedUserInfos

            try saveSetting()
        }
    }

    func removeBlockedUser(_ userId: String) throws {
        blockedUsers.removeAll { $0 == userId }
        userSetting.blockedUsers = blockedUsers

        blockedUserInfos.removeAll { $0.userId == userId }
        userSetting.blockedUserInfos = blockedUserInfos

        try saveSetting()
    }

    func addBlockedIllust(_ illustId: Int) throws {
        if !blockedIllusts.contains(illustId) {
            blockedIllusts.append(illustId)
            userSetting.blockedIllusts = blockedIllusts
            try saveSetting()
        }
    }

    func addBlockedIllustWithInfo(_ illustId: Int, title: String?, authorId: String?, authorName: String?, thumbnailUrl: String?) throws {
        if !blockedIllusts.contains(illustId) {
            blockedIllusts.append(illustId)
            userSetting.blockedIllusts = blockedIllusts

            let info = BlockedIllustInfo(illustId: illustId, title: title, authorId: authorId, authorName: authorName, thumbnailUrl: thumbnailUrl)
            blockedIllustInfos.append(info)
            userSetting.blockedIllustInfos = blockedIllustInfos

            try saveSetting()
        }
    }

    func removeBlockedIllust(_ illustId: Int) throws {
        blockedIllusts.removeAll { $0 == illustId }
        userSetting.blockedIllusts = blockedIllusts

        blockedIllustInfos.removeAll { $0.illustId == illustId }
        userSetting.blockedIllustInfos = blockedIllustInfos

        try saveSetting()
    }

    /// 过滤插画列表，根据屏蔽设置
    func filterIllusts(_ illusts: [Illusts]) -> [Illusts] {
        var result = illusts

        // R18 过滤
        switch userSetting.r18DisplayMode {
        case 2:
            result = result.filter { $0.xRestrict < 1 }
        case 3:
            result = result.filter { $0.xRestrict >= 1 }
        default:
            break
        }

        // AI 过滤
        switch userSetting.aiDisplayMode {
        case 1:
            result = result.filter { $0.illustAIType != 2 }
        case 2:
            result = result.filter { $0.illustAIType == 2 }
        default:
            break
        }

        // 屏蔽标签
        if !blockedTags.isEmpty {
            result = result.filter { illust in
                !illust.tags.contains { tag in
                    blockedTags.contains(tag.name)
                }
            }
        }

        // 屏蔽作者
        if !blockedUsers.isEmpty {
            result = result.filter { illust in
                !blockedUsers.contains(illust.user.id.stringValue)
            }
        }

        // 屏蔽插画
        if !blockedIllusts.isEmpty {
            result = result.filter { illust in
                !blockedIllusts.contains(illust.id)
            }
        }

        return result
    }

    /// 过滤用户预览列表，根据屏蔽设置
    func filterUserPreviews(_ users: [UserPreviews]) -> [UserPreviews] {
        var result = users

        // 屏蔽作者
        if !blockedUsers.isEmpty {
            result = result.filter { user in
                !blockedUsers.contains(user.user.id.stringValue)
            }
        }

        return result
    }

    /// 过滤小说列表，根据屏蔽设置
    func filterNovels(_ novels: [Novel]) -> [Novel] {
        var result = novels

        // R18 过滤
        switch userSetting.r18DisplayMode {
        case 2:
            result = result.filter { $0.xRestrict < 1 }
        case 3:
            result = result.filter { $0.xRestrict >= 1 }
        default:
            break
        }

        // AI 过滤
        switch userSetting.aiDisplayMode {
        case 1:
            result = result.filter { $0.novelAIType != 2 }
        case 2:
            result = result.filter { $0.novelAIType == 2 }
        default:
            break
        }

        // 屏蔽标签
        if !blockedTags.isEmpty {
            result = result.filter { novel in
                !novel.tags.contains { tag in
                    blockedTags.contains(tag.name)
                }
            }
        }

        // 屏蔽作者
        if !blockedUsers.isEmpty {
            result = result.filter { novel in
                !blockedUsers.contains(novel.user.id.stringValue)
            }
        }

        return result
    }

    // MARK: - 翻译设置

    func setTranslateServiceId(_ id: String) throws {
        userSetting.translateServiceId = id
        try saveSetting()
    }

    func setTranslateTargetLanguage(_ language: String) throws {
        userSetting.translateTargetLanguage = language
        try saveSetting()
    }

    func setTranslateOpenAIApiKey(_ key: String) throws {
        userSetting.translateOpenAIApiKey = key
        try saveSetting()
    }

    func setTranslateOpenAIBaseURL(_ url: String) throws {
        userSetting.translateOpenAIBaseURL = url
        try saveSetting()
    }

    func setTranslateOpenAIModel(_ model: String) throws {
        userSetting.translateOpenAIModel = model
        try saveSetting()
    }

    func setTranslateOpenAITemperature(_ temperature: Double) throws {
        userSetting.translateOpenAITemperature = temperature
        try saveSetting()
    }

    func setTranslateBaiduAppid(_ appid: String) throws {
        userSetting.translateBaiduAppid = appid
        try saveSetting()
    }

    func setTranslateBaiduKey(_ key: String) throws {
        userSetting.translateBaiduKey = key
        try saveSetting()
    }

    func setTranslateGoogleApiKey(_ key: String) throws {
        userSetting.translateGoogleApiKey = key
        try saveSetting()
    }

    func setTranslatePrimaryServiceId(_ id: String) throws {
        userSetting.translatePrimaryServiceId = id
        try saveSetting()
    }

    func setTranslateBackupServiceId(_ id: String) throws {
        userSetting.translateBackupServiceId = id
        try saveSetting()
    }

    func setTranslateTapToTranslate(_ enabled: Bool) throws {
        userSetting.translateTapToTranslate = enabled
        try saveSetting()
    }

    var availableTranslateServices: [(id: String, name: String, requiresSecret: Bool)] {
        [
            ("google", "Google 网页翻译", false),
            ("googleapi", "Google Translate API", false),
            ("openai", "OpenAI 兼容服务", true),
            ("baidu", "百度翻译", true)
        ]
    }

    var availableLanguages: [(code: String, name: String)] {
        [
            ("zh-CN", "简体中文"),
            ("zh-TW", "繁體中文"),
            ("en", "English"),
            ("ja", "日本語"),
            ("ko", "한국어"),
            ("fr", "Français"),
            ("de", "Deutsch"),
            ("es", "Español"),
            ("pt", "Português"),
            ("ru", "Русский"),
            ("ar", "العربية")
        ]
    }
}
