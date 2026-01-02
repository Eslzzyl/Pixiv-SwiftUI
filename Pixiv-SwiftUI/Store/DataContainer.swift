import Foundation
import SwiftData

/// SwiftData 模型容器配置
final class DataContainer {
    static let shared = DataContainer()

    let modelContainer: ModelContainer
    let mainContext: ModelContext

    private init() {
        // 定义所有需要持久化的模型
        let schema = Schema([
            // 账户相关
            ProfileImageUrls.self,
            User.self,
            AccountResponse.self,
            AccountPersist.self,

            // 插画相关
            Tag.self,
            ImageUrls.self,
            MetaSinglePage.self,
            MetaPagesImageUrls.self,
            MetaPages.self,
            IllustSeries.self,
            Illusts.self,

            // 用户设置
            UserSetting.self,

            // 翻译缓存
            TranslationCache.self,

            // 持久化数据
            BanIllustId.self,
            BanUserId.self,
            BanTag.self,
            GlanceIllustPersist.self,
            TaskPersist.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
        )

        do {
            self.modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            self.mainContext = ModelContext(modelContainer)
        } catch {
            fatalError("无法初始化 SwiftData 容器: \(error)")
        }
    }

    /// 创建一个新的后台上下文用于异步操作
    func createBackgroundContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    /// 保存当前上下文中的更改
    func save() throws {
        try mainContext.save()
    }
}
