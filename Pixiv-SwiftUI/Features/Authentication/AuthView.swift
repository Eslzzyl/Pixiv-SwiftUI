import SwiftUI
import WebKit

#if os(macOS)
private typealias AuthWebViewRepresentable = NSViewRepresentable
#else
private typealias AuthWebViewRepresentable = UIViewRepresentable
#endif

/// 登录页面
struct AuthView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) var themeManager
    @State private var refreshToken: String = ""
    @State private var phpSessId: String = ""
    @State private var loginWebViewItem: LoginWebViewItem?
    @State private var showingWebLoginError = false
    @State private var webLoginErrorMessage = ""
    @SceneStorage("pixiv.pendingWebLogin.url") private var pendingWebLoginURL = ""
    @SceneStorage("pixiv.pendingWebLogin.codeVerifier") private var pendingWebLoginCodeVerifier = ""
    @SceneStorage("pixiv.pendingWebLogin.startedAt") private var pendingWebLoginStartedAt: Double = 0
    @FocusState private var focusedField: AuthField?
    @Bindable var accountStore: AccountStore
    var onGuestMode: (() -> Void)?

    private enum AuthField: Hashable {
        case refreshToken
        case phpSessId
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    themeManager.currentColor.opacity(0.1),
                    Color.purple.opacity(0.1),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(themeManager.currentColor)
                            .accessibilityHidden(true)

                        Text("Pixiv-SwiftUI")
                            .font(.largeTitle.weight(.bold))

                        Text("登录后可使用收藏、关注和动态等功能")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 48)

                    unifiedLoginView

                    if let error = accountStore.error {
                        Spacer(minLength: 24)

                        Label {
                            Text(error.localizedDescription)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.red.opacity(0.1), in: .rect(cornerRadius: 8))
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        #if os(macOS)
        .frame(minWidth: 450, idealWidth: 450, minHeight: 600, idealHeight: 660)
        #endif
        .sheet(item: $loginWebViewItem) { item in
                #if os(macOS)
                LoginWebView(
                    url: item.url,
                    onCallback: { code, cookies in
                        handleLoginCallback(code: code, cookies: cookies, verifier: item.codeVerifier)
                    },
                    onError: handleWebLoginError
                )
                .frame(width: 800, height: 600)
                #else
                NavigationStack {
                    LoginWebView(
                        url: item.url,
                        onCallback: { code, cookies in
                            handleLoginCallback(code: code, cookies: cookies, verifier: item.codeVerifier)
                        },
                        onError: handleWebLoginError
                    )
                    .navigationTitle("登录 Pixiv")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                cancelWebLogin()
                            }
                        }
                    }
                }
                #endif
            }
        .alert("网页登录失败", isPresented: $showingWebLoginError) {
            Button("确定", role: .cancel) { }
            Button("重新登录") {
                startWebLogin()
            }
        } message: {
            Text(webLoginErrorMessage)
        }
        .onAppear {
            restorePendingWebLoginIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                restorePendingWebLoginIfNeeded()
            }
        }
    }

    var unifiedLoginView: some View {
        VStack(spacing: 24) {
            Button(action: startWebLogin) {
                Text("通过网页登录（推荐）")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))

            HStack {
                VStack { Divider().background(Color.gray) }
                Text("或")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                VStack { Divider().background(Color.gray) }
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("刷新令牌", systemImage: "key.fill")
                        .font(.subheadline.weight(.semibold))

                    SecureField("输入您的 refresh_token（必填）", text: $refreshToken)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .refreshToken)
                        .onSubmit {
                            focusedField = .phpSessId
                        }
                        .authCredentialFieldStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label("网页登录凭证", systemImage: "safari.fill")
                        .font(.subheadline.weight(.semibold))

                    SecureField("输入您的 PHPSESSID（可选）", text: $phpSessId)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .phpSessId)
                        .onSubmit {
                            loginWithToken()
                        }
                        .authCredentialFieldStyle()

                    Text("推荐使用上方的网页登录；不确定时可以留空。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: loginWithToken) {
                ZStack {
                    if accountStore.isLoading {
                        ProgressView()
                            .tint(themeManager.currentColor)
                    } else {
                        Text("登录并进入应用")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(themeManager.currentColor)
            .disabled(refreshToken.isEmpty || accountStore.isLoading)
        }
    }

    func startWebLogin() {
        let verifier = PKCEHelper.generateCodeVerifier()
        pendingWebLoginCodeVerifier = verifier
        pendingWebLoginStartedAt = Date().timeIntervalSince1970
        let codeChallenge = PKCEHelper.generateCodeChallenge(codeVerifier: verifier)
        let urlString = "https://app-api.pixiv.net/web/v1/login?code_challenge=\(codeChallenge)&code_challenge_method=S256&client=pixiv-android"
        guard let url = URL(string: urlString) else {
            clearPendingWebLogin()
            return
        }

        pendingWebLoginURL = url.absoluteString
        self.loginWebViewItem = LoginWebViewItem(url: url, codeVerifier: verifier)
    }

    func handleLoginCallback(code: String, cookies: [HTTPCookie], verifier itemVerifier: String? = nil) {
        let verifier = itemVerifier ?? pendingWebLoginCodeVerifier
        guard !verifier.isEmpty else {
            handleWebLoginError(AppError.authenticationError("登录状态已失效，请重新开始网页登录"))
            return
        }

        Task {
            // 登录 OAuth
            await accountStore.loginWithCode(code, codeVerifier: verifier)

            // 不能用 isLoggedIn 判断本次登录是否成功：添加账号时可能已有其他账号处于登录状态。
            if accountStore.error == nil {
                // 提取 .pixiv.net 下的 Cookie
                var phpSessId: String?
                var yuidB: String?
                var pAbDId: String?
                var pAbId: String?
                var pAbId2: String?

                for cookie in cookies where cookie.domain.contains("pixiv.net") {
                    switch cookie.name {
                    case "PHPSESSID":
                        // 取出包含 _ 的 PHPSESSID
                        if cookie.value.contains("_") {
                            phpSessId = cookie.value
                        }
                    case "yuid_b":
                        yuidB = cookie.value
                    case "p_ab_d_id":
                        pAbDId = cookie.value
                    case "p_ab_id":
                        pAbId = cookie.value
                    case "p_ab_id_2":
                        pAbId2 = cookie.value
                    default:
                        break
                    }
                }

                accountStore.updateCurrentAccountAjaxCookies(
                    phpSessId: phpSessId,
                    yuidB: yuidB,
                    pAbDId: pAbDId,
                    pAbId: pAbId,
                    pAbId2: pAbId2
                )

                clearPendingWebLogin()
                loginWebViewItem = nil
                dismiss()
            } else if let error = accountStore.error {
                handleWebLoginError(error)
            }
        }
    }

    func loginWithToken() {
        Task {
            await accountStore.loginWithRefreshToken(refreshToken)
            if accountStore.error == nil {
                if !phpSessId.isEmpty {
                    accountStore.updateCurrentAccountAjaxCookies(
                        phpSessId: phpSessId,
                        yuidB: nil,
                        pAbDId: nil,
                        pAbId: nil,
                        pAbId2: nil
                    )
                }
                dismiss()
            }
        }
    }

    private func restorePendingWebLoginIfNeeded() {
        guard loginWebViewItem == nil else { return }

        let age = Date().timeIntervalSince1970 - pendingWebLoginStartedAt
        guard !pendingWebLoginURL.isEmpty,
              !pendingWebLoginCodeVerifier.isEmpty,
              pendingWebLoginStartedAt > 0,
              age < 15 * 60,
              let url = URL(string: pendingWebLoginURL) else {
            if !pendingWebLoginURL.isEmpty || !pendingWebLoginCodeVerifier.isEmpty {
                clearPendingWebLogin()
            }
            return
        }

        loginWebViewItem = LoginWebViewItem(url: url, codeVerifier: pendingWebLoginCodeVerifier)
    }

    private func clearPendingWebLogin() {
        pendingWebLoginURL = ""
        pendingWebLoginCodeVerifier = ""
        pendingWebLoginStartedAt = 0
    }

    private func cancelWebLogin() {
        loginWebViewItem = nil
        clearPendingWebLogin()
    }

    private func handleWebLoginError(_ error: Error) {
        loginWebViewItem = nil
        clearPendingWebLogin()
        webLoginErrorMessage = error.localizedDescription
        showingWebLoginError = true
    }

    func finishAndEnterHome() {
        accountStore.markLoginAttempted()
        dismiss()
    }
}

private extension View {
    @ViewBuilder
    func authCredentialFieldStyle() -> some View {
        #if os(macOS)
        textFieldStyle(.roundedBorder)
            .controlSize(.large)
        #else
        textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: 10))
        #endif
    }
}

#Preview {
    AuthView(accountStore: .shared)
}
