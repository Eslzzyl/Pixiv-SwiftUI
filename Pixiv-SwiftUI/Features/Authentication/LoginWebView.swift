import Foundation
import SwiftUI
import WebKit

#if os(macOS)
private typealias Representable = NSViewRepresentable
#else
private typealias Representable = UIViewRepresentable
#endif

/// Identifiable wrapper for login URL, used with .sheet(item:) to avoid state timing issues.
struct LoginWebViewItem: Identifiable {
    let id = UUID()
    let url: URL
    let codeVerifier: String?

    init(url: URL, codeVerifier: String? = nil) {
        self.url = url
        self.codeVerifier = codeVerifier
    }
}

struct LoginWebView: Representable {
    let url: URL
    let onCallback: (String, [HTTPCookie]) -> Void
    let onError: ((Error) -> Void)?

    init(
        url: URL,
        onCallback: @escaping (String, [HTTPCookie]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) {
        self.url = url
        self.onCallback = onCallback
        self.onError = onError
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }
    #endif

    private func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        // Keep the authentication session in WebKit's persistent store. A non-persistent
        // store loses its cookies when the view/process is recreated after backgrounding.
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // Setup user agent to simulate a mobile app? Or leave it default?
        // Let's just use the default

        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LoginWebView
        private var hasHandledCallback = false

        init(_ parent: LoginWebView) {
            self.parent = parent
        }

        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let isCustomCallback = url.scheme?.lowercased() == "pixiv"
            let isHTTPSCallback = url.host?.lowercased() == "app-api.pixiv.net"
                && url.path == "/web/v1/users/auth/pixiv/callback"

            if isCustomCallback || isHTTPSCallback {
                guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    decisionHandler(.cancel)
                    self.reportError(AppError.authenticationError("登录回调地址无效"))
                    return
                }

                if let error = components.queryItems?.first(where: { $0.name == "error" })?.value {
                    decisionHandler(.cancel)
                    self.reportError(AppError.authenticationError("网页登录失败：" + error))
                    return
                }

                if let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                    hasHandledCallback = true

                    // We found the code callback. Now fetch cookies.
                    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                        let pixivCookies = cookies.filter { $0.domain.contains("pixiv.net") }

                        DispatchQueue.main.async {
                            self?.parent.onCallback(code, pixivCookies)
                        }
                    }
                    decisionHandler(.cancel)
                    return
                }

                decisionHandler(.cancel)
                self.reportError(AppError.authenticationError("登录回调缺少授权 code"))
                return
            }

            decisionHandler(.allow)
        }

        @MainActor
        private func reportError(_ error: Error) {
            if hasHandledCallback {
                return
            }
            parent.onError?(error)
        }
    }
}
