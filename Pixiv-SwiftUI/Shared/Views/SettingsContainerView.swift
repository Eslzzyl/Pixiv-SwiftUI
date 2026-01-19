import SwiftUI

#if os(macOS)
struct SettingsContainerView: View {
    @State private var selectedDestination: SettingsDestination = .general
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(UserSettingStore.self) var userSettingStore

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedDestination) {
                Section("通用") {
                    NavigationLink(value: SettingsDestination.general) {
                        Label("通用", systemImage: "gearshape")
                    }
                }

                Section("显示") {
                    NavigationLink(value: SettingsDestination.display) {
                        Label("显示", systemImage: "eye")
                    }
                }

                Section("网络") {
                    NavigationLink(value: SettingsDestination.network) {
                        Label("网络", systemImage: "network")
                    }
                }

                Section("内容") {
                    NavigationLink(value: SettingsDestination.block) {
                        Label("屏蔽", systemImage: "nosign")
                    }

                    NavigationLink(value: SettingsDestination.translation) {
                        Label("翻译", systemImage: "character.bubble")
                    }

                    NavigationLink(value: SettingsDestination.download) {
                        Label("下载", systemImage: "arrow.down.circle")
                    }
                }

                Section("关于") {
                    NavigationLink(value: SettingsDestination.about) {
                        Label("关于", systemImage: "info.circle")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            #endif
        } detail: {
            SettingsDetailView(destination: selectedDestination)
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
        }
    }
}

enum SettingsDestination: String, CaseIterable, Identifiable, Hashable {
    case general
    case display
    case network
    case block
    case translation
    case download
    case about

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .general: return "通用"
        case .display: return "显示"
        case .network: return "网络"
        case .block: return "屏蔽"
        case .translation: return "翻译"
        case .download: return "下载"
        case .about: return "关于"
        }
    }

    var windowTitle: String {
        "设置 - \(displayTitle)"
    }
}

#Preview {
    SettingsContainerView()
}
#endif
