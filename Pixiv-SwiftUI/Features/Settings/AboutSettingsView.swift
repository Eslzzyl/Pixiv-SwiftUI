import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct AboutSettingsView: View {
    @Environment(UserSettingStore.self) var userSettingStore
    @State private var showingResetAlert = false

    @State private var isCheckingUpdate = false
    @State private var updateInfo: AppUpdateInfo?
    @State private var showingUpdateAlert = false
    @State private var showingNoUpdateAlert = false
    @State private var checkError: String?

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
                updateSection
                autoCheckSection
                linksSection
            }
            .formStyle(.grouped)
        }
        #if os(iOS)
        .background(Color(.systemGroupedBackground))
        #endif
        #if os(macOS)
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
        #endif
        .alert("发现新版本", isPresented: $showingUpdateAlert) {
            Button("取消", role: .cancel) { }
            Button("查看") {
                if let urlString = updateInfo?.releaseUrl,
                   let url = URL(string: urlString) {
                    #if os(macOS)
                    NSWorkspace.shared.open(url)
                    #else
                    UIApplication.shared.open(url)
                    #endif
                }
            }
        } message: {
            if let info = updateInfo {
                Text("版本 \(info.version)\n\n\(info.releaseNotes)")
            }
        }
        .alert("已是最新版本", isPresented: $showingNoUpdateAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("当前已是最新版本")
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

    #if os(macOS)
    private var resetButton: some View {
        Button("重置所有设置") {
            showingResetAlert = true
        }
        .buttonStyle(.link)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    #endif

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

    private var updateSection: some View {
        Section {
            Button {
                checkForUpdate()
            } label: {
                HStack {
                    Text("检查更新")
                    Spacer()
                    if isCheckingUpdate {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .buttonStyle(.plain)
            .tint(nil)
            .disabled(isCheckingUpdate)
        }
    }

    private var autoCheckSection: some View {
        Section {
            Toggle("启动时检查更新", isOn: Binding(
                get: { userSettingStore.userSetting.checkUpdateOnLaunch },
                set: { newValue in
                    try? userSettingStore.setCheckUpdateOnLaunch(newValue)
                }
            ))
        } header: {
            Text("自动更新")
        }
    }

    private var linksSection: some View {
        Section("链接") {
            if let githubURL = URL(string: "https://github.com/anomalyco/Pixiv-SwiftUI") {
                Link(destination: githubURL) {
                    HStack {
                        Text("GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondary)
                    }
                }
            }

            if let pixivURL = URL(string: "https://www.pixiv.net") {
                Link(destination: pixivURL) {
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

    private func checkForUpdate() {
        isCheckingUpdate = true
        checkError = nil

        Task {
            let result = await UpdateChecker.shared.checkForUpdate()
            await MainActor.run {
                isCheckingUpdate = false

                if let info = result {
                    updateInfo = info
                    if info.isNewerThanCurrent {
                        showingUpdateAlert = true
                    } else {
                        showingNoUpdateAlert = true
                    }
                } else {
                    checkError = "检查更新失败"
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
