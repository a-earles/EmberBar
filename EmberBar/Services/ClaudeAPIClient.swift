import Foundation
import ObjectiveC
import WebKit

private var navDelegateKey: UInt8 = 0

enum APIError: Error, LocalizedError {
    case noCookie
    case invalidCookie
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case noOrganization
    case cloudflareChallenge
    case timeout

    var errorDescription: String? {
        switch self {
        case .noCookie: return "No session cookie configured"
        case .invalidCookie: return "Session cookie is invalid or expired"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code): return "Server returned status \(code)"
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .noOrganization: return "No organization found"
        case .cloudflareChallenge: return "Cloudflare challenge encountered — please refresh your cookie"
        case .timeout: return "Request timed out"
        }
    }
}

/// Uses a hidden WKWebView to fetch data from claude.ai, bypassing Cloudflare challenges.
/// WKWebView can execute JavaScript and solve Cloudflare's bot detection automatically.
@MainActor
class ClaudeAPIClient {
    private var webView: WKWebView?

    init() {}

    private func getOrCreateWebView(cookie: String) -> WKWebView {
        if let existing = webView { return existing }

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        let wv = WKWebView(frame: .zero, configuration: config)
        webView = wv

        // Inject cookies into the web view
        setCookies(on: wv, cookieString: cookie)

        return wv
    }

    private func setCookies(on webView: WKWebView, cookieString: String) {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        let pairs = cookieString.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }

        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let name = String(parts[0])
            let value = String(parts[1])

            let properties: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: ".claude.ai",
                .path: "/",
                .secure: true,
            ]

            if let cookie = HTTPCookie(properties: properties) {
                cookieStore.setCookie(cookie)
            }
        }
    }

    /// Fetches JSON from a URL using WKWebView to handle Cloudflare challenges.
    private func fetchJSON(url: URL, cookie: String) async throws -> Data {
        let wv = getOrCreateWebView(cookie: cookie)

        // Inject cookies fresh each time in case they've been updated
        setCookies(on: wv, cookieString: cookie)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = WebViewNavigationDelegate(continuation: continuation)
            wv.navigationDelegate = delegate

            // Hold a strong reference to the delegate
            objc_setAssociatedObject(wv, &navDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN)

            let request = URLRequest(url: url, timeoutInterval: 30)
            wv.load(request)

            // Timeout after 30 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak wv] in
                guard let wv = wv else { return }
                let del = objc_getAssociatedObject(wv, &navDelegateKey) as? WebViewNavigationDelegate
                del?.timeoutIfNeeded()
            }
        }
    }

    func fetchOrganizations(cookie: String) async throws -> [Organization] {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            throw APIError.invalidCookie
        }

        let data = try await fetchJSON(url: url, cookie: cookie)

        do {
            return try JSONDecoder().decode([Organization].self, from: data)
        } catch {
            // Check if we got HTML instead of JSON (Cloudflare challenge)
            if let text = String(data: data, encoding: .utf8), text.contains("Just a moment") {
                throw APIError.cloudflareChallenge
            }
            #if DEBUG
            print("[EmberBar] Decode error for orgs: \(error)")
            print("[EmberBar] Response: \(String(data: data.prefix(500), encoding: .utf8) ?? "nil")")
            #endif
            throw APIError.decodingError(error)
        }
    }

    func fetchUsage(cookie: String, orgId: String) async throws -> UsageResponse {
        // Validate orgId is a UUID to prevent URL injection
        guard orgId.range(of: #"^[0-9a-fA-F\-]{36}$"#, options: .regularExpression) != nil,
              let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw APIError.invalidResponse(0)
        }

        let data = try await fetchJSON(url: url, cookie: cookie)

        // Empty response = session likely expired
        guard !data.isEmpty else {
            throw APIError.invalidCookie
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            if let text = String(data: data, encoding: .utf8) {
                if text.contains("Just a moment") {
                    throw APIError.cloudflareChallenge
                }
                // If we got HTML or non-JSON, the cookie is likely expired
                if text.hasPrefix("<") || text.hasPrefix("<!") {
                    throw APIError.invalidCookie
                }
            }
            #if DEBUG
            print("[EmberBar] Decode error for usage: \(error)")
            print("[EmberBar] Response (\(data.count) bytes): \(String(data: data.prefix(500), encoding: .utf8) ?? "nil")")
            #endif
            throw APIError.decodingError(error)
        }
    }

    func validateCookie(_ cookie: String) async throws -> (orgId: String, orgName: String) {
        let orgs = try await fetchOrganizations(cookie: cookie)
        guard let org = orgs.first else {
            throw APIError.noOrganization
        }
        return (org.uuid, org.name ?? "Personal")
    }

    /// Reset the web view (e.g., when cookie changes)
    func reset() {
        webView?.stopLoading()
        webView = nil
    }
}

// MARK: - WKWebView Navigation Delegate

private class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Data, Error>?
    private var hasResumed = false

    init(continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func timeoutIfNeeded() {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: APIError.timeout)
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasResumed else { return }

        // Verify we're still on claude.ai (prevent redirect-based attacks)
        guard let finalURL = webView.url, finalURL.host?.hasSuffix("claude.ai") == true else {
            hasResumed = true
            continuation?.resume(throwing: APIError.invalidResponse(0))
            continuation = nil
            return
        }

        // Extract the page content (should be JSON for API endpoints)
        webView.evaluateJavaScript("document.body.innerText") { [weak self] result, error in
            guard let self = self, !self.hasResumed else { return }
            self.hasResumed = true

            if let error = error {
                self.continuation?.resume(throwing: APIError.networkError(error))
                self.continuation = nil
                return
            }

            guard let text = result as? String, !text.isEmpty else {
                self.continuation?.resume(throwing: APIError.invalidResponse(0))
                self.continuation = nil
                return
            }

            // Check for Cloudflare challenge page — retry with increasing delays
            if text.contains("Just a moment") || text.contains("Enable JavaScript") {
                self.retryAfterCloudflare(webView: webView, attempt: 1)
                return
            }

            self.continuation?.resume(returning: Data(text.utf8))
            self.continuation = nil
        }
    }

    /// Retry extracting content after Cloudflare challenge, up to 5 attempts with increasing delays
    private func retryAfterCloudflare(webView: WKWebView, attempt: Int) {
        guard !hasResumed else { return }
        let maxAttempts = 5
        let delay = Double(attempt) * 2.0 // 2s, 4s, 6s, 8s, 10s

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, !self.hasResumed else { return }

            webView.evaluateJavaScript("document.body.innerText") { result, _ in
                guard !self.hasResumed else { return }

                if let text = result as? String,
                   !text.isEmpty,
                   !text.contains("Just a moment"),
                   !text.contains("Enable JavaScript") {
                    self.hasResumed = true
                    self.continuation?.resume(returning: Data(text.utf8))
                    self.continuation = nil
                } else if attempt < maxAttempts {
                    self.retryAfterCloudflare(webView: webView, attempt: attempt + 1)
                } else {
                    self.hasResumed = true
                    self.continuation?.resume(throwing: APIError.cloudflareChallenge)
                    self.continuation = nil
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: APIError.networkError(error))
        continuation = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation?.resume(throwing: APIError.networkError(error))
        continuation = nil
    }
}
