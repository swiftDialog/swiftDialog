//
//  ComplianceComponents.swift
//  dialog
//
//  Compliance dashboard header and category cards, used by guidance content.
//

import SwiftUI

// MARK: - Compliance Dashboard Components

/// Compliance dashboard header with overall statistics.
struct ComplianceDashboardHeader: View {
    @Environment(\.palette) private var palette
    /// nil falls back to the translatable `ui.complianceHeaderTitle` key.
    let title: String?
    let subtitle: String?
    let icon: String?
    let passed: Int
    let failed: Int
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds
    @Environment(\.inspectLocalization) private var l10n

    private var resolvedTitle: String {
        title ?? l10n("ui.complianceHeaderTitle", "Compliance Dashboard")
    }

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
        colorThresholds.getColor(for: score, palette: palette)
    }

    var body: some View {
        VStack(spacing: 20 * scaleFactor) {
            HStack(spacing: 20 * scaleFactor) {
                if let iconName = icon {
                    if let sfSymbol = IconRef.symbol(iconName) {
                        Image(systemName: sfSymbol)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                            .foregroundStyle(Color.accentColor)
                    } else {
                        Image(systemName: iconName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64 * scaleFactor, height: 64 * scaleFactor)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                    Text(resolvedTitle)
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

            VStack(spacing: 12 * scaleFactor) {
                HStack(spacing: 32 * scaleFactor) {
                    HStack(spacing: 8 * scaleFactor) {
                        Circle()
                            .fill(colorThresholds.getPositiveColor(palette: palette))
                            .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                        Text("Passed")
                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("\(passed)")
                            .font(.system(size: 16 * scaleFactor, weight: .bold, design: .monospaced))
                            .foregroundStyle(colorThresholds.getPositiveColor(palette: palette))
                    }

                    Spacer()

                    Text("\(Int(score * 100))%")
                        .font(.system(size: 20 * scaleFactor, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()

                    HStack(spacing: 8 * scaleFactor) {
                        Text("\(failed)")
                            .font(.system(size: 16 * scaleFactor, weight: .bold, design: .monospaced))
                            .foregroundStyle(colorThresholds.getNegativeColor(palette: palette))
                        Text("Failed")
                            .font(.system(size: 11 * scaleFactor, weight: .medium))
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(colorThresholds.getNegativeColor(palette: palette))
                            .frame(width: 8 * scaleFactor, height: 8 * scaleFactor)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6 * scaleFactor)
                            .fill(palette.text.opacity(0.2))
                            .frame(height: 12 * scaleFactor)

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
                        .stroke(palette.text.opacity(0.1), lineWidth: 1)
                )
        )
        .id("compliance-header-\(passed)-\(failed)")
    }
}

/// Compliance card for one category: check list, ring and counts; taps open a detail sheet.
struct ComplianceCardView: View {
    @Environment(\.palette) private var palette
    let categoryName: String
    let passed: Int
    let total: Int
    let icon: String?
    let checkDetails: String?  // check items, `|` or newline separated
    let scaleFactor: CGFloat
    let colorThresholds: InspectConfig.ColorThresholds
    /// Tint for the drill-down sheet this card opens.
    var accentColor: Color = .accentColor

    /// Tappable only when there is something to drill into.
    private var hasDetails: Bool {
        guard let checkDetails else { return false }
        return !checkDetails.isEmpty
    }

    @State private var showingDetail = false

    private var score: Double {
        guard total > 0 else { return 0.0 }
        return Double(passed) / Double(total)
    }

    private var statusText: String {
        colorThresholds.getLabel(for: score)
    }

    private var statusColor: Color {
        colorThresholds.getColor(for: score, palette: palette)
    }

    /// Parse a check item into symbol, text and status. Scripts author `pass:`/`fail:` prefixes;
    /// the aggregator emits glyph prefixes, so both are recognised and stripped.
    private func parseCheckItem(_ item: String) -> (symbol: String, text: String, isPassed: Bool, isFailed: Bool) {
        let trimmed = item.trimmingCharacters(in: .whitespaces)

        if trimmed.lowercased().hasPrefix("pass:") {
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return ("✓", text, true, false)
        }

        if trimmed.lowercased().hasPrefix("fail:") {
            let text = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            return ("✗", text, false, true)
        }

        for glyph in ["✓", "✅"] where trimmed.hasPrefix(glyph) {
            return ("✓", String(trimmed.dropFirst(glyph.count)).trimmingCharacters(in: .whitespaces), true, false)
        }

        for glyph in ["✗", "❌"] where trimmed.hasPrefix(glyph) {
            return ("✗", String(trimmed.dropFirst(glyph.count)).trimmingCharacters(in: .whitespaces), false, true)
        }

        return ("•", trimmed, false, false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 10 * scaleFactor) {
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

                Text(statusText)
                    .font(.system(size: 10 * scaleFactor, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10 * scaleFactor)
                    .padding(.vertical, 4 * scaleFactor)
                    .background(
                        Capsule()
                            .fill(statusColor.opacity(0.12))
                    )

                if hasDetails {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16 * scaleFactor)
            .padding(.top, 14 * scaleFactor)
            .padding(.bottom, 12 * scaleFactor)

            Divider()
                .padding(.horizontal, 16 * scaleFactor)

            HStack(alignment: .top, spacing: 20 * scaleFactor) {
                if let details = checkDetails, !details.isEmpty {
                    // `|` is the script format; newline-separated JSON cards still parse.
                    let separator = details.contains("|") ? "|" : "\n"
                    let items = details.components(separatedBy: separator)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8 * scaleFactor) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                let parsed = parseCheckItem(item)
                                let symbol = parsed.symbol
                                let text = parsed.text
                                let isPassed = parsed.isPassed
                                let isFailed = parsed.isFailed

                                HStack(alignment: .top, spacing: 8 * scaleFactor) {
                                    Text(symbol)
                                        .font(.system(size: 10 * scaleFactor, weight: .semibold))
                                        .foregroundStyle(isPassed ? colorThresholds.getPositiveColor(palette: palette) :
                                                       isFailed ? colorThresholds.getNegativeColor(palette: palette) :
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

                VStack(spacing: 10 * scaleFactor) {
                    Spacer()
                        .frame(height: 20 * scaleFactor)

                    ZStack {
                        Circle()
                            .stroke(palette.text.opacity(0.15), lineWidth: 3 * scaleFactor)
                            .frame(width: 50 * scaleFactor, height: 50 * scaleFactor)

                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(
                                statusColor,
                                style: StrokeStyle(lineWidth: 3 * scaleFactor, lineCap: .round)
                            )
                            .frame(width: 50 * scaleFactor, height: 50 * scaleFactor)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(score * 100))%")
                            .font(.system(size: 11 * scaleFactor, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    VStack(spacing: 5 * scaleFactor) {
                        HStack(spacing: 5 * scaleFactor) {
                            Circle()
                                .fill(colorThresholds.getPositiveColor(palette: palette))
                                .frame(width: 4 * scaleFactor, height: 4 * scaleFactor)
                            Text("\(passed)")
                                .font(.system(size: 9 * scaleFactor, weight: .medium, design: .monospaced))
                                .foregroundStyle(colorThresholds.getPositiveColor(palette: palette))
                        }

                        HStack(spacing: 5 * scaleFactor) {
                            Circle()
                                .fill(colorThresholds.getNegativeColor(palette: palette))
                                .frame(width: 4 * scaleFactor, height: 4 * scaleFactor)
                            Text("\(total - passed)")
                                .font(.system(size: 9 * scaleFactor, weight: .medium, design: .monospaced))
                                .foregroundStyle(colorThresholds.getNegativeColor(palette: palette))
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
                // No shadow: fill plus hairline matches the header card above it.
                RoundedRectangle(cornerRadius: 16 * scaleFactor)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16 * scaleFactor)
                            .stroke(
                                palette.text.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            }
        )
        .id("compliance-card-\(categoryName)-\(passed)-\(total)-\(checkDetails ?? "")")
        .contentShape(Rectangle())
        .onTapGesture {
            if hasDetails { showingDetail = true }
        }
        .sheet(isPresented: $showingDetail) {
            ComplianceDetailView(
                categoryName: categoryName,
                icon: icon,
                passed: passed,
                total: total,
                checkDetails: checkDetails ?? "",
                accentColor: accentColor
            )
        }
    }
}
