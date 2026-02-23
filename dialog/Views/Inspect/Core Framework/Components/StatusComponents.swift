//
//  StatusComponents.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  Extracted from PresetCommonHelpers.swift
//  Status badges, comparison tables, feature tables, phase trackers
//

import SwiftUI

// MARK: - Status Monitoring Components

/// Status badge showing binary or multi-state status with icon and color
/// Used for compliance checks, service status, feature states
struct StatusBadgeView: View {
    let label: String
    let state: String
    let icon: String?
    let autoColor: Bool
    let customColor: Color?
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    private var stateColor: Color {
        if let customColor = customColor {
            return customColor
        }

        if !autoColor {
            return .secondary
        }

        // Auto-color based on semantic state (prefix/contains matching for flexibility)
        let lowercaseState = state.lowercased()
        let successStates = ["enabled", "active", "pass", "success", "valid", "enrolled", "connected", "on", "true", "yes", "installed", "present", "compliant"]
        let failStates = ["disabled", "inactive", "fail", "failure", "invalid", "unenrolled", "disconnected", "off", "false", "no", "not found", "missing", "error", "non-compliant"]
        let pendingStates = ["pending", "in-progress", "waiting", "unknown", "partial", "checking"]

        // Check if state starts with or contains any success keywords
        if successStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState == $0 }) {
            return palette.success
        }
        // Check if state starts with or contains any fail keywords
        if failStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState.contains($0) }) {
            return palette.error
        }
        // Check if state matches any pending keywords
        if pendingStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState == $0 }) {
            return palette.warning
        }

        return .secondary
    }

    private var defaultIcon: String {
        let lowercaseState = state.lowercased()
        let successStates = ["enabled", "active", "pass", "success", "valid", "enrolled", "connected", "on", "true", "yes", "installed", "present", "compliant"]
        let failStates = ["disabled", "inactive", "fail", "failure", "invalid", "unenrolled", "disconnected", "off", "false", "no", "not found", "missing", "error", "non-compliant"]
        let pendingStates = ["pending", "in-progress", "waiting", "checking"]
        let unknownStates = ["unknown", "partial"]

        if successStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState == $0 }) {
            return "checkmark.circle.fill"
        }
        if failStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState.contains($0) }) {
            return "xmark.circle.fill"
        }
        if pendingStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState == $0 }) {
            return "clock.fill"
        }
        if unknownStates.contains(where: { lowercaseState.hasPrefix($0) || lowercaseState == $0 }) {
            return "questionmark.circle.fill"
        }

        return "circle.fill"
    }

    /// Renders the icon as a file-based image (if path exists on disk) or SF Symbol
    @ViewBuilder
    private var statusBadgeIcon: some View {
        if let iconPath = icon, isFilePath(iconPath),
           FileManager.default.fileExists(atPath: iconPath),
           let nsImage = NSImage(contentsOfFile: iconPath) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 4 * scaleFactor))
        } else {
            Image(systemName: icon ?? defaultIcon)
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(stateColor)
        }
    }

    /// Check if a string looks like a file path (starts with / or contains a file extension)
    private func isFilePath(_ value: String) -> Bool {
        value.hasPrefix("/") || (value.contains(".") && !value.hasPrefix("SF="))
    }

    var body: some View {
        let _ = writeLog("🟡 VIEW: StatusBadgeView rendering label='\(label)' state='\(state)' color=\(stateColor)", logLevel: .debug)

        return HStack(spacing: 8 * scaleFactor) {
            statusBadgeIcon
                .frame(width: 20 * scaleFactor, height: 20 * scaleFactor)

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)

                Text(state)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(stateColor)
                    .fontWeight(.semibold)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 60 * scaleFactor, alignment: .leading)
        .padding(.horizontal, 12 * scaleFactor)
        .padding(.vertical, 10 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(stateColor.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .stroke(stateColor.opacity(0.3), lineWidth: 1)
        )
    }
}

/// Comparison table showing expected vs actual values
/// Used for configuration validation, version checks, server comparisons
struct ComparisonTableView: View {
    let label: String
    let expected: String
    let actual: String
    let expectedLabel: String
    let actualLabel: String
    let expectedIcon: String?
    let actualIcon: String?
    let comparisonStyle: String?
    let highlightCells: Bool
    let autoColor: Bool
    let customColor: Color?
    let expectedColor: Color?
    let actualColor: Color?
    let scaleFactor: CGFloat
    let stateOverride: String?  // Optional: "pass", "fail", "pending" to override auto-match
    @Environment(\.palette) private var palette

    /// Smart comparison that handles common edge cases
    /// Can be overridden by stateOverride for evaluation types like withinSeconds, notExists
    private var isMatch: Bool {
        // Check for explicit state override first
        if let state = stateOverride?.lowercased() {
            switch state {
            case "pass", "passed", "success", "true", "yes", "enabled", "enrolled", "detected":
                return true
            case "fail", "failed", "failure", "false", "no", "disabled", "error", "not detected":
                return false
            default:
                break  // Fall through to auto-detect
            }
        }

        // Auto-detect based on string comparison
        let expectedNorm = normalizeForComparison(expected)
        let actualNorm = normalizeForComparison(actual)
        return expectedNorm == actualNorm
    }

    /// Normalize strings for flexible comparison
    /// Handles: URL protocols, trailing slashes, case differences
    private func normalizeForComparison(_ value: String) -> String {
        var normalized = value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common URL protocols
        let protocols = ["https://", "http://", "ftp://", "ftps://"]
        for proto in protocols where normalized.hasPrefix(proto) {
            normalized = String(normalized.dropFirst(proto.count))
            break
        }

        // Remove trailing slashes
        while normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }

        return normalized
    }

    private var comparisonColor: Color {
        if let customColor = customColor {
            return customColor
        }

        if !autoColor {
            return .secondary
        }

        return palette.colorForMatch(isMatch)
    }

    /// Effective color for expected column (with override support)
    private var effectiveExpectedColor: Color {
        if let expectedColor = expectedColor {
            return expectedColor
        }
        // Default to secondary (neutral) for expected column
        return .secondary
    }

    /// Effective color for actual column (with override support)
    private var effectiveActualColor: Color {
        if let actualColor = actualColor {
            return actualColor
        }
        // Default to match-based color
        return comparisonColor
    }

    /// Auto-assign SF Symbol icon based on match state or color semantics when not explicitly provided
    private func getIconForState(isExpected: Bool) -> String {
        if isExpected {
            // Expected value icon (always neutral)
            return "circle.fill"
        } else {
            // Actual value icon: Consider color override semantics first
            if let actualColor = actualColor {
                // When actualColor is specified, choose icon based on color semantics
                // This allows migration scenarios to show green/checkmark for "new" state
                // even when values don't match
                let nsColor = NSColor(actualColor)
                let red = nsColor.redComponent
                let green = nsColor.greenComponent
                let blue = nsColor.blueComponent

                // Check for standard swiftDialog colors by RGB components
                if abs(red - 0.204) < 0.01 && abs(green - 0.780) < 0.01 && abs(blue - 0.349) < 0.01 {
                    // Green #34C759 (0.204, 0.780, 0.349) → success/checkmark
                    return "checkmark.circle.fill"
                } else if abs(red - 1.0) < 0.01 && abs(green - 0.231) < 0.01 && abs(blue - 0.188) < 0.01 {
                    // Red #FF3B30 (1.0, 0.231, 0.188) → error/X
                    return "xmark.circle.fill"
                } else if abs(red - 1.0) < 0.01 && abs(green - 0.624) < 0.01 && abs(blue - 0.039) < 0.01 {
                    // Orange #FF9F0A (1.0, 0.624, 0.039) → warning
                    return "exclamationmark.triangle.fill"
                } else {
                    // Other colors → generic circle
                    return "circle.fill"
                }
            }

            // Default: icon based on match state
            return isMatch ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
    }

    /// Render stacked layout (existing behavior)
    private var stackedLayout: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            VStack(spacing: 6 * scaleFactor) {
                // Expected row
                HStack {
                    Text(expectedLabel + ":")
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80 * scaleFactor, alignment: .leading)

                    Text(expected)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8 * scaleFactor)
                        .padding(.vertical, 4 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .fill(Color.secondary.opacity(0.1))
                        )

                    Spacer()
                }

                // Actual row
                HStack {
                    Text(actualLabel + ":")
                        .font(.system(size: 12 * scaleFactor, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 80 * scaleFactor, alignment: .leading)

                    Text(actual)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(comparisonColor)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8 * scaleFactor)
                        .padding(.vertical, 4 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .fill(comparisonColor.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .stroke(comparisonColor.opacity(0.3), lineWidth: 1)
                        )

                    Image(systemName: isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 14 * scaleFactor))
                        .foregroundStyle(comparisonColor)

                    Spacer()
                }
            }
        }
        .padding(12 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(Color(.textBackgroundColor).opacity(0.5))
        )
    }

    /// Render columns layout (A | B side-by-side)
    private var columnsLayout: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            HStack(spacing: 12 * scaleFactor) {
                // Expected column
                VStack(spacing: 4 * scaleFactor) {
                    Text(expectedLabel)
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 6 * scaleFactor) {
                        if let icon = expectedIcon {
                            Image(systemName: icon)
                                .font(.system(size: 24 * scaleFactor))
                                .foregroundStyle(expectedColor != nil ? effectiveExpectedColor : .secondary)
                                .frame(height: 24 * scaleFactor)
                        }

                        Text(expected)
                            .font(.system(size: highlightCells ? 14 * scaleFactor : 12 * scaleFactor, weight: highlightCells ? .bold : .regular))
                            .foregroundStyle(expectedColor != nil ? effectiveExpectedColor : .primary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60 * scaleFactor, alignment: .center)
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(expectedColor != nil ? effectiveExpectedColor.opacity(highlightCells ? 0.2 : 0.1) : Color.secondary.opacity(highlightCells ? 0.15 : 0.1))
                    )
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1)

                // Actual column
                VStack(spacing: 4 * scaleFactor) {
                    Text(actualLabel)
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 6 * scaleFactor) {
                        if let icon = actualIcon {
                            Image(systemName: icon)
                                .font(.system(size: 24 * scaleFactor))
                                .foregroundStyle(effectiveActualColor)
                                .frame(height: 24 * scaleFactor)
                        } else {
                            // Auto-assign icon based on match
                            Image(systemName: getIconForState(isExpected: false))
                                .font(.system(size: 24 * scaleFactor))
                                .foregroundStyle(effectiveActualColor)
                                .frame(height: 24 * scaleFactor)
                        }

                        Text(actual)
                            .font(.system(size: highlightCells ? 14 * scaleFactor : 12 * scaleFactor, weight: highlightCells ? .bold : .semibold))
                            .foregroundStyle(effectiveActualColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60 * scaleFactor, alignment: .center)
                    .padding(10 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(effectiveActualColor.opacity(highlightCells ? 0.2 : 0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .stroke(effectiveActualColor.opacity(highlightCells ? 0.4 : 0.3), lineWidth: highlightCells ? 2 : 1.5)
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 8 * scaleFactor)
                .fill(Color(.textBackgroundColor).opacity(0.5))
        )
    }

    var body: some View {
        let _ = writeLog("🟡 VIEW: ComparisonTableView rendering label='\(label)' actual='\(actual)' match=\(isMatch) color=\(comparisonColor) style=\(comparisonStyle ?? "stacked")", logLevel: .debug)

        return Group {
            if comparisonStyle == "columns" {
                columnsLayout
            } else {
                stackedLayout
            }
        }
    }
}

/// Comparison group for organizing related comparisons under collapsible categories
/// Used for CIS compliance, security baselines, multi-section configurations
struct ComparisonGroupView: View {
    let category: String
    let comparisons: [InspectConfig.GuidanceContent]
    let scaleFactor: CGFloat
    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            // Category header (collapsible)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 8 * scaleFactor) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12 * scaleFactor)

                    Text(category)
                        .font(.system(size: 14 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Summary badge (count of items)
                    Text("\(comparisons.count)")
                        .font(.system(size: 11 * scaleFactor, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6 * scaleFactor)
                        .padding(.vertical, 2 * scaleFactor)
                        .background(
                            RoundedRectangle(cornerRadius: 4 * scaleFactor)
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
                .padding(.horizontal, 12 * scaleFactor)
                .padding(.vertical, 10 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 8 * scaleFactor)
                        .fill(Color(.textBackgroundColor).opacity(0.3))
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            // Expandable comparison items
            if isExpanded {
                VStack(spacing: 8 * scaleFactor) {
                    ForEach(Array(comparisons.enumerated()), id: \.offset) { index, comparison in
                        if comparison.type == "comparison-table",
                           let label = comparison.label ?? comparison.content,
                           let expected = comparison.expected,
                           let actual = comparison.actual {

                            let autoColor = comparison.autoColor ?? true
                            let customColor: Color? = {
                                if let colorHex = comparison.color {
                                    return Color(hex: colorHex)
                                }
                                return nil
                            }()

                            ComparisonTableView(
                                label: label,
                                expected: expected,
                                actual: actual,
                                expectedLabel: comparison.expectedLabel ?? "Expected",
                                actualLabel: comparison.actualLabel ?? "Actual",
                                expectedIcon: comparison.expectedIcon,
                                actualIcon: comparison.actualIcon,
                                comparisonStyle: comparison.comparisonStyle,
                                highlightCells: comparison.highlightCells ?? false,
                                autoColor: autoColor,
                                customColor: customColor,
                                expectedColor: comparison.expectedColor.flatMap { Color(hex: $0) },
                                actualColor: comparison.actualColor.flatMap { Color(hex: $0) },
                                scaleFactor: scaleFactor,
                                stateOverride: comparison.state
                            )
                            .id("comparison-group-\(category)-\(index)-\(actual)-\(comparison.state ?? "")")
                        }
                    }
                }
                .padding(.leading, 20 * scaleFactor)
                .transition(.opacity)
            }
        }
    }
}

/// Feature comparison table showing checkmark/X indicators across columns
/// Used for comparing features between products, services, or options (e.g., Safari vs Chrome privacy features)
struct FeatureTableView: View {
    let columns: [InspectConfig.GuidanceContent.FeatureTableColumn]
    let rows: [InspectConfig.GuidanceContent.FeatureTableRow]
    let style: String?
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    private var isDarkStyle: Bool {
        style == "dark"
    }

    private var backgroundColor: Color {
        isDarkStyle ? Color.black.opacity(0.85) : Color(.textBackgroundColor).opacity(0.5)
    }

    private var textColor: Color {
        isDarkStyle ? .white : .primary
    }

    private var secondaryTextColor: Color {
        isDarkStyle ? .white.opacity(0.7) : .secondary
    }

    private var dividerColor: Color {
        isDarkStyle ? Color.white.opacity(0.2) : Color.secondary.opacity(0.3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row with column labels
            HStack(spacing: 0) {
                // Empty space for feature column
                Spacer()
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Column headers (right-aligned)
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(spacing: 4 * scaleFactor) {
                        if let icon = column.icon {
                            Image(systemName: icon)
                                .font(.system(size: 20 * scaleFactor))
                                .foregroundStyle(secondaryTextColor)
                        }
                        Text(column.label)
                            .font(.system(size: 12 * scaleFactor, weight: .semibold))
                            .foregroundStyle(textColor)
                    }
                    .frame(width: 80 * scaleFactor)
                }
            }
            .padding(.horizontal, 12 * scaleFactor)
            .padding(.vertical, 10 * scaleFactor)

            // Divider
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            // Feature rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Feature text (left-aligned)
                        Text(row.feature)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(textColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Value indicators for each column
                        ForEach(Array(row.values.prefix(columns.count).enumerated()), id: \.offset) { _, value in
                            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 18 * scaleFactor))
                                .foregroundStyle(value ? palette.success : palette.error)
                                .frame(width: 80 * scaleFactor)
                        }
                    }
                    .padding(.horizontal, 12 * scaleFactor)
                    .padding(.vertical, 10 * scaleFactor)

                    // Row divider (except for last row)
                    if rowIndex < rows.count - 1 {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)
                            .padding(.leading, 12 * scaleFactor)
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10 * scaleFactor)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10 * scaleFactor)
                .stroke(dividerColor, lineWidth: 1)
        )
    }
}

/// Phase tracker showing multi-step progress
/// Used for workflows like MDM migration, software installation, onboarding
struct PhaseTrackerView: View {
    let currentPhase: Int
    let phases: [String]
    let style: String
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    private var defaultPhaseLabels: [String] {
        ["Prepare", "Execute", "Verify", "Complete"]
    }

    private var phaseLabels: [String] {
        phases.isEmpty ? defaultPhaseLabels : phases
    }

    var body: some View {
        if style == "progress" {
            progressBarStyle
        } else if style == "checklist" {
            checklistStyle
        } else {
            stepperStyle // default
        }
    }

    // Stepper style - horizontal numbered steps
    private var stepperStyle: some View {
        HStack(spacing: 0) {
            ForEach(0..<phaseLabels.count, id: \.self) { index in
                let phaseNum = index + 1
                let isActive = phaseNum == currentPhase
                let isCompleted = phaseNum < currentPhase

                HStack(spacing: 8 * scaleFactor) {
                    // Phase circle
                    ZStack {
                        Circle()
                            .fill(isCompleted ? palette.success :
                                    isActive ? palette.warning :
                                  Color.secondary.opacity(0.3))
                            .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)

                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12 * scaleFactor, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(phaseNum)")
                                .font(.system(size: 12 * scaleFactor, weight: .bold))
                                .foregroundStyle(isActive ? .white : .secondary)
                        }
                    }

                    // Phase label
                    Text(phaseLabels[index])
                        .font(.system(size: 11 * scaleFactor, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? .primary : .secondary)

                    // Connector line (except for last item)
                    if index < phaseLabels.count - 1 {
                        Rectangle()
                            .fill(phaseNum < currentPhase ? palette.success : Color.secondary.opacity(0.3))
                            .frame(width: 20 * scaleFactor, height: 2 * scaleFactor)
                    }
                }
            }
        }
        .padding(12 * scaleFactor)
    }

    // Progress bar style
    private var progressBarStyle: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            HStack {
                Text("Phase \(currentPhase) of \(phaseLabels.count)")
                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(phaseLabels[safe: currentPhase - 1] ?? "")
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: Double(currentPhase), total: Double(phaseLabels.count))
                .progressViewStyle(LinearProgressViewStyle())
                .tint(palette.warning)
        }
        .padding(12 * scaleFactor)
    }

    // Checklist style - vertical checkboxes
    private var checklistStyle: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            ForEach(0..<phaseLabels.count, id: \.self) { index in
                let phaseNum = index + 1
                let isActive = phaseNum == currentPhase
                let isCompleted = phaseNum < currentPhase

                HStack(spacing: 8 * scaleFactor) {
                    Image(systemName: isCompleted ? "checkmark.square.fill" :
                          isActive ? "square.fill" :
                          "square")
                        .font(.system(size: 16 * scaleFactor))
                        .foregroundStyle(isCompleted ? palette.success :
                                       isActive ? palette.warning : Color.secondary)

                    Text(phaseLabels[index])
                        .font(.system(size: 12 * scaleFactor, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? .primary : .secondary)

                    Spacer()
                }
            }
        }
        .padding(12 * scaleFactor)
    }
}
