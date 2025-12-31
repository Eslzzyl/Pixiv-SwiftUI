import Foundation
import SwiftData
import Observation

/// 用户设置管理
@Observable
final class UserSettingStore {
    var userSetting: UserSetting = UserSetting()
    var isLoading: Bool = false
    var error: AppError?
    
    private let dataContainer = DataContainer.shared
    
    init() {
        loadUserSetting()
    }
    
    /// 从 SwiftData 加载用户设置
    func loadUserSetting() {
        let context = dataContainer.mainContext
        do {
            let descriptor = FetchDescriptor<UserSetting>()
            if let setting = try context.fetch(descriptor).first {
                self.userSetting = setting
            } else {
                // 如果不存在，创建默认设置
                let newSetting = UserSetting()
                context.insert(newSetting)
                try context.save()
                self.userSetting = newSetting
            }
        } catch {
            self.error = AppError.databaseError("无法加载用户设置: \(error)")
            self.userSetting = UserSetting()
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
    
    // MARK: - 主题设置
    
    func setAMOLED(_ enabled: Bool) throws {
        userSetting.isAMOLED = enabled
        try saveSetting()
    }
    
    func setTopMode(_ enabled: Bool) throws {
        userSetting.isTopMode = enabled
        try saveSetting()
    }
    
    func setUseDynamicColor(_ enabled: Bool) throws {
        userSetting.useDynamicColor = enabled
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
    
    func setSwipeChangeArtwork(_ enabled: Bool) throws {
        userSetting.swipeChangeArtwork = enabled
        try saveSetting()
    }
    
    func setFeedAIBadge(_ enabled: Bool) throws {
        userSetting.feedAIBadge = enabled
        try saveSetting()
    }
    
    func setR18DisplayMode(_ mode: Int) throws {
        userSetting.r18DisplayMode = mode
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
}
