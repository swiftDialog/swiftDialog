//
//  StatusComponents.swift
//  dialog
//
//  Status badges, the feature and comparison tables, the phase tracker and the shared status
//  circle, drawn by the guidance blocks and the item rows.
//

import SwiftUI

// MARK: - Status Monitoring Components

/// A status row: icon, label and the value or state word, auto-coloured from the state.
struct StatusBadgeView: View {
    let label: String
    let state: String
    let actual: String?
    let icon: String?
    let autoColor: Bool
    let customColor: Color?
    let scaleFactor: CGFloat
    /// Resolves a relative `icon` path.
    let iconBasePath: String?
    @Environment(\.palette) private var palette

    init(label: String, state: String, actual: String?, icon: String?, autoColor: Bool,
         customColor: Color?, scaleFactor: CGFloat, iconBasePath: String? = nil) {
        self.label = label
        self.state = state
        self.actual = actual
        self.icon = icon
        self.autoColor = autoColor
        self.customColor = customColor
        self.scaleFactor = scaleFactor
        self.iconBasePath = iconBasePath
    }

    private var stateColor: Color {
        if let customColor = customColor {
            return customColor
        }

        if !autoColor {
            return .secondary
        }

        // Hue and glyph come from one classification so they cannot disagree.
        return ExternalFactStatus.classify(state).color(palette: palette)
    }

    private var defaultIcon: String {
        ExternalFactStatus.classify(state).symbol
    }

    /// A file image (relative paths resolve against `iconBasePath`) or an SF Symbol.
    @ViewBuilder
    private var statusBadgeIcon: some View {
        if let iconPath = icon, Self.isFilePath(iconPath) {
            AsyncImageView(
                iconPath: iconPath,
                basePath: iconBasePath,
                maxWidth: 20 * scaleFactor,
                maxHeight: 20 * scaleFactor,
                imageFit: .fit,
                showLoadingState: false,
                fallback: {
                    Image(systemName: defaultIcon)
                        .font(.system(size: 16 * scaleFactor))
                        .foregroundStyle(stateColor)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 4 * scaleFactor))
        } else {
            Image(systemName: icon ?? defaultIcon)
                .font(.system(size: 16 * scaleFactor))
                .foregroundStyle(stateColor)
        }
    }

    /// File path or SF Symbol name; the rule lives once in `IconRef`.
    static func isFilePath(_ value: String) -> Bool { IconRef.isFilePath(value) }

    private var displayText: String {
        actual ?? state
    }

    var body: some View {
        let _ = writeLog("VIEW: StatusBadgeView rendering label='\(label)' state='\(state)' actual='\(actual ?? "-")' color=\(stateColor)", logLevel: .debug)

        return HStack(spacing: 8 * scaleFactor) {
            statusBadgeIcon
                .frame(width: 20 * scaleFactor, height: 20 * scaleFactor)

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)

                // The glyph carries the state; the text carries the value, uncoloured.
                Text(displayText)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(minWidth: 60 * scaleFactor, alignment: .leading)
        .padding(.vertical, 8 * scaleFactor)
        // A hairline row, not a tinted banner.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .frame(height: 1)
        }
        // A monitor- or IPC-driven state flip must show at once, not inherit the host's animation.
        .transaction { $0.animation = nil }
    }
}

/// A feature table: tick or cross per column, one row per feature.
struct FeatureTableView: View {
    let columns: [InspectConfig.GuidanceContent.FeatureTableColumn]
    let rows: [InspectConfig.GuidanceContent.FeatureTableRow]
    let style: String?
    let scaleFactor: CGFloat
    /// The authored `label`, drawn as a heading.
    var label: String?
    @Environment(\.palette) private var palette
    @Environment(\.inspectLocalization) private var l10n

    private var isDarkStyle: Bool {
        style == "dark"
    }

    private var backgroundColor: Color {
        isDarkStyle ? Color.black.opacity(0.85) : palette.cardSurface.opacity(0.5)
    }

    private var textColor: Color {
        isDarkStyle ? .white : palette.text
    }

    private var secondaryTextColor: Color {
        isDarkStyle ? .white.opacity(0.7) : palette.textMuted
    }

    private var dividerColor: Color {
        isDarkStyle ? Color.white.opacity(0.2) : palette.hairline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                    .padding(.bottom, 8 * scaleFactor)
            }

            // Header columns carry words only; a glyph in a header reads as a result.
            HStack(spacing: 12 * scaleFactor) {
                Text(l10n("ui.tableApp", "App"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    Text(column.label)
                        .frame(width: 96 * scaleFactor, alignment: .leading)
                }
            }
            .font(.system(size: 10 * scaleFactor, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(isDarkStyle ? secondaryTextColor : Color.secondary.opacity(0.8))
            .padding(.bottom, 7 * scaleFactor)

            Rectangle().fill(dividerColor).frame(height: 1)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12 * scaleFactor) {
                    VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                        Text(row.feature)
                            .font(.system(size: 13 * scaleFactor))
                            .foregroundStyle(textColor)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = row.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundStyle(secondaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(Array(row.values.prefix(columns.count).enumerated()), id: \.offset) { _, value in
                        Image(systemName: value ? "checkmark" : "xmark")
                            .font(.system(size: 12 * scaleFactor, weight: .semibold))
                            .foregroundStyle(value ? palette.success : palette.error)
                            .frame(width: 96 * scaleFactor, alignment: .leading)
                    }
                }
                .padding(.vertical, 9 * scaleFactor)

                Rectangle().fill(dividerColor).frame(height: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Multi-phase progress: a horizontal track, a proportional timeline bar, a vertical list or a
/// progress bar, chosen by the phases' content and `style`.
struct PhaseTrackerView: View {
    let currentPhase: Int
    let phases: [InspectConfig.GuidanceContent.PhaseSpec]
    let style: String
    let scaleFactor: CGFloat
    var activeColor: Color?              // nil → BlockSemantics.tint(for: .active)
    var caption: String?                 // heading above the track
    /// Live 0…1 progress of the phase in flight; only the timeline bar reads it. Absent means
    /// "started", not "half".
    var progress: Double?
    @Environment(\.palette) private var palette
    /// Measured track width for the timeline bar's segments; zero until the first layout pass,
    /// when the segments fall back to equal flexible frames.
    @State private var trackWidth: CGFloat = 0

    private var defaultPhaseLabels: [String] {
        ["Prepare", "Execute", "Verify", "Complete"]
    }

    private var trackPhases: [InspectConfig.GuidanceContent.PhaseSpec] {
        phases.isEmpty
            ? defaultPhaseLabels.map { .init(label: $0) }
            : phases
    }

    private var phaseLabels: [String] { trackPhases.map(\.label) }

    private var resolvedActiveColor: Color {
        activeColor ?? BlockSemantics.tint(for: .active, palette: palette) ?? palette.accent
    }

    var body: some View {
        if style == "progress" {
            progressBarStyle
        } else if PhaseTrack.prefersProportional(trackPhases) && !PhaseTrack.prefersVertical(trackPhases) {
            // Phases with durations draw to scale; a phase with a sentence cannot fit on a bar.
            proportionalBarStyle
        } else if PhaseTrack.prefersVertical(trackPhases) {
            // A phase that needs a sentence has nowhere to put one on a horizontal track.
            verticalTrackStyle
        } else {
            // Every other style value renders the one track; the values stay accepted so existing
            // configs keep validating.
            trackStyle
        }
    }

    /// The horizontal track: no numerals, one accent in three weights (filled behind, ringed now,
    /// hairline ahead), equal-width columns so labels share one baseline, `time` under the label.
    private var trackStyle: some View {
        let phases = trackPhases
        return VStack(alignment: .leading, spacing: 10 * scaleFactor) {
            if let caption {
                Text(caption)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(phases.indices, id: \.self) { index in
                    let state = PhaseTrack.state(at: index, in: phases, currentPhase: currentPhase)
                    VStack(spacing: 7 * scaleFactor) {
                        ZStack {
                            // Connector halves live inside each column so they meet at the column
                            // boundary, and stop short of the mark: the step background is a
                            // gradient, so the line cannot be hidden behind a filled mark.
                            HStack(spacing: 0) {
                                connector(visible: index > 0,
                                          covered: PhaseTrack.isCovered(segmentBefore: index, currentPhase: currentPhase))
                                    .padding(.trailing, markClearance)
                                connector(visible: index < phases.count - 1,
                                          covered: PhaseTrack.isCovered(segmentBefore: index + 1, currentPhase: currentPhase))
                                    .padding(.leading, markClearance)
                            }
                            mark(for: state)
                        }
                        .frame(height: 22 * scaleFactor)

                        Text(phases[index].label)
                            .font(.system(size: 12 * scaleFactor,
                                          weight: state == .current ? .semibold : .regular))
                            .foregroundStyle(state == .pending ? .secondary : .primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let time = phases[index].time {
                            Text(time)
                                .font(.system(size: 11 * scaleFactor))
                                .foregroundStyle(palette.textFaint)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
        }
    }

    // MARK: - The timeline bar

    /// The timeline bar: segment width is the phase's share of the total time. A phase with an
    /// empty label is an unnamed stretch of time; only the phase in flight shows a partial fill.
    @ViewBuilder
    private var proportionalBarStyle: some View {
        let phases = trackPhases
        let widths = barSegmentWidths(for: phases)
        VStack(alignment: .leading, spacing: 14 * scaleFactor) {
            if let caption {
                Text(caption)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10 * scaleFactor) {
                HStack(spacing: barGap) {
                    ForEach(phases.indices, id: \.self) { index in
                        segment(PhaseTrack.fill(at: index, in: phases,
                                                currentPhase: currentPhase, progress: progress),
                                shape: barShape(at: index, count: phases.count))
                            .frame(width: widths[safe: index])
                            .frame(maxWidth: widths.isEmpty ? .infinity : nil)
                    }
                }
                .frame(height: barHeight)

                // The label row mirrors the bar's widths so a label sits under its stretch of time.
                HStack(alignment: .top, spacing: barGap) {
                    ForEach(phases.indices, id: \.self) { index in
                        segmentLabel(phases[index],
                                     isCurrent: PhaseTrack.state(at: index, in: phases,
                                                                 currentPhase: currentPhase) == .current)
                            .frame(width: widths[safe: index], alignment: .leading)
                            .frame(maxWidth: widths.isEmpty ? .infinity : nil, alignment: .leading)
                    }
                }
            }
            // Keep filling the container once columns have explicit widths, or the measurement
            // below would only ever re-measure the sum it just produced.
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: TrackWidthKey.self, value: geo.size.width)
                }
            )
            .onPreferenceChange(TrackWidthKey.self) { trackWidth = $0 }
        }
    }

    private var barHeight: CGFloat { 14 * scaleFactor }
    private var barGap: CGFloat { 3 * scaleFactor }

    /// Segment widths; empty until the row has been measured, when the segments are flexible.
    private func barSegmentWidths(for phases: [InspectConfig.GuidanceContent.PhaseSpec]) -> [CGFloat] {
        guard trackWidth > 0, phases.count > 1 else { return [] }
        let usable = trackWidth - barGap * CGFloat(phases.count - 1)
        guard usable > 0 else { return [] }
        return PhaseTrack.segmentWidths(for: phases,
                                        total: usable,
                                        minimum: labelledSegmentMinimum,
                                        spacerMinimum: spacerSegmentMinimum)
    }

    /// Room for a label under a named segment.
    private var labelledSegmentMinimum: CGFloat { 68 * scaleFactor }
    /// Room for an unnamed segment to still be visible.
    private var spacerSegmentMinimum: CGFloat { 10 * scaleFactor }

    private func barShape(at index: Int, count: Int) -> (leading: CGFloat, trailing: CGFloat) {
        let outer = barHeight / 2
        let inner = 3 * scaleFactor
        return (leading: index == 0 ? outer : inner,
                trailing: index == count - 1 ? outer : inner)
    }

    @ViewBuilder
    private func segment(_ fill: PhaseTrack.SegmentFill,
                         shape: (leading: CGFloat, trailing: CGFloat)) -> some View {
        let clip = UnevenRoundedRectangle(topLeadingRadius: shape.leading,
                                          bottomLeadingRadius: shape.leading,
                                          bottomTrailingRadius: shape.trailing,
                                          topTrailingRadius: shape.trailing,
                                          style: .continuous)
        let empty = Color.secondary.opacity(0.18)
        switch fill {
        case .full:
            clip.fill(resolvedActiveColor)
        case .partial(let fraction):
            clip.fill(empty)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        resolvedActiveColor.frame(width: geo.size.width * fraction)
                    }
                }
                .clipShape(clip)
        case .inFlight:
            // Running with no progress reported: a wash, not a fraction nobody supplied.
            clip.fill(resolvedActiveColor.opacity(0.38))
        case .blocked:
            clip.fill(empty)
                .overlay(clip.stroke(resolvedActiveColor, lineWidth: 1.5 * scaleFactor))
        case .failed:
            clip.fill(palette.error)
        case .empty:
            clip.fill(empty)
        }
    }

    @ViewBuilder
    private func segmentLabel(_ phase: InspectConfig.GuidanceContent.PhaseSpec,
                              isCurrent: Bool) -> some View {
        if phase.label.isEmpty && phase.time == nil {
            Color.clear.frame(height: 0)
        } else {
            VStack(alignment: .leading, spacing: 3 * scaleFactor) {
                if !phase.label.isEmpty {
                    Text(phase.label)
                        .font(.system(size: 12 * scaleFactor,
                                      weight: isCurrent ? .semibold : .medium))
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                }
                if let time = phase.time {
                    // Monospaced so a row of durations does not look ragged.
                    Text(time)
                        .font(.system(size: 11 * scaleFactor, design: .monospaced))
                        .foregroundStyle(isCurrent ? AnyShapeStyle(resolvedActiveColor)
                                                   : AnyShapeStyle(palette.textFaint))
                }
            }
            .lineLimit(1)
            .truncationMode(.tail)
        }
    }

    /// The vertical list: the track's marks and accent on the other axis, with room for a sentence
    /// per phase. The connector is drawn within each row so it stretches with the row's text.
    private var verticalTrackStyle: some View {
        let phases = trackPhases
        return VStack(alignment: .leading, spacing: 0) {
            if let caption {
                Text(caption)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 10 * scaleFactor)
            }
            ForEach(phases.indices, id: \.self) { index in
                let state = PhaseTrack.state(at: index, in: phases, currentPhase: currentPhase)
                HStack(alignment: .top, spacing: 12 * scaleFactor) {
                    VStack(spacing: 0) {
                        // A short stub lands the mark on the label's first line.
                        connector(visible: index > 0,
                                  covered: PhaseTrack.isCovered(segmentBefore: index, currentPhase: currentPhase),
                                  vertical: true)
                            .frame(height: 3 * scaleFactor)
                        mark(for: state)
                        connector(visible: index < phases.count - 1,
                                  covered: PhaseTrack.isCovered(segmentBefore: index + 1, currentPhase: currentPhase),
                                  vertical: true)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: 16 * scaleFactor)

                    VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                        Text(phases[index].label)
                            .font(.system(size: 13 * scaleFactor,
                                          weight: state == .current ? .semibold : .regular))
                            .foregroundStyle(state == .pending ? .secondary : .primary)
                        if let detail = phases[index].detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 12 * scaleFactor))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let time = phases[index].time {
                        Text(time)
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(palette.textFaint)
                            .lineLimit(1)
                    }
                }
                .padding(.bottom, index < phases.count - 1 ? 14 * scaleFactor : 0)
            }
        }
    }

    /// Half the mark plus air, so a connector stops before it.
    private var markClearance: CGFloat { 13 * scaleFactor }

    /// One accent, three weights; only the done mark carries a glyph.
    @ViewBuilder
    private func mark(for state: PhaseTrack.MarkState) -> some View {
        let size = 16 * scaleFactor
        switch state {
        case .done:
            Circle().fill(resolvedActiveColor)
                .frame(width: size, height: size)
                .overlay(Image(systemName: "checkmark")
                    .font(.system(size: 8.5 * scaleFactor, weight: .bold))
                    .foregroundStyle(.white))
        case .current:
            // A ring, so "now" differs from "done" in kind without a second hue.
            Circle().stroke(resolvedActiveColor, lineWidth: 3 * scaleFactor)
                .frame(width: size, height: size)
        case .blocked:
            Circle().stroke(resolvedActiveColor, lineWidth: 2 * scaleFactor)
                .frame(width: size, height: size)
                .overlay(Circle().fill(resolvedActiveColor)
                    .frame(width: size * 0.32, height: size * 0.32))
        case .failed:
            // Red appears on the mark only, never the connector or the label.
            Circle().fill(palette.error)
                .frame(width: size, height: size)
                .overlay(Image(systemName: "xmark")
                    .font(.system(size: 8.5 * scaleFactor, weight: .bold))
                    .foregroundStyle(.white))
        case .pending:
            Circle().stroke(Color.secondary.opacity(0.40), lineWidth: 1.5 * scaleFactor)
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func connector(visible: Bool, covered: Bool, vertical: Bool = false) -> some View {
        let paint = visible ? (covered ? resolvedActiveColor : Color.secondary.opacity(0.25)) : Color.clear
        if vertical {
            Rectangle().fill(paint).frame(width: 2 * scaleFactor)
        } else {
            Rectangle().fill(paint).frame(height: 2 * scaleFactor)
        }
    }

    private var progressBarStyle: some View {
        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            HStack {
                Text("Phase \(PhaseTrack.clamped(phaseNumber: currentPhase, count: phaseLabels.count)) of \(phaseLabels.count)")
                    .font(.system(size: 12 * scaleFactor, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(phaseLabels[safe: PhaseTrack.clamped(phaseNumber: currentPhase,
                                                         count: phaseLabels.count) - 1] ?? "")
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // Not `currentPhase / count`: that reads full while the last phase still runs and
            // disagrees with weighted phases.
            ProgressView(value: PhaseTrack.coveredFraction(for: trackPhases,
                                                           currentPhase: currentPhase))
                .progressViewStyle(LinearProgressViewStyle())
                .tint(resolvedActiveColor)
        }
        .padding(12 * scaleFactor)
    }

}

// MARK: - Status Indicator Circle (shared)

/// The one status circle, drawn by the Preset 1 item rows, the plain-simple list screen and
/// `AppIconView`'s install badge. Non-circle status shapes keep their own renderers.
struct StatusIndicatorCircle: View {
    @Environment(\.palette) private var palette
    enum ActiveStyle {
        case haloDot      // accent dot on a soft accent halo, static
        case accentDot    // white dot on a filled accent circle, static
        case spinner      // spinning ProgressView
    }

    let status: StepStatus
    /// Completed, but plist validation failed: a flag beside the state, not a state.
    var hasWarning: Bool = false
    let accent: Color
    var size: CGFloat = 20
    var glyphSize: CGFloat?          // default: size * 0.6
    var activeStyle: ActiveStyle = .haloDot
    var showPending: Bool = true           // false draws nothing for .pending
    var completedHelp: String = "Installed and validated"
    /// A ring of this colour around the disc, so a badge set on an icon reads as cut out of it.
    var ring: Color?
    var ringWidth: CGFloat = 3

    private var glyph: CGFloat { glyphSize ?? size * 0.6 }

    var body: some View {
        switch status {
        case .failed:
            circle(StatusGlyph.failure)
                .help("Installation failed")
        case .completed:
            if hasWarning {
                circle(StatusGlyph.warning)
                    .help("Installed, but a setting couldn't be verified")
            } else {
                circle(StatusGlyph.success)
                    .help(completedHelp)
            }
        case .skipped:
            circle(StatusGlyph.success)
                .help("Skipped")
        case .active:
            activeBadge
                .help("Installing…")
        case .pending:
            if showPending {
                Circle()
                    .stroke(palette.text.opacity(0.3), lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
    }

    private func circle(_ status: StatusGlyph) -> some View {
        ZStack {
            if let ring {
                Circle().fill(ring).frame(width: size + ringWidth * 2, height: size + ringWidth * 2)
            }
            disc(status)
        }
    }

    private func disc(_ status: StatusGlyph) -> some View {
        Circle()
            // The palette's colour, so a branded success or error hue applies here too.
            .fill(status.paletteColor(palette))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: status.discSymbol ?? status.symbol)
                    .font(.system(size: glyph, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    @ViewBuilder
    private var activeBadge: some View {
        switch activeStyle {
        case .haloDot:
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(accent)
                        .frame(width: size * 0.5, height: size * 0.5)
                )
        case .accentDot:
            Circle()
                .fill(accent)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: size * (9.0 / 26.0), height: size * (9.0 / 26.0))
                )
        case .spinner:
            ProgressView()
                .scaleEffect(0.8)
                .tint(StatusGlyph.paletteActiveColor(palette))
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Comparison Checks Table

/// Required-versus-found checks as one table with headers once. A found cell states its result
/// once, a glyph and a value; colour appears only where something failed.
struct ComparisonChecksTable: View {
    let label: String?
    /// Authored `expectedLabel`/`actualLabel`; nil falls back to the localized `ui.*` key here.
    let requiredLabel: String?
    let foundLabel: String?
    let checks: [InspectConfig.GuidanceContent.ComparisonCheck]
    let accentColor: Color
    var scaleFactor: CGFloat = 1.0
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let label {
                Text(label)
                    .font(.system(size: 13 * scaleFactor, weight: .semibold))
                    .padding(.bottom, 8 * scaleFactor)
            }

            HStack(spacing: 12 * scaleFactor) {
                Text(l10n("ui.tableCheck", "Check"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(requiredLabel ?? l10n("ui.tableRequired", "Required"))
                    .frame(width: 150 * scaleFactor, alignment: .leading)
                Text(foundLabel ?? l10n("ui.tableFound", "Found"))
                    .frame(width: 190 * scaleFactor, alignment: .leading)
            }
            .font(.system(size: 10 * scaleFactor, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(palette.textFaint)
            .padding(.bottom, 7 * scaleFactor)

            Divider()

            ForEach(Array(checks.enumerated()), id: \.offset) { _, row in
                rowView(row)
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The found cell's glyph and tint, or nil for none. Gating on `mark != nil` is right for this
    /// binary vocabulary; `GuidanceAdvisoryBlock` keeps its own signal because its `warning` is
    /// markless but tinted.
    static func rowSignal(for row: InspectConfig.GuidanceContent.ComparisonCheck,
                          palette: ResolvedPalette) -> (symbol: String, tint: Color)? {
        let passed = row.pass ?? (row.required == row.found)
        let state: BlockSemantics.State = passed ? .pass : .fail
        guard let mark = BlockSemantics.mark(for: state) else { return nil }
        return (mark, BlockSemantics.tint(for: state, palette: palette) ?? .primary)
    }

    @ViewBuilder
    private func rowView(_ row: InspectConfig.GuidanceContent.ComparisonCheck) -> some View {
        let isExpanded = row.expanded == true

        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            HStack(alignment: .top, spacing: 12 * scaleFactor) {
                Text(row.check)
                    .font(.system(size: 13 * scaleFactor))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(row.required)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .frame(width: 150 * scaleFactor, alignment: .leading)

                HStack(spacing: 6 * scaleFactor) {
                    if let signal = Self.rowSignal(for: row, palette: palette) {
                        Image(systemName: signal.symbol)
                            .font(.system(size: 12 * scaleFactor, weight: .semibold))
                            .foregroundStyle(signal.tint)
                    }
                    Text(row.found)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 190 * scaleFactor, alignment: .leading)
            }

            if isExpanded {
                HStack(alignment: .top, spacing: 12 * scaleFactor) {
                    if let actionLabel = row.actionLabel {
                        Button(actionLabel) {
                            if let urlString = row.actionURL, let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(accentColor)
                    }
                    if let note = row.note {
                        Text(note)
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.vertical, 9 * scaleFactor)
        .padding(.horizontal, isExpanded ? 10 * scaleFactor : 0)
        // Only the row the user can act on gets a tint and a button.
        .background(isExpanded ? palette.error.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8 * scaleFactor, style: .continuous))
    }
}


/// The measured phase-track width for `PhaseTrack.segmentWidths`. Internal because a
/// PreferenceKey used in a `some View` body cannot be more constrained than the view.
struct TrackWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
