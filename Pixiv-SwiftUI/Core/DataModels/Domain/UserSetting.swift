import Foundation
import SwiftData

/// 用户设置存储
@Model
final class UserSetting: Codable {
    var ownerId: String = "guest"

    /// 图片质量设置：0=中等 1=大 2=原始
    var pictureQuality: Int = 0

    /// 漫画质量设置：0=中等 1=大 2=原始
    var mangaQuality: Int = 0

    /// 推荐页预览质量：0=中等 1=大 2=原始
    var feedPreviewQuality: Int = 0

    /// 列表多页插画预取页数：0=不额外预取，-1=全部页，其他值表示前 N 页
    var listMultiPagePrefetchCount: Int = 5

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

    /// 主题模式：0=跟随系统 1=浅色 2=深色
    var colorSchemeMode: Int = 0

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

    /// 下载分片并发数
    var downloadConcurrency: Int = 8

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

    /// 主题色种子（颜色 ID）
    var seedColor: Int = 0x0096FA

    /// 是否使用自定义主题色
    var isCustomTheme: Bool = false

    /// 自定义主题色 hex
    var customThemeColor: Int = 0x0096FA

    /// AI 显示模式：0=正常显示 1=屏蔽 2=仅显示AI
    var aiDisplayMode: Int = 0

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

    /// macOS: 退出程序当所有窗口关闭
    var quitAfterWindowClosed: Bool = false

    /// R18 显示模式：0=正常显示 1=模糊显示 2=屏蔽 3=仅显示R18
    var r18DisplayMode: Int = 0

    /// R18G 显示模式：0=正常显示 1=模糊显示 2=屏蔽 3=仅显示R18G
    var r18gDisplayMode: Int = 0

    /// 是否显示 XVIII 排行榜分组
    var showXVIIIRankingGroups: Bool = false

    /// 已启用的隐藏插画排行榜分组
    var enabledHiddenIllustRankingModes: [String] = []

    /// 已启用的插画排行榜分组
    var enabledIllustRankingModes: [String] = []

    /// 插画排行榜分组顺序
    var illustRankingModeOrder: [String] = []

    /// 剧透内容显示模式：0=正常显示 1=模糊显示 2=屏蔽 3=仅显示剧透
    var spoilerDisplayMode: Int = 0

    /// 是否在进入后台时模糊页面预览
    var blurAppPreviewInBackground: Bool = false

    /// 是否自动播放动图
    var autoPlayUgoira: Bool = false

    /// 是否显示动图头像
    var showGifAvatar: Bool = true

    /// 搜索页热门排序时是否显示收藏数
    var showSearchPopularBookmarkCount: Bool = false

    /// 默认搜索排序
    var defaultSearchSort: String = SearchSortOption.dateDesc.rawValue

    /// 复制信息文本格式
    var copyInfoText: String = "title:{title}\npainter:{user_name}\nillust id:{illust_id}"

    /// 是否启用容器动画
    var animContainer: Bool = true

    /// 名称评估值
    var nameEval: String?

    /// 屏蔽的标签列表（仅存储名称，用于过滤）
    var blockedTags: [String] = []

    /// 屏蔽的作者ID列表（仅存储ID，用于过滤）
    var blockedUsers: [String] = []

    /// 屏蔽的插画ID列表（仅存储ID，用于过滤）
    var blockedIllusts: [Int] = []

    /// 屏蔽的小说ID列表（仅存储ID，用于过滤）
    var blockedNovels: [Int] = []

    /// 按小说标题屏蔽的关键字
    var blockedNovelTitleKeywords: [String] = []

    /// 按小说系列屏蔽的关键字
    var blockedNovelSeriesKeywords: [String] = []

    /// 按小说简介屏蔽的关键字
    var blockedNovelCaptionKeywords: [String] = []

    /// 屏蔽标签的详细信息
    var blockedTagInfos: [BlockedTagInfo] = []

    /// 屏蔽作者的详细信息
    var blockedUserInfos: [BlockedUserInfo] = []

    /// 屏蔽插画的详细信息
    var blockedIllustInfos: [BlockedIllustInfo] = []

    /// 屏蔽小说的详细信息
    var blockedNovelInfos: [BlockedNovelInfo] = []

    // MARK: - 翻译设置

    /// 当前使用的翻译服务 ID
    var translateServiceId: String = "google"

    /// 目标翻译语言
    var translateTargetLanguage: String = "system"

    /// OpenAI 兼容服务的 API Key
    var translateOpenAIApiKey: String = ""

    /// OpenAI 兼容服务的基础 URL
    var translateOpenAIBaseURL: String = "https://api.openai.com/v1"

    /// OpenAI 使用的模型
    var translateOpenAIModel: String = "gpt-5.1-nano"

    /// OpenAI 温度参数
    var translateOpenAITemperature: Double = 0.3

    /// 百度翻译 AppID
    var translateBaiduAppid: String = ""

    /// 百度翻译 API Key
    var translateBaiduKey: String = ""

    /// Google API 密钥
    var translateGoogleApiKey: String = ""

    /// 腾讯翻译 Secret ID
    var translateTencentSecretId: String = ""

    /// 腾讯翻译 Secret Key
    var translateTencentSecretKey: String = ""

    /// 腾讯翻译区域
    var translateTencentRegion: String = "ap-shanghai"

    /// 腾讯翻译项目 ID
    var translateTencentProjectId: String = "0"

    /// 当前翻译服务 ID
    var translatePrimaryServiceId: String = "bing"

    /// 是否启用轻触翻译
    var translateTapToTranslate: Bool = false

    /// 小说场景是否启用 OpenAI 批量翻译
    var translateNovelBatchEnabled: Bool = true

    /// 小说批量翻译每批最大段落数
    var translateNovelBatchMaxParagraphs: Int = 8

    /// 小说批量翻译每批最大字符数
    var translateNovelBatchMaxCharacters: Int = 4_000

    /// 小说批量翻译附带的前文上下文段落数
    var translateNovelContextParagraphs: Int = 2

    /// 小说批量翻译最大并发批次
    var translateNovelMaxConcurrentBatches: Int = 2

    /// OpenAI 常规翻译系统提示词
    var translateOpenAISystemPrompt: String = "Translate the text provided by the user into {targetLang}. This text comes from Pixiv, a Japanese illustration website. The text may include illustration titles, descriptions, comments, or light novel content, which could contain character names or idiomatic expressions. Ensure the translation is appropriate and accurate, without avoiding NSFW content. Provide only the translation, without any explanation."

    /// OpenAI 小说翻译系统提示词
    var translateNovelSystemPrompt: String = "You are a professional literary translator for Pixiv Japanese novels. Translate the text provided by the user into {targetLang}. Ensure the translation is fluent and natural, maintaining the original meaning and style. Keep names, tone, pacing, and line intent consistent with the source. Do not censor or skip any content. Provide only the translation, without any explanation."

    /// VLM 图片解释是否启用
    var vlmEnabled: Bool = false

    /// VLM 使用的模型（必须是视觉模型，如 gpt-4o）
    var vlmModel: String = "gpt-4o"

    /// VLM 温度参数
    var vlmTemperature: Double = 0.3

    /// VLM 图像细节级别：auto / low / high
    var vlmDetail: String = "auto"

    /// Tag翻译显示模式：0=不显示译文 1=仅显示官方译文 2=使用本地的优化译文
    var tagTranslationDisplayMode: Int = 2

    /// 下载画质设置：0=中等 1=大 2=原始
    var downloadQuality: Int = 2

    /// 是否按作者创建文件夹（macOS）
    var createAuthorFolder: Bool = true

    /// 是否在显示保存完成提示
    var showSaveCompleteToast: Bool = true

    /// 是否导出插画元数据
    var saveMetadata: Bool = true

    // MARK: - 收藏缓存设置

    /// 是否启用收藏缓存
    var bookmarkCacheEnabled: Bool = false

    /// 是否自动预取图片
    var bookmarkAutoPreload: Bool = true

    /// 缓存画质：0=中等 1=大图 2=原图
    var bookmarkCacheQuality: Int = 1

    /// 是否缓存所有页面
    var bookmarkCacheAllPages: Bool = false

    /// 是否缓存动图
    var bookmarkCacheUgoira: Bool = false

    /// 默认启动标签页
    var defaultTab: String = "recommend"

    /// 启动时检查更新
    var checkUpdateOnLaunch: Bool = true

    init(ownerId: String = "guest") {
        self.ownerId = ownerId
    }

    enum CodingKeys: String, CodingKey {
        case ownerId
        case pictureQuality
        case mangaQuality
        case feedPreviewQuality
        case listMultiPagePrefetchCount
        case zoomQuality
        case languageNum
        case crossCount
        case hCrossCount
        case singleFolder
        case overSanityLevelFolder
        case isClearOldFormatFile
        case colorSchemeMode
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
        case seedColor
        case isCustomTheme
        case customThemeColor
        case aiDisplayMode
        case illustDetailSaveSkipLongPress
        case dragStartX
        case crossAdaptWidth
        case crossAdapt
        case hCrossAdaptWidth
        case hCrossAdapt
        case quitAfterWindowClosed
        case r18DisplayMode
        case r18gDisplayMode
        case showXVIIIRankingGroups
        case enabledHiddenIllustRankingModes
        case enabledIllustRankingModes
        case illustRankingModeOrder
        case spoilerDisplayMode
        case blurAppPreviewInBackground
        case autoPlayUgoira
        case showGifAvatar
        case showSearchPopularBookmarkCount
        case defaultSearchSort
        case copyInfoText
        case animContainer
        case nameEval
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
        case translateServiceId
        case translateTargetLanguage
        case translateOpenAIApiKey
        case translateOpenAIBaseURL
        case translateOpenAIModel
        case translateOpenAITemperature
        case translateBaiduAppid
        case translateBaiduKey
        case translateGoogleApiKey
        case translateTencentSecretId
        case translateTencentSecretKey
        case translateTencentRegion
        case translateTencentProjectId
        case translatePrimaryServiceId
        case translateTapToTranslate
        case translateNovelBatchEnabled
        case translateNovelBatchMaxParagraphs
        case translateNovelBatchMaxCharacters
        case translateNovelContextParagraphs
        case translateNovelMaxConcurrentBatches
        case translateOpenAISystemPrompt
        case translateNovelSystemPrompt
        case vlmEnabled
        case vlmModel
        case vlmTemperature
        case vlmDetail
        case tagTranslationDisplayMode
        case downloadQuality
        case createAuthorFolder
        case showSaveCompleteToast
        case saveMetadata
        case bookmarkCacheEnabled
        case bookmarkAutoPreload
        case bookmarkCacheQuality
        case bookmarkCacheAllPages
        case bookmarkCacheUgoira
        case defaultTab
        case checkUpdateOnLaunch
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ownerId = try container.decodeIfPresent(String.self, forKey: .ownerId) ?? "guest"
        self.pictureQuality = try container.decodeIfPresent(Int.self, forKey: .pictureQuality) ?? 0
        self.mangaQuality = try container.decodeIfPresent(Int.self, forKey: .mangaQuality) ?? 0
        self.feedPreviewQuality = try container.decodeIfPresent(Int.self, forKey: .feedPreviewQuality) ?? 0
        self.listMultiPagePrefetchCount = try container.decodeIfPresent(Int.self, forKey: .listMultiPagePrefetchCount) ?? 5
        self.zoomQuality = try container.decodeIfPresent(Int.self, forKey: .zoomQuality) ?? 0
        self.languageNum = try container.decodeIfPresent(Int.self, forKey: .languageNum) ?? 0
        self.crossCount = try container.decodeIfPresent(Int.self, forKey: .crossCount) ?? 2
        self.hCrossCount = try container.decodeIfPresent(Int.self, forKey: .hCrossCount) ?? 4
        self.singleFolder = try container.decodeIfPresent(Bool.self, forKey: .singleFolder) ?? false
        self.overSanityLevelFolder = try container.decodeIfPresent(Bool.self, forKey: .overSanityLevelFolder) ?? false
        self.isClearOldFormatFile = try container.decodeIfPresent(Bool.self, forKey: .isClearOldFormatFile) ?? false
        self.colorSchemeMode = try container.decodeIfPresent(Int.self, forKey: .colorSchemeMode) ?? 0
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
        self.seedColor = try container.decodeIfPresent(Int.self, forKey: .seedColor) ?? 0x0096FA
        self.isCustomTheme = try container.decodeIfPresent(Bool.self, forKey: .isCustomTheme) ?? false
        self.customThemeColor = try container.decodeIfPresent(Int.self, forKey: .customThemeColor) ?? 0x0096FA
        self.aiDisplayMode = try container.decodeIfPresent(Int.self, forKey: .aiDisplayMode) ?? 0
        self.illustDetailSaveSkipLongPress = try container.decodeIfPresent(Bool.self, forKey: .illustDetailSaveSkipLongPress) ?? false
        self.dragStartX = try container.decodeIfPresent(Double.self, forKey: .dragStartX) ?? 0.0
        self.crossAdaptWidth = try container.decodeIfPresent(Int.self, forKey: .crossAdaptWidth) ?? 100
        self.crossAdapt = try container.decodeIfPresent(Bool.self, forKey: .crossAdapt) ?? false
        self.hCrossAdaptWidth = try container.decodeIfPresent(Int.self, forKey: .hCrossAdaptWidth) ?? 100
        self.hCrossAdapt = try container.decodeIfPresent(Bool.self, forKey: .hCrossAdapt) ?? false
        self.quitAfterWindowClosed = try container.decodeIfPresent(Bool.self, forKey: .quitAfterWindowClosed) ?? false
        self.r18DisplayMode = try container.decodeIfPresent(Int.self, forKey: .r18DisplayMode) ?? 0
        self.r18gDisplayMode = try container.decodeIfPresent(Int.self, forKey: .r18gDisplayMode) ?? 0
        self.showXVIIIRankingGroups = try container.decodeIfPresent(Bool.self, forKey: .showXVIIIRankingGroups) ?? false
        let storedHiddenRankingModes = try container.decodeIfPresent([String].self, forKey: .enabledHiddenIllustRankingModes) ?? []
        if storedHiddenRankingModes.isEmpty, self.showXVIIIRankingGroups {
            self.enabledHiddenIllustRankingModes = ["day_r18_ai", "day_r18", "week_r18", "week_r18g"]
        } else {
            self.enabledHiddenIllustRankingModes = storedHiddenRankingModes
        }
        let storedEnabledRankingModes = try container.decodeIfPresent([String].self, forKey: .enabledIllustRankingModes) ?? []
        self.enabledIllustRankingModes = IllustRankingMode.enabledModes(
            from: storedEnabledRankingModes,
            legacyHiddenRawValues: self.enabledHiddenIllustRankingModes,
            showXVIIIRankingGroups: self.showXVIIIRankingGroups
        ).map(\.rawValue)
        let storedRankingModeOrder = try container.decodeIfPresent([String].self, forKey: .illustRankingModeOrder) ?? []
        self.illustRankingModeOrder = IllustRankingMode.orderedModes(from: storedRankingModeOrder).map(\.rawValue)
        self.spoilerDisplayMode = try container.decodeIfPresent(Int.self, forKey: .spoilerDisplayMode) ?? 0
        self.blurAppPreviewInBackground = try container.decodeIfPresent(Bool.self, forKey: .blurAppPreviewInBackground) ?? false
        self.autoPlayUgoira = try container.decodeIfPresent(Bool.self, forKey: .autoPlayUgoira) ?? false
        self.showGifAvatar = try container.decodeIfPresent(Bool.self, forKey: .showGifAvatar) ?? true
        self.showSearchPopularBookmarkCount = try container.decodeIfPresent(Bool.self, forKey: .showSearchPopularBookmarkCount) ?? false
        self.defaultSearchSort = try container.decodeIfPresent(String.self, forKey: .defaultSearchSort) ?? SearchSortOption.dateDesc.rawValue
        self.copyInfoText = try container.decodeIfPresent(String.self, forKey: .copyInfoText) ?? "title:{title}\npainter:{user_name}\nillust id:{illust_id}"
        self.animContainer = try container.decodeIfPresent(Bool.self, forKey: .animContainer) ?? true
        self.nameEval = try container.decodeIfPresent(String.self, forKey: .nameEval)
        self.blockedTags = try container.decodeIfPresent([String].self, forKey: .blockedTags) ?? []
        self.blockedUsers = try container.decodeIfPresent([String].self, forKey: .blockedUsers) ?? []
        self.blockedIllusts = try container.decodeIfPresent([Int].self, forKey: .blockedIllusts) ?? []
        self.blockedNovels = try container.decodeIfPresent([Int].self, forKey: .blockedNovels) ?? []
        self.blockedNovelTitleKeywords = try container.decodeIfPresent([String].self, forKey: .blockedNovelTitleKeywords) ?? []
        self.blockedNovelSeriesKeywords = try container.decodeIfPresent([String].self, forKey: .blockedNovelSeriesKeywords) ?? []
        self.blockedNovelCaptionKeywords = try container.decodeIfPresent([String].self, forKey: .blockedNovelCaptionKeywords) ?? []
        self.blockedTagInfos = (try container.decodeIfPresent([BlockedTagInfoData].self, forKey: .blockedTagInfos) ?? []).map { data in
            let info = BlockedTagInfo(name: data.name, translatedName: data.translatedName)
            return info
        }
        self.blockedUserInfos = (try container.decodeIfPresent([BlockedUserInfoData].self, forKey: .blockedUserInfos) ?? []).map { data in
            let info = BlockedUserInfo(userId: data.userId, name: data.name, account: data.account, avatarUrl: data.avatarUrl)
            return info
        }
        self.blockedIllustInfos = (try container.decodeIfPresent([BlockedIllustInfoData].self, forKey: .blockedIllustInfos) ?? []).map { data in
            let info = BlockedIllustInfo(illustId: data.illustId, title: data.title, authorId: data.authorId, authorName: data.authorName, thumbnailUrl: data.thumbnailUrl)
            return info
        }
        self.blockedNovelInfos = (try container.decodeIfPresent([BlockedNovelInfoData].self, forKey: .blockedNovelInfos) ?? []).map { data in
            let info = BlockedNovelInfo(novelId: data.novelId, title: data.title, authorId: data.authorId, authorName: data.authorName, thumbnailUrl: data.thumbnailUrl)
            return info
        }
        self.translateServiceId = try container.decodeIfPresent(String.self, forKey: .translateServiceId) ?? "google"
        self.translateTargetLanguage = try container.decodeIfPresent(String.self, forKey: .translateTargetLanguage) ?? "system"
        self.translateOpenAIApiKey = try container.decodeIfPresent(String.self, forKey: .translateOpenAIApiKey) ?? ""
        self.translateOpenAIBaseURL = try container.decodeIfPresent(String.self, forKey: .translateOpenAIBaseURL) ?? "https://api.openai.com/v1"
        self.translateOpenAIModel = try container.decodeIfPresent(String.self, forKey: .translateOpenAIModel) ?? "gpt-5.1-nano"
        self.translateOpenAITemperature = try container.decodeIfPresent(Double.self, forKey: .translateOpenAITemperature) ?? 0.3
        self.translateBaiduAppid = try container.decodeIfPresent(String.self, forKey: .translateBaiduAppid) ?? ""
        self.translateBaiduKey = try container.decodeIfPresent(String.self, forKey: .translateBaiduKey) ?? ""
        self.translateGoogleApiKey = try container.decodeIfPresent(String.self, forKey: .translateGoogleApiKey) ?? ""
        self.translateTencentSecretId = try container.decodeIfPresent(String.self, forKey: .translateTencentSecretId) ?? ""
        self.translateTencentSecretKey = try container.decodeIfPresent(String.self, forKey: .translateTencentSecretKey) ?? ""
        self.translateTencentRegion = try container.decodeIfPresent(String.self, forKey: .translateTencentRegion) ?? "ap-shanghai"
        self.translateTencentProjectId = try container.decodeIfPresent(String.self, forKey: .translateTencentProjectId) ?? "0"
        self.translatePrimaryServiceId = try container.decodeIfPresent(String.self, forKey: .translatePrimaryServiceId) ?? "bing"
        self.translateTapToTranslate = try container.decodeIfPresent(Bool.self, forKey: .translateTapToTranslate) ?? false
        self.translateNovelBatchEnabled = try container.decodeIfPresent(Bool.self, forKey: .translateNovelBatchEnabled) ?? true
        self.translateNovelBatchMaxParagraphs = try container.decodeIfPresent(Int.self, forKey: .translateNovelBatchMaxParagraphs) ?? 8
        self.translateNovelBatchMaxCharacters = try container.decodeIfPresent(Int.self, forKey: .translateNovelBatchMaxCharacters) ?? 4_000
        self.translateNovelContextParagraphs = try container.decodeIfPresent(Int.self, forKey: .translateNovelContextParagraphs) ?? 2
        self.translateNovelMaxConcurrentBatches = try container.decodeIfPresent(Int.self, forKey: .translateNovelMaxConcurrentBatches) ?? 2
        self.translateOpenAISystemPrompt = try container.decodeIfPresent(String.self, forKey: .translateOpenAISystemPrompt) ?? "Translate the text provided by the user into {targetLang}. This text comes from Pixiv, a Japanese illustration website. The text may include illustration titles, descriptions, comments, or light novel content, which could contain character names or idiomatic expressions. Ensure the translation is appropriate and accurate, without avoiding NSFW content. Provide only the translation, without any explanation."
        self.translateNovelSystemPrompt = try container.decodeIfPresent(String.self, forKey: .translateNovelSystemPrompt) ?? "You are a professional literary translator for Pixiv Japanese novels. Translate the text provided by the user into {targetLang}. Ensure the translation is fluent and natural, maintaining the original meaning and style. Keep names, tone, pacing, and line intent consistent with the source. Do not censor or skip any content. Provide only the translation, without any explanation."
        self.vlmEnabled = try container.decodeIfPresent(Bool.self, forKey: .vlmEnabled) ?? false
        self.vlmModel = try container.decodeIfPresent(String.self, forKey: .vlmModel) ?? "gpt-4o"
        self.vlmTemperature = try container.decodeIfPresent(Double.self, forKey: .vlmTemperature) ?? 0.3
        self.vlmDetail = try container.decodeIfPresent(String.self, forKey: .vlmDetail) ?? "auto"
        self.tagTranslationDisplayMode = try container.decodeIfPresent(Int.self, forKey: .tagTranslationDisplayMode) ?? 2
        self.downloadQuality = try container.decodeIfPresent(Int.self, forKey: .downloadQuality) ?? 2
        self.createAuthorFolder = try container.decodeIfPresent(Bool.self, forKey: .createAuthorFolder) ?? true
        self.showSaveCompleteToast = try container.decodeIfPresent(Bool.self, forKey: .showSaveCompleteToast) ?? true
        self.saveMetadata = try container.decodeIfPresent(Bool.self, forKey: .saveMetadata) ?? true
        self.bookmarkCacheEnabled = try container.decodeIfPresent(Bool.self, forKey: .bookmarkCacheEnabled) ?? false
        self.bookmarkAutoPreload = try container.decodeIfPresent(Bool.self, forKey: .bookmarkAutoPreload) ?? true
        self.bookmarkCacheQuality = try container.decodeIfPresent(Int.self, forKey: .bookmarkCacheQuality) ?? 1
        self.bookmarkCacheAllPages = try container.decodeIfPresent(Bool.self, forKey: .bookmarkCacheAllPages) ?? false
        self.bookmarkCacheUgoira = try container.decodeIfPresent(Bool.self, forKey: .bookmarkCacheUgoira) ?? false
        self.defaultTab = try container.decodeIfPresent(String.self, forKey: .defaultTab) ?? "recommend"
        self.checkUpdateOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .checkUpdateOnLaunch) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ownerId, forKey: .ownerId)
        try container.encode(pictureQuality, forKey: .pictureQuality)
        try container.encode(mangaQuality, forKey: .mangaQuality)
        try container.encode(feedPreviewQuality, forKey: .feedPreviewQuality)
        try container.encode(listMultiPagePrefetchCount, forKey: .listMultiPagePrefetchCount)
        try container.encode(zoomQuality, forKey: .zoomQuality)
        try container.encode(languageNum, forKey: .languageNum)
        try container.encode(crossCount, forKey: .crossCount)
        try container.encode(hCrossCount, forKey: .hCrossCount)
        try container.encode(singleFolder, forKey: .singleFolder)
        try container.encode(overSanityLevelFolder, forKey: .overSanityLevelFolder)
        try container.encode(isClearOldFormatFile, forKey: .isClearOldFormatFile)
        try container.encode(colorSchemeMode, forKey: .colorSchemeMode)
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
        try container.encode(seedColor, forKey: .seedColor)
        try container.encode(isCustomTheme, forKey: .isCustomTheme)
        try container.encode(customThemeColor, forKey: .customThemeColor)
        try container.encode(aiDisplayMode, forKey: .aiDisplayMode)
        try container.encode(illustDetailSaveSkipLongPress, forKey: .illustDetailSaveSkipLongPress)
        try container.encode(dragStartX, forKey: .dragStartX)
        try container.encode(crossAdaptWidth, forKey: .crossAdaptWidth)
        try container.encode(crossAdapt, forKey: .crossAdapt)
        try container.encode(hCrossAdaptWidth, forKey: .hCrossAdaptWidth)
        try container.encode(hCrossAdapt, forKey: .hCrossAdapt)
        try container.encode(quitAfterWindowClosed, forKey: .quitAfterWindowClosed)
        try container.encode(r18DisplayMode, forKey: .r18DisplayMode)
        try container.encode(r18gDisplayMode, forKey: .r18gDisplayMode)
        try container.encode(showXVIIIRankingGroups, forKey: .showXVIIIRankingGroups)
        try container.encode(enabledHiddenIllustRankingModes, forKey: .enabledHiddenIllustRankingModes)
        try container.encode(enabledIllustRankingModes, forKey: .enabledIllustRankingModes)
        try container.encode(illustRankingModeOrder, forKey: .illustRankingModeOrder)
        try container.encode(spoilerDisplayMode, forKey: .spoilerDisplayMode)
        try container.encode(blurAppPreviewInBackground, forKey: .blurAppPreviewInBackground)
        try container.encode(autoPlayUgoira, forKey: .autoPlayUgoira)
        try container.encode(showGifAvatar, forKey: .showGifAvatar)
        try container.encode(showSearchPopularBookmarkCount, forKey: .showSearchPopularBookmarkCount)
        try container.encode(defaultSearchSort, forKey: .defaultSearchSort)
        try container.encode(copyInfoText, forKey: .copyInfoText)
        try container.encode(animContainer, forKey: .animContainer)
        try container.encodeIfPresent(nameEval, forKey: .nameEval)
        try container.encode(blockedTags, forKey: .blockedTags)
        try container.encode(blockedUsers, forKey: .blockedUsers)
        try container.encode(blockedIllusts, forKey: .blockedIllusts)
        try container.encode(blockedNovels, forKey: .blockedNovels)
        try container.encode(blockedNovelTitleKeywords, forKey: .blockedNovelTitleKeywords)
        try container.encode(blockedNovelSeriesKeywords, forKey: .blockedNovelSeriesKeywords)
        try container.encode(blockedNovelCaptionKeywords, forKey: .blockedNovelCaptionKeywords)
        try container.encode(blockedTagInfos.map { BlockedTagInfoData(name: $0.name, translatedName: $0.translatedName) }, forKey: .blockedTagInfos)
        try container.encode(blockedUserInfos.map { BlockedUserInfoData(userId: $0.userId, name: $0.name, account: $0.account, avatarUrl: $0.avatarUrl) }, forKey: .blockedUserInfos)
        try container.encode(blockedIllustInfos.map { BlockedIllustInfoData(illustId: $0.illustId, title: $0.title, authorId: $0.authorId, authorName: $0.authorName, thumbnailUrl: $0.thumbnailUrl) }, forKey: .blockedIllustInfos)
        try container.encode(blockedNovelInfos.map { BlockedNovelInfoData(novelId: $0.novelId, title: $0.title, authorId: $0.authorId, authorName: $0.authorName, thumbnailUrl: $0.thumbnailUrl) }, forKey: .blockedNovelInfos)
        try container.encode(translateServiceId, forKey: .translateServiceId)
        try container.encode(translateTargetLanguage, forKey: .translateTargetLanguage)
        try container.encodeIfPresent(translateOpenAIApiKey, forKey: .translateOpenAIApiKey)
        try container.encode(translateOpenAIBaseURL, forKey: .translateOpenAIBaseURL)
        try container.encode(translateOpenAIModel, forKey: .translateOpenAIModel)
        try container.encode(translateOpenAITemperature, forKey: .translateOpenAITemperature)
        try container.encodeIfPresent(translateBaiduAppid, forKey: .translateBaiduAppid)
        try container.encodeIfPresent(translateBaiduKey, forKey: .translateBaiduKey)
        try container.encodeIfPresent(translateGoogleApiKey, forKey: .translateGoogleApiKey)
        try container.encodeIfPresent(translateTencentSecretId, forKey: .translateTencentSecretId)
        try container.encodeIfPresent(translateTencentSecretKey, forKey: .translateTencentSecretKey)
        try container.encode(translateTencentRegion, forKey: .translateTencentRegion)
        try container.encode(translateTencentProjectId, forKey: .translateTencentProjectId)
        try container.encode(translatePrimaryServiceId, forKey: .translatePrimaryServiceId)
        try container.encode(translateTapToTranslate, forKey: .translateTapToTranslate)
        try container.encode(translateNovelBatchEnabled, forKey: .translateNovelBatchEnabled)
        try container.encode(translateNovelBatchMaxParagraphs, forKey: .translateNovelBatchMaxParagraphs)
        try container.encode(translateNovelBatchMaxCharacters, forKey: .translateNovelBatchMaxCharacters)
        try container.encode(translateNovelContextParagraphs, forKey: .translateNovelContextParagraphs)
        try container.encode(translateNovelMaxConcurrentBatches, forKey: .translateNovelMaxConcurrentBatches)
        try container.encode(translateOpenAISystemPrompt, forKey: .translateOpenAISystemPrompt)
        try container.encode(translateNovelSystemPrompt, forKey: .translateNovelSystemPrompt)
        try container.encode(vlmEnabled, forKey: .vlmEnabled)
        try container.encode(vlmModel, forKey: .vlmModel)
        try container.encode(vlmTemperature, forKey: .vlmTemperature)
        try container.encode(vlmDetail, forKey: .vlmDetail)
        try container.encode(tagTranslationDisplayMode, forKey: .tagTranslationDisplayMode)
        try container.encode(downloadQuality, forKey: .downloadQuality)
        try container.encode(createAuthorFolder, forKey: .createAuthorFolder)
        try container.encode(showSaveCompleteToast, forKey: .showSaveCompleteToast)
        try container.encode(saveMetadata, forKey: .saveMetadata)
        try container.encode(bookmarkCacheEnabled, forKey: .bookmarkCacheEnabled)
        try container.encode(bookmarkAutoPreload, forKey: .bookmarkAutoPreload)
        try container.encode(bookmarkCacheQuality, forKey: .bookmarkCacheQuality)
        try container.encode(bookmarkCacheAllPages, forKey: .bookmarkCacheAllPages)
        try container.encode(bookmarkCacheUgoira, forKey: .bookmarkCacheUgoira)
        try container.encode(defaultTab, forKey: .defaultTab)
        try container.encode(checkUpdateOnLaunch, forKey: .checkUpdateOnLaunch)
    }
}

struct BlockedTagInfoData: Codable {
    var name: String
    var translatedName: String?
}

struct BlockedUserInfoData: Codable {
    var userId: String
    var name: String?
    var account: String?
    var avatarUrl: String?
}

struct BlockedIllustInfoData: Codable {
    var illustId: Int
    var title: String?
    var authorId: String?
    var authorName: String?
    var thumbnailUrl: String?
}

struct BlockedNovelInfoData: Codable {
    var novelId: Int
    var title: String?
    var authorId: String?
    var authorName: String?
    var thumbnailUrl: String?
}

// MARK: - 显示辅助方法

extension UserSetting {
    /// 根据当前用户的显示设置判断指定插画是否需要模糊
    func shouldBlurIllust(_ illust: Illusts) -> Bool {
        if illust.xRestrict == 1 && r18DisplayMode == 1 { return true }
        if illust.xRestrict == 2 && r18gDisplayMode == 1 { return true }
        if illust.isSpoiler && spoilerDisplayMode == 1 { return true }
        return false
    }

    /// 根据当前用户的显示设置判断指定插画是否应该隐藏
    func shouldHideIllust(_ illust: Illusts) -> Bool {
        let isR18 = illust.xRestrict == 1
        let isR18G = illust.xRestrict == 2
        let isSpoiler = illust.isSpoiler
        let isAI = illust.illustAIType == 2

        let hideR18 = (isR18 && r18DisplayMode == 2) || (!isR18 && r18DisplayMode == 3)
        let hideR18G = (isR18G && r18gDisplayMode == 2) || (!isR18G && r18gDisplayMode == 3)
        let hideSpoiler = (isSpoiler && spoilerDisplayMode == 2) || (!isSpoiler && spoilerDisplayMode == 3)
        let hideAI = (isAI && aiDisplayMode == 1) || (!isAI && aiDisplayMode == 2)

        return hideR18 || hideR18G || hideSpoiler || hideAI
    }
}
