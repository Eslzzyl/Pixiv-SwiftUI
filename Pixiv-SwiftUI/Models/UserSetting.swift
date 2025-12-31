import Foundation
import SwiftData

/// 用户设置存储
@Model
final class UserSetting: Codable {
    /// 图片质量设置：0=中等 1=大 2=原始
    var pictureQuality: Int = 0
    
    /// 漫画质量设置：0=中等 1=大 2=原始
    var mangaQuality: Int = 0
    
    /// 推荐页预览质量：0=中等 1=大 2=原始
    var feedPreviewQuality: Int = 0
    
    /// 缩放质量：0=中等 1=大
    var zoomQuality: Int = 0
    
    /// UI 语言：0=跟随系统 1=中文 2=English 等
    var languageNum: Int = 0
    
    /// 竖屏网格列数
    var crossCount: Int = 2
    
    /// 横屏网格列数
    var hCrossCount: Int = 4
    
    /// 是否为单文件夹保存模式
    var singleFolder: Bool = false
    
    /// 是否覆盖高 sanity 等级创建文件夹
    var overSanityLevelFolder: Bool = false
    
    /// 是否清理旧格式文件
    var isClearOldFormatFile: Bool = false
    
    /// 是否使用 AMOLED 黑色主题
    var isAMOLED: Bool = false
    
    /// 是否启用顶部模式（Fluent UI）
    var isTopMode: Bool = false
    
    /// 保存文件路径
    var storePath: String?
    
    /// 是否启用 bang 手势
    var isBangs: Bool = false
    
    /// 是否禁用 SNI 绕过
    var disableBypassSni: Bool = false
    
    /// 是否在收藏后跟随用户
    var followAfterStar: Bool = false
    
    /// 收藏后是否保存
    var saveAfterStar: Bool = false
    
    /// 保存后是否收藏
    var starAfterSave: Bool = false
    
    /// 默认私密收藏
    var defaultPrivateLike: Bool = false
    
    /// 是否使用返回确认退出
    var isReturnAgainToExit: Bool = false
    
    /// 保存模式：0=默认 1=自定义
    var saveMode: Int = 0
    
    /// 小说字体大小
    var novelFontSize: Int = 16
    
    /// 最大并行下载任务数
    var maxRunningTask: Int = 3
    
    /// 是否启用动态颜色
    var useDynamicColor: Bool = false
    
    /// 主题色种子（颜色 ID）
    var seedColor: Int = 0xFF0000
    
    /// 是否在滑动时切换作品
    var swipeChangeArtwork: Bool = true
    
    /// 是否显示 AI 徽章
    var feedAIBadge: Bool = true
    
    /// 是否跳过长按确认保存
    var illustDetailSaveSkipLongPress: Bool = false
    
    /// 拖动开始 X 坐标
    var dragStartX: Double = 0.0
    
    /// 竖屏网格自适应宽度
    var crossAdaptWidth: Int = 100
    
    /// 竖屏是否自适应
    var crossAdapt: Bool = false
    
    /// 横屏网格自适应宽度
    var hCrossAdaptWidth: Int = 100
    
    /// 横屏是否自适应
    var hCrossAdapt: Bool = false
    
    /// 复制信息文本格式
    var copyInfoText: String = "title:{title}\npainter:{user_name}\nillust id:{illust_id}"
    
    /// 是否启用容器动画
    var animContainer: Bool = true
    
    /// 名称评估值
    var nameEval: String?
    
    init() {}
    
    enum CodingKeys: String, CodingKey {
        case pictureQuality
        case mangaQuality
        case feedPreviewQuality
        case zoomQuality
        case languageNum
        case crossCount
        case hCrossCount
        case singleFolder
        case overSanityLevelFolder
        case isClearOldFormatFile
        case isAMOLED
        case isTopMode
        case storePath
        case isBangs
        case disableBypassSni
        case followAfterStar
        case saveAfterStar
        case starAfterSave
        case defaultPrivateLike
        case isReturnAgainToExit
        case saveMode
        case novelFontSize
        case maxRunningTask
        case useDynamicColor
        case seedColor
        case swipeChangeArtwork
        case feedAIBadge
        case illustDetailSaveSkipLongPress
        case dragStartX
        case crossAdaptWidth
        case crossAdapt
        case hCrossAdaptWidth
        case hCrossAdapt
        case copyInfoText
        case animContainer
        case nameEval
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.pictureQuality = try container.decodeIfPresent(Int.self, forKey: .pictureQuality) ?? 0
        self.mangaQuality = try container.decodeIfPresent(Int.self, forKey: .mangaQuality) ?? 0
        self.feedPreviewQuality = try container.decodeIfPresent(Int.self, forKey: .feedPreviewQuality) ?? 0
        self.zoomQuality = try container.decodeIfPresent(Int.self, forKey: .zoomQuality) ?? 0
        self.languageNum = try container.decodeIfPresent(Int.self, forKey: .languageNum) ?? 0
        self.crossCount = try container.decodeIfPresent(Int.self, forKey: .crossCount) ?? 2
        self.hCrossCount = try container.decodeIfPresent(Int.self, forKey: .hCrossCount) ?? 4
        self.singleFolder = try container.decodeIfPresent(Bool.self, forKey: .singleFolder) ?? false
        self.overSanityLevelFolder = try container.decodeIfPresent(Bool.self, forKey: .overSanityLevelFolder) ?? false
        self.isClearOldFormatFile = try container.decodeIfPresent(Bool.self, forKey: .isClearOldFormatFile) ?? false
        self.isAMOLED = try container.decodeIfPresent(Bool.self, forKey: .isAMOLED) ?? false
        self.isTopMode = try container.decodeIfPresent(Bool.self, forKey: .isTopMode) ?? false
        self.storePath = try container.decodeIfPresent(String.self, forKey: .storePath)
        self.isBangs = try container.decodeIfPresent(Bool.self, forKey: .isBangs) ?? false
        self.disableBypassSni = try container.decodeIfPresent(Bool.self, forKey: .disableBypassSni) ?? false
        self.followAfterStar = try container.decodeIfPresent(Bool.self, forKey: .followAfterStar) ?? false
        self.saveAfterStar = try container.decodeIfPresent(Bool.self, forKey: .saveAfterStar) ?? false
        self.starAfterSave = try container.decodeIfPresent(Bool.self, forKey: .starAfterSave) ?? false
        self.defaultPrivateLike = try container.decodeIfPresent(Bool.self, forKey: .defaultPrivateLike) ?? false
        self.isReturnAgainToExit = try container.decodeIfPresent(Bool.self, forKey: .isReturnAgainToExit) ?? false
        self.saveMode = try container.decodeIfPresent(Int.self, forKey: .saveMode) ?? 0
        self.novelFontSize = try container.decodeIfPresent(Int.self, forKey: .novelFontSize) ?? 16
        self.maxRunningTask = try container.decodeIfPresent(Int.self, forKey: .maxRunningTask) ?? 3
        self.useDynamicColor = try container.decodeIfPresent(Bool.self, forKey: .useDynamicColor) ?? false
        self.seedColor = try container.decodeIfPresent(Int.self, forKey: .seedColor) ?? 0xFF0000
        self.swipeChangeArtwork = try container.decodeIfPresent(Bool.self, forKey: .swipeChangeArtwork) ?? true
        self.feedAIBadge = try container.decodeIfPresent(Bool.self, forKey: .feedAIBadge) ?? true
        self.illustDetailSaveSkipLongPress = try container.decodeIfPresent(Bool.self, forKey: .illustDetailSaveSkipLongPress) ?? false
        self.dragStartX = try container.decodeIfPresent(Double.self, forKey: .dragStartX) ?? 0.0
        self.crossAdaptWidth = try container.decodeIfPresent(Int.self, forKey: .crossAdaptWidth) ?? 100
        self.crossAdapt = try container.decodeIfPresent(Bool.self, forKey: .crossAdapt) ?? false
        self.hCrossAdaptWidth = try container.decodeIfPresent(Int.self, forKey: .hCrossAdaptWidth) ?? 100
        self.hCrossAdapt = try container.decodeIfPresent(Bool.self, forKey: .hCrossAdapt) ?? false
        self.copyInfoText = try container.decodeIfPresent(String.self, forKey: .copyInfoText) ?? "title:{title}\npainter:{user_name}\nillust id:{illust_id}"
        self.animContainer = try container.decodeIfPresent(Bool.self, forKey: .animContainer) ?? true
        self.nameEval = try container.decodeIfPresent(String.self, forKey: .nameEval)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pictureQuality, forKey: .pictureQuality)
        try container.encode(mangaQuality, forKey: .mangaQuality)
        try container.encode(feedPreviewQuality, forKey: .feedPreviewQuality)
        try container.encode(zoomQuality, forKey: .zoomQuality)
        try container.encode(languageNum, forKey: .languageNum)
        try container.encode(crossCount, forKey: .crossCount)
        try container.encode(hCrossCount, forKey: .hCrossCount)
        try container.encode(singleFolder, forKey: .singleFolder)
        try container.encode(overSanityLevelFolder, forKey: .overSanityLevelFolder)
        try container.encode(isClearOldFormatFile, forKey: .isClearOldFormatFile)
        try container.encode(isAMOLED, forKey: .isAMOLED)
        try container.encode(isTopMode, forKey: .isTopMode)
        try container.encodeIfPresent(storePath, forKey: .storePath)
        try container.encode(isBangs, forKey: .isBangs)
        try container.encode(disableBypassSni, forKey: .disableBypassSni)
        try container.encode(followAfterStar, forKey: .followAfterStar)
        try container.encode(saveAfterStar, forKey: .saveAfterStar)
        try container.encode(starAfterSave, forKey: .starAfterSave)
        try container.encode(defaultPrivateLike, forKey: .defaultPrivateLike)
        try container.encode(isReturnAgainToExit, forKey: .isReturnAgainToExit)
        try container.encode(saveMode, forKey: .saveMode)
        try container.encode(novelFontSize, forKey: .novelFontSize)
        try container.encode(maxRunningTask, forKey: .maxRunningTask)
        try container.encode(useDynamicColor, forKey: .useDynamicColor)
        try container.encode(seedColor, forKey: .seedColor)
        try container.encode(swipeChangeArtwork, forKey: .swipeChangeArtwork)
        try container.encode(feedAIBadge, forKey: .feedAIBadge)
        try container.encode(illustDetailSaveSkipLongPress, forKey: .illustDetailSaveSkipLongPress)
        try container.encode(dragStartX, forKey: .dragStartX)
        try container.encode(crossAdaptWidth, forKey: .crossAdaptWidth)
        try container.encode(crossAdapt, forKey: .crossAdapt)
        try container.encode(hCrossAdaptWidth, forKey: .hCrossAdaptWidth)
        try container.encode(hCrossAdapt, forKey: .hCrossAdapt)
        try container.encode(copyInfoText, forKey: .copyInfoText)
        try container.encode(animContainer, forKey: .animContainer)
        try container.encodeIfPresent(nameEval, forKey: .nameEval)
    }
}
