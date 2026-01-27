import SwiftUI

struct AboutSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var showingResetAlert = false

    var body: some View {
        VStack {
            Image("launch")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .padding(.top, topPadding)

            Text("Pixiv-SwiftUI")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, bottomPadding)

            Form {
                appInfoSection
                linksSection
            }
            .formStyle(.grouped)
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
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

    private var iconSize: CGFloat {
        #if os(macOS)
        80
        #else
        64
        #endif
    }

    private var topPadding: CGFloat {
        #if os(macOS)
        20
        #else
        16
        #endif
    }

    private var bottomPadding: CGFloat {
        #if os(macOS)
        10
        #else
        8
        #endif
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
                Text("版本")
                Spacer()
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("\(version) (Build \(build))")
                        .foregroundColor(.secondary)
                } else if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text(version)
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var linksSection: some View {
        Section("链接") {
            // swiftlint:disable:next force_unwrapping
            Link(destination: URL(string: "https://github.com/anomalyco/Pixiv-SwiftUI")!) {
                HStack {
                    Text("GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondary)
                }
            }

            // swiftlint:disable:next force_unwrapping
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
