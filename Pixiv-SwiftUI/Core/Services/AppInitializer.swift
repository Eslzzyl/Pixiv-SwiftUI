import SwiftUI
import Observation

/// 应用启动初始化器，负责协调启动过程中的各种任务
@MainActor
@Observable
final class AppInitializer {
    static let shared = AppInitializer()

    var isLaunching = true
    var accountStore: AccountStore?
    var illustStore: IllustStore?
    var userSettingStore: UserSettingStore?

    private init() {}

    /// 执行应用初始化序列
    func performInitialization() async {
        // 1. 配置基础服务
        CacheConfig.configureKingfisher()
        UgoiraStore.cleanupLegacyCache()

        // 2. 初始化核心 Store
        let aStore = AccountStore.shared
        let iStore = IllustStore.shared
        let uStore = UserSettingStore.shared

        // 3. 异步加载持久化数据
        // 并行加载账户和设置
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await aStore.loadAccountsAsync() }
            group.addTask { await uStore.loadUserSettingAsync() }
        }

        // 4. 更新初始化状态
        self.accountStore = aStore
        self.illustStore = iStore
        self.userSettingStore = uStore

        // 5. 稍微延迟以确保 UI 衔接自然
        try? await Task.sleep(for: .milliseconds(200))

        // 6. 结束启动状态
        withAnimation(.easeInOut(duration: 0.4)) {
            self.isLaunching = false
        }

        // 7. 后续任务
        AccountStore.shared.markLoginAttempted()
    }
}
