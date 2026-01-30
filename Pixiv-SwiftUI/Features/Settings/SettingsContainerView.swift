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

                Section(String(localized: "过滤与屏蔽")) {
                    NavigationLink(value: SettingsDestination.privacy) {
                        Label(String(localized: "过滤"), systemImage: "line.3.horizontal.decrease.circle")
                    }

                    NavigationLink(value: SettingsDestination.block) {
                        Label(String(localized: "屏蔽"), systemImage: "nosign")
                    }
                }

                Section(String(localized: "功能")) {
                    NavigationLink(value: SettingsDestination.translation) {
                        Label(String(localized: "翻译"), systemImage: "character.bubble")
                    }

                    NavigationLink(value: SettingsDestination.download) {
                        Label(String(localized: "下载"), systemImage: "arrow.down.circle")
                    }

                    NavigationLink(value: SettingsDestination.network) {
                        Label(String(localized: "网络"), systemImage: "network")
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
        case .appearance:
            ThemeSettingsView()
        case .privacy:
            PrivacySettingsView()
        case .block:
            BlockSettingView()
        case .translation:
            TranslationSettingView()
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
