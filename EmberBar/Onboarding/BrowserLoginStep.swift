import SwiftUI
import WebKit

// MARK: - Browser Login Step

/// Tier-1 onboarding: embed claude.ai in a WKWebView and automatically detect
/// the session cookie once the user logs in. No DevTools or copy-paste required.
struct BrowserLoginStep: View {
    @ObservedObject var appState: AppState
    let onSuccess: () -> Void
    let onManualFallback: () -> Void

    @State private var statusMessage: String?
    @State private var isConnecting = false
    @State private var isError = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 5) {
                Text("Sign in to Claude")
                    .font(.system(size: 18, weight: .bold))
                Text("Enter your email address below to sign in.\nGoogle sign-in is not supported in this window.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)
            .padding(.bottom, 10)

            ClaudeWebView(
                appState: appState,
                onCookieDetected: { cookie in
                    guard !isConnecting else { return }
                    isConnecting = true
                    isError = false
                    statusMessage = "Session detected — connecting…"
                    Task { @MainActor in
                        let result = await appState.validateAndSaveCookie(cookie)
                        isConnecting = false
                        switch result {
                        case .success:
                            onSuccess()
                        case .failure(let error):
                            isError = true
                            statusMessage = error.localizedDescription
                        }
                    }
                }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            .padding(.horizontal, 16)

            Group {
                if let msg = statusMessage {
                    HStack(spacing: 6) {
                        if isConnecting {
                            ProgressView().controlSize(.small)
                        } else if isError {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
                        } else {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        }
                        Text(msg)
                            .font(.system(size: 12))
                            .foregroundColor(isError ? .red : .secondary)
                    }
                    .padding(.top, 8)
                } else {
                    Color.clear.frame(height: 8)
                }
            }

            Button("Enter cookie manually instead") {
                onManualFallback()
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - WKWebView wrapper

private struct ClaudeWebView: NSViewRepresentable {
    @ObservedObject var appState: AppState
    let onCookieDetected: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator

        let cookieStore = wv.configuration.websiteDataStore.httpCookieStore
        cookieStore.add(context.coordinator)
        context.coordinator.cookieStore = cookieStore

        // Clear existing claude.ai cookies so the user sees the login page
        // (prevents auto-login from a previous session)
        cookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.domain.contains("claude.ai") {
                cookieStore.delete(cookie)
            }
            // Start polling and load login page after cookies are cleared
            DispatchQueue.main.async {
                context.coordinator.startPolling()
                if let url = URL(string: "https://claude.ai/login") {
                    wv.load(URLRequest(url: url))
                }
            }
        }
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCookieDetected: onCookieDetected)
    }

    // MARK: Coordinator
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        let onCookieDetected: (String) -> Void
        var cookieStore: WKHTTPCookieStore?
        private var detected = false
        private var pollTimer: Timer?

        init(onCookieDetected: @escaping (String) -> Void) {
            self.onCookieDetected = onCookieDetected
        }

        deinit {
            pollTimer?.invalidate()
        }

        /// Start a repeating timer that checks for the session cookie every 2 seconds.
        /// cookiesDidChange is unreliable for cookies set during OAuth redirects.
        func startPolling() {
            guard pollTimer == nil else { return }
            pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.checkForSessionCookie()
            }
        }

        private func checkForSessionCookie() {
            guard !detected, let cookieStore else { return }
            cookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.detected else { return }
                guard let session = cookies.first(where: {
                    $0.name == "sessionKey" && $0.value.hasPrefix("sk-ant-sid")
                    && ($0.domain == "claude.ai" || $0.domain == ".claude.ai")
                }) else { return }

                self.detected = true
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                let cookieString = "sessionKey=\(session.value)"
                DispatchQueue.main.async {
                    self.onCookieDetected(cookieString)
                }
            }
        }

        // Cookie observer — fires on some cookie changes but not reliably during OAuth
        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            checkForSessionCookie()
        }

        // Also check after every page finishes loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            checkForSessionCookie()
        }

        // Only allow navigation to claude.ai and anthropic.com domains
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let host = navigationAction.request.url?.host else {
                decisionHandler(.allow)
                return
            }
            let allowed = host == "claude.ai" || host.hasSuffix(".claude.ai")
                || host == "anthropic.com" || host.hasSuffix(".anthropic.com")
            decisionHandler(allowed ? .allow : .cancel)
        }

        // Handle popup windows — load in main WebView if allowed domain, otherwise block
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let host = navigationAction.request.url?.host,
               host == "claude.ai" || host.hasSuffix(".claude.ai")
                || host == "anthropic.com" || host.hasSuffix(".anthropic.com") {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
