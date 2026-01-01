import SwiftData
import SwiftUI

@main
struct PixivApp: App {
    // 初始化 SwiftData 容器
    let dataContainer = DataContainer.shared

    // 应用状态管理
    @State var accountStore = AccountStore.shared
    @State var illustStore = IllustStore()
    @State var userSettingStore = UserSettingStore()

    init() {
        CacheConfig.configureKingfisher()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(accountStore)
                .environment(illustStore)
                .environment(userSettingStore)
                .modelContainer(dataContainer.modelContainer)
        }
    }
}

// 主内容视图
struct ContentView: View {
    @Environment(AccountStore.self) var accountStore
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        if accountStore.isLoggedIn {
            MainTabView(accountStore: accountStore)
                .preferredColorScheme(
                    userSettingStore.userSetting.isAMOLED ? .dark : nil
                )
        } else {
            AuthView(accountStore: accountStore)
        }
    }
}

#Preview {
    ContentView()
        .environment(AccountStore.shared)
        .environment(IllustStore())
        .environment(UserSettingStore())
}
