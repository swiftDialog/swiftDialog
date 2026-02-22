//
//  ResolvedPalette.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH
//
//  Environment-based brand palette that cascades through the SwiftUI view hierarchy.
//  Set once at the preset root via .environment(\.palette, ...) — all child views
//  read brand colors automatically via @Environment(\.palette).
//

import SwiftUI

/// Resolved brand palette with concrete SwiftUI Color values.
/// Initialized from `InspectConfig.BrandPalette` (JSON) with Apple HIG fallbacks.
struct ResolvedPalette {
    let primary: Color
    let secondary: Color
    let accent: Color
    let success: Color
    let warning: Color
    let error: Color
    let info: Color

    // MARK: - Background Variants (0.15 opacity)

    var successBackground: Color { success.opacity(0.15) }
    var warningBackground: Color { warning.opacity(0.15) }
    var errorBackground: Color { error.opacity(0.15) }
    var infoBackground: Color { info.opacity(0.15) }

    // MARK: - Defaults (Apple HIG system colors)

    static let `default` = ResolvedPalette(
        primary: .accentColor,
        secondary: .secondary,
        accent: .accentColor,
        success: .semanticSuccess,
        warning: .semanticWarning,
        error: .semanticFailure,
        info: .semanticInfo
    )

    // MARK: - Init from BrandPalette config

    /// Build a resolved palette from the optional JSON config.
    /// Any nil field falls back to the Apple HIG default.
    init(from palette: InspectConfig.BrandPalette?, primaryColor: Color = .accentColor) {
        self.primary = palette?.primary.map { Color(hex: $0) } ?? primaryColor
        self.secondary = palette?.secondary.map { Color(hex: $0) } ?? .secondary
        self.accent = palette?.accent.map { Color(hex: $0) } ?? primaryColor
        self.success = palette?.success.map { Color(hex: $0) } ?? .semanticSuccess
        self.warning = palette?.warning.map { Color(hex: $0) } ?? .semanticWarning
        self.error = palette?.error.map { Color(hex: $0) } ?? .semanticFailure
        self.info = palette?.info.map { Color(hex: $0) } ?? .semanticInfo
    }

    /// Memberwise init for direct construction
    init(primary: Color, secondary: Color, accent: Color,
         success: Color, warning: Color, error: Color, info: Color) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
    }

    // MARK: - Status Color Lookup

    /// Get the palette color for a status string (success/error/warning/info/pending).
    func colorForStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "success", "complete", "completed", "pass", "passed", "ok", "true":
            return success
        case "error", "fail", "failed", "false":
            return error
        case "warning", "caution", "attention", "pending":
            return warning
        case "info", "active", "running", "processing":
            return info
        default:
            return .semanticPending
        }
    }

    /// Get palette color for a boolean match result
    func colorForMatch(_ isMatch: Bool) -> Color {
        isMatch ? success : error
    }
}

// MARK: - SwiftUI Environment Key

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = ResolvedPalette.default
}

extension EnvironmentValues {
    var palette: ResolvedPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
