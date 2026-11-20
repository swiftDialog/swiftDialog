//
//  SemanticColors.swift
//  Dialog
//
//  Semantic status colours for the inspect framework, matching the system colours.
//

import SwiftUI

/// Semantic colors for status indicators and UI elements.
extension Color {

    // MARK: - Status Colors

    // The system colours, not their light-mode hex values: AppKit resolves each for light, dark and
    // increased contrast (systemGreen is #34C759 light, #30D158 dark).

    /// Success/complete state - system green
    static let semanticSuccess = Color(nsColor: .systemGreen)

    /// Error/failure state - system red
    static let semanticFailure = Color(nsColor: .systemRed)

    /// Warning/caution state - system orange
    static let semanticWarning = Color(nsColor: .systemOrange)

    /// Info/active state - system blue
    static let semanticInfo = Color(nsColor: .systemBlue)

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

    /// Light success background for cards/badges. 8% keeps text contrast without a second foreground colour.
    static let successBackground = semanticSuccess.opacity(0.08)

    /// Light failure background for cards/badges
    static let failureBackground = semanticFailure.opacity(0.08)

    /// Light warning background for cards/badges
    static let warningBackground = semanticWarning.opacity(0.08)

    /// Light info background for cards/badges
    static let infoBackground = semanticInfo.opacity(0.08)
}

// MARK: - Status Enum Support

extension Color {
    /// Get semantic color for a boolean match result
    static func forMatch(_ isMatch: Bool) -> Color {
        isMatch ? .semanticSuccess : .semanticFailure
    }
}

// MARK: - StatusGlyph → palette

/// Inspect's palette-aware reading of a `StatusGlyph`. Additive: `StatusGlyph.color` is shared
/// with classic Dialog and stays unchanged. `.error` and `.pending` fall through to the system
/// map because no inspect site constructs them.
extension StatusGlyph {
    func paletteColor(_ palette: ResolvedPalette) -> Color {
        switch self {
        case .success: palette.success
        case .failure: palette.error
        case .warning: palette.warning
        case .error, .pending: color
        }
    }

    /// The active/running tint: the accent, so a spinner matches the chip wash and status word.
    static func paletteActiveColor(_ palette: ResolvedPalette) -> Color {
        palette.accent
    }
}
