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
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    sidebarHeader(String(localized: "通用"), topPadding: 4)
                    sidebarRow(title: String(localized: "通用"), icon: "gearshape", destination: .general)
                    sidebarRow(title: String(localized: "外观"), icon: "paintpalette", destination: .appearance)

                    sidebarHeader(String(localized: "过滤与屏蔽"), topPadding: 20)
                    sidebarRow(title: String(localized: "过滤"), icon: "line.3.horizontal.decrease.circle", destination: .privacy)
                    sidebarRow(title: String(localized: "屏蔽"), icon: "nosign", destination: .block)

                    sidebarHeader(String(localized: "功能"), topPadding: 20)
                    sidebarRow(title: String(localized: "翻译"), icon: "character.bubble", destination: .translation)
                    sidebarRow(title: String(localized: "同步"), icon: "arrow.triangle.2.circlepath", destination: .sync)
                    sidebarRow(title: String(localized: "收藏"), icon: "bookmark", destination: .bookmark)
                    sidebarRow(title: String(localized: "下载"), icon: "arrow.down.circle", destination: .download)
                    sidebarRow(title: String(localized: "网络"), icon: "network", destination: .network)

                    sidebarHeader(String(localized: "关于"), topPadding: 20)
                    sidebarRow(title: String(localized: "关于"), icon: "info.circle", destination: .about)
                }
                .padding(.horizontal, 8)
                .padding(.top, 12)
            }
            .navigationTitle(String(localized: "设置"))
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 170, ideal: 205, max: 250)
            #endif
        } detail: {
            SettingsDetailView(destination: selectedDestination)
                .environment(themeManager)
                .tint(nil)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func sidebarHeader(_ title: String, topPadding: CGFloat = 20) -> some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 8)
            .padding(.top, topPadding)
            .padding(.bottom, 6)
    }

    private func sidebarRow(
        title: String,
        icon: String,
        destination: SettingsDestination
    ) -> some View {
        let isSelected = selectedDestination == destination

        return Button {
            selectedDestination = destination
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 16.5, weight: .medium))
                    .foregroundStyle(themeManager.currentColor)
                    .frame(width: 20, alignment: .center)

                Text(title)
                    .font(.system(size: 13.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
