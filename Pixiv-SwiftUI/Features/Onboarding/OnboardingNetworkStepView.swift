import SwiftUI

/// 向导步骤 2：网络模式配置与连通性测试
struct OnboardingNetworkStepView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var networkModeStore = NetworkModeStore.shared
    @State private var selectedMode: NetworkMode = NetworkModeStore.shared.currentMode
    @State private var proxyHost: String = NetworkModeStore.shared.customProxyConfiguration?.host ?? ""
    @State private var proxyPort: String = NetworkModeStore.shared.customProxyConfiguration.map { String($0.port) } ?? ""
    @State private var proxyError: String?

    @State private var isTesting = false
    @State private var latencyMs: Int?
    @State private var pingFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            headerSection

            optionsList

            if selectedMode == .customProxy {
                customProxyForm
            }

            pingStatusRow
        }
        .frame(maxWidth: 580)
        .onAppear {
            selectedMode = networkModeStore.currentMode
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "网络连接"))
                .font(.title2.weight(.bold))
                .foregroundStyle(.primary)

            Text(String(localized: "选择适合当前网络环境的连接方式。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var optionsList: some View {
        VStack(spacing: 10) {
            modeCard(
                mode: .direct,
                title: String(localized: "HTTP/3 直连"),
                subtitle: String(localized: "无需代理，国内网络直接连接。"),
                badge: String(localized: "推荐")
            )

            modeCard(
                mode: .normal,
                title: String(localized: "系统代理 / VPN"),
                subtitle: String(localized: "走系统全局代理或 VPN。"),
                badge: nil
            )

            modeCard(
                mode: .customProxy,
                title: String(localized: "自定义代理"),
                subtitle: String(localized: "手动指定本地或局域网代理服务器。"),
                badge: nil
            )
        }
    }

    private func modeCard(
        mode: NetworkMode,
        title: String,
        subtitle: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedMode == mode

        return Button {
            selectedMode = mode
            if mode != .customProxy {
                networkModeStore.setMode(mode)
                proxyError = nil
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? themeManager.currentColor : Color.secondary.opacity(0.4))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeManager.currentColor.opacity(0.12))
                                .foregroundStyle(themeManager.currentColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? themeManager.currentColor.opacity(0.06) : Color.primary.opacity(0.03))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        isSelected ? themeManager.currentColor.opacity(0.4) : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var customProxyForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                TextField(String(localized: "主机地址（如 127.0.0.1）"), text: $proxyHost)
                    .textFieldStyle(.roundedBorder)

                TextField(String(localized: "端口（如 7890）"), text: $proxyPort)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)

                Button(String(localized: "保存并启用")) {
                    saveCustomProxy()
                }
                .buttonStyle(.bordered)
            }

            if let error = proxyError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var pingStatusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(pingDotColor)
                .frame(width: 8, height: 8)

            Text(pingDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()

            Button(isTesting ? String(localized: "测试中...") : String(localized: "测试连接")) {
                Task { @MainActor in
                    await testConnection()
                }
            }
            .buttonStyle(.borderless)
            .font(.footnote)
            .disabled(isTesting)
        }
        .padding(.horizontal, 4)
    }

    private var pingDotColor: Color {
        if isTesting {
            return .orange
        }
        if pingFailed {
            return .red
        }
        if let latency = latencyMs {
            return latency < 800 ? .green : .orange
        }
        return .secondary
    }

    private var pingDescription: String {
        if isTesting {
            return String(localized: "正在测试连接...")
        }
        if pingFailed {
            return String(localized: "连接失败，建议切换连接方式")
        }
        if let latency = latencyMs {
            return String(localized: "Pixiv 连通正常 (\(latency) ms)")
        }
        return String(localized: "未测试连接")
    }

    @MainActor
    private func testConnection() async {
        guard !isTesting else { return }
        isTesting = true
        pingFailed = false
        latencyMs = nil
        do {
            let latency = try await NetworkClient.shared.testPixivConnection()
            latencyMs = latency
            pingFailed = false
        } catch {
            pingFailed = true
        }
        isTesting = false
    }

    private func saveCustomProxy() {
        guard let port = Int(proxyPort), (1...65535).contains(port) else {
            proxyError = String(localized: "端口号必须在 1 到 65535 之间")
            return
        }

        do {
            try networkModeStore.saveCustomProxyConfiguration(
                CustomProxyConfiguration(
                    protocolType: .httpConnect,
                    host: proxyHost,
                    port: port,
                    username: ""
                ),
                password: ""
            )
            proxyError = nil
            networkModeStore.setMode(.customProxy)
        } catch {
            proxyError = error.localizedDescription
        }
    }
}

#Preview {
    OnboardingNetworkStepView()
        .padding()
        .frame(width: 600)
        .environment(ThemeManager.shared)
}
