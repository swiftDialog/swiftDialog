//
//  ComplianceComponents.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  Extracted from PresetCommonHelpers.swift
//  Compliance dashboard header, circular progress, compliance cards
//

import SwiftUI

// MARK: - Compliance Dashboard Components (Migrated from Preset5)

/// Compliance dashboard header with overall statistics
/// Migrated from Preset5 header for use in Preset6 guidance content
struct ComplianceDashboardHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let passed: Int
    let failed: Int
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds

    private var total: Int {
        passed + failed
    }

    private var score: Double {
        guard total > 0 else { return 0.0 }
        return Double(passed) / Double(total)
    }

    private var statusText: String {
        colorThresholds.getLabel(for: score)
    }

    private var statusColor: Color {
        colorThresholds.getColor(for: score)
    }

    var body: some View {
        VStack(spacing: 20 * scaleFactor) {
            // Icon and Title
            HStack(spacing: 20 * scaleFactor) {
                // Icon
                if let iconName = icon {
                    if iconName.hasPrefix("sf=") {
                        let sfSymbol = String(iconName.dropFirst(3))
                        Image(systemName: sfSymbol)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Image(systemName: iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                    Text(title)
                        .font(.system(size: 22 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                // Status badge
                Text(statusText)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 16 * scaleFactor)
                    .padding(.vertical, 8 * scaleFactor)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.15))
                    )
            }

            // Progress Bar Section
            VStack(spacing: 12 * scaleFactor) {
                // Stats row
                HStack(spacing: 32 * scaleFactor) {
                    // Passed
                    HStack(spacing: 8 * scaleFactor) {
                        Circle()
                            .fill(colorThresholds.getPositiveColor())
                            .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                        Text("Passed")
                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(passed)")
                            .font(.system(size: 16 * scaleFactor, weight: .bold, design: .monospaced))
                            .foregroundStyle(colorThresholds.getPositiveColor())
                    }

                    Spacer()

                    // Overall percentage
                    Text("\(Int(score * 100))%")
                        .font(.system(size: 20 * scaleFactor, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Failed
                    HStack(spacing: 8 * scaleFactor) {
                        Text("\(failed)")
                            .font(.system(size: 16 * scaleFactor, weight: .bold, design: .monospaced))
                            .foregroundStyle(colorThresholds.getNegativeColor())
                        Text("Failed")
                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(colorThresholds.getNegativeColor())
                            .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background bar
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 12 * scaleFactor)

                        // Progress bar
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        statusColor,
                                        statusColor.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geometry.size.width * score), height: 12 * scaleFactor)
                            .animation(.spring(response: 0.8, dampingFraction: 0.6), value: score)
                    }
                }
                .frame(height: 12 * scaleFactor)

                // Total count
                Text("Total: \(total) items")
                    .font(.system(size: 10 * scaleFactor, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 32 * scaleFactor)
        .padding(.vertical, 20 * scaleFactor)
        .background(
            RoundedRectangle(cornerRadius: 12 * scaleFactor)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12 * scaleFactor)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        )
        .id("compliance-header-\(passed)-\(failed)")  // Force re-render on data change
    }
}

/// Circular progress indicator with percentage display
/// Used in compliance cards to show category completion percentage
struct CircularProgressView: View {
    let progress: Double  // 0.0 to 1.0
    let color: Color
    let scaleFactor: CGFloat
    @State private var animateProgress = false

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 4 * scaleFactor)
                .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)

            // Progress circle
            Circle()
                .trim(from: 0, to: animateProgress ? progress : 0)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4 * scaleFactor, lineCap: .round)
                )
                .frame(width: 60 * scaleFactor, height: 60 * scaleFactor)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.6), value: animateProgress)

            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 12 * scaleFactor, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.1)) {
                animateProgress = true
            }
        }
        .id("circular-progress-\(progress)")  // Force re-render on progress change
    }
}

/// Compliance card displaying category metrics with circular progress
/// Migrated from Preset5 CategoryCardView for use in Preset6 guidance content
struct ComplianceCardView: View {
    let categoryName: String
    let passed: Int
    let total: Int
    let icon: String?
    let checkDetails: String?  // Optional: newline-separated check items to display inside card
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds

    private var score: Double {
        guard total > 0 else { return 0.0 }
        return Double(passed) / Double(total)
    }

    private var statusText: String {
        colorThresholds.getLabel(for: score)
    }

    private var statusColor: Color {
        colorThresholds.getColor(for: score)
    }

    /// Parse a check item to extract symbol, text, and status
    /// Format: "pass:Description" or "fail:Description"
    /// Returns: (symbol: String, text: String, isPassed: Bool, isFailed: Bool)
    private func parseCheckItem(_ item: String) -> (symbol: String, text: String, isPassed: Bool, isFailed: Bool) {
        let trimmed = item.trimmingCharacters(in: .whitespaces)

        // Check for keyword prefixes (ASCII-safe, shell-independent)
        if trimmed.lowercased().hasPrefix("pass:") {
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return ("✓", text, true, false)
        }

        if trimmed.lowercased().hasPrefix("fail:") {
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return ("✗", text, false, true)
        }

        // No status keyword - use neutral bullet point
        return ("•", trimmed, false, false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with category title and status badge
            HStack {
                HStack(spacing: 10 * scaleFactor) {
                    // Category icon (LARGER, more prominent)
                    if let iconName = icon {
                        Image(systemName: iconName)
                            .font(.system(size: 20 * scaleFactor, weight: .semibold))
                            .foregroundStyle(statusColor)
                    }

                    Text(categoryName)
                        .font(.system(size: 15 * scaleFactor, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }

                Spacer()

                // Status badge
                Text(statusText)
                    .font(.system(size: 10 * scaleFactor, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10 * scaleFactor)
                    .padding(.vertical, 4 * scaleFactor)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.12))
                    )
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.top, 14 * scaleFactor)
            .padding(.bottom, 12 * scaleFactor)

            Divider()
                .padding(.horizontal, 16 * scaleFactor)

            // Main content: Two-column layout like Preset 5 (CLEAN design)
            HStack(alignment: .top, spacing: 20 * scaleFactor) {
                // Left: Check details list (scrollable)
                if let details = checkDetails, !details.isEmpty {
                    // Split on | separator (pipe-delimited format for external scripts)
                    // Falls back to \n for backward compatibility with JSON-defined cards
                    let separator = details.contains("|") ? "|" : "\n"
                    let items = details.components(separatedBy: separator)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8 * scaleFactor) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                // Parse the check item to extract symbol, text, and status
                                let parsed = parseCheckItem(item)
                                let symbol = parsed.symbol
                                let text = parsed.text
                                let isPassed = parsed.isPassed
                                let isFailed = parsed.isFailed

                                HStack(alignment: .top, spacing: 8 * scaleFactor) {
                                    // Color-coded symbol
                                    Text(symbol)
                                        .font(.system(size: 10 * scaleFactor, weight: .semibold))
                                        .foregroundStyle(isPassed ? colorThresholds.getPositiveColor() :
                                                       isFailed ? colorThresholds.getNegativeColor() :
                                                       Color.secondary)
                                        .frame(width: 10 * scaleFactor, alignment: .leading)

                                    Text(text)
                                        .font(.system(size: 10 * scaleFactor, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2 * scaleFactor)

                                if index < items.count - 1 {
                                    Divider()
                                        .padding(.leading, 16 * scaleFactor)
                                        .padding(.vertical, 2 * scaleFactor)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 180 * scaleFactor)
                }

                // Right: Progress indicator and metrics
                VStack(spacing: 10 * scaleFactor) {
                    // Spacer to push content down (like Preset 5)
                    Spacer()
                        .frame(height: 20 * scaleFactor)

                    // Circular progress with percentage inside
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 3 * scaleFactor)
                            .frame(width: 50 * scaleFactor, height: 50 * scaleFactor)

                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(
                                statusColor,
                                style: StrokeStyle(lineWidth: 3 * scaleFactor, lineCap: .round)
                            )
                            .frame(width: 50 * scaleFactor, height: 50 * scaleFactor)
                            .rotationEffect(.degrees(-90))

                        // Percentage inside ring
                        Text("\(Int(score * 100))%")
                            .font(.system(size: 11 * scaleFactor, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    // Compact metrics (just numbers with dots)
                    VStack(spacing: 5 * scaleFactor) {
                        HStack(spacing: 5 * scaleFactor) {
                            Circle()
                                .fill(colorThresholds.getPositiveColor())
                                .frame(width: 4 * scaleFactor, height: 4 * scaleFactor)
                            Text("\(passed)")
                                .font(.system(size: 9 * scaleFactor, weight: .medium, design: .monospaced))
                                .foregroundStyle(colorThresholds.getPositiveColor())
                        }

                        HStack(spacing: 5 * scaleFactor) {
                            Circle()
                                .fill(colorThresholds.getNegativeColor())
                                .frame(width: 4 * scaleFactor, height: 4 * scaleFactor)
                            Text("\(total - passed)")
                                .font(.system(size: 9 * scaleFactor, weight: .medium, design: .monospaced))
                                .foregroundStyle(colorThresholds.getNegativeColor())
                        }
                    }

                    Spacer()
                }
                .frame(width: 80 * scaleFactor)
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.vertical, 12 * scaleFactor)
        }
        .background(
            ZStack(alignment: .leading) {
                // Main card background
                RoundedRectangle(cornerRadius: 16 * scaleFactor)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(
                        color: Color.black.opacity(0.06),
                        radius: 8 * scaleFactor,
                        x: 0,
                        y: 2 * scaleFactor
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16 * scaleFactor)
                            .stroke(
                                Color.gray.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            }
        )
        .id("compliance-card-\(categoryName)-\(passed)-\(total)-\(checkDetails ?? "")")  // Force re-render on data change
    }
}
