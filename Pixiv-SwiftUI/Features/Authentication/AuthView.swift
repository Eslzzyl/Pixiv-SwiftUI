import SwiftUI

/// 登录页面
struct AuthView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) var themeManager
    @State private var refreshToken: String = ""
    @State private var showingError = false
    @State private var codeVerifier: String = ""
    @State private var loginMode: LoginMode = .main
    @Bindable var accountStore: AccountStore
    var onGuestMode: (() -> Void)?

    enum LoginMode {
        case main
        case token
    }

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    themeManager.currentColor.opacity(0.1),
                    Color.purple.opacity(0.1),
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // 标题
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(themeManager.currentColor)

                    Text(String(localized: "Pixiv-SwiftUI"))
                        .font(.system(size: 36, weight: .bold))

                    Text(String(localized: "优雅的插画社区客户端"))
                        .font(.callout)
                        .foregroundColor(.gray)
                }

                Spacer()

                ZStack {
                    if loginMode == .main {
                        mainLoginView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .leading)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    } else {
                        tokenLoginView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .trailing))
                            ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: loginMode)

                Spacer()

                // 错误提示
                if let error = accountStore.error {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error.localizedDescription)
                    }
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(32)
        }
        #if os(macOS)
        .frame(width: 450, height: 600)
        #endif
    }

    var mainLoginView: some View {
        VStack(spacing: 20) {
            Button(action: startWebLogin) {
                Text(String(localized: "登录"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    loginMode = .token
                }
            }) {
                Text(String(localized: "使用 Token 登录"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: nil))

            if onGuestMode != nil {
                Divider()

                Button(action: { onGuestMode?() }) {
                    Text(String(localized: "以游客身份浏览"))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    var tokenLoginView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
Label(String(localized: "刷新令牌"), systemImage: "key.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                SecureField(String(localized: "输入您的 refresh_token"), text: $refreshToken)
                    .padding(12)
                    .background {
                        if #available(iOS 26.0, macOS 26.0, *) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.clear)
                                .glassEffect(in: .rect(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
            }

            Button(action: loginWithToken) {
                ZStack {
                    if accountStore.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(String(localized: "登录"))
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: themeManager.currentColor))
            .disabled(refreshToken.isEmpty || accountStore.isLoading)

            Button(action: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    loginMode = .main
                }
            }) {
                Text(String(localized: "返回"))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: nil))
        }
    }

    func startWebLogin() {
        codeVerifier = PKCEHelper.generateCodeVerifier()
        let codeChallenge = PKCEHelper.generateCodeChallenge(codeVerifier: codeVerifier)
        let urlString = "https://app-api.pixiv.net/web/v1/login?code_challenge=\(codeChallenge)&code_challenge_method=S256&client=pixiv-android"
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let callbackURL = try await AuthenticationManager.shared.startLogin(url: url, callbackScheme: "pixiv")
                if let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                   let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                    await accountStore.loginWithCode(code, codeVerifier: codeVerifier)
                    if accountStore.isLoggedIn {
                        accountStore.markLoginAttempted()
                        dismiss()
                    }
                }
            } catch is CancellationError {
                // 用户取消，无需处理
            } catch {
                // 处理其他错误
                print("登录失败: \(error)")
            }
        }
    }

    func loginWithToken() {
        Task {
            await accountStore.loginWithRefreshToken(refreshToken)
            if accountStore.isLoggedIn {
                accountStore.markLoginAttempted()
                dismiss()
            }
        }
    }
}
#Preview {
    AuthView(accountStore: .shared)
}
