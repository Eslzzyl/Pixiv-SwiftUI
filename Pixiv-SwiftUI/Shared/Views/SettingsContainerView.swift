import SwiftUI
import Observation

#if os(macOS)
struct SettingsContainerView: View {
    @State private var selectedDestination: SettingsDestination = .general
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(UserSettingStore.self) var userSettingStore
    @State var themeManager = ThemeManager.shared

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedDestination) {
                Section(String(localized: "通用")) {
                    NavigationLink(value: SettingsDestination.general) {
                        Label(String(localized: "通用"), systemImage: "gearshape")
                    }

                    NavigationLink(value: SettingsDestination.appearance) {
                        Label(String(localized: "外观"), systemImage: "paintpalette")
                    }
                }

                Section(String(localized: "显示")) {
                    NavigationLink(value: SettingsDestination.display) {
                        Label(String(localized: "显示"), systemImage: "eye")
                    }
                }

                Section(String(localized: "网络")) {
                    NavigationLink(value: SettingsDestination.network) {
                        Label(String(localized: "网络"), systemImage: "network")
                    }
                }

                Section(String(localized: "内容过滤")) {
                    NavigationLink(value: SettingsDestination.block) {
                        Label(String(localized: "屏蔽"), systemImage: "nosign")
                    }

                    NavigationLink(value: SettingsDestination.translation) {
                        Label(String(localized: "翻译"), systemImage: "character.bubble")
                    }

                    NavigationLink(value: SettingsDestination.download) {
                        Label(String(localized: "下载设置"), systemImage: "arrow.down.circle")
                    }
                }

                Section(String(localized: "关于")) {
                    NavigationLink(value: SettingsDestination.about) {
                        Label(String(localized: "关于"), systemImage: "info.circle")
                    }
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
        .frame(minWidth: 700, minHeight: 500)
    }
}

struct SettingsDetailView: View {
    let destination: SettingsDestination

    var body: some View {
        switch destination {
        case .general:
            GeneralSettingsView()
        case .display:
            DisplaySettingsView()
        case .network:
            NetworkSettingsView()
        case .block:
            BlockSettingView()
        case .translation:
            TranslationSettingView()
        case .download:
            DownloadSettingView()
        case .about:
            AboutSettingsView()
        case .appearance:
            ThemeSettingsView()
        }
    }
}

enum SettingsDestination: String, CaseIterable, Identifiable, Hashable {
    case general
    case appearance
    case display
    case network
    case block
    case translation
    case download
    case about

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .general: return String(localized: "通用")
        case .appearance: return String(localized: "外观")
        case .display: return String(localized: "显示")
        case .network: return String(localized: "网络")
        case .block: return String(localized: "屏蔽")
        case .translation: return String(localized: "翻译")
        case .download: return String(localized: "下载设置")
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
