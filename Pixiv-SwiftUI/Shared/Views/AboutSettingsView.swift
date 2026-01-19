import SwiftUI

struct AboutSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var showingResetAlert = false

    var body: some View {
        Form {
            appInfoSection
            linksSection
        }
        .formStyle(.grouped)
        .alert("确认重置", isPresented: $showingResetAlert) {
            Button("取消", role: .cancel) { }
            Button("重置", role: .destructive) {
            }
        } message: {
            Text("确定要重置所有设置为默认值吗？")
        }
        .safeAreaInset(edge: .bottom) {
            resetButton
        }
    }

    private var resetButton: some View {
        Button("重置所有设置") {
            showingResetAlert = true
        }
        #if os(macOS)
        .buttonStyle(.link)
        #endif
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appInfoSection: some View {
        Section("应用信息") {
            HStack {
                Text("应用名称")
                Spacer()
                Text("Pixiv SwiftUI")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("版本")
                Spacer()
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text(version)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown")
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Build")
                Spacer()
                if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text(build)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown")
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("平台")
                Spacer()
                #if os(macOS)
                Text("macOS")
                    .foregroundColor(.secondary)
                #else
                Text("iOS")
                    .foregroundColor(.secondary)
                #endif
            }
        }
    }

    private var linksSection: some View {
        Section("链接") {
            Link(destination: URL(string: "https://github.com/anomalyco/Pixiv-SwiftUI")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }

            Link(destination: URL(string: "https://www.pixiv.net")!) {
                HStack {
                    Text("Pixiv 官网")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutSettingsView()
    }
}
