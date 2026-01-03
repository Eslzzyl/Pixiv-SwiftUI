import SwiftData
import SwiftUI

@main
struct PixivApp: App {
    @State private var isLaunching = true

    @State var accountStore = AccountStore.shared
    @State var illustStore = IllustStore()
    @State var userSettingStore = UserSettingStore.shared

    init() {
        CacheConfig.configureKingfisher()
        UgoiraStore.cleanupLegacyCache()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if isLaunching {
                    LaunchScreenView()
                } else {
                    ContentView()
                        .environment(accountStore)
                        .environment(illustStore)
                        .environment(userSettingStore)
                        .modelContainer(DataContainer.shared.modelContainer)
                }
            }
            .task {
                await initializeApp()
            }
        }
    }

    private func initializeApp() async {
        async let accounts: Void = AccountStore.shared.loadAccountsAsync()
        async let settings: Void = userSettingStore.loadUserSettingAsync()

        _ = await (accounts, settings)

        isLaunching = false
    }
}

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
