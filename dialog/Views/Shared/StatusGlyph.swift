//
//  StatusGlyph.swift
//  dialog
//
//  Canonical status → symbol/color map shared by classic dialog (ListView status icons) and
//  inspect presets. Only the map is shared; each call site keeps its own shape, and states drawn
//  as shapes (spinners, rings) stay at their call sites.
//

import SwiftUI

enum StatusGlyph {
    case success
    case failure
    /// Inspect's "completed with validation warning". No classic counterpart.
    case warning
    /// Classic listitem "error", distinct from `failure`. No inspect counterpart.
    case error
    /// Classic listitem "pending". Inspect presets draw pending as shapes and skip the map.
    case pending

    /// Self-colored symbol — rows, pills, and classic list images.
    var symbol: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .warning: "exclamationmark.circle.fill"
        case .error: "exclamationmark.circle.fill"
        case .pending: "ellipsis.circle.fill"
        }
    }

    /// Bare symbol for white-glyph-on-colored-disc rendering (StatusIndicatorCircle).
    /// nil where no disc form exists in the codebase.
    var discSymbol: String? {
        switch self {
        case .success: "checkmark"
        case .failure: "xmark"
        case .warning: "exclamationmark"
        case .error, .pending: nil
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failure: .red
        case .warning: .orange
        case .error: .yellow
        case .pending: .gray
        }
    }

    /// Tint for active/installing states, always drawn as a shape, never a glyph.
    static let activeColor: Color = .blue

    /// Classic listitem status vocabulary ("success" / "fail" / "error" / "pending"). "wait",
    /// "progress", "" and custom "<symbol>-<color>" strings are not map states; callers handle them first.
    init?(classicListStatus: String) {
        switch classicListStatus {
        case "success": self = .success
        case "fail": self = .failure
        case "error": self = .error
        case "pending": self = .pending
        default: return nil
        }
    }
}
