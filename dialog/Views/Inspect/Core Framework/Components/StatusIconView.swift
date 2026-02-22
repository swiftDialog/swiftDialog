//
//  StatusIconView.swift
//  Dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 19/01/2026
//
//  Unified inline status icon rendering for the Inspect framework
//  Consolidates 60+ instances of inline checkmark/xmark/spinner patterns
//

import SwiftUI

// MARK: - Status Icon View

/// Simple inline status icon with semantic coloring
/// Use this for individual status indicators (checkmarks, X marks, spinners)
struct StatusIconView: View {
    let status: StatusIconType
    let size: CGFloat
    let filled: Bool
    @Environment(\.palette) private var palette

    init(_ status: StatusIconType, size: CGFloat = 16, filled: Bool = true) {
        self.status = status
        self.size = size
        self.filled = filled
    }

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: size))
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        switch status {
        case .success, .complete, .pass:
            return filled ? "checkmark.circle.fill" : "checkmark.circle"
        case .failure, .error, .fail:
            return filled ? "xmark.circle.fill" : "xmark.circle"
        case .warning, .caution:
            return filled ? "exclamationmark.triangle.fill" : "exclamationmark.triangle"
        case .pending, .waiting:
            return filled ? "clock.fill" : "clock"
        case .active, .inProgress:
            return filled ? "circle.fill" : "circle"
        case .info:
            return filled ? "info.circle.fill" : "info.circle"
        case .unknown:
            return filled ? "questionmark.circle.fill" : "questionmark.circle"
        case .empty:
            return "circle"
        case .custom(let name, _):
            return name
        }
    }

    private var iconColor: Color {
        switch status {
        case .success, .complete, .pass:
            return palette.success
        case .failure, .error, .fail:
            return palette.error
        case .warning, .caution:
            return palette.warning
        case .pending, .waiting, .unknown:
            return .secondary
        case .active, .inProgress, .info:
            return palette.info
        case .empty:
            return .secondary.opacity(0.5)
        case .custom(_, let color):
            return color ?? .secondary
        }
    }
}

// MARK: - Status Icon Type

/// Enumeration of status icon types
enum StatusIconType {
    // Success states
    case success
    case complete
    case pass

    // Failure states
    case failure
    case error
    case fail

    // Warning states
    case warning
    case caution

    // Pending states
    case pending
    case waiting
    case unknown

    // Active states
    case active
    case inProgress
    case info

    // Empty state
    case empty

    // Custom icon with optional color
    case custom(iconName: String, color: Color?)

    /// Create from boolean match value
    static func forMatch(_ isMatch: Bool) -> StatusIconType {
        isMatch ? .success : .failure
    }

    /// Create from status string
    static func forStatus(_ status: String) -> StatusIconType {
        let lowercased = status.lowercased()
        switch lowercased {
        case "success", "complete", "completed", "pass", "passed", "ok", "true", "yes", "valid":
            return .success
        case "failure", "error", "fail", "failed", "false", "no", "invalid":
            return .failure
        case "warning", "caution", "attention":
            return .warning
        case "pending", "waiting":
            return .pending
        case "active", "running", "processing", "in_progress", "inprogress":
            return .active
        case "info":
            return .info
        case "unknown":
            return .unknown
        default:
            return .pending
        }
    }
}

// MARK: - Convenience Views

/// Checkmark icon with success color
struct CheckmarkIcon: View {
    let size: CGFloat
    let filled: Bool

    init(size: CGFloat = 16, filled: Bool = true) {
        self.size = size
        self.filled = filled
    }

    var body: some View {
        StatusIconView(.success, size: size, filled: filled)
    }
}

/// X mark icon with failure color
struct XMarkIcon: View {
    let size: CGFloat
    let filled: Bool

    init(size: CGFloat = 16, filled: Bool = true) {
        self.size = size
        self.filled = filled
    }

    var body: some View {
        StatusIconView(.failure, size: size, filled: filled)
    }
}

/// Warning icon with warning color
struct WarningIcon: View {
    let size: CGFloat
    let filled: Bool

    init(size: CGFloat = 16, filled: Bool = true) {
        self.size = size
        self.filled = filled
    }

    var body: some View {
        StatusIconView(.warning, size: size, filled: filled)
    }
}

/// Match result icon - checkmark for true, X for false
struct MatchIcon: View {
    let isMatch: Bool
    let size: CGFloat
    let filled: Bool

    init(_ isMatch: Bool, size: CGFloat = 16, filled: Bool = true) {
        self.isMatch = isMatch
        self.size = size
        self.filled = filled
    }

    var body: some View {
        StatusIconView(.forMatch(isMatch), size: size, filled: filled)
    }
}

// MARK: - Spinner View

/// Animated spinner for loading/processing states
struct StatusSpinnerView: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 16, color: Color = .blue) {
        self.size = size
        self.color = color
    }

    var body: some View {
        ProgressView()
            .controlSize(controlSize)
            .tint(color)
    }

    private var controlSize: ControlSize {
        if size <= 12 {
            return .mini
        } else if size <= 16 {
            return .small
        } else {
            return .regular
        }
    }
}

// MARK: - Conditional Status Icon

/// Icon that shows either a status or a spinner based on loading state
struct ConditionalStatusIcon: View {
    let isLoading: Bool
    let status: StatusIconType
    let size: CGFloat
    let filled: Bool

    init(isLoading: Bool, status: StatusIconType, size: CGFloat = 16, filled: Bool = true) {
        self.isLoading = isLoading
        self.status = status
        self.size = size
        self.filled = filled
    }

    var body: some View {
        if isLoading {
            StatusSpinnerView(size: size)
        } else {
            StatusIconView(status, size: size, filled: filled)
        }
    }
}
