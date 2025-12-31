import SwiftUI

/// 登录页面
struct AuthView: View {
    @State private var refreshToken: String = ""
    @State private var showingError = false
    @Bindable var accountStore: AccountStore

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

                // 登录表单
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("刷新令牌", systemImage: "key.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        SecureField("输入您的 refresh_token", text: $refreshToken)
                            .padding(12)
                            .cornerRadius(12)
                    }

                    // 提示文字
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .font(.footnote)
                            .foregroundColor(.blue)

                        Text("从Pixiv官方应用获取您的刷新令牌")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()

                // 登录按钮
                Button(action: login) {
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
                .foregroundColor(.white)
                .background(
                    refreshToken.isEmpty ? Color.gray : Color.blue
                )
                .cornerRadius(12)
                .disabled(refreshToken.isEmpty || accountStore.isLoading)

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
    }

    /// 执行登录
    private func login() {
        Task {
            await accountStore.loginWithRefreshToken(refreshToken)
        }
    }
}

#Preview {
    AuthView(accountStore: AccountStore())
}
