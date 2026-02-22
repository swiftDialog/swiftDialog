//
//  PortalWebView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  WKWebView wrapper for self-service portal display (Preset5)
//  Supports optional authentication headers and offline caching
//

import SwiftUI
import WebKit

// MARK: - Download Constants

private let downloadableExtensions: Set<String> = [
    "mobileconfig", "pkg", "dmg", "zip", "tar", "gz", "pdf"
]
private let downloadableMIMETypes: Set<String> = [
    "application/x-apple-aspen-config",
    "application/octet-stream",
    "application/zip",
    "application/x-tar",
    "application/gzip",
    "application/pdf",
    "application/vnd.apple.installer+xml"
]

// MARK: - Load State

/// WebView load state
enum PortalLoadState: Equatable {
    case initializing       // Setting up
    case loading            // Content loading
    case loaded             // Content visible
    case error(String)      // Error with message
    case offline            // Viewing cached content

    static func == (lhs: PortalLoadState, rhs: PortalLoadState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.loading, .loading),
             (.loaded, .loaded),
             (.offline, .offline):
            return true
        case (.error(let l), .error(let r)):
            return l == r
        default:
            return false
        }
    }

    /// Icon to display for this state
    var errorIcon: String {
        return "wifi.exclamationmark"
    }

    /// Title for error state
    var errorTitle: String {
        return "Unable to Connect"
    }
}

// MARK: - PortalWebView

/// SwiftUI wrapper for WKWebView with optional authentication
struct PortalWebView: NSViewRepresentable {

    let url: URL
    var authHeaders: [String: String]?
    var customHeaders: [String: String]?  // Includes branding key and any user-defined headers
    var userAgent: String?
    var ephemeralSession: Bool = false
    var errorDetectionPhrases: [String] = []
    var errorDetectionThreshold: Int = 2
    var openExternalLinksInBrowser: Bool = true
    var onLoadStateChange: ((PortalLoadState) -> Void)?
    var onNavigationError: ((Error) -> Void)?

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        coordinator.portalHost = url.host
        coordinator.errorDetectionPhrases = errorDetectionPhrases
        coordinator.errorDetectionThreshold = errorDetectionThreshold
        coordinator.openExternalLinksInBrowser = openExternalLinksInBrowser
        return coordinator
    }

    func makeNSView(context: Context) -> WKWebView {
        writeLog("PortalWebView: makeNSView called - url=\(url)", logLevel: .debug)

        let configuration = WKWebViewConfiguration()

        // Enable JavaScript using modern API
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Configure data store (ephemeral or persistent)
        if ephemeralSession {
            configuration.websiteDataStore = .nonPersistent()
            writeLog("PortalWebView: Using non-persistent (ephemeral) data store", logLevel: .debug)
        } else {
            configuration.websiteDataStore = .default()
        }

        // Add script message handler if we need JS communication
        configuration.userContentController.add(context.coordinator, name: "portalMessage")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Set custom User-Agent if provided
        if let userAgent = userAgent {
            webView.customUserAgent = userAgent
            writeLog("PortalWebView: Using custom User-Agent: \(userAgent)", logLevel: .debug)
        }

        // Register cookie observer for debugging
        context.coordinator.observeCookies(store: configuration.websiteDataStore.httpCookieStore)

        // Set cookies for branding/auth before loading
        // WKWebView reliably sends cookies (unlike custom headers)
        setCookiesAndLoad(webView: webView, configuration: configuration)

        return webView
    }

    private func setCookiesAndLoad(webView: WKWebView, configuration: WKWebViewConfiguration) {
        let cookieStore = configuration.websiteDataStore.httpCookieStore
        let domain = url.host ?? "localhost"

        writeLog("PortalWebView: setCookiesAndLoad called, customHeaders=\(String(describing: customHeaders))", logLevel: .debug)

        // Build cookies from custom headers (headers become cookies)
        var cookiesToSet: [HTTPCookie] = []

        if let headers = customHeaders {
            for (name, value) in headers {
                // Build cookie properties - only include secure for https
                var properties: [HTTPCookiePropertyKey: Any] = [
                    .domain: domain,
                    .path: "/",
                    .name: name,
                    .value: value,
                    .expires: Date().addingTimeInterval(3600), // 1 hour
                    .sameSitePolicy: "none"  // Required for WKWebView cross-site
                ]

                // Only mark as secure if using HTTPS
                if url.scheme == "https" {
                    properties[.secure] = "TRUE"
                }

                if let cookie = HTTPCookie(properties: properties) {
                    cookiesToSet.append(cookie)
                    writeLog("PortalWebView: Created cookie \(name)=\(value) for domain \(domain) (SameSite=None)", logLevel: .debug)
                } else {
                    writeLog("PortalWebView: Failed to create cookie for \(name)", logLevel: .error)
                }
            }
        } else {
            writeLog("PortalWebView: No custom headers to convert to cookies", logLevel: .debug)
        }

        if cookiesToSet.isEmpty {
            writeLog("PortalWebView: No cookies to set, loading directly", logLevel: .debug)
            loadURL(webView: webView)
        } else {
            // Set cookies asynchronously, then load
            writeLog("PortalWebView: Setting \(cookiesToSet.count) cookies before loading", logLevel: .debug)
            let group = DispatchGroup()
            for cookie in cookiesToSet {
                group.enter()
                cookieStore.setCookie(cookie) {
                    group.leave()
                }
            }
            group.notify(queue: .main) { [self] in
                writeLog("PortalWebView: All \(cookiesToSet.count) cookies set, now loading URL", logLevel: .debug)
                loadURL(webView: webView)
            }
        }
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Don't reload a URL that just failed - prevents infinite loop on 403/401/etc.
        if context.coordinator.failedURL == url {
            return
        }

        // Reload if URL changes
        if webView.url != url {
            loadURL(webView: webView)
        }
    }

    private func loadURL(webView: WKWebView) {
        var request = URLRequest(url: url)

        // Add authentication headers if provided
        if let headers = authHeaders {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Add custom headers (branding key, etc.) if provided
        if let headers = customHeaders {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
                writeLog("PortalWebView: Adding custom header \(key): \(value)", logLevel: .debug)
            }
        }

        // Set cache policy
        request.cachePolicy = .returnCacheDataElseLoad

        onLoadStateChange?(.loading)
        webView.load(request)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKHTTPCookieStoreObserver, WKDownloadDelegate, WKUIDelegate {
        var parent: PortalWebView

        // Track URLs we've already injected headers for (to avoid infinite loops)
        private var pendingHeaderInjection: URL?

        // Reference to cookie store for observation
        weak var cookieStore: WKHTTPCookieStore?

        // Track the URL that failed to prevent infinite reload loops
        // (internal access to allow updateNSView to check before reloading)
        var failedURL: URL?

        // SSO flow tracking (Gap 2)
        private var ssoFlowActive = false
        var portalHost: String?

        // DOM error detection (Gap 3)
        var errorDetectionPhrases: [String] = []
        var errorDetectionThreshold: Int = 2

        // External link handling (Gap 4)
        var openExternalLinksInBrowser: Bool = true

        // Track whether initial page load completed (suppress loading overlay during SSO redirects)
        private var hasCompletedInitialLoad = false

        // Combined headers (auth + custom) for injection
        var headersToInject: [String: String] {
            var headers: [String: String] = [:]
            if let authHeaders = parent.authHeaders {
                headers.merge(authHeaders) { _, new in new }
            }
            if let customHeaders = parent.customHeaders {
                headers.merge(customHeaders) { _, new in new }
            }
            return headers
        }

        init(_ parent: PortalWebView) {
            self.parent = parent
        }

        deinit {
            cookieStore?.remove(self)
        }

        /// Start observing cookie changes
        func observeCookies(store: WKHTTPCookieStore) {
            self.cookieStore = store
            store.add(self)
            writeLog("PortalWebView: Cookie observer registered", logLevel: .debug)
        }

        // MARK: - WKHTTPCookieStoreObserver

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            // Log cookie changes for debugging
            cookieStore.getAllCookies { cookies in
                let cookieNames = cookies.map { $0.name }
                writeLog("PortalWebView: Cookies changed - count: \(cookies.count), names: \(cookieNames)", logLevel: .debug)
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            // Only show loading spinner before the first successful load.
            // After that, suppress it so SSO redirects don't flash the overlay
            // over already-visible content.
            if !hasCompletedInitialLoad {
                parent.onLoadStateChange?(.loading)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            hasReportedError = false  // Reset on successful load
            hasCompletedInitialLoad = true  // Suppress loading overlay for subsequent navigations
            failedURL = nil  // Clear failed URL on successful load

            // Reset SSO if we're back on the portal host
            if webView.url?.host == portalHost {
                ssoFlowActive = false
            }

            parent.onLoadStateChange?(.loaded)
            writeLog("PortalWebView: Content loaded for \(webView.url?.absoluteString ?? "unknown")", logLevel: .info)

            // DOM error detection (Gap 3)
            if !errorDetectionPhrases.isEmpty {
                let phraseChecks = errorDetectionPhrases.map { phrase in
                    let escaped = phrase.replacingOccurrences(of: "'", with: "\\'")
                    return "if (body.indexOf('\(escaped)') !== -1) errors++;"
                }.joined(separator: "\n")

                let js = """
                (function() {
                    var body = document.body ? document.body.innerText : '';
                    var errors = 0;
                    \(phraseChecks)
                    return errors >= \(errorDetectionThreshold) ? 'error' : 'ok';
                })();
                """
                webView.evaluateJavaScript(js) { [weak self] result, _ in
                    if let status = result as? String, status == "error" {
                        DispatchQueue.main.async {
                            self?.parent.onLoadStateChange?(.error("Portal returned an error page"))
                            writeLog("PortalWebView: DOM error detection triggered", logLevel: .error)
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let requestURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = requestURL.scheme?.lowercased()

            // Handle non-HTTP schemes
            if scheme == "mailto" || scheme == "tel" {
                NSWorkspace.shared.open(requestURL)
                decisionHandler(.cancel)
                return
            }

            guard scheme == "https" || scheme == "http" else {
                decisionHandler(.cancel)
                return
            }

            // 1. Same-host navigation — always allow (with header injection)
            if requestURL.host == portalHost || scheme == "about" {
                if ssoFlowActive {
                    ssoFlowActive = false
                    writeLog("PortalWebView: SSO flow ended — returned to portal host", logLevel: .debug)
                }

                // Header injection for same-host top-level navigations
                let headers = headersToInject
                if !headers.isEmpty && navigationAction.targetFrame?.isMainFrame == true {
                    if let pending = pendingHeaderInjection, pending.absoluteString == requestURL.absoluteString {
                        pendingHeaderInjection = nil
                        writeLog("PortalWebView: Allowing header-injected request for \(requestURL.absoluteString)", logLevel: .debug)
                        decisionHandler(.allow)
                    } else {
                        decisionHandler(.cancel)
                        pendingHeaderInjection = requestURL

                        var newRequest = URLRequest(url: requestURL)
                        for (key, value) in headers {
                            newRequest.setValue(value, forHTTPHeaderField: key)
                        }
                        newRequest.cachePolicy = .returnCacheDataElseLoad
                        writeLog("PortalWebView: Intercepted navigation, re-loading with headers for \(requestURL.absoluteString)", logLevel: .debug)
                        webView.load(newRequest)
                    }
                } else {
                    decisionHandler(.allow)
                }
                return
            }

            // 2. During active SSO flow — allow HTTPS only
            if ssoFlowActive {
                if scheme == "https" {
                    writeLog("PortalWebView: SSO flow — allowing cross-origin HTTPS to \(requestURL.host ?? "?")", logLevel: .debug)
                    decisionHandler(.allow)
                } else {
                    writeLog("PortalWebView: SSO flow — blocking non-HTTPS URL", logLevel: .info)
                    ssoFlowActive = false
                    decisionHandler(.cancel)
                }
                return
            }

            // 3. Detect SSO start: server redirect or form submission from portal host
            if navigationAction.navigationType == .other || navigationAction.navigationType == .formSubmitted {
                if navigationAction.sourceFrame.request.url?.host == portalHost,
                   scheme == "https" {
                    ssoFlowActive = true
                    writeLog("PortalWebView: SSO flow started — redirect to \(requestURL.host ?? "?")", logLevel: .debug)
                    decisionHandler(.allow)
                    return
                }
            }

            // 4. External link handling (Gap 4)
            if openExternalLinksInBrowser {
                let allowedSchemes: Set<String> = ["https", "http", "mailto", "tel"]
                if let urlScheme = scheme, allowedSchemes.contains(urlScheme) {
                    writeLog("PortalWebView: Opening external link in browser: \(requestURL.absoluteString)", logLevel: .debug)
                    NSWorkspace.shared.open(requestURL)
                }
                decisionHandler(.cancel)
                return
            }

            // Fallback: allow in webview (if external link handling is disabled)
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // Check if response should trigger a download (Gap 1)
            let mimeType = navigationResponse.response.mimeType ?? ""
            let ext = navigationResponse.response.url?.pathExtension.lowercased() ?? ""

            if downloadableMIMETypes.contains(mimeType)
                || downloadableExtensions.contains(ext)
                || !navigationResponse.canShowMIMEType {
                writeLog("PortalWebView: Triggering download for \(navigationResponse.response.url?.absoluteString ?? "?") (mime=\(mimeType), ext=\(ext))", logLevel: .info)
                decisionHandler(.download)
                return
            }

            guard let httpResponse = navigationResponse.response as? HTTPURLResponse else {
                decisionHandler(.allow)
                return
            }

            switch httpResponse.statusCode {
            case 200...299:
                decisionHandler(.allow)

            case 401:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error("Session expired"))
                writeLog("PortalWebView: 401 Unauthorized", logLevel: .error)

            case 403:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error("Access denied"))
                writeLog("PortalWebView: 403 Forbidden", logLevel: .error)

            case 404:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error("Page not found"))
                writeLog("PortalWebView: 404 Not Found", logLevel: .error)

            case 500...599:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error("Server error"))
                writeLog("PortalWebView: Server error \(httpResponse.statusCode)", logLevel: .error)

            default:
                decisionHandler(.allow)
            }
        }

        // MARK: - Download Delegate Assignment (Gap 1)

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        // MARK: - WKDownloadDelegate (Gap 1)

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            var destinationURL = downloadsDir.appendingPathComponent(suggestedFilename)

            // Duplicate avoidance: append (1), (2), etc.
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                let nameWithoutExt = destinationURL.deletingPathExtension().lastPathComponent
                let ext = destinationURL.pathExtension
                for i in 1...999 {
                    let newName = ext.isEmpty ? "\(nameWithoutExt) (\(i))" : "\(nameWithoutExt) (\(i)).\(ext)"
                    let newURL = downloadsDir.appendingPathComponent(newName)
                    if !FileManager.default.fileExists(atPath: newURL.path) {
                        destinationURL = newURL
                        break
                    }
                }
            }

            writeLog("PortalWebView: Download destination: \(destinationURL.path)", logLevel: .info)
            completionHandler(destinationURL)
        }

        func downloadDidFinish(_ download: WKDownload) {
            writeLog("PortalWebView: Download finished", logLevel: .info)

            // Auto-open .mobileconfig files (MDM enrollment profiles)
            if let url = download.progress.fileURL,
               url.pathExtension.lowercased() == "mobileconfig" {
                writeLog("PortalWebView: Auto-opening .mobileconfig: \(url.path)", logLevel: .info)
                NSWorkspace.shared.open(url)
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            writeLog("PortalWebView: Download failed - \(error.localizedDescription)", logLevel: .error)
        }

        // MARK: - WKUIDelegate (Gap 4 — target="_blank" links)

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if url.host == portalHost || ssoFlowActive {
                    // Load portal/SSO URLs in the same webview
                    webView.load(URLRequest(url: url))
                } else if openExternalLinksInBrowser {
                    NSWorkspace.shared.open(url)
                }
            }
            return nil
        }

        // Track if we've already reported an error (to prevent overwriting)
        private var hasReportedError = false

        private func handleNavigationError(_ error: Error) {
            // Don't overwrite if we've already reported an error
            if hasReportedError { return }

            let nsError = error as NSError

            // Handle cancelled requests silently
            if nsError.code == NSURLErrorCancelled {
                return
            }

            // Handle network errors
            let errorMessage: String
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                errorMessage = "No internet connection"
            case NSURLErrorTimedOut:
                errorMessage = "Connection timed out"
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                errorMessage = "Cannot connect to server"
            default:
                errorMessage = error.localizedDescription
            }

            ssoFlowActive = false  // Reset SSO on errors
            hasCompletedInitialLoad = false  // Show loading on retry
            hasReportedError = true
            failedURL = parent.url  // Track failed URL to prevent reload loop
            parent.onLoadStateChange?(.error(errorMessage))
            parent.onNavigationError?(error)
            writeLog("PortalWebView: Navigation error - \(errorMessage)", logLevel: .error)
        }

        // MARK: - Authentication Challenge Handler

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

            let authMethod = challenge.protectionSpace.authenticationMethod

            if authMethod == NSURLAuthenticationMethodServerTrust {
                // Server trust validation
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    let credential = URLCredential(trust: serverTrust)
                    completionHandler(.useCredential, credential)
                } else {
                    completionHandler(.performDefaultHandling, nil)
                }
            } else {
                // Use default handling for other auth methods
                completionHandler(.performDefaultHandling, nil)
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Handle messages from JavaScript if needed
            if let body = message.body as? [String: Any] {
                writeLog("PortalWebView: Received JS message - \(body)", logLevel: .debug)
            }
        }
    }
}

// MARK: - Portal Web View Container

/// Container view with loading/error states for PortalWebView
struct PortalWebViewContainer: View {

    let url: URL
    var authHeaders: [String: String]?
    var fallbackMessage: String?
    var supportURL: String?
    var supportContact: String?
    var onRetry: (() -> Void)?

    @State private var loadState: PortalLoadState = .initializing
    @State private var viewId = UUID()  // Used to force view recreation on retry

    var body: some View {
        ZStack {
            // WebView - id(viewId) forces recreation when retry is pressed
            PortalWebView(
                url: url,
                authHeaders: authHeaders,
                onLoadStateChange: { state in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        loadState = state
                    }
                }
            )
            .id(viewId)
            .opacity(loadState == .loaded ? 1 : 0.3)

            // Error overlay (network errors)
            if case .error(let message) = loadState {
                errorOverlay(message: message, state: loadState)
            }
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }

    private func errorOverlay(message: String, state: PortalLoadState) -> some View {
        VStack(spacing: 20) {
            Image(systemName: state.errorIcon)
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text(state.errorTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let fallback = fallbackMessage {
                Text(fallback)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            HStack(spacing: 16) {
                Button(action: {
                    // Reset state and force view recreation to clear failedURL
                    loadState = .loading
                    viewId = UUID()
                    onRetry?()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                }
                .buttonStyle(.bordered)

                if let supportURLString = supportURL,
                   let supportURL = URL(string: supportURLString) {
                    Link(destination: supportURL) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Contact IT")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let contact = supportContact {
                Text(contact)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Simple Web View (No Auth)

/// Simplified web view for unauthenticated URLs (e.g., SOFA, public docs)
struct SimplePortalWebView: View {

    let urlString: String
    var height: CGFloat = 400

    @State private var loadState: PortalLoadState = .initializing

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                ZStack {
                    PortalWebView(
                        url: url,
                        authHeaders: nil,
                        onLoadStateChange: { state in
                            loadState = state
                        }
                    )

                    if loadState == .loading || loadState == .initializing {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                    }

                    if case .error(let message) = loadState {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.orange)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                }
                .frame(height: height)
            } else {
                Text("Invalid URL: \(urlString)")
                    .foregroundStyle(.red)
                    .frame(height: height)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Embedded Portal Web View (With Auth)

/// Embedded web view for preset6 guidance blocks with authentication support
/// Supports custom headers (branding, bearer tokens) and custom user agent
struct EmbeddedPortalWebView: View {

    let url: URL
    var customHeaders: [String: String]?
    var userAgent: String?
    var ephemeralSession: Bool = false
    var errorDetectionPhrases: [String] = []
    var errorDetectionThreshold: Int = 2
    var openExternalLinksInBrowser: Bool = true
    var height: CGFloat = 400

    @State private var loadState: PortalLoadState = .initializing
    @State private var viewId = UUID()  // Used to force view recreation on retry

    private var isErrorState: Bool {
        if case .error = loadState { return true }
        return false
    }

    var body: some View {
        ZStack {
            PortalWebView(
                url: url,
                authHeaders: nil,
                customHeaders: customHeaders,
                userAgent: userAgent,
                ephemeralSession: ephemeralSession,
                errorDetectionPhrases: errorDetectionPhrases,
                errorDetectionThreshold: errorDetectionThreshold,
                openExternalLinksInBrowser: openExternalLinksInBrowser,
                onLoadStateChange: { state in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        loadState = state
                    }
                }
            )
            .id(viewId)  // Forces view recreation when viewId changes
            .opacity(loadState == .loaded ? 1 : 0.3)

            // Loading overlay - don't show during error states
            if (loadState == .loading || loadState == .initializing) && !isErrorState {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.7))
            }

            // Offline/cached content indicator
            if loadState == .offline {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(.orange)
                        Text("Viewing cached content")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
