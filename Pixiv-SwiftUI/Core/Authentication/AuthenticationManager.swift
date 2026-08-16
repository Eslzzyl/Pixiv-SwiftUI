import Foundation
import AuthenticationServices
import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
        #if os(iOS) || os(macOS)
        guard presentationWindow() != nil else {
            throw AppError.authenticationError("没有可用于显示登录页面的应用窗口")
        }
        #endif

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
        guard let window = presentationWindow() else {
            preconditionFailure("ASWebAuthenticationSession requires a visible application window")
        }
        return window
        #elseif os(macOS)
        guard let window = presentationWindow() else {
            preconditionFailure("ASWebAuthenticationSession requires a visible application window")
        }
        return window
        #else
        return ASPresentationAnchor()
        #endif
    }
}

#if os(iOS)
private extension AuthenticationManager {
    func presentationWindow() -> UIWindow? {
        let activeWindowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }

        return activeWindowScenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })
            ?? activeWindowScenes
                .flatMap(\.windows)
                .first(where: { !$0.isHidden && $0.alpha > 0 })
    }
}
#elseif os(macOS)
private extension AuthenticationManager {
    func presentationWindow() -> NSWindow? {
        let application = NSApplication.shared
        return application.keyWindow
            ?? application.mainWindow
            ?? application.windows.first(where: { $0.isVisible && $0.canBecomeKey })
            ?? application.windows.first(where: \.isVisible)
    }
}
#endif
