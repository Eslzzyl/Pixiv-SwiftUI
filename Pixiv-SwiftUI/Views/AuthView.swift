import SwiftUI

/// 登录页面
struct AuthView: View {
    @State private var refreshToken: String = ""
    @State private var showingError = false
    @State private var webViewData: WebViewData?
    @State private var codeVerifier: String = ""
    @State private var loginMode: LoginMode = .main
    @Bindable var accountStore: AccountStore

    struct WebViewData: Identifiable {
        let id = UUID()
        let url: URL
    }

    enum LoginMode {
        case main
        case token
    }

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.1),
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
                        .foregroundColor(.blue)

                    Text("Pixiv")
                        .font(.system(size: 36, weight: .bold))

                    Text("优雅的插画社区客户端")
                        .font(.callout)
                        .foregroundColor(.gray)
                }

                Spacer()

                if loginMode == .main {
                    mainLoginView
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    tokenLoginView
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }

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
            .sheet(item: $webViewData) { data in
                WebView(url: data.url) { redirectURL in
                    handleRedirect(url: redirectURL)
                }
            }
        }
    }

    var mainLoginView: some View {
        VStack(spacing: 20) {
            Button(action: startWebLogin) {
                Text("登录")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: .blue))

            Button(action: { withAnimation { loginMode = .token } }) {
                Text("使用 Token 登录")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: nil))
        }
    }

    var tokenLoginView: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("刷新令牌", systemImage: "key.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                SecureField("输入您的 refresh_token", text: $refreshToken)
                    .padding(12)
                    .background {
                        if #available(iOS 18.0, macOS 15.0, visionOS 1.0, *) {
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
                        Text("登录")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(GlassButtonStyle(color: .blue))
            .disabled(refreshToken.isEmpty || accountStore.isLoading)
            
            Button(action: { withAnimation { loginMode = .main } }) {
                Text("返回")
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
        if let url = URL(string: urlString) {
            webViewData = WebViewData(url: url)
        }
    }

    func handleRedirect(url: URL) {
        webViewData = nil
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return
        }
        
        Task {
            await accountStore.loginWithCode(code, codeVerifier: codeVerifier)
        }
    }

    func loginWithToken() {
        Task {
            await accountStore.loginWithRefreshToken(refreshToken)
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    var color: Color? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color != nil ? .white : .primary)
            .background {
                if #available(iOS 18.0, macOS 15.0, visionOS 1.0, *) {
                    if let color = color {
                        Capsule()
                            .fill(color)
                            .glassEffect(in: .capsule)
                    } else {
                        Capsule()
                            .fill(.clear)
                            .glassEffect(in: .capsule)
                    }
                } else {
                    if let color = color {
                        Capsule()
                            .fill(color)
                            .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring, value: configuration.isPressed)
    }
}
#Preview {
    AuthView(accountStore: .shared)
}
