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

    @State private var initializer = AppInitializer.shared

    init() {
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if initializer.isLaunching || initializer.accountStore == nil {
                    LaunchScreenView()
                } else {
                    ContentView()
                        .environment(initializer.accountStore!)
                        .environment(initializer.illustStore!)
                        .environment(initializer.userSettingStore!)
                        .modelContainer(DataContainer.shared.modelContainer)
                }
            }
            .task {
                await initializer.performInitialization()
            }
            #if os(macOS)
            .frame(minWidth: 1000, minHeight: 700)
            #endif
        }
        .commands {
            if let accountStore = initializer.accountStore {
                AppCommands(accountStore: accountStore)
            }
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif

        #if os(macOS)
        WindowGroup(id: "illust-detail", for: Int.self) { $id in
            if let id = id {
                IllustWindowRootView(illustID: id)
                    .environment(AccountStore.shared)
                    .environment(IllustStore.shared)
                    .environment(UserSettingStore.shared)
                    .modelContainer(DataContainer.shared.modelContainer)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        WindowGroup(id: "novel-detail", for: Int.self) { $id in
            if let id = id {
                NovelWindowRootView(novelID: id)
                    .environment(AccountStore.shared)
                    .environment(IllustStore.shared)
                    .environment(UserSettingStore.shared)
                    .modelContainer(DataContainer.shared.modelContainer)
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
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
