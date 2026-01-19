import SwiftUI

struct SettingsContainerView: View {
    #if os(macOS)
    @State private var selectedDestination: SettingsDestination = .general
    #endif

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(selection: $selectedDestination) {
                Section("通用") {
                    NavigationLink(value: SettingsDestination.general) {
                        Label("通用设置", systemImage: "gearshape")
                    }
                }

                Section("内容") {
                    NavigationLink(value: SettingsDestination.block) {
                        Label("屏蔽设置", systemImage: "nosign")
                    }

                    NavigationLink(value: SettingsDestination.translation) {
                        Label("翻译设置", systemImage: "character.bubble")
                    }
                }

                Section("下载") {
                    NavigationLink(value: SettingsDestination.download) {
                        Label("下载设置", systemImage: "arrow.down.circle")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("设置")
        } detail: {
            switch selectedDestination {
            case .general:
                ProfileSettingView(isPresented: .constant(true))
            case .block:
                BlockSettingView()
            case .translation:
                TranslationSettingView()
            case .download:
                DownloadSettingView()
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        #else
        Text("此功能仅在 macOS 上可用")
            .foregroundColor(.secondary)
        #endif
    }
}

enum SettingsDestination: String, CaseIterable, Identifiable, Hashable {
    case general
    case block
    case translation
    case download

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用设置"
        case .block: return "屏蔽设置"
        case .translation: return "翻译设置"
        case .download: return "下载设置"
        }
    }
}

#Preview {
    SettingsContainerView()
}
