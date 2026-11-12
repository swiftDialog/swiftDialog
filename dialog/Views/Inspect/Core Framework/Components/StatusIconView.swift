//
//  StatusIconView.swift
//  Dialog
//
//  The inline status icon (check, cross, warning, clock) inspect views share.
//

import SwiftUI

// MARK: - Status Icon View

/// An SF Symbol for a status, colored from the palette.
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

/// The statuses `StatusIconView` can draw; synonyms share an icon and color.
enum StatusIconType {
    case success
    case complete
    case pass

    case failure
    case error
    case fail

    case warning
    case caution

    case pending
    case waiting
    case unknown

    case active
    case inProgress
    case info

    case empty

    case custom(iconName: String, color: Color?)

    static func forMatch(_ isMatch: Bool) -> StatusIconType {
        isMatch ? .success : .failure
    }
}

// MARK: - Conditional Status Icon

