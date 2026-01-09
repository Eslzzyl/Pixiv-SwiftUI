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
            fatalError("无法初始化 SwiftData 容器: \(error)")
        }
    }

    func createBackgroundContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func save() throws {
        try mainContext.save()
    }
}
