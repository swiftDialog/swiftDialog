//
//  GuidanceStatChecklistBlocks.swift
//  dialog
//
//  "stat-row" and "checklist" guidance blocks, shared by Preset 5 and 6 steps, the Preset 1/2 phase
//  screens. Values come from config or measured tokens; nothing is invented.

import SwiftUI

// MARK: - Stat row (type: "stat-row")

/// Horizontal strip of equal-width stat tiles: big figure over a caption. `style` picks the alternate
/// card form; absent draws the strip.
struct GuidanceStatRowBlock: View {
    enum Form: Equatable { case row, card }

    let stats: [InspectConfig.GuidanceContent.StatCell]
    let scaleFactor: CGFloat
    /// The raw `"style"` value; only `resolveForm` interprets it.
    var style: String?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.palette) private var palette

    private var tileColor: Color { palette.surfaceRaised }

    /// A cell's tile fill: its state's 15% tinted background (matching callouts), or the neutral surface.
    private func tileFill(for cell: InspectConfig.GuidanceContent.StatCell) -> Color {
        switch cell.state?.lowercased() {
        case "ok", "success", "pass":     return palette.successBackground
        case "warning", "warn":           return palette.warningBackground
        case "error", "fail", "failed":   return palette.error.opacity(0.15)
        case "info":                      return palette.infoBackground
        default:                          return tileColor
        }
    }

    /// The figure's colour; a tinted tile carries a tinted number.
    private func valueColor(for cell: InspectConfig.GuidanceContent.StatCell) -> Color {
        switch cell.state?.lowercased() {
        case "ok", "success", "pass":     return palette.success
        case "warning", "warn":           return palette.warning
        case "error", "fail", "failed":   return palette.error
        case "info":                      return palette.info
        default:                          return palette.text
        }
    }
    private var hairline: Color { palette.hairline }

    /// The row/card decision, which `body` switches on, so tests can assert it without rendering.
    static func resolveForm(style: String?) -> Form {
        style == "card" ? .card : .row
    }

    var body: some View {
        switch Self.resolveForm(style: style) {
        case .row:
            rowBody
        case .card:
            cardBody
        }
    }

    private var rowBody: some View {
        HStack(spacing: 12 * scaleFactor) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, cell in
                VStack(alignment: .leading, spacing: 3) {
                    Text(cell.value)
                        .font(.system(size: 22 * scaleFactor, weight: .bold))
                        .foregroundStyle(valueColor(for: cell))
                        .tracking(-0.5)
                        .lineLimit(1)
                    Text(cell.label)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16 * scaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                // One fixed height for the row, so a two-line label does not make its tile taller.
                .frame(height: 84 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(tileFill(for: cell))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(hairline, lineWidth: 0.5)
                        )
                )
            }
        }
        .frame(maxWidth: 560 * scaleFactor)
    }

    /// Mono uppercase label over bold value in a two-column `LazyVGrid`, so 1, 3 or 4 stats wrap cleanly.
    private var cardBody: some View {
        let columns = [
            GridItem(.flexible(), spacing: 12 * scaleFactor),
            GridItem(.flexible())
        ]
        return LazyVGrid(columns: columns, spacing: 12 * scaleFactor) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, cell in
                VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                    Text(cell.label.uppercased())
                        .font(.system(size: 10 * scaleFactor, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                    Text(cell.value)
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                }
                .padding(14 * scaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(palette.cardSurface)
                )
            }
        }
        .frame(maxWidth: 560 * scaleFactor)
    }
}

// MARK: - Checklist (type: "checklist")

/// Marker lines: numbered chips on intros, check/info/warning marks on outros. Numbers count only
/// numbered lines. `states` comes from `ChecklistState.resolve`, index-aligned with `lines`;
/// `.unwatched` draws the authored marker, and a checkmark is only drawn for a passing watch.
struct GuidanceChecklistBlock: View {
    let lines: [InspectConfig.GuidanceContent.ChecklistLine]
    let states: [ChecklistLineState]
    let accentColor: Color?
    let scaleFactor: CGFloat
    @Environment(\.palette) private var palette

    /// The number chip's neutral, system-adapting background.
    private var chipSurface: Color {
        palette.textMuted.opacity(0.12)
    }

    private var tint: Color { accentColor ?? palette.accent }

    var body: some View {
        let numberedPositions = numberedIndex(for: lines)
        VStack(alignment: .leading, spacing: 12 * scaleFactor) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                if !line.text.isEmpty {
                    row(for: line,
                        state: states.indices.contains(index) ? states[index] : .unwatched,
                        number: numberedPositions[index] ?? 0)
                }
            }
        }
        .frame(maxWidth: 560 * scaleFactor, alignment: .leading)
    }

    /// 1-based number per line, counting numbered lines only.
    private func numberedIndex(for lines: [InspectConfig.GuidanceContent.ChecklistLine]) -> [Int: Int] {
        var map: [Int: Int] = [:]
        var counter = 0
        for (idx, line) in lines.enumerated() where (line.marker ?? "number") == "number" {
            counter += 1
            map[idx] = counter
        }
        return map
    }

    @ViewBuilder
    private func row(for line: InspectConfig.GuidanceContent.ChecklistLine,
                     state: ChecklistLineState, number: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12 * scaleFactor) {
            marker(for: line, state: state, number: number)
            // A VStack reports its first subview's baseline, so the marker stays aligned to `text`.
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                lineText(line.text, state: state)
                if let hint = line.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8 * scaleFactor)
            // Trailing muted label: where this step lives ("General", "Encryption").
            if let context = line.context, !context.isEmpty {
                Text(context)
                    .font(.system(size: 11 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // No padding here in any state: the active decoration bleeds outward, so only colour changes.
        .background(activeBackground(for: state))
    }

    @ViewBuilder
    private func lineText(_ text: String, state: ChecklistLineState) -> some View {
        // Satisfied is muted, active is semibold, others plain; all use the palette's ink.
        switch state {
        case .satisfied:
            Text(text)
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        case .active:
            Text(text)
                .font(.system(size: 14 * scaleFactor, weight: .semibold))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        case .unwatched, .pending:
            Text(text)
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The active row's card: `accentColor` at 0.06 fill and 0.35 ring, falling back to `palette.accent`.
    @ViewBuilder
    private func activeBackground(for state: ChecklistLineState) -> some View {
        if state == .active {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                )
                // Negative padding grows the fill past the row without changing the row's layout.
                .padding(.vertical, -6 * scaleFactor)
                .padding(.horizontal, -10 * scaleFactor)
        }
    }

    @ViewBuilder
    private func marker(for line: InspectConfig.GuidanceContent.ChecklistLine,
                        state: ChecklistLineState, number: Int) -> some View {
        switch state {
        case .unwatched:
            // The authored marker, for checklists without watches.
            marker(for: line.marker ?? "number", number: number)
        case .satisfied:
            // Earned by a passing watch; same glyph as the authored "check" marker.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(BlockSemantics.tint(for: .pass, palette: palette) ?? .secondary)
                .frame(width: 22 * scaleFactor, height: 22 * scaleFactor)
        case .active:
            // The current line: the numbered chip filled with the accent.
            Text("\(number)")
                .font(.system(size: 11 * scaleFactor, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22 * scaleFactor, height: 22 * scaleFactor)
                .background(Circle().fill(tint))
        case .pending:
            // The neutral numbered chip, as the authored default draws it.
            Text("\(number)")
                .font(.system(size: 11 * scaleFactor, weight: .semibold))
                .foregroundStyle(palette.textMuted)
                .frame(width: 22 * scaleFactor, height: 22 * scaleFactor)
                .background(Circle().fill(chipSurface))
        }
    }

    @ViewBuilder
    private func marker(for style: String, number: Int) -> some View {
        let dim = 22 * scaleFactor
        switch style {
        case "check":
            // A pass earns no hue (`BlockSemantics.tint(for: .pass)` is nil), so the glyph falls back to secondary.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(BlockSemantics.tint(for: .pass, palette: palette) ?? .secondary)
                .frame(width: dim, height: dim)
        case "info":
            Image(systemName: "info.circle")
                .font(.system(size: 15 * scaleFactor))
                .foregroundStyle(palette.textMuted)
                .frame(width: dim, height: dim)
        case "warn":
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(BlockSemantics.tint(for: .warning, palette: palette) ?? .secondary)
                .frame(width: dim, height: dim)
        default:
            Text("\(number)")
                .font(.system(size: 11 * scaleFactor, weight: .semibold))
                .foregroundStyle(palette.textMuted)
                .frame(width: dim, height: dim)
                .background(Circle().fill(chipSurface))
        }
    }
}
