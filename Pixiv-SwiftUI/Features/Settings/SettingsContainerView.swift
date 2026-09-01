import SwiftUI
import Observation

#if os(macOS)
struct SettingsContainerView: View {
    @State private var selectedDestination: SettingsDestination = .general
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(UserSettingStore.self) var userSettingStore
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedDestination) {
                Section(String(localized: "通用")) {
                    NavigationLink(value: SettingsDestination.general) {
                        sidebarLabel(
                            title: String(localized: "通用"),
                            systemImage: "gearshape",
                            destination: .general
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .general))

                    NavigationLink(value: SettingsDestination.appearance) {
                        sidebarLabel(
                            title: String(localized: "外观"),
                            systemImage: "paintpalette",
                            destination: .appearance
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .appearance))
                }

                Section(String(localized: "过滤与屏蔽")) {
                    NavigationLink(value: SettingsDestination.privacy) {
                        sidebarLabel(
                            title: String(localized: "过滤"),
                            systemImage: "line.3.horizontal.decrease.circle",
                            destination: .privacy
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .privacy))

                    NavigationLink(value: SettingsDestination.block) {
                        sidebarLabel(
                            title: String(localized: "屏蔽"),
                            systemImage: "nosign",
                            destination: .block
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .block))
                }

                Section(String(localized: "功能")) {
                    NavigationLink(value: SettingsDestination.translation) {
                        sidebarLabel(
                            title: String(localized: "翻译"),
                            systemImage: "character.bubble",
                            destination: .translation
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .translation))

                    NavigationLink(value: SettingsDestination.sync) {
                        sidebarLabel(
                            title: String(localized: "同步"),
                            systemImage: "arrow.triangle.2.circlepath",
                            destination: .sync
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .sync))

                    NavigationLink(value: SettingsDestination.bookmark) {
                        sidebarLabel(
                            title: String(localized: "收藏"),
                            systemImage: "bookmark",
                            destination: .bookmark
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .bookmark))

                    NavigationLink(value: SettingsDestination.download) {
                        sidebarLabel(
                            title: String(localized: "下载"),
                            systemImage: "arrow.down.circle",
                            destination: .download
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .download))

                    NavigationLink(value: SettingsDestination.network) {
                        sidebarLabel(
                            title: String(localized: "网络"),
                            systemImage: "network",
                            destination: .network
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .network))
                }

                Section(String(localized: "关于")) {
                    NavigationLink(value: SettingsDestination.about) {
                        sidebarLabel(
                            title: String(localized: "关于"),
                            systemImage: "info.circle",
                            destination: .about
                        )
                    }
                    .listItemTint(themeManager.currentColor)
                    .listRowBackground(sidebarSelectionBackground(for: .about))
                }
            }
            .listStyle(.sidebar)
            .navigationTitle(String(localized: "设置"))
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            #endif
        } detail: {
            SettingsDetailView(destination: selectedDestination)
                .environment(themeManager)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func sidebarLabel(
        title: String,
        systemImage: String,
        destination: SettingsDestination
    ) -> some View {
        let isSelected = selectedDestination == destination

        return Label {
            Text(title)
                .foregroundStyle(isSelected ? .white : .primary)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isSelected ? .white : themeManager.currentColor)
        }
        .background(SidebarRowSelectionStyle())
    }

    private func sidebarSelectionBackground(for destination: SettingsDestination) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(selectedDestination == destination ? themeManager.currentColor : .clear)
            .padding(.horizontal, 8)
    }
}

struct SettingsDetailView: View {
    let destination: SettingsDestination

    var body: some View {
        switch destination {
        case .general:
            GeneralSettingsView()
        case .appearance:
            ThemeSettingsView()
        case .privacy:
            PrivacySettingsView()
        case .block:
            BlockSettingView()
        case .translation:
            TranslationSettingView()
        case .sync:
            WebDAVSyncSettingsView()
        case .bookmark:
            BookmarkSettingView()
        case .download:
            DownloadSettingView()
        case .network:
            NetworkSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}

enum SettingsDestination: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case privacy
    case block
    case translation
    case sync
    case bookmark
    case download
    case network
    case about

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .general: return String(localized: "通用")
        case .appearance: return String(localized: "外观")
        case .privacy: return String(localized: "过滤")
        case .block: return String(localized: "屏蔽")
        case .translation: return String(localized: "翻译")
        case .sync: return String(localized: "同步")
        case .bookmark: return String(localized: "收藏")
        case .download: return String(localized: "下载")
        case .network: return String(localized: "网络")
        case .about: return String(localized: "关于")
        }
    }

    var windowTitle: String {
        String(localized: "设置") + " - \(displayTitle)"
    }
}

#Preview {
    SettingsContainerView()
}
#endif
