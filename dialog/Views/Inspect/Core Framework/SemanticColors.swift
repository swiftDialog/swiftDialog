//
//  SemanticColors.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Semantic color constants for the Inspect framework
//  Consolidates hardcoded hex values into reusable named constants
//

import SwiftUI

/// Semantic colors for status indicators and UI elements
/// These match Apple's Human Interface Guidelines system colors
extension Color {

    // MARK: - Status Colors

    /// Success/complete state - Apple system green (#34C759)
    static let semanticSuccess = Color(hex: "#34C759")

    /// Error/failure state - Apple system red (#FF3B30)
    static let semanticFailure = Color(hex: "#FF3B30")

    /// Warning/caution state - Apple system orange (#FF9F0A)
    static let semanticWarning = Color(hex: "#FF9F0A")

    /// Info/active state - Apple system blue (#007AFF)
    static let semanticInfo = Color(hex: "#007AFF")

    /// Pending/inactive state - System gray
    static let semanticPending = Color.secondary

    // MARK: - Convenience Aliases

    /// Alias for semanticSuccess - used for checkmarks, completed items
    static let statusComplete = semanticSuccess

    /// Alias for semanticFailure - used for X marks, failed items
    static let statusError = semanticFailure

    /// Alias for semanticWarning - used for in-progress, attention items
    static let statusActive = semanticWarning

    /// Alias for semanticInfo - used for highlights, selections
    static let statusNormal = semanticInfo

    // MARK: - Background Variants

    /// Light success background for cards/badges
    static let successBackground = semanticSuccess.opacity(0.15)

    /// Light failure background for cards/badges
    static let failureBackground = semanticFailure.opacity(0.15)

    /// Light warning background for cards/badges
    static let warningBackground = semanticWarning.opacity(0.15)

    /// Light info background for cards/badges
    static let infoBackground = semanticInfo.opacity(0.15)
}

// MARK: - Status Enum Support

extension Color {
    /// Get semantic color for a status string
    static func forStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "success", "complete", "completed", "pass", "passed", "ok", "true":
            return .semanticSuccess
        case "error", "fail", "failed", "false":
            return .semanticFailure
        case "warning", "caution", "attention", "pending":
            return .semanticWarning
        case "info", "active", "running", "processing":
            return .semanticInfo
        default:
            return .semanticPending
        }
    }

    /// Get semantic color for a boolean match result
    static func forMatch(_ isMatch: Bool) -> Color {
        isMatch ? .semanticSuccess : .semanticFailure
    }
}
