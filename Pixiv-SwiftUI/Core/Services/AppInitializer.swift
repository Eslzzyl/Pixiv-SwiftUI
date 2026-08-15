import SwiftUI
import SwiftData
import Observation
import os.log

/// 应用启动初始化器，负责协调启动过程中的各种任务
@MainActor
@Observable
final class AppInitializer {
    static let shared = AppInitializer()

    var isLaunching = true
    var accountStore: AccountStore?
    var illustStore: IllustStore?
    var userSettingStore: UserSettingStore?
    var modelContainer: ModelContainer?
    var initializationError: AppError?

    private init() {}

    /// 执行应用初始化序列
    func performInitialization() async {
        // 1. 初始化 SwiftData 容器（此时 LaunchScreenView 已显示，不会阻塞首帧）
        let dataContainer = DataContainer.shared
        let container = dataContainer.modelContainer
        self.modelContainer = container

        // 持久化失败时不能继续使用内存库，否则用户会在下次启动时看到账号和设置全部消失。
        guard dataContainer.isPersistent else {
            let detail = dataContainer.persistenceErrorDescription ?? "未知原因"
            self.initializationError = .databaseError("本地数据存储无法打开：\(detail)")
            self.isLaunching = false
            return
        }

        // 2. 初始化核心 Store
        let aStore = AccountStore.shared
        let iStore = IllustStore.shared
        let uStore = UserSettingStore.shared

        // 3. 异步加载持久化数据
        // 用户设置依赖当前账户 ownerId，必须在账户恢复后再加载。
        await aStore.loadAccountsAsync()
        await uStore.loadUserSettingAsync()

        guard aStore.error == nil, uStore.error == nil else {
            self.initializationError = aStore.error ?? uStore.error
                ?? .databaseError("启动数据加载失败")
            self.isLaunching = false
            return
        }

        // 4. 账户加载完成后，主动刷新已过期的 token（启动画面期间进行）
        if aStore.isLoggedIn {
            await aStore.refreshTokenIfExpired()
        }

        await ImageCacheSettingsStore.shared.apply()

        // 5. 设置加载完成后刷新主题色（此时 UserSetting 已就绪）
        ThemeManager.shared.updateThemeColor()

        // 5. 更新初始化状态
        self.accountStore = aStore
        self.illustStore = iStore
        self.userSettingStore = uStore

        // 6. 结束启动状态
        withAnimation(.easeInOut(duration: 0.4)) {
            self.isLaunching = false
        }

        // 7. 后续任务（不阻塞 UI 展示）
        AccountStore.shared.markLoginAttempted()

        // 8. 后台配置基础服务（不阻塞启动）
        Task {
            UgoiraStore.cleanupLegacyCache()
        }

        // 9. 检查更新（后台执行）
        checkForUpdateOnLaunch()
    }

    private func checkForUpdateOnLaunch() {
        guard userSettingStore?.userSetting.checkUpdateOnLaunch == true else { return }

        Task {
            if let updateInfo = await UpdateChecker.shared.checkForUpdate() {
                Logger.updater.debug("Current: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"), Latest: \(updateInfo.version), Newer: \(updateInfo.isNewerThanCurrent)")
                await MainActor.run {
                    if updateInfo.isNewerThanCurrent {
                        NotificationCenter.default.post(
                            name: .init("ShowUpdateNotification"),
                            object: updateInfo
                        )
                    }
                }
            }
        }
    }
}
