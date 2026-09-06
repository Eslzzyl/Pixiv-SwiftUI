// swiftlint:disable file_length
import Foundation
import SwiftData
import Observation

let spoilerTags: Set<String> = ["ネタバレ", "spoiler", "ネタバレ注意"]

private enum NovelKeywordBlockMatcher {
    nonisolated static func normalizedKeyword(_ keyword: String) -> String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated static func containsKeyword(_ keyword: String, in keywords: [String]) -> Bool {
        let normalizedKeyword = normalizedKeyword(keyword)
        guard !normalizedKeyword.isEmpty else {
            return false
        }

        return keywords.contains {
            $0.compare(normalizedKeyword, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    nonisolated static func matchesKeyword(in text: String, keywords: [String]) -> Bool {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            return false
        }

        return keywords.contains { keyword in
            let normalizedKeyword = normalizedKeyword(keyword)
            guard !normalizedKeyword.isEmpty else {
                return false
            }

            return normalizedText.range(of: normalizedKeyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    nonisolated static func isNovelBlocked(
        title: String,
        seriesTitle: String,
        caption: String,
        titleKeywords: [String],
        seriesKeywords: [String],
        captionKeywords: [String]
    ) -> Bool {
        matchesKeyword(in: title, keywords: titleKeywords)
            || matchesKeyword(in: seriesTitle, keywords: seriesKeywords)
            || matchesKeyword(in: caption, keywords: captionKeywords)
    }
}

/// 用户设置管理
@MainActor
@Observable
final class UserSettingStore: AppSettingsProtocol {
    static let shared = UserSettingStore()

    var userSetting: UserSetting = UserSetting()
    var isLoading: Bool = false
    var error: AppError?
    var isLoaded: Bool = false

    var blockedTags: [String] = []
    var blockedUsers: [String] = []
    var blockedIllusts: [Int] = []
    var blockedNovels: [Int] = []
    var blockedNovelTitleKeywords: [String] = []
    var blockedNovelSeriesKeywords: [String] = []
    var blockedNovelCaptionKeywords: [String] = []

    var blockedTagInfos: [BlockedTagInfo] = []
    var blockedUserInfos: [BlockedUserInfo] = []
    var blockedIllustInfos: [BlockedIllustInfo] = []
    var blockedNovelInfos: [BlockedNovelInfo] = []

    private let dataContainer = DataContainer.shared

    // MARK: - AppSettingsProtocol

    var defaultPrivateLike: Bool { userSetting.defaultPrivateLike }
    var bookmarkCacheEnabled: Bool { userSetting.bookmarkCacheEnabled }
    var saveMetadata: Bool { userSetting.saveMetadata }
    var maxRunningTask: Int { userSetting.maxRunningTask }
    var translatePrimaryServiceId: String { userSetting.translatePrimaryServiceId }
    var translateTargetLanguage: String { userSetting.translateTargetLanguage }
    var isCustomTheme: Bool { userSetting.isCustomTheme }
    var customThemeColor: Int { userSetting.customThemeColor }
    var seedColor: Int { userSetting.seedColor }
    var colorSchemeMode: Int { userSetting.colorSchemeMode }

    private var blockedTagsSet: Set<String> {
        Set(blockedTags)
    }

    init() {
        NotificationCenter.default.addObserver(
            forName: .accountDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.loadUserSettingAsync()
            }
        }
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
        let (currentUserId, accountGeneration) = await MainActor.run {
            (AccountStore.shared.currentUserId, AccountStore.shared.accountGeneration)
        }

        do {
            let descriptor = FetchDescriptor<UserSetting>(
                predicate: #Predicate { $0.ownerId == currentUserId }
            )
            let fetched = try backgroundContext.fetch(descriptor)

            if let setting = fetched.first {
                let id = setting.persistentModelID
                await MainActor.run {
                    guard AccountStore.shared.currentUserId == currentUserId,
                          AccountStore.shared.accountGeneration == accountGeneration else { return }
                    if let mainSetting = dataContainer.mainContext.model(for: id) as? UserSetting {
                        applySetting(mainSetting)
                    }
                }
            } else {
                await MainActor.run {
                    guard AccountStore.shared.currentUserId == currentUserId,
                          AccountStore.shared.accountGeneration == accountGeneration else { return }
                    loadUserSetting() // 回退到主线程进行创建
                }
            }
        } catch {
            await MainActor.run {
                guard AccountStore.shared.currentUserId == currentUserId,
                      AccountStore.shared.accountGeneration == accountGeneration else { return }
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
        self.blockedNovels = setting.blockedNovels
        self.blockedNovelTitleKeywords = setting.blockedNovelTitleKeywords
        self.blockedNovelSeriesKeywords = setting.blockedNovelSeriesKeywords
        self.blockedNovelCaptionKeywords = setting.blockedNovelCaptionKeywords
        self.blockedTagInfos = setting.blockedTagInfos
        self.blockedUserInfos = setting.blockedUserInfos
        self.blockedIllustInfos = setting.blockedIllustInfos
        self.blockedNovelInfos = setting.blockedNovelInfos
        self.isLoaded = true

        do {
            try normalizeIllustRankingModesIfNeeded()
        } catch {
            self.error = AppError.databaseError("无法保存插画排行榜设置: \(error)")
        }
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

    func setListMultiPagePrefetchCount(_ count: Int) throws {
        userSetting.listMultiPagePrefetchCount = count
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

    func setShowSearchPopularBookmarkCount(_ enabled: Bool) throws {
        userSetting.showSearchPopularBookmarkCount = enabled
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

    func setR18gDisplayMode(_ mode: Int) throws {
        userSetting.r18gDisplayMode = mode
        try saveSetting()
    }

    var orderedIllustRankingModes: [IllustRankingMode] {
        IllustRankingMode.orderedModes(from: userSetting.illustRankingModeOrder)
    }

    var enabledIllustRankingModes: [IllustRankingMode] {
        let enabledModeSet = Set(IllustRankingMode.enabledModes(
            from: userSetting.enabledIllustRankingModes,
            legacyHiddenRawValues: userSetting.enabledHiddenIllustRankingModes,
            showXVIIIRankingGroups: userSetting.showXVIIIRankingGroups
        ))
        return orderedIllustRankingModes.filter { enabledModeSet.contains($0) }
    }

    var enabledHiddenIllustRankingModes: [IllustRankingMode] {
        IllustRankingMode.enabledHiddenModes(from: enabledIllustRankingModes)
    }

    func isIllustRankingModeEnabled(_ mode: IllustRankingMode) -> Bool {
        enabledIllustRankingModes.contains(mode)
    }

    func isHiddenIllustRankingModeEnabled(_ mode: IllustRankingMode) -> Bool {
        enabledHiddenIllustRankingModes.contains(mode)
    }

    private func normalizeIllustRankingModesIfNeeded() throws {
        let normalizedOrder = orderedIllustRankingModes
        let normalizedEnabledModes = enabledIllustRankingModes
        let normalizedHiddenModes = IllustRankingMode.enabledHiddenModes(from: normalizedEnabledModes)
        let hasEnabledXVIIIMode = normalizedHiddenModes.contains { $0.isXVIIIMode }

        let currentOrder = userSetting.illustRankingModeOrder.compactMap(IllustRankingMode.init(rawValue:))
        let currentEnabledModes = userSetting.enabledIllustRankingModes.compactMap(IllustRankingMode.init(rawValue:))
        let currentHiddenModes = userSetting.enabledHiddenIllustRankingModes.compactMap(IllustRankingMode.init(rawValue:))

        guard
            currentOrder != normalizedOrder
                || currentEnabledModes != normalizedEnabledModes
                || currentHiddenModes != normalizedHiddenModes
                || userSetting.showXVIIIRankingGroups != hasEnabledXVIIIMode
        else {
            return
        }

        try persistIllustRankingModes(enabledModes: normalizedEnabledModes, orderedModes: normalizedOrder)
    }

    private func persistIllustRankingModes(
        enabledModes: [IllustRankingMode]? = nil,
        orderedModes: [IllustRankingMode]? = nil
    ) throws {
        let normalizedOrder = IllustRankingMode.orderedModes(from: (orderedModes ?? orderedIllustRankingModes).map(\.rawValue))
        let enabledModeSet = Set(enabledModes ?? enabledIllustRankingModes)
        var normalizedEnabledModes = normalizedOrder.filter { enabledModeSet.contains($0) }

        if normalizedEnabledModes.isEmpty, let fallbackMode = normalizedOrder.first {
            normalizedEnabledModes = [fallbackMode]
        }

        let normalizedHiddenModes = IllustRankingMode.enabledHiddenModes(from: normalizedEnabledModes)
        userSetting.illustRankingModeOrder = normalizedOrder.map(\.rawValue)
        userSetting.enabledIllustRankingModes = normalizedEnabledModes.map(\.rawValue)
        userSetting.enabledHiddenIllustRankingModes = normalizedHiddenModes.map(\.rawValue)
        userSetting.showXVIIIRankingGroups = normalizedHiddenModes.contains { $0.isXVIIIMode }
        try saveSetting()
    }

    func setIllustRankingMode(_ mode: IllustRankingMode, enabled: Bool) throws {
        var modes = enabledIllustRankingModes
        if enabled {
            if !modes.contains(mode) {
                modes.append(mode)
            }
        } else {
            guard modes.count > 1 else { return }
            modes.removeAll { $0 == mode }
        }

        try persistIllustRankingModes(enabledModes: modes)
    }

    func setHiddenIllustRankingMode(_ mode: IllustRankingMode, enabled: Bool) throws {
        guard mode.isHiddenByDefault else { return }
        try setIllustRankingMode(mode, enabled: enabled)
    }

    func setShowXVIIIRankingGroups(_ enabled: Bool) throws {
        var modes = enabledIllustRankingModes.filter { !$0.isXVIIIMode }
        if enabled {
            modes += orderedIllustRankingModes.filter { $0.isXVIIIMode }
        }
        try persistIllustRankingModes(enabledModes: modes)
    }

    func moveIllustRankingModes(fromOffsets: IndexSet, toOffset: Int) throws {
        var orderedModes = orderedIllustRankingModes
        let movingModes = fromOffsets.map { orderedModes[$0] }

        for index in fromOffsets.sorted(by: >) {
            orderedModes.remove(at: index)
        }

        orderedModes.insert(contentsOf: movingModes, at: min(max(toOffset, 0), orderedModes.count))
        try persistIllustRankingModes(orderedModes: orderedModes)
    }

    func setSpoilerDisplayMode(_ mode: Int) throws {
        userSetting.spoilerDisplayMode = mode
        try saveSetting()
    }

    func setBlurAppPreviewInBackground(_ enabled: Bool) throws {
        userSetting.blurAppPreviewInBackground = enabled
        try saveSetting()
    }

    func setAutoPlayUgoira(_ autoPlay: Bool) throws {
        userSetting.autoPlayUgoira = autoPlay
        try saveSetting()
    }

    func setShowGifAvatar(_ show: Bool) throws {
        userSetting.showGifAvatar = show
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

    func setSaveMetadata(_ enabled: Bool) throws {
        userSetting.saveMetadata = enabled
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

    func addBlockedNovel(_ novelId: Int) throws {
        if !blockedNovels.contains(novelId) {
            blockedNovels.append(novelId)
            userSetting.blockedNovels = blockedNovels
            try saveSetting()
        }
    }

    func addBlockedNovelWithInfo(_ novelId: Int, title: String?, authorId: String?, authorName: String?, thumbnailUrl: String?) throws {
        if !blockedNovels.contains(novelId) {
            blockedNovels.append(novelId)
            userSetting.blockedNovels = blockedNovels

            let info = BlockedNovelInfo(novelId: novelId, title: title, authorId: authorId, authorName: authorName, thumbnailUrl: thumbnailUrl)
            blockedNovelInfos.append(info)
            userSetting.blockedNovelInfos = blockedNovelInfos

            try saveSetting()
        }
    }

    func removeBlockedNovel(_ novelId: Int) throws {
        blockedNovels.removeAll { $0 == novelId }
        userSetting.blockedNovels = blockedNovels

        blockedNovelInfos.removeAll { $0.novelId == novelId }
        userSetting.blockedNovelInfos = blockedNovelInfos

        try saveSetting()
    }

    func addBlockedNovelTitleKeyword(_ keyword: String) throws {
        let normalizedKeyword = NovelKeywordBlockMatcher.normalizedKeyword(keyword)
        guard !normalizedKeyword.isEmpty, !NovelKeywordBlockMatcher.containsKeyword(normalizedKeyword, in: blockedNovelTitleKeywords) else {
            return
        }

        blockedNovelTitleKeywords.append(normalizedKeyword)
        userSetting.blockedNovelTitleKeywords = blockedNovelTitleKeywords
        try saveSetting()
    }

    func removeBlockedNovelTitleKeyword(_ keyword: String) throws {
        let normalizedKeyword = NovelKeywordBlockMatcher.normalizedKeyword(keyword)
        blockedNovelTitleKeywords.removeAll {
            $0.compare(normalizedKeyword, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        userSetting.blockedNovelTitleKeywords = blockedNovelTitleKeywords
        try saveSetting()
    }

    func addBlockedNovelSeriesKeyword(_ keyword: String) throws {
        let normalizedKeyword = NovelKeywordBlockMatcher.normalizedKeyword(keyword)
        guard !normalizedKeyword.isEmpty, !NovelKeywordBlockMatcher.containsKeyword(normalizedKeyword, in: blockedNovelSeriesKeywords) else {
            return
        }

        blockedNovelSeriesKeywords.append(normalizedKeyword)
        userSetting.blockedNovelSeriesKeywords = blockedNovelSeriesKeywords
        try saveSetting()
    }

    func removeBlockedNovelSeriesKeyword(_ keyword: String) throws {
        let normalizedKeyword = NovelKeywordBlockMatcher.normalizedKeyword(keyword)
        blockedNovelSeriesKeywords.removeAll {
            $0.compare(normalizedKeyword, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        userSetting.blockedNovelSeriesKeywords = blockedNovelSeriesKeywords
        try saveSetting()
    }

    func addBlockedNovelCaptionKeyword(_ keyword: String) throws {
        let normalizedKeyword = NovelKeywordBlockMatcher.normalizedKeyword(keyword)
        guard !normalizedKeyword.isEmpty, !NovelKeywordBlockMatcher.containsKeyword(normalizedKeyword, in: blockedNovelCaptionKeywords) else {
            return
        }

        blockedNovelCaptionKeywords.append(normalizedKeyword)
        userSetting.blockedNovelCaptionKeywords = blockedNovelCaptionKeywords
        try saveSetting()
    }

    func removeBlockedNovelCaptionKeyword(_ keyword: String) throws {
        let normalizedKeyword = NovelKeywordBlockMatcher.normalizedKeyword(keyword)
        blockedNovelCaptionKeywords.removeAll {
            $0.compare(normalizedKeyword, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        userSetting.blockedNovelCaptionKeywords = blockedNovelCaptionKeywords
        try saveSetting()
    }

    /// 过滤插画列表，根据屏蔽设置（同步版本，用于计算属性）
    func filterIllusts(_ illusts: [Illusts]) -> [Illusts] {
        var result = illusts

        // R18 过滤 (xRestrict == 1)
        switch userSetting.r18DisplayMode {
        case 2:
            result = result.filter { $0.xRestrict != 1 }
        case 3:
            result = result.filter { $0.xRestrict == 1 }
        default:
            break
        }

        // R18G 过滤 (xRestrict == 2)
        switch userSetting.r18gDisplayMode {
        case 2:
            result = result.filter { $0.xRestrict != 2 }
        case 3:
            result = result.filter { $0.xRestrict == 2 }
        default:
            break
        }

        // 剧透内容过滤
        switch userSetting.spoilerDisplayMode {
        case 2:
            result = result.filter { !$0.isSpoiler }
        case 3:
            result = result.filter { $0.isSpoiler }
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
            let tagsSet = blockedTagsSet
            result = result.filter { illust in
                !illust.tags.contains { tagsSet.contains($0.name) }
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

    /// 过滤插画列表，根据屏蔽配置（异步版本，在后台线程执行）
    func filterIllustsAsync(_ illusts: [Illusts]) async -> [Illusts] { // swiftlint:disable:this cyclomatic_complexity
        let r18Mode = userSetting.r18DisplayMode
        let r18gMode = userSetting.r18gDisplayMode
        let spoilerMode = userSetting.spoilerDisplayMode
        let aiMode = userSetting.aiDisplayMode
        let tagsSet = blockedTagsSet
        let blockedUsersList = blockedUsers
        let blockedIllustsList = blockedIllusts
        let spoilerTagsSet = spoilerTags

        let illustData = illusts.map { ($0.id, $0.xRestrict, $0.illustAIType, $0.user.id.stringValue, $0.tags.map { $0.name }) }

        let indicesToKeep = await Task.detached(priority: .userInitiated) {
            var indicesToKeep: [Int] = []
            indicesToKeep.reserveCapacity(illustData.count)

            for (index, data) in illustData.enumerated() {
                let (id, xRestrict, aiType, userId, tags) = data

                // R18 过滤 (xRestrict == 1)
                switch r18Mode {
                case 2:
                    if xRestrict == 1 { continue }
                case 3:
                    if xRestrict != 1 { continue }
                default:
                    break
                }

                // R18G 过滤 (xRestrict == 2)
                switch r18gMode {
                case 2:
                    if xRestrict == 2 { continue }
                case 3:
                    if xRestrict != 2 { continue }
                default:
                    break
                }

                // 剧透内容过滤
                switch spoilerMode {
                case 2:
                    if tags.contains(where: { spoilerTagsSet.contains($0.lowercased()) }) { continue }
                case 3:
                    if !tags.contains(where: { spoilerTagsSet.contains($0.lowercased()) }) { continue }
                default:
                    break
                }

                // AI 过滤
                switch aiMode {
                case 1:
                    if aiType == 2 { continue }
                case 2:
                    if aiType != 2 { continue }
                default:
                    break
                }

                // 屏蔽标签
                if !tagsSet.isEmpty {
                    if tags.contains(where: { tagsSet.contains($0) }) {
                        continue
                    }
                }

                // 屏蔽作者
                if !blockedUsersList.isEmpty {
                    if blockedUsersList.contains(userId) {
                        continue
                    }
                }

                // 屏蔽插画
                if !blockedIllustsList.isEmpty {
                    if blockedIllustsList.contains(id) {
                        continue
                    }
                }

                indicesToKeep.append(index)
            }

            return indicesToKeep
        }.value

        return indicesToKeep.map { illusts[$0] }
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

    /// 过滤小说列表，根据屏蔽设置（同步版本，用于计算属性）
    func filterNovels(_ novels: [Novel]) -> [Novel] {
        var result = novels

        // R18 过滤 (xRestrict == 1)
        switch userSetting.r18DisplayMode {
        case 2:
            result = result.filter { $0.xRestrict != 1 }
        case 3:
            result = result.filter { $0.xRestrict == 1 }
        default:
            break
        }

        // R18G 过滤 (xRestrict == 2)
        switch userSetting.r18gDisplayMode {
        case 2:
            result = result.filter { $0.xRestrict != 2 }
        case 3:
            result = result.filter { $0.xRestrict == 2 }
        default:
            break
        }

        // 剧透内容过滤
        switch userSetting.spoilerDisplayMode {
        case 2:
            result = result.filter { novel in
                !novel.tags.contains { spoilerTags.contains($0.name.lowercased()) }
            }
        case 3:
            result = result.filter { novel in
                novel.tags.contains { spoilerTags.contains($0.name.lowercased()) }
            }
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
            let tagsSet = blockedTagsSet
            result = result.filter { novel in
                !novel.tags.contains { tagsSet.contains($0.name) }
            }
        }

        // 屏蔽作者
        if !blockedUsers.isEmpty {
            result = result.filter { novel in
                !blockedUsers.contains(novel.user.id.stringValue)
            }
        }

        // 屏蔽小说
        if !blockedNovels.isEmpty {
            result = result.filter { novel in
                !blockedNovels.contains(novel.id)
            }
        }

        if !blockedNovelTitleKeywords.isEmpty || !blockedNovelSeriesKeywords.isEmpty || !blockedNovelCaptionKeywords.isEmpty {
            result = result.filter { novel in
                !NovelKeywordBlockMatcher.isNovelBlocked(
                    title: novel.title,
                    seriesTitle: novel.series?.title ?? "",
                    caption: TextCleaner.cleanDescription(novel.caption),
                    titleKeywords: blockedNovelTitleKeywords,
                    seriesKeywords: blockedNovelSeriesKeywords,
                    captionKeywords: blockedNovelCaptionKeywords
                )
            }
        }

        return result
    }

    /// 过滤小说列表，根据屏蔽设置（异步版本，在后台线程执行）
    func filterNovelsAsync(_ novels: [Novel]) async -> [Novel] { // swiftlint:disable:this cyclomatic_complexity
        let r18Mode = userSetting.r18DisplayMode
        let r18gMode = userSetting.r18gDisplayMode
        let spoilerMode = userSetting.spoilerDisplayMode
        let aiMode = userSetting.aiDisplayMode
        let tagsSet = blockedTagsSet
        let blockedUsersList = blockedUsers
        let blockedNovelsList = blockedNovels
        let blockedNovelTitleKeywordsList = blockedNovelTitleKeywords
        let blockedNovelSeriesKeywordsList = blockedNovelSeriesKeywords
        let blockedNovelCaptionKeywordsList = blockedNovelCaptionKeywords
        let spoilerTagsSet = spoilerTags

        let novelData = novels.map {
            (
                $0.id,
                $0.xRestrict,
                $0.novelAIType,
                $0.user.id.stringValue,
                $0.tags.map { $0.name },
                $0.title,
                $0.series?.title ?? "",
                TextCleaner.cleanDescription($0.caption)
            )
        }

        let indicesToKeep = await Task.detached(priority: .userInitiated) {
            var indicesToKeep: [Int] = []
            indicesToKeep.reserveCapacity(novelData.count)

            for (index, data) in novelData.enumerated() {
                let (id, xRestrict, aiType, userId, tags, title, seriesTitle, caption) = data

                // R18 过滤 (xRestrict == 1)
                switch r18Mode {
                case 2:
                    if xRestrict == 1 { continue }
                case 3:
                    if xRestrict != 1 { continue }
                default:
                    break
                }

                // R18G 过滤 (xRestrict == 2)
                switch r18gMode {
                case 2:
                    if xRestrict == 2 { continue }
                case 3:
                    if xRestrict != 2 { continue }
                default:
                    break
                }

                // 剧透内容过滤
                switch spoilerMode {
                case 2:
                    if tags.contains(where: { spoilerTagsSet.contains($0.lowercased()) }) { continue }
                case 3:
                    if !tags.contains(where: { spoilerTagsSet.contains($0.lowercased()) }) { continue }
                default:
                    break
                }

                // AI 过滤
                switch aiMode {
                case 1:
                    if aiType == 2 { continue }
                case 2:
                    if aiType != 2 { continue }
                default:
                    break
                }

                // 屏蔽标签
                if !tagsSet.isEmpty {
                    if tags.contains(where: { tagsSet.contains($0) }) {
                        continue
                    }
                }

                // 屏蔽作者
                if !blockedUsersList.isEmpty {
                    if blockedUsersList.contains(userId) {
                        continue
                    }
                }

                // 屏蔽小说
                if !blockedNovelsList.isEmpty {
                    if blockedNovelsList.contains(id) {
                        continue
                    }
                }

                if !blockedNovelTitleKeywordsList.isEmpty || !blockedNovelSeriesKeywordsList.isEmpty || !blockedNovelCaptionKeywordsList.isEmpty {
                    if NovelKeywordBlockMatcher.isNovelBlocked(
                        title: title,
                        seriesTitle: seriesTitle,
                        caption: caption,
                        titleKeywords: blockedNovelTitleKeywordsList,
                        seriesKeywords: blockedNovelSeriesKeywordsList,
                        captionKeywords: blockedNovelCaptionKeywordsList
                    ) {
                        continue
                    }
                }

                indicesToKeep.append(index)
            }

            return indicesToKeep
        }.value

        return indicesToKeep.map { novels[$0] }
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

    func resolveTargetLanguage(_ language: String) -> String {
        if language == "system" || language.isEmpty {
            return Self.systemLanguageCode
        }
        return language
    }

    static var systemLanguageCode: String {
        guard let preferred = Locale.preferredLanguages.first else { return "en" }
        let locale = Locale(identifier: preferred)
        let langCode = locale.language.languageCode?.identifier ?? "en"

        switch langCode {
        case "zh":
            let script = locale.language.script?.identifier ?? ""
            let region = locale.language.region?.identifier ?? ""
            if script == "Hant" || region == "TW" || region == "HK" || region == "MO" {
                return "zh-TW"
            }
            return "zh-CN"
        default:
            return langCode
        }
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

    func setTranslateTencentSecretId(_ secretId: String) throws {
        userSetting.translateTencentSecretId = secretId
        try saveSetting()
    }

    func setTranslateTencentSecretKey(_ secretKey: String) throws {
        userSetting.translateTencentSecretKey = secretKey
        try saveSetting()
    }

    func setTranslateTencentRegion(_ region: String) throws {
        userSetting.translateTencentRegion = region
        try saveSetting()
    }

    func setTranslateTencentProjectId(_ projectId: String) throws {
        userSetting.translateTencentProjectId = projectId
        try saveSetting()
    }

    func setTranslateOpenAISystemPrompt(_ prompt: String) throws {
        userSetting.translateOpenAISystemPrompt = prompt
        try saveSetting()
    }

    func setTranslateNovelSystemPrompt(_ prompt: String) throws {
        userSetting.translateNovelSystemPrompt = prompt
        try saveSetting()
    }

    func setVLMEnabled(_ enabled: Bool) throws {
        userSetting.vlmEnabled = enabled
        try saveSetting()
    }

    func setVLMModel(_ model: String) throws {
        userSetting.vlmModel = model
        try saveSetting()
    }

    func setVLMTemperature(_ temperature: Double) throws {
        userSetting.vlmTemperature = temperature
        try saveSetting()
    }

    func setVLMDetail(_ detail: String) throws {
        userSetting.vlmDetail = detail
        try saveSetting()
    }

    func setTranslatePrimaryServiceId(_ id: String) throws {
        userSetting.translatePrimaryServiceId = id
        try saveSetting()
    }

    func setTranslateTapToTranslate(_ enabled: Bool) throws {
        userSetting.translateTapToTranslate = enabled
        try saveSetting()
    }

    func setTranslateNovelBatchEnabled(_ enabled: Bool) throws {
        userSetting.translateNovelBatchEnabled = enabled
        try saveSetting()
    }

    func setTranslateNovelBatchMaxParagraphs(_ count: Int) throws {
        userSetting.translateNovelBatchMaxParagraphs = count
        try saveSetting()
    }

    func setTranslateNovelBatchMaxCharacters(_ count: Int) throws {
        userSetting.translateNovelBatchMaxCharacters = count
        try saveSetting()
    }

    func setTranslateNovelContextParagraphs(_ count: Int) throws {
        userSetting.translateNovelContextParagraphs = count
        try saveSetting()
    }

    func setTranslateNovelMaxConcurrentBatches(_ count: Int) throws {
        userSetting.translateNovelMaxConcurrentBatches = count
        try saveSetting()
    }

    func setTagTranslationDisplayMode(_ mode: Int) throws {
        userSetting.tagTranslationDisplayMode = mode
        try saveSetting()
    }

    func setTagLayoutOptimizationEnabled(_ enabled: Bool) throws {
        userSetting.tagLayoutOptimizationEnabled = enabled
        try saveSetting()
    }

    // MARK: - 收藏缓存设置

    func setBookmarkCacheEnabled(_ enabled: Bool) throws {
        userSetting.bookmarkCacheEnabled = enabled
        try saveSetting()
    }

    func setBookmarkAutoPreload(_ enabled: Bool) throws {
        userSetting.bookmarkAutoPreload = enabled
        try saveSetting()
    }

    func setBookmarkCacheQuality(_ quality: Int) throws {
        userSetting.bookmarkCacheQuality = quality
        try saveSetting()
    }

    func setBookmarkCacheAllPages(_ enabled: Bool) throws {
        userSetting.bookmarkCacheAllPages = enabled
        try saveSetting()
    }

    func setBookmarkCacheUgoira(_ enabled: Bool) throws {
        userSetting.bookmarkCacheUgoira = enabled
        try saveSetting()
    }

    func setDefaultTab(_ tab: NavigationItem) throws {
        userSetting.defaultTab = tab.rawValue
        try saveSetting()
    }

    func setDefaultSearchSort(_ sort: SearchSortOption) throws {
        userSetting.defaultSearchSort = sort.rawValue
        try saveSetting()
    }

    func setCheckUpdateOnLaunch(_ enabled: Bool) throws {
        userSetting.checkUpdateOnLaunch = enabled
        try saveSetting()
    }

    var availableTranslateServices: [(id: String, name: String, requiresSecret: Bool)] {
        [
            ("google", "Google 网页翻译", false),
            ("googleapi", "Google Translate API", false),
            ("openai", "OpenAI 兼容服务", true),
            ("baidu", "百度翻译", true),
            ("bing", "Bing 翻译", false),
            ("tencent", "腾讯翻译", true)
        ]
    }

    var availableLanguages: [(code: String, name: String)] {
        [
            ("system", String(localized: "系统语言")),
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
