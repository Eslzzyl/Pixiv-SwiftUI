import Foundation
import SwiftData

final class DataContainer {
    static let shared = DataContainer()

    let modelContainer: ModelContainer
    let mainContext: ModelContext

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
            // 如果初始化失败，尝试使用内存存储作为回退，避免应用直接崩溃
            print("警告: 无法初始化持久化 SwiftData 容器: \(error)。尝试使用内存模式。")
            let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                self.modelContainer = try ModelContainer(for: schema, configurations: [memConfig])
                self.mainContext = ModelContext(modelContainer)
            } catch {
                fatalError("严重错误: 即使是内存模式也无法启动 SwiftData: \(error)")
            }
        }
    }

    func createBackgroundContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func save() throws {
        try mainContext.save()
    }
}
