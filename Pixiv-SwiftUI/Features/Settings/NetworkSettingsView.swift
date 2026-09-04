import SwiftUI

struct NetworkSettingsView: View {
    @Environment(AccountStore.self) private var accountStore
    @State private var userSettingStore = UserSettingStore.shared
    @State private var networkModeStore = NetworkModeStore.shared
    @State private var showAuthView = false
    @State private var selectedNetworkMode = NetworkModeStore.shared.currentMode
    @State private var proxyProtocol = NetworkModeStore.shared.customProxyConfiguration?.protocolType ?? .httpConnect
    @State private var proxyHost = NetworkModeStore.shared.customProxyConfiguration?.host ?? ""
    @State private var proxyPort = NetworkModeStore.shared.customProxyConfiguration.map { String($0.port) } ?? ""
    @State private var proxyUsername = NetworkModeStore.shared.customProxyConfiguration?.username ?? ""
    @State private var proxyPassword = NetworkModeStore.shared.loadCustomProxyPassword()
    @State private var proxyConfigurationError: String?

    var body: some View {
        Form {
            networkSection
            if selectedNetworkMode == .customProxy {
                customProxySection
            }
            downloadSection
        }
        .formStyle(.grouped)
        .navigationTitle(String(localized: "网络"))
        .sheet(isPresented: $showAuthView) {
            AuthView(accountStore: accountStore, onGuestMode: nil)
        }
    }

    private var networkSection: some View {
        Section {
            LabeledContent(String(localized: "网络模式")) {
                Picker("", selection: $selectedNetworkMode) {
                    ForEach(NetworkMode.allCases) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "网络"))
        } footer: {
            Text(networkModeDescription)
        }
        .onChange(of: selectedNetworkMode) { _, mode in
            selectNetworkMode(mode)
        }
    }

    private var customProxySection: some View {
        Section {
            Picker(String(localized: "代理协议"), selection: $proxyProtocol) {
                ForEach(CustomProxyProtocol.allCases) { protocolType in
                    Text(protocolType.displayName)
                        .tag(protocolType)
                }
            }

            TextField(String(localized: "代理服务器地址"), text: $proxyHost)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            TextField(String(localized: "代理端口"), text: $proxyPort)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif

            TextField(String(localized: "用户名（可选）"), text: $proxyUsername)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()

            SecureField(String(localized: "密码（可选）"), text: $proxyPassword)

            Button(String(localized: "保存并启用代理")) {
                saveCustomProxyConfiguration()
            }
        } header: {
            Text(String(localized: "自定义代理"))
        } footer: {
            Text(proxyConfigurationError ?? String(localized: "仅代理 Pixiv 的 API、图片和导出下载；密码保存在系统钥匙串。"))
        }
    }

    private var networkModeDescription: String {
        if selectedNetworkMode == .customProxy,
           networkModeStore.currentMode != .customProxy {
            return String(localized: "填写代理配置后点击“保存并启用代理”生效。")
        }
        return selectedNetworkMode.description
    }

    private func selectNetworkMode(_ mode: NetworkMode) {
        guard mode == .customProxy else {
            proxyConfigurationError = nil
            networkModeStore.setMode(mode)
            return
        }

        guard networkModeStore.hasUsableCustomProxyConfiguration else {
            proxyConfigurationError = String(localized: "请填写代理配置并选择“保存并启用代理”")
            return
        }

        proxyConfigurationError = nil
        networkModeStore.setMode(.customProxy)
    }

    private func saveCustomProxyConfiguration() {
        guard let port = Int(proxyPort) else {
            proxyConfigurationError = String(localized: "代理端口必须在 1 到 65535 之间")
            return
        }

        do {
            try networkModeStore.saveCustomProxyConfiguration(
                CustomProxyConfiguration(
                    protocolType: proxyProtocol,
                    host: proxyHost,
                    port: port,
                    username: proxyUsername
                ),
                password: proxyPassword
            )
            selectedNetworkMode = .customProxy
            proxyConfigurationError = nil
        } catch {
            proxyConfigurationError = error.localizedDescription
        }
    }

    private var downloadSection: some View {
        Section {
            LabeledContent(String(localized: "下载线程数")) {
                Picker("", selection: $userSettingStore.userSetting.downloadConcurrency) {
                    ForEach([1, 2, 4, 8, 12, 16], id: \.self) { count in
                        Text("\(count)")
                            .tag(count)
                    }
                }
                #if os(macOS)
                .pickerStyle(.menu)
                #endif
            }
        } header: {
            Text(String(localized: "下载"))
        } footer: {
            Text(String(localized: "动图等多线程加载时的并发分片数。"))
        }
    }
}

#Preview {
    NavigationStack {
        NetworkSettingsView()
    }
}
