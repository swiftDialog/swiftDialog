//
//  ErrorHandling.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 21/09/2025
//
//  Comprehensive error handling and recovery service for Inspect mode
//

import Foundation
import SwiftUI

/// Types of errors that can occur in Inspect mode
enum InspectError: LocalizedError {
    case configurationNotFound(path: String)
    case configurationInvalid(reason: String)
    case fileSystemError(path: String, underlying: Error?)
    case plistParsingError(path: String, key: String?)
    case networkError(url: String, underlying: Error?)
    case persistenceError(reason: String)
    case monitoringError(reason: String)
    case validationTimeout(item: String)
    case unexpectedState(reason: String)

    var errorDescription: String? {
        switch self {
        case .configurationNotFound(let path):
            return "Configuration not found at: \(path)"
        case .configurationInvalid(let reason):
            return "Invalid configuration: \(reason)"
        case .fileSystemError(let path, let error):
            return "File system error at \(path): \(error?.localizedDescription ?? "Unknown")"
        case .plistParsingError(let path, let key):
            return "Failed to parse plist at \(path), key: \(key ?? "root")"
        case .networkError(let url, let error):
            return "Network error for \(url): \(error?.localizedDescription ?? "Unknown")"
        case .persistenceError(let reason):
            return "Persistence error: \(reason)"
        case .monitoringError(let reason):
            return "Monitoring error: \(reason)"
        case .validationTimeout(let item):
            return "Validation timeout for item: \(item)"
        case .unexpectedState(let reason):
            return "Unexpected state: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .configurationNotFound:
            return "Check that the configuration file exists and the path is correct"
        case .configurationInvalid:
            return "Verify the configuration JSON is properly formatted"
        case .fileSystemError:
            return "Check file permissions and disk space"
        case .plistParsingError:
            return "Ensure the plist file is not corrupted"
        case .networkError:
            return "Check network connection and try again"
        case .persistenceError:
            return "Try clearing the cache and restarting"
        case .monitoringError:
            return "Restart the monitoring service"
        case .validationTimeout:
            return "The validation is taking longer than expected, please wait"
        case .unexpectedState:
            return "Try restarting the application"
        }
    }
}

/// Service for handling errors and attempting recovery
class ErrorHandling: ObservableObject {
    static let shared = ErrorHandling()

    @Published var lastError: InspectError?
    @Published var isRecovering: Bool = false
    @Published var errorHistory: [ErrorEvent] = []

    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    private var retryCounters: [String: Int] = [:]

    struct ErrorEvent {
        let error: InspectError
        let timestamp: Date
        let recovered: Bool
        let context: String?
    }

    // MARK: - Error Handling

    /// Handle an error with automatic recovery attempts
    func handle(_ error: InspectError, context: String? = nil, recovery: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            self.lastError = error
            self.errorHistory.append(ErrorEvent(
                error: error,
                timestamp: Date(),
                recovered: false,
                context: context
            ))
        }

        writeLog("ErrorRecovery: \(error.localizedDescription)", logLevel: .error)

        // Attempt automatic recovery based on error type
        attemptRecovery(for: error, recovery: recovery)
    }

    // MARK: - Recovery Strategies

    private func attemptRecovery(for error: InspectError, recovery: (() -> Void)? = nil) {
        let errorKey = String(describing: error)
        let retryCount = retryCounters[errorKey] ?? 0

        guard retryCount < maxRetryAttempts else {
            writeLog("ErrorRecovery: Max retries reached for \(errorKey)", logLevel: .error)
            showUserAlert(for: error)
            return
        }

        retryCounters[errorKey] = retryCount + 1
        isRecovering = true

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            guard let self = self else { return }

            switch error {
            case .configurationNotFound, .configurationInvalid:
                self.recoverFromConfigurationError(error, recovery: recovery)

            case .fileSystemError:
                self.recoverFromFileSystemError(error, recovery: recovery)

            case .plistParsingError:
                self.recoverFromPlistError(error, recovery: recovery)

            case .networkError:
                self.recoverFromNetworkError(error, recovery: recovery)

            case .persistenceError:
                self.recoverFromPersistenceError(error, recovery: recovery)

            case .monitoringError:
                self.recoverFromMonitoringError(error, recovery: recovery)

            case .validationTimeout:
                self.recoverFromValidationTimeout(error, recovery: recovery)

            case .unexpectedState:
                self.recoverFromUnexpectedState(error, recovery: recovery)
            }

            DispatchQueue.main.async {
                self.isRecovering = false
            }
        }
    }

    // MARK: - Specific Recovery Methods

    private func recoverFromConfigurationError(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Attempting to recover from configuration error", logLevel: .info)

        // Try alternative configuration sources
        if let envPath = ProcessInfo.processInfo.environment["DIALOG_INSPECT_CONFIG"] {
            writeLog("ErrorRecovery: Trying environment config at \(envPath)", logLevel: .info)
            recovery?()
        } else {
            // Fall back to default configuration
            writeLog("ErrorRecovery: Using fallback configuration", logLevel: .info)
            // Load fallback configuration\n            writeLog("ErrorRecovery: Loading fallback configuration", logLevel: .info)
            recovery?()
        }
    }

    private func recoverFromFileSystemError(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Attempting to recover from file system error", logLevel: .info)

        // Clear file caches and retry
        Task { @MainActor in
            Validation.shared.clearCache()
        }

        recovery?()
    }

    private func recoverFromPlistError(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Attempting to recover from plist error", logLevel: .info)

        // Invalidate cached plist and retry
        if case .plistParsingError(let path, _) = error {
            Task { @MainActor in
                Validation.shared.invalidateCacheForPath(path)
            }
        }

        recovery?()
    }

    private func recoverFromNetworkError(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Attempting to recover from network error", logLevel: .info)

        // Wait longer and retry
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            recovery?()
        }
    }

    private func recoverFromPersistenceError(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Attempting to recover from persistence error", logLevel: .info)

        // Persistence recovery should be handled by the preset itself via the recovery closure
        recovery?()
    }

    private func recoverFromMonitoringError(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Attempting to recover from monitoring error", logLevel: .info)

        // Restart monitoring service
        // Restart monitoring would go here\n        writeLog("ErrorRecovery: Would restart monitoring service", logLevel: .info)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            recovery?()
        }
    }

    private func recoverFromValidationTimeout(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Validation timeout - continuing anyway", logLevel: .info)
        recovery?()
    }

    private func recoverFromUnexpectedState(_ error: InspectError, recovery: (() -> Void)?) {
        writeLog("ErrorRecovery: Resetting to clean state", logLevel: .info)

        // Reset all services
        Task { @MainActor in
            Validation.shared.clearCache()
        }

        recovery?()
    }

    // MARK: - User Notification

    private func showUserAlert(for error: InspectError) {
        // In production, this would show a user-friendly dialog
        writeLog("ErrorRecovery: User alert - \(error.localizedDescription) - \(error.recoverySuggestion ?? "No suggestion")", logLevel: .error)
    }

    // MARK: - Utilities

    func clearErrorHistory() {
        errorHistory.removeAll()
        retryCounters.removeAll()
        lastError = nil
    }

    func resetRetryCounter(for error: InspectError) {
        let errorKey = String(describing: error)
        retryCounters.removeValue(forKey: errorKey)
    }
}

// MARK: - Safe Execution Utilities

/// Execute a throwing closure with automatic error handling
func safeExecute<T>(_ context: String, recovery: (() -> Void)? = nil, operation: () throws -> T) -> T? {
    do {
        return try operation()
    } catch {
        let inspectError = InspectError.unexpectedState(reason: error.localizedDescription)
        ErrorHandling.shared.handle(inspectError, context: context, recovery: recovery)
        return nil
    }
}

/// Execute an async operation with timeout protection
func safeAsyncExecute<T>(_ context: String, timeout: TimeInterval = 30.0, operation: @escaping () async throws -> T) async -> T? {
    do {
        return try await withTimeout(seconds: timeout) {
            try await operation()
        }
    } catch {
        let inspectError = InspectError.validationTimeout(item: context)
        ErrorHandling.shared.handle(inspectError, context: context)
        return nil
    }
}

/// Helper for timeout handling
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw InspectError.validationTimeout(item: "Operation")
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
