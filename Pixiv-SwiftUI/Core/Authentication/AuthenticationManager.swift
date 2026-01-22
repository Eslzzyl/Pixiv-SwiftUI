import Foundation
import AuthenticationServices
import SwiftUI

/// 认证管理器，负责处理基于 ASWebAuthenticationSession 的 OAuth 流程
@MainActor
final class AuthenticationManager: NSObject {
    static let shared = AuthenticationManager()
    
    private var session: ASWebAuthenticationSession?
    
    /// 开启 Web 登录流程
    /// - Parameters:
    ///   - url: 登录 URL
    ///   - callbackScheme: 自定义回调协议名 (例如 "pixiv")
    /// - Returns: 返回重定向后的完整 URL
    func startLogin(url: URL, callbackScheme: String) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError, authError.code == .canceledLogin {
                        // 用户取消登录不抛出严重的错误流，可以根据业务需求处理
                        continuation.resume(throwing: CancellationError())
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: AppError.authenticationError("未获取到回调 URL"))
                    return
                }
                
                continuation.resume(returning: callbackURL)
            }
            
            session.presentationContextProvider = self
            // 允许使用 Safari 的 Cookie，增强体验
            session.prefersEphemeralWebBrowserSession = false
            
            self.session = session
            session.start()
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first { $0.isKeyWindow } ?? UIWindow()
        #elseif os(macOS)
        return NSApplication.shared.keyWindow ?? NSWindow()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
