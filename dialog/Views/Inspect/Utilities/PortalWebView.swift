//
//  PortalWebView.swift
//  dialog
//
//  WKWebView wrapper for the preset 5 portal step: cache-first loads, SSO redirects, downloads
//  and external-link hand-off.
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

/// Why a page did not load, for the failure screen. The code is the one the system produced,
/// never re-derived; with no code, `diagnostic` is nil and the line is not drawn.
struct PortalLoadFailure: Equatable {
    let message: String         // "Cannot connect to server"
    var symbolicCode: String?   // "NSURLErrorCannotConnectToHost", or "HTTP"
    var code: Int?              // -1004, or 404
    var host: String?           // "github.com"

    /// E.g. `NSURLErrorCannotConnectToHost · -1004`; nil when nothing verifiable is known.
    var diagnostic: String? {
        switch (symbolicCode, code) {
        case let (symbol?, code?):   return "\(symbol) · \(code)"
        case let (symbol?, nil):     return symbol
        case let (nil, code?):       return "\(code)"
        default:                     return nil
        }
    }

    /// Symbolic names for the `NSURLError` codes a portal hits; anything else is `URLError <n>`.
    static func symbolicName(forURLErrorCode code: Int) -> String {
        switch code {
        case NSURLErrorCancelled:               return "NSURLErrorCancelled"
        case NSURLErrorBadURL:                  return "NSURLErrorBadURL"
        case NSURLErrorTimedOut:                return "NSURLErrorTimedOut"
        case NSURLErrorUnsupportedURL:          return "NSURLErrorUnsupportedURL"
        case NSURLErrorCannotFindHost:          return "NSURLErrorCannotFindHost"
        case NSURLErrorCannotConnectToHost:     return "NSURLErrorCannotConnectToHost"
        case NSURLErrorNetworkConnectionLost:   return "NSURLErrorNetworkConnectionLost"
        case NSURLErrorDNSLookupFailed:         return "NSURLErrorDNSLookupFailed"
        case NSURLErrorHTTPTooManyRedirects:    return "NSURLErrorHTTPTooManyRedirects"
        case NSURLErrorNotConnectedToInternet:  return "NSURLErrorNotConnectedToInternet"
        case NSURLErrorSecureConnectionFailed:  return "NSURLErrorSecureConnectionFailed"
        case NSURLErrorServerCertificateUntrusted:
            return "NSURLErrorServerCertificateUntrusted"
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            return "NSURLErrorAppTransportSecurityRequiresSecureConnection"
        default:                                return "URLError \(code)"
        }
    }
}

enum PortalLoadState: Equatable {
    case initializing               // Setting up
    case loading                    // Content loading
    case loaded                     // Content visible
    case error(PortalLoadFailure)   // Failed, with the detail the failure screen prints
    case offline                    // Viewing cached content

    /// Message-only failure, for call sites with nothing else to report.
    static func error(_ message: String) -> PortalLoadState {
        .error(PortalLoadFailure(message: message))
    }

    var failure: PortalLoadFailure? {
        if case .error(let failure) = self { return failure }
        return nil
    }

    var isError: Bool { failure != nil }

    var errorIcon: String {
        return "wifi.exclamationmark"
    }

    var errorTitle: String {
        return "Unable to Connect"
    }
}

// MARK: - PortalWebView

struct PortalWebView: NSViewRepresentable {

    let url: URL
    var openExternalLinksInBrowser: Bool = true
    var onLoadStateChange: ((PortalLoadState) -> Void)?
    var onNavigationError: ((Error) -> Void)?
    /// Fires whenever the committed URL changes, so the address readout shows the live URL.
    var onURLChange: ((URL) -> Void)?

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        coordinator.portalHost = url.host
        coordinator.openExternalLinksInBrowser = openExternalLinksInBrowser
        return coordinator
    }

    func makeNSView(context: Context) -> WKWebView {
        writeLog("PortalWebView: makeNSView called - url=\(url)", logLevel: .debug)

        let configuration = WKWebViewConfiguration()

        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        configuration.websiteDataStore = .default()

        configuration.userContentController.add(context.coordinator, name: "portalMessage")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.observeCookies(store: configuration.websiteDataStore.httpCookieStore)

        loadURL(webView: webView, coordinator: context.coordinator)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // The coordinator outlives every copy of this struct; keep its parent and host current.
        context.coordinator.parent = self
        context.coordinator.portalHost = url.host

        // Never reload a URL that just failed; that loops on 401/403.
        if context.coordinator.failedURL == url {
            return
        }

        // Compare with the last requested URL, not `webView.url`: WebKit normalises `https://host`
        // to `https://host/`, which would reload on every update.
        if context.coordinator.lastRequestedURL != url {
            context.coordinator.resetForNewPage()
            loadURL(webView: webView, coordinator: context.coordinator)
        }
    }

    private func loadURL(webView: WKWebView, coordinator: Coordinator) {
        var request = URLRequest(url: url)

        request.cachePolicy = .returnCacheDataElseLoad
        onLoadStateChange?(.loading)
        coordinator.lastRequestedURL = url
        coordinator.currentNavigation = webView.load(request)
    }

    /// Stops observing the cookie store here, on the main actor, since a `deinit` cannot.
    static func dismantleNSView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cookieStore?.remove(coordinator)
        coordinator.cookieStore = nil
    }

    // MARK: - Coordinator

    /// Main-actor because WebKit's delegate protocols are; a nonisolated class cannot satisfy
    /// `WKDownloadDelegate` under strict concurrency checking.
    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKHTTPCookieStoreObserver, WKDownloadDelegate, WKUIDelegate {
        var parent: PortalWebView

        weak var cookieStore: WKHTTPCookieStore?

        /// The URL that last failed; `updateNSView` must not reload it.
        var failedURL: URL?

        private var ssoFlowActive = false
        var portalHost: String?

        var openExternalLinksInBrowser: Bool = true

        /// Suppresses the loading overlay during SSO redirects after the first successful load.
        private var hasCompletedInitialLoad = false

        /// The URL most recently handed to `webView.load`; the reload decision keys on this.
        var lastRequestedURL: URL?

        /// The navigation for that URL, so callbacks from a superseded page are dropped. Server
        /// redirects keep the same navigation object.
        var currentNavigation: WKNavigation?

        /// Whether a callback belongs to the page currently shown; a late `didFinish` from the
        /// previous page must not overwrite this page's failure.
        func isCurrent(_ navigation: WKNavigation!) -> Bool {
            guard let currentNavigation else { return true }
            guard let navigation else { return false }
            return navigation === currentNavigation
        }

        /// Clears per-page state when the URL changes under a reused coordinator (a step change).
        func resetForNewPage() {
            hasCompletedInitialLoad = false
            hasReportedError = false
            failedURL = nil
            ssoFlowActive = false
            currentNavigation = nil
        }

        init(_ parent: PortalWebView) {
            self.parent = parent
        }

        // No deinit: `dismantleNSView` removes the cookie observer on the main actor.

        func observeCookies(store: WKHTTPCookieStore) {
            self.cookieStore = store
            store.add(self)
            writeLog("PortalWebView: Cookie observer registered", logLevel: .debug)
        }

        // MARK: - WKHTTPCookieStoreObserver

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            cookieStore.getAllCookies { cookies in
                let cookieNames = cookies.map { $0.name }
                writeLog("PortalWebView: Cookies changed - count: \(cookies.count), names: \(cookieNames)", logLevel: .debug)
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            guard isCurrent(navigation) else { return }
            // A new navigation may report its own first error; didFinish never runs for a failed page.
            hasReportedError = false

            // After the first load, SSO redirects must not flash the overlay over visible content.
            if !hasCompletedInitialLoad {
                parent.onLoadStateChange?(.loading)
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            guard isCurrent(navigation) else { return }
            // Earliest point the destination is settled, so a redirect is visible while loading.
            if let url = webView.url { parent.onURLChange?(url) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard isCurrent(navigation) else { return }
            hasReportedError = false
            hasCompletedInitialLoad = true
            failedURL = nil

            if webView.url?.host == portalHost {
                ssoFlowActive = false
            }

            if let url = webView.url { parent.onURLChange?(url) }
            parent.onLoadStateChange?(.loaded)
            writeLog("PortalWebView: Content loaded for \(webView.url?.absoluteString ?? "unknown")", logLevel: .info)

        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard isCurrent(navigation) else { return }
            handleNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard isCurrent(navigation) else { return }
            handleNavigationError(error)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard let requestURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let scheme = requestURL.scheme?.lowercased()

            if scheme == "mailto" || scheme == "tel" {
                NSWorkspace.shared.open(requestURL)
                decisionHandler(.cancel)
                return
            }

            guard scheme == "https" || scheme == "http" else {
                decisionHandler(.cancel)
                return
            }

            // 1. Same host: always allow
            if requestURL.host == portalHost || scheme == "about" {
                if ssoFlowActive {
                    ssoFlowActive = false
                    writeLog("PortalWebView: SSO flow ended — returned to portal host", logLevel: .debug)
                }

                decisionHandler(.allow)
                return
            }

            // 2. During an SSO flow: HTTPS only
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

            // 3. SSO starts with a redirect or form submission from the portal host
            if navigationAction.navigationType == .other || navigationAction.navigationType == .formSubmitted {
                if navigationAction.sourceFrame.request.url?.host == portalHost,
                   scheme == "https" {
                    ssoFlowActive = true
                    writeLog("PortalWebView: SSO flow started — redirect to \(requestURL.host ?? "?")", logLevel: .debug)
                    decisionHandler(.allow)
                    return
                }
            }

            // 4. External links
            if openExternalLinksInBrowser {
                let allowedSchemes: Set<String> = ["https", "http", "mailto", "tel"]
                if let urlScheme = scheme, allowedSchemes.contains(urlScheme) {
                    writeLog("PortalWebView: Opening external link in browser: \(requestURL.absoluteString)", logLevel: .debug)
                    NSWorkspace.shared.open(requestURL)
                }
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
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
                parent.onLoadStateChange?(.error(httpFailure("Session expired", httpResponse)))
                writeLog("PortalWebView: 401 Unauthorized", logLevel: .error)

            case 403:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error(httpFailure("Access denied", httpResponse)))
                writeLog("PortalWebView: 403 Forbidden", logLevel: .error)

            case 404:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error(httpFailure("Page not found", httpResponse)))
                writeLog("PortalWebView: 404 Not Found", logLevel: .error)

            case 500...599:
                failedURL = httpResponse.url
                decisionHandler(.cancel)
                parent.onLoadStateChange?(.error(httpFailure("Server error", httpResponse)))
                writeLog("PortalWebView: Server error \(httpResponse.statusCode)", logLevel: .error)

            default:
                decisionHandler(.allow)
            }
        }

        /// Carries the status as `HTTP · <code>` so the failure screen shows it like a network error.
        private func httpFailure(_ message: String, _ response: HTTPURLResponse) -> PortalLoadFailure {
            PortalLoadFailure(message: message,
                              symbolicCode: "HTTP",
                              code: response.statusCode,
                              host: response.url?.host ?? parent.url.host)
        }

        // MARK: - Download Delegate Assignment

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }

        // MARK: - WKDownloadDelegate

        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
            let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            var destinationURL = downloadsDir.appendingPathComponent(suggestedFilename)

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

            // A .mobileconfig is an enrollment profile; opening it starts installation.
            if let url = download.progress.fileURL,
               url.pathExtension.lowercased() == "mobileconfig" {
                writeLog("PortalWebView: Auto-opening .mobileconfig: \(url.path)", logLevel: .info)
                NSWorkspace.shared.open(url)
            }
        }

        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            writeLog("PortalWebView: Download failed - \(error.localizedDescription)", logLevel: .error)
        }

        // MARK: - WKUIDelegate (target="_blank" links)

        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                if url.host == portalHost || ssoFlowActive {
                    webView.load(URLRequest(url: url))
                } else if openExternalLinksInBrowser {
                    NSWorkspace.shared.open(url)
                }
            }
            return nil
        }

        /// Only the first error of a navigation is reported.
        private var hasReportedError = false

        private func handleNavigationError(_ error: Error) {
            if hasReportedError { return }

            let nsError = error as NSError

            if nsError.code == NSURLErrorCancelled {
                return
            }

            let errorMessage: String
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet:
                errorMessage = "Your Mac is not connected to a network."
            case NSURLErrorTimedOut:
                errorMessage = "The server took too long to respond."
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                errorMessage = "Your network blocks it, or it is down."
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
                errorMessage = "The secure connection could not be established."
            default:
                errorMessage = error.localizedDescription
            }

            let failure = PortalLoadFailure(
                message: errorMessage,
                symbolicCode: PortalLoadFailure.symbolicName(forURLErrorCode: nsError.code),
                code: nsError.code,
                host: parent.url.host
            )

            ssoFlowActive = false
            hasCompletedInitialLoad = false  // show loading on retry
            hasReportedError = true
            failedURL = parent.url
            parent.onLoadStateChange?(.error(failure))
            parent.onNavigationError?(error)
            writeLog("PortalWebView: Navigation error - \(errorMessage)", logLevel: .error)
        }

        // MARK: - Authentication Challenge Handler

        func webView(_ webView: WKWebView,
                     didReceive challenge: URLAuthenticationChallenge,
                     completionHandler: @escaping @MainActor @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

            let authMethod = challenge.protectionSpace.authenticationMethod
            writeLog("PortalWebView: auth challenge (\(authMethod)) from \(challenge.protectionSpace.host)", logLevel: .debug)

            // Default handling for every challenge, server trust included: the certificate chain is
            // evaluated against the Mac's trust settings. Never answer server trust with `.useCredential`.
            completionHandler(.performDefaultHandling, nil)
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if let body = message.body as? [String: Any] {
                writeLog("PortalWebView: Received JS message - \(body)", logLevel: .debug)
            }
        }
    }
}
