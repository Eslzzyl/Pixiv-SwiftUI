import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return UserDefaults.standard.bool(forKey: "quit_after_window_closed")
    }
}
#endif

@main
struct PixivApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @State private var isLaunching = true

    @State var accountStore = AccountStore.shared
    @State var illustStore = IllustStore.shared
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
        await AccountStore.shared.loadAccountsAsync()
        await userSettingStore.loadUserSettingAsync()

        // 稍微延长一点点 SwiftUI 层的显示时间，确保与系统动画衔接自然
        try? await Task.sleep(for: .milliseconds(200))

        withAnimation(.easeInOut(duration: 0.4)) {
            isLaunching = false
        }

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
