import SwiftUI
import Combine
import Kingfisher
import SwiftData

#if os(macOS)
struct MenuCommandHandler: ViewModifier {
    @Bindable var accountStore: AccountStore
    @Binding var selectedItem: NavigationItem?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    @Binding var showAuthView: Bool
    @Binding var showClearCacheAlert: Bool
    @Binding var showClearHistoryAlert: Bool

    let modelContext: ModelContext

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .showLoginSheet)) { _ in
                showAuthView = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToSearch)) { _ in
                selectedItem = .search
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToProfile)) { _ in
                if accountStore.isLoggedIn {
                    selectedItem = .recommend
                    accountStore.requestNavigation(.userDetail(accountStore.currentUserId))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToDownloads)) { _ in
                selectedItem = .downloads
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                withAnimation {
                    switch columnVisibility {
                    case .all:
                        columnVisibility = .detailOnly
                    default:
                        columnVisibility = .all
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearCache)) { _ in
                showClearCacheAlert = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearHistory)) { _ in
                showClearHistoryAlert = true
            }
            .alert("确认清除缓存", isPresented: $showClearCacheAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    Task {
                        Kingfisher.ImageCache.default.clearMemoryCache()
                        await Kingfisher.ImageCache.default.clearDiskCache()
                    }
                }
            } message: {
                Text("清除缓存后将重新下载图片，可能会消耗更多流量。")
            }
            .alert("确认清除历史记录", isPresented: $showClearHistoryAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    Task {
                        try? modelContext.delete(model: GlanceIllustPersist.self)
                        try? modelContext.delete(model: GlanceNovelPersist.self)
                    }
                }
            } message: {
                Text("清除后无法恢复，确定要继续吗？")
            }
    }
}

extension View {
    func handleMenuCommands(
        accountStore: AccountStore,
        selectedItem: Binding<NavigationItem?>,
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        showAuthView: Binding<Bool>,
        showClearCacheAlert: Binding<Bool>,
        showClearHistoryAlert: Binding<Bool>,
        modelContext: ModelContext
    ) -> some View {
        modifier(MenuCommandHandler(
            accountStore: accountStore,
            selectedItem: selectedItem,
            columnVisibility: columnVisibility,
            showAuthView: showAuthView,
            showClearCacheAlert: showClearCacheAlert,
            showClearHistoryAlert: showClearHistoryAlert,
            modelContext: modelContext
        ))
    }
}
#endif
