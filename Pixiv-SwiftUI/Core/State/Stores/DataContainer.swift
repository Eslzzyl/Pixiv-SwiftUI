import Foundation
import SwiftData
import os.log

final class DataContainer {
    static let shared = DataContainer()

    let modelContainer: ModelContainer
    let mainContext: ModelContext
    let isPersistent: Bool
    let persistenceErrorDescription: String?

    private init() {
        let schema = Schema([
            ProfileImageUrls.self,
            User.self,
            AccountResponse.self,
            AccountPersist.self,

            Tag.self,
            ImageUrls.self,
            MetaSinglePage.self,
            MetaPagesImageUrls.self,
            MetaPages.self,
            IllustSeries.self,
            Illusts.self,

            UserSetting.self,

            TranslationCache.self,

            BanIllustId.self,
            BanUserId.self,
            BanTag.self,
            GlanceIllustPersist.self,
            GlanceNovelPersist.self,
            CachedNovel.self,
            CachedIllust.self,
            TaskPersist.self,
            BookmarkCache.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
        )

        var persistenceErrorDescription: String?

        // 尝试持久化容器
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.modelContainer = container
            self.mainContext = ModelContext(container)
            self.isPersistent = true
            self.persistenceErrorDescription = nil
            return
        } catch {
            persistenceErrorDescription = error.localizedDescription
            Logger.database.error("无法初始化持久化 SwiftData 容器: \(error.localizedDescription, privacy: .public)")
        }

        // 尝试全 Schema 内存容器
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [memConfig]) {
            self.modelContainer = container
            self.mainContext = ModelContext(container)
            self.isPersistent = false
            self.persistenceErrorDescription = persistenceErrorDescription
            return
        }

        Logger.database.error("警告: 内存模式也失败，使用最小化 Schema 回退。")

        // 最终回退：空 Schema + 内存模式，保证应用不会因 SwiftData 初始化失败而崩溃
        let fallbackContainer = DataContainer.createFallbackContainer()
        self.modelContainer = fallbackContainer
        self.mainContext = ModelContext(fallbackContainer)
        self.isPersistent = false
        self.persistenceErrorDescription = persistenceErrorDescription ?? "无法创建 SwiftData 容器"
    }

    /// 创建一个最小化的内存 ModelContainer 作为最后回退
    private static func createFallbackContainer() -> ModelContainer {
        let emptySchema = Schema([])
        let config = ModelConfiguration(schema: emptySchema, isStoredInMemoryOnly: true)
        // 空 Schema + 内存模式不会失败，但为保险使用 try?
        if let container = try? ModelContainer(for: emptySchema, configurations: [config]) {
            return container
        }
        // 理论上不可能到达这里，使用 try! 显式表达意图
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: emptySchema, configurations: config)
    }

    func createBackgroundContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func save() throws {
        try mainContext.save()
    }
}
