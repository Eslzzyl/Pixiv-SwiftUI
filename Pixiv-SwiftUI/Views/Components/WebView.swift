import SwiftUI
import WebKit

#if os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#else
typealias ViewRepresentable = UIViewRepresentable
#endif

struct WebView: View {
    let url: URL
    let onRedirect: (URL) -> Void
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        ZStack {
            Color.white.edgesIgnoringSafeArea(.all) // 确保有背景色
            
            WebViewRepresentable(url: url, onRedirect: onRedirect, isLoading: $isLoading, error: $error)
                .frame(maxWidth: .infinity, maxHeight: .infinity) // 确保占满空间
            
            if isLoading {
                VStack {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.blue)
                    Text("正在加载...")
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.8))
            }
            
            if let error = error {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("加载失败")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
            }
        }
    }
}

struct WebViewRepresentable: ViewRepresentable {
    let url: URL
    let onRedirect: (URL) -> Void
    @Binding var isLoading: Bool
    @Binding var error: Error?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    #if os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }
    #else
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op
        context.coordinator.parent = self
    }
    #endif

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                if url.scheme == "pixiv" {
                    parent.onRedirect(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.error = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.error = error
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.error = error
        }
    }
}
