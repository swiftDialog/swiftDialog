//
//  PortalAuthService.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  Generic authentication service for self-service portal integration (Preset5)
//  Supports pluggable authentication providers for different portal types
//

import Foundation
import SwiftUI

// MARK: - Portal Errors

/// Types of errors that can occur during portal authentication and loading
enum PortalError: LocalizedError {
    // Authentication errors
    case authSecretNotFound(path: String)
    case authSecretReadFailed(path: String, underlying: Error?)
    case tokenGenerationFailed(endpoint: String, underlying: Error?)
    case tokenExpired
    case tokenRefreshFailed(underlying: Error?)
    case scriptAuthFailed(script: String, exitCode: Int)
    case keychainReadFailed(service: String, account: String)

    // Network errors
    case networkUnavailable
    case networkTimeout
    case serverUnreachable(url: String)
    case serverError(statusCode: Int, message: String?)
    case sslCertificateError(underlying: Error?)

    // Client errors
    case unauthorized
    case forbidden
    case deviceNotRegistered
    case configurationMissing(field: String)

    // Content errors
    case contentLoadFailed(url: String, underlying: Error?)
    case cacheExpired
    case cacheCorrupted

    var errorDescription: String? {
        switch self {
        case .authSecretNotFound(let path):
            return "Authentication secret not found at: \(path)"
        case .authSecretReadFailed(let path, let error):
            return "Failed to read auth secret at \(path): \(error?.localizedDescription ?? "Unknown")"
        case .tokenGenerationFailed(let endpoint, let error):
            return "Token generation failed for \(endpoint): \(error?.localizedDescription ?? "Unknown")"
        case .tokenExpired:
            return "Session token has expired"
        case .tokenRefreshFailed(let error):
            return "Failed to refresh token: \(error?.localizedDescription ?? "Unknown")"
        case .scriptAuthFailed(let script, let exitCode):
            return "Auth script '\(script)' failed with exit code \(exitCode)"
        case .keychainReadFailed(let service, let account):
            return "Failed to read from keychain: \(service)/\(account)"
        case .networkUnavailable:
            return "No network connection available"
        case .networkTimeout:
            return "Network request timed out"
        case .serverUnreachable(let url):
            return "Server unreachable: \(url)"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message ?? "Unknown")"
        case .sslCertificateError(let error):
            return "SSL certificate error: \(error?.localizedDescription ?? "Unknown")"
        case .unauthorized:
            return "Session expired - authentication required"
        case .forbidden:
            return "Access denied - device may not be enrolled"
        case .deviceNotRegistered:
            return "Device is not registered with this portal"
        case .configurationMissing(let field):
            return "Required configuration missing: \(field)"
        case .contentLoadFailed(let url, let error):
            return "Failed to load content from \(url): \(error?.localizedDescription ?? "Unknown")"
        case .cacheExpired:
            return "Cached content has expired"
        case .cacheCorrupted:
            return "Cached content is corrupted"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .authSecretNotFound, .authSecretReadFailed:
            return "Ensure the device is properly enrolled with the MDM service"
        case .tokenGenerationFailed, .tokenRefreshFailed:
            return "Check network connection and try again"
        case .tokenExpired:
            return "Refreshing authentication..."
        case .scriptAuthFailed:
            return "Contact IT support to verify device enrollment"
        case .keychainReadFailed:
            return "Check keychain access permissions"
        case .networkUnavailable, .networkTimeout, .serverUnreachable:
            return "Check your network connection and try again"
        case .serverError:
            return "The server may be experiencing issues. Try again later"
        case .sslCertificateError:
            return "Contact IT support - certificate issue detected"
        case .unauthorized:
            return "Please wait while we refresh your session"
        case .forbidden, .deviceNotRegistered:
            return "Contact IT support to enroll this device"
        case .configurationMissing:
            return "Check portal configuration in the config file"
        case .contentLoadFailed:
            return "Try refreshing or check network connection"
        case .cacheExpired, .cacheCorrupted:
            return "Refresh to load latest content"
        }
    }

    /// Whether this error type allows retry
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .networkTimeout, .serverUnreachable,
             .serverError, .tokenExpired, .tokenRefreshFailed,
             .contentLoadFailed:
            return true
        case .authSecretNotFound, .deviceNotRegistered, .forbidden,
             .configurationMissing, .keychainReadFailed:
            return false
        default:
            return true
        }
    }

    /// Whether to show "Contact IT" button
    var showContactIT: Bool {
        switch self {
        case .authSecretNotFound, .deviceNotRegistered, .forbidden,
             .scriptAuthFailed, .sslCertificateError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Authentication Credentials

/// Authentication credentials container
struct AuthCredentials {
    let token: String?
    let cookies: [HTTPCookie]?
    let headers: [String: String]?
    let expiresAt: Date?

    var isExpired: Bool {
        guard let expiry = expiresAt else { return false }
        return Date() >= expiry
    }

    var timeUntilExpiry: TimeInterval? {
        guard let expiry = expiresAt else { return nil }
        return expiry.timeIntervalSinceNow
    }
}

// MARK: - Authentication Provider Protocol

/// Protocol for pluggable authentication providers
/// Implement this protocol to support different portal authentication methods
protocol AuthProviderProtocol {
    /// Provider identifier (for logging and configuration)
    var providerId: String { get }

    /// Display name for UI
    var displayName: String { get }

    /// Current authentication state
    var isAuthenticated: Bool { get }

    /// Authenticate and return credentials
    func authenticate() async throws -> AuthCredentials

    /// Refresh credentials if expired or about to expire
    func refreshCredentials() async throws -> AuthCredentials

    /// Get HTTP headers for authenticated requests
    func getAuthHeaders() -> [String: String]

    /// Get cookies for authenticated requests (optional)
    func getAuthCookies() -> [HTTPCookie]

    /// Handle 401 unauthorized response
    func handleUnauthorized() async throws -> AuthCredentials

    /// Clear stored credentials
    func clearCredentials()
}

// MARK: - Portal Authentication Service

/// Main authentication service for self-service portals
/// Manages authentication flow using pluggable providers
class PortalAuthService: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticating: Bool = false
    @Published var isAuthenticated: Bool = false
    @Published var lastError: PortalError?
    @Published var currentToken: String?

    // MARK: - Private Properties

    private var credentials: AuthCredentials?
    private var provider: AuthProviderProtocol?
    private var config: InspectConfig.PortalConfig?
    private var refreshTask: Task<Void, Never>?

    private let tokenRefreshMargin: TimeInterval = 300 // Refresh 5 min before expiry

    // MARK: - Initialization

    /// Initialize with portal configuration
    /// - Parameter config: Portal configuration from InspectConfig
    func configure(with config: InspectConfig.PortalConfig) {
        self.config = config

        // Create appropriate provider based on config
        let providerType = config.provider ?? "generic"
        self.provider = createProvider(type: providerType, config: config)

        writeLog("PortalAuth: Configured with provider '\(providerType)'", logLevel: .info)
    }

    /// Create authentication provider based on type
    private func createProvider(type: String, config: InspectConfig.PortalConfig) -> AuthProviderProtocol {
        // Check for mTLS configuration first
        if config.authSources?.clientCertIdentity != nil {
            return MTLSAuthProvider(config: config)
        }

        switch type.lowercased() {
        case "script":
            return ScriptAuthProvider(config: config)
        case "mtls", "certificate":
            return MTLSAuthProvider(config: config)
        default:
            // Generic token-based provider (works for most MDM tools)
            return GenericTokenProvider(config: config)
        }
    }

    // MARK: - Authentication

    /// Perform initial authentication
    func authenticate() async throws {
        guard let provider = provider else {
            throw PortalError.configurationMissing(field: "provider")
        }

        await MainActor.run {
            isAuthenticating = true
            lastError = nil
        }

        do {
            let credentials = try await provider.authenticate()
            await updateCredentials(credentials)
            startTokenRefreshTimer()

            writeLog("PortalAuth: Authentication successful", logLevel: .info)
        } catch {
            let portalError = mapError(error)
            await MainActor.run {
                lastError = portalError
                isAuthenticating = false
            }
            throw portalError
        }
    }

    /// Refresh authentication credentials
    func refresh() async throws {
        guard let provider = provider else {
            throw PortalError.configurationMissing(field: "provider")
        }

        do {
            let credentials = try await provider.refreshCredentials()
            await updateCredentials(credentials)

            writeLog("PortalAuth: Token refreshed successfully", logLevel: .info)
        } catch {
            let portalError = mapError(error)
            await MainActor.run {
                lastError = portalError
            }
            throw portalError
        }
    }

    /// Handle 401 response from portal
    func handleUnauthorized() async throws {
        guard let provider = provider else {
            throw PortalError.configurationMissing(field: "provider")
        }

        writeLog("PortalAuth: Handling 401 unauthorized", logLevel: .info)

        do {
            let credentials = try await provider.handleUnauthorized()
            await updateCredentials(credentials)
        } catch {
            throw mapError(error)
        }
    }

    /// Clear authentication state
    func logout() {
        refreshTask?.cancel()
        refreshTask = nil
        credentials = nil
        provider?.clearCredentials()

        Task { @MainActor in
            isAuthenticated = false
            currentToken = nil
        }

        writeLog("PortalAuth: Logged out", logLevel: .info)
    }

    // MARK: - Credentials Access

    /// Get current authentication headers for requests
    func getAuthHeaders() -> [String: String] {
        return provider?.getAuthHeaders() ?? [:]
    }

    /// Get current authentication cookies for requests
    func getAuthCookies() -> [HTTPCookie] {
        return provider?.getAuthCookies() ?? []
    }

    // MARK: - Private Helpers

    private func updateCredentials(_ credentials: AuthCredentials) async {
        self.credentials = credentials

        await MainActor.run {
            self.isAuthenticated = true
            self.isAuthenticating = false
            self.currentToken = credentials.token
        }
    }

    private func startTokenRefreshTimer() {
        refreshTask?.cancel()

        guard let expiry = credentials?.expiresAt else { return }

        let refreshTime = expiry.addingTimeInterval(-tokenRefreshMargin)
        let delay = max(refreshTime.timeIntervalSinceNow, 60) // At least 1 minute

        refreshTask = Task {
            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            do {
                try await refresh()
                startTokenRefreshTimer() // Schedule next refresh
            } catch {
                writeLog("PortalAuth: Auto-refresh failed: \(error)", logLevel: .error)
            }
        }

        writeLog("PortalAuth: Token refresh scheduled in \(Int(delay))s", logLevel: .debug)
    }

    private func mapError(_ error: Error) -> PortalError {
        if let portalError = error as? PortalError {
            return portalError
        }

        let nsError = error as NSError

        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .networkTimeout
        case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
            return .serverUnreachable(url: config?.portalURL ?? "unknown")
        case NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasUnknownRoot:
            return .sslCertificateError(underlying: error)
        default:
            return .contentLoadFailed(url: config?.portalURL ?? "unknown", underlying: error)
        }
    }
}

// MARK: - Generic Token Provider

/// Generic token-based authentication provider
/// Works with most MDM self-service portals that use bearer tokens
class GenericTokenProvider: AuthProviderProtocol {

    let providerId = "generic"
    let displayName = "Self-Service Portal"

    private var credentials: AuthCredentials?
    private let config: InspectConfig.PortalConfig

    init(config: InspectConfig.PortalConfig) {
        self.config = config
    }

    var isAuthenticated: Bool {
        guard let creds = credentials else { return false }
        return !creds.isExpired
    }

    func authenticate() async throws -> AuthCredentials {
        // Check for static token first (e.g., Cloudflare bearer token)
        if let authSources = config.authSources,
           let staticToken = authSources.staticToken {
            writeLog("PortalAuth: Using static token", logLevel: .debug)
            let credentials = AuthCredentials(
                token: staticToken,
                cookies: nil,
                headers: buildHeaders(token: staticToken),
                expiresAt: nil // Static tokens don't expire in our context
            )
            self.credentials = credentials
            return credentials
        }

        // Read secret from configured source
        let secret = try readAuthSecret()

        // Generate token from endpoint
        guard let tokenEndpoint = config.tokenEndpoint else {
            // No token endpoint = assume secret is the token
            let credentials = AuthCredentials(
                token: secret,
                cookies: nil,
                headers: buildHeaders(token: secret),
                expiresAt: nil
            )
            self.credentials = credentials
            return credentials
        }

        // POST to token endpoint
        let token = try await generateToken(secret: secret, endpoint: tokenEndpoint)

        let credentials = AuthCredentials(
            token: token,
            cookies: nil,
            headers: buildHeaders(token: token),
            expiresAt: Date().addingTimeInterval(3600) // Default 1 hour expiry
        )
        self.credentials = credentials
        return credentials
    }

    func refreshCredentials() async throws -> AuthCredentials {
        return try await authenticate()
    }

    func getAuthHeaders() -> [String: String] {
        return credentials?.headers ?? [:]
    }

    func getAuthCookies() -> [HTTPCookie] {
        return credentials?.cookies ?? []
    }

    func handleUnauthorized() async throws -> AuthCredentials {
        credentials = nil
        return try await authenticate()
    }

    func clearCredentials() {
        credentials = nil
    }

    // MARK: - Private Helpers

    private func readAuthSecret() throws -> String {
        guard let authSources = config.authSources else {
            throw PortalError.configurationMissing(field: "authSources")
        }

        // Static token takes priority (handled in authenticate(), but check here too)
        if let staticToken = authSources.staticToken {
            return staticToken
        }

        // Try file source first
        if let secretFile = authSources.secretFile {
            let expandedPath = NSString(string: secretFile).expandingTildeInPath

            guard FileManager.default.fileExists(atPath: expandedPath) else {
                throw PortalError.authSecretNotFound(path: secretFile)
            }

            do {
                let secret = try String(contentsOfFile: expandedPath, encoding: .utf8)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return secret
            } catch {
                throw PortalError.authSecretReadFailed(path: secretFile, underlying: error)
            }
        }

        // Try keychain source
        if let service = authSources.keychainService,
           let account = authSources.keychainAccount {
            // Keychain read would go here
            throw PortalError.keychainReadFailed(service: service, account: account)
        }

        throw PortalError.configurationMissing(field: "authSources.secretFile or keychain")
    }

    private func generateToken(secret: String, endpoint: String) async throws -> String {
        guard let portalURLString = config.portalURL,
              let baseURL = URL(string: portalURLString),
              let tokenURL = URL(string: endpoint, relativeTo: baseURL) else {
            throw PortalError.configurationMissing(field: "portalURL or tokenEndpoint")
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Send secret in request body (format may vary by provider)
        let body = ["orbit_node_key": secret]
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PortalError.tokenGenerationFailed(endpoint: endpoint, underlying: nil)
            }

            switch httpResponse.statusCode {
            case 200...299:
                // Parse token from response
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String {
                    return token
                }
                throw PortalError.tokenGenerationFailed(endpoint: endpoint, underlying: nil)

            case 401:
                throw PortalError.unauthorized

            case 403:
                throw PortalError.deviceNotRegistered

            default:
                let message = String(data: data, encoding: .utf8)
                throw PortalError.serverError(statusCode: httpResponse.statusCode, message: message)
            }
        } catch let error as PortalError {
            throw error
        } catch {
            throw PortalError.tokenGenerationFailed(endpoint: endpoint, underlying: error)
        }
    }

    private func buildHeaders(token: String) -> [String: String] {
        let headerName = config.authSources?.headerName ?? "Authorization"
        let headerPrefix = config.authSources?.headerPrefix ?? "Bearer "
        return [headerName: "\(headerPrefix)\(token)"]
    }
}

// MARK: - Script Auth Provider

/// Script-based authentication provider
/// Executes a custom script to generate authentication credentials
class ScriptAuthProvider: AuthProviderProtocol {

    let providerId = "script"
    let displayName = "Custom Auth Script"

    private var credentials: AuthCredentials?
    private let config: InspectConfig.PortalConfig

    init(config: InspectConfig.PortalConfig) {
        self.config = config
    }

    var isAuthenticated: Bool {
        guard let creds = credentials else { return false }
        return !creds.isExpired
    }

    func authenticate() async throws -> AuthCredentials {
        guard let authSources = config.authSources,
              let scriptPath = authSources.scriptPath else {
            throw PortalError.configurationMissing(field: "authSources.scriptPath")
        }

        let timeout = authSources.scriptTimeout ?? 30
        let result = try await runScript(path: scriptPath, timeout: timeout)

        // Parse script output as token
        let token = result.trimmingCharacters(in: .whitespacesAndNewlines)

        let headerName = authSources.headerName ?? "Authorization"
        let headerPrefix = authSources.headerPrefix ?? "Bearer "

        let credentials = AuthCredentials(
            token: token,
            cookies: nil,
            headers: [headerName: "\(headerPrefix)\(token)"],
            expiresAt: Date().addingTimeInterval(3600)
        )
        self.credentials = credentials
        return credentials
    }

    func refreshCredentials() async throws -> AuthCredentials {
        return try await authenticate()
    }

    func getAuthHeaders() -> [String: String] {
        return credentials?.headers ?? [:]
    }

    func getAuthCookies() -> [HTTPCookie] {
        return credentials?.cookies ?? []
    }

    func handleUnauthorized() async throws -> AuthCredentials {
        credentials = nil
        return try await authenticate()
    }

    func clearCredentials() {
        credentials = nil
    }

    // MARK: - Private Helpers

    private func runScript(path: String, timeout: Int) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", path]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw PortalError.scriptAuthFailed(script: path, exitCode: -1)
        }

        // Wait with timeout
        let deadline = Date().addingTimeInterval(TimeInterval(timeout))
        while process.isRunning && Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.isRunning {
            process.terminate()
            throw PortalError.networkTimeout
        }

        guard process.terminationStatus == 0 else {
            throw PortalError.scriptAuthFailed(script: path, exitCode: Int(process.terminationStatus))
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            throw PortalError.scriptAuthFailed(script: path, exitCode: 0)
        }

        return output
    }
}

// MARK: - mTLS Auth Provider

/// mTLS (mutual TLS) authentication provider
/// Uses client certificate from keychain for authentication
class MTLSAuthProvider: AuthProviderProtocol {

    let providerId = "mtls"
    let displayName = "Certificate Authentication"

    private var identity: SecIdentity?
    private let config: InspectConfig.PortalConfig

    init(config: InspectConfig.PortalConfig) {
        self.config = config
    }

    var isAuthenticated: Bool {
        return identity != nil
    }

    func authenticate() async throws -> AuthCredentials {
        guard let authSources = config.authSources,
              let certIdentity = authSources.clientCertIdentity else {
            throw PortalError.configurationMissing(field: "authSources.clientCertIdentity")
        }

        // Find client certificate in keychain
        identity = try findIdentityInKeychain(commonName: certIdentity)

        writeLog("PortalAuth: mTLS identity found for '\(certIdentity)'", logLevel: .info)

        // mTLS doesn't use tokens - authentication happens at TLS level
        return AuthCredentials(
            token: nil,
            cookies: nil,
            headers: nil,
            expiresAt: nil
        )
    }

    func refreshCredentials() async throws -> AuthCredentials {
        // mTLS credentials don't need refresh
        return try await authenticate()
    }

    func getAuthHeaders() -> [String: String] {
        // mTLS doesn't use headers
        return [:]
    }

    func getAuthCookies() -> [HTTPCookie] {
        return []
    }

    func handleUnauthorized() async throws -> AuthCredentials {
        // Re-authenticate
        identity = nil
        return try await authenticate()
    }

    func clearCredentials() {
        identity = nil
    }

    /// Get the SecIdentity for use in URLSession delegate
    func getIdentity() -> SecIdentity? {
        return identity
    }

    // MARK: - Private Helpers

    private func findIdentityInKeychain(commonName: String) throws -> SecIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchSubjectContains as String: commonName,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let identity = item else {
            writeLog("PortalAuth: Client certificate '\(commonName)' not found in keychain (status: \(status))", logLevel: .error)
            throw PortalError.keychainReadFailed(service: "Identity", account: commonName)
        }

        // swiftlint:disable:next force_cast
        return (identity as! SecIdentity)
    }
}

// MARK: - mTLS URLSession Delegate

/// URLSession delegate that provides client certificate for mTLS
class MTLSSessionDelegate: NSObject, URLSessionDelegate {

    private let identity: SecIdentity

    init(identity: SecIdentity) {
        self.identity = identity
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle client certificate challenge
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
            completionHandler(.useCredential, credential)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            // Accept server certificate (you might want to validate it in production)
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
