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
            #if os(macOS)
            .frame(minWidth: 1000, minHeight: 700)
            #endif
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }

    private func initializeApp() async {
        async let accounts: Void = AccountStore.shared.loadAccountsAsync()
        async let settings: Void = userSettingStore.loadUserSettingAsync()

        _ = await (accounts, settings)

        isLaunching = false

        AccountStore.shared.markLoginAttempted()
    }
}

struct ContentView: View {
    @Environment(AccountStore.self) var accountStore
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var showTokenRefreshFailedToast: Bool = false

    var body: some View {
        Group {
            if !accountStore.hasAttemptedLogin {
                AuthView(accountStore: accountStore, onGuestMode: {
                    accountStore.markLoginAttempted()
                })
            } else {
                Group {
                    #if os(macOS)
                    MainSplitView(accountStore: accountStore)
                    #else
                    MainTabView(accountStore: accountStore)
                    #endif
                }
                .preferredColorScheme(
                    userSettingStore.userSetting.isAMOLED ? .dark : nil
                )
                    .toast(
                        isPresented: $showTokenRefreshFailedToast,
                        message: "登录状态已过期，请重新登录",
                        duration: 3.0
                    )
                    .onChange(of: accountStore.showTokenRefreshFailedToast) { _, newValue in
                        showTokenRefreshFailedToast = newValue
                    }
                    .animation(.easeInOut(duration: 0.3), value: accountStore.isLoggedIn)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AccountStore.shared)
        .environment(IllustStore())
        .environment(UserSettingStore())
}
