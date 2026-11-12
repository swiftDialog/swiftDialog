//
//  InstallationProgressModule.swift
//  dialog
//
//  Installation progress model, summary maths and row views (`InstallationItemData`,
//  `InstallMath`, `InstallOverallBar`, `InstallRowsList`, `InstallTilesGrid`) for the
//  installation and deployment steps of presets 5 and 6.
//

import SwiftUI

// MARK: - Installation Layout Style

/// Layout for installation progress. Any `installationLayout` value other than "grid" draws the list.
enum InstallationLayout: String, CaseIterable {
    case list       // Vertical list of items (compact)
    case grid       // Grid of item cards
}

// MARK: - Installation Item Data

/// One installation row: name, state, progress and authored facts.
struct InstallationItemData: Identifiable {
    let id: String
    let displayName: String
    let icon: String?
    let iconPath: String?
    let status: StepStatus
    let progress: Double?
    let statusMessage: String?

    /// Authored facts; `identifier` is derived from the app requirement. All optional.
    let claim: String?
    let size: String?
    let identifier: String?
    let version: String?
    let timeEstimate: Double?

    init(
        id: String,
        displayName: String,
        icon: String? = nil,
        iconPath: String? = nil,
        status: StepStatus = .pending,
        progress: Double? = nil,
        statusMessage: String? = nil,
        claim: String? = nil,
        size: String? = nil,
        identifier: String? = nil,
        version: String? = nil,
        timeEstimate: Double? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.icon = icon
        self.iconPath = iconPath
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
        self.claim = claim
        self.size = size
        self.identifier = identifier
        self.version = version
        self.timeEstimate = timeEstimate
    }

    /// Creates a row from any watched item: an `ItemConfig` (presets 1–4) or a step's `ListItem`.
    init(from item: any MonitoredItem, status: StepStatus = .pending, progress: Double? = nil, statusMessage: String? = nil,
         iconOverride: String? = nil) {
        self.id = item.id
        self.displayName = item.displayName
        // A runtime `itemicon:` override wins; otherwise the art ladder, so an icon-less row draws
        // its installed app once that app is on the Mac.
        self.icon = iconOverride.flatMap { $0.isEmpty ? nil : $0 } ?? item.resolvedArt
        self.iconPath = self.icon
        self.status = status
        self.progress = progress
        self.statusMessage = statusMessage
        self.claim = item.claim
        self.size = item.size
        self.identifier = item.displayIdentifier
        self.version = item.version
        self.timeEstimate = item.timeEstimate
    }
}

// MARK: - Circular Progress View

/// Small circular progress indicator; `progress` is percent, 0–100.
struct CircularProgressIndicator: View {
    let progress: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Summary maths, list, grid

/// Estimates over authored per-item facts. Sizes are human strings ("210 MB", "1.1 GB"): the
/// leading number is parsed and GB normalised to MB; unparseable sizes drop out of the totals.
/// Time left sums `timeEstimate` over unfinished rows, the active one scaled by its remaining fraction.
enum InstallMath {
    /// The row a long list keeps in view: the active one, else the first pending one, else nil.
    static func focusRow(_ rows: [(id: String, status: StepStatus)]) -> String? {
        rows.first { $0.status == .active }?.id ?? rows.first { $0.status == .pending }?.id
    }

    static func focusRow(_ items: [InstallationItemData]) -> String? {
        focusRow(items.map { ($0.id, $0.status) })
    }

    static func megabytes(_ size: String?) -> Double? {
        guard let size else { return nil }
        let scanner = Scanner(string: size)
        guard let value = scanner.scanDouble() else { return nil }
        return size.uppercased().contains("GB") ? value * 1024 : value
    }

    struct Summary: Equatable {
        var downloadedMB: Double = 0
        var totalMB: Double = 0
        var secondsLeft: Double?
        var completed: Int = 0
        var total: Int = 0
        var activeName: String?
    }

    static func summarize(_ items: [InstallationItemData]) -> Summary {
        var out = Summary(total: items.count)
        var anyEstimate = false
        var seconds = 0.0
        for item in items {
            let fraction: Double = {
                switch item.status {
                case .completed: return 1
                case .active:    return min(max((item.progress ?? 0) / 100, 0), 1)
                default:         return 0
                }
            }()
            if item.status == .completed { out.completed += 1 }
            if item.status == .active && out.activeName == nil { out.activeName = item.displayName }
            if let mb = megabytes(item.size) {
                out.totalMB += mb
                out.downloadedMB += mb * fraction
            }
            if let t = item.timeEstimate {
                anyEstimate = true
                seconds += t * (1 - fraction)
            }
        }
        out.secondsLeft = anyEstimate ? seconds : nil
        return out
    }

    /// "under a minute" / "~1 minute" / "~4 minutes"; rough on purpose.
    static func friendlyTime(_ seconds: Double) -> String {
        if seconds < 45 { return "under a minute" }
        let minutes = Int((seconds / 60).rounded())
        return minutes <= 1 ? "~1 minute" : "~\(minutes) minutes"
    }
}

/// Indeterminate sibling of `CircularProgressIndicator`: a spinning quarter arc in the same ring
/// vocabulary. Active rows without a percentage draw this, never the AppKit spinner.
struct IndeterminateRing: View {
    let size: CGFloat
    let color: Color
    /// Stroke weight; the inset is derived from it.
    var lineWidth: CGFloat = 3
    /// The track under the arc; nil is the arc's colour at 20 %.
    var track: Color?

    var body: some View {
        // Inset by half the stroke so the ring stays inside `size` instead of straddling the frame.
        let inset = lineWidth / 2
        return ZStack {
            Circle().inset(by: inset).stroke(track ?? color.opacity(0.2), lineWidth: lineWidth)
            Circle().inset(by: inset).trim(from: 0, to: 0.28)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .clockSpin()
        }
        .frame(width: size, height: size)
    }
}

/// The overall line above the rows: slim bar, "3 of 4 installed", "now: <active>".
struct InstallOverallBar: View {
    @Environment(\.palette) private var palette
    let summary: InstallMath.Summary
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            AccentProgressCapsule(progress: summary.total == 0 ? 0 : Double(summary.completed) / Double(summary.total),
                                  accent: palette.success, height: 5, animation: nil)
            HStack(spacing: 10) {
                Text("\(summary.completed) of \(summary.total) installed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(palette.text.opacity(0.9))
                if let now = summary.activeName {
                    Text("now: \(now)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.text.opacity(0.5))
                }
            }
        }
    }
}

/// One row's icon: SF symbol reference, else file image, else a tinted placeholder.
private struct InstallRowIcon: View {
    let item: InstallationItemData
    let accent: Color
    let side: CGFloat

    var body: some View {
        Group {
            if let iconPath = item.iconPath, let symbol = IconRef.symbol(iconPath) {
                Image(systemName: symbol)
                    .font(.system(size: side * 0.55, weight: .medium))
                    .foregroundStyle(accent)
            } else if let nsImage = ItemArt.image(at: item.iconPath) {
                // The path may be an installed `.app`, which NSImage(contentsOfFile:) cannot load.
                Image(nsImage: nsImage).resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: side * 0.25, style: .continuous)
                    .fill(accent.opacity(0.25))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.25, style: .continuous))
    }
}

/// A row's state cluster: mono state word plus disc (tick, ring, spinner or failure cross).
/// Shared by list rows and grid tiles.
private struct InstallStateCluster: View {
    @Environment(\.palette) private var palette
    let item: InstallationItemData
    let accent: Color
    var discFirst = false      // tiles lead with the disc; rows trail with it
    var showsWord = true       // list rows carry the word in their subline, so disc only


    var body: some View {
        HStack(spacing: discFirst ? 8 : 10) {
            if discFirst { disc }
            if showsWord {
                Text(stateWord)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(item.status == .active ? accent.opacity(0.9)
                                                            : palette.text.opacity(0.5))
            }
            if !discFirst { disc }
        }
    }

    private var stateWord: String {
        switch item.status {
        case .completed: return "installed"
        case .active:    return "installing"
        case .failed:    return "failed"
        default:         return "queued"
        }
    }

    @ViewBuilder private var disc: some View {
        switch item.status {
        case .completed:
            ZStack {
                Circle().fill(palette.success)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 19, height: 19)
        case .active:
            // At 100 % the installer is running and reports nothing, so spin rather than show a frozen ring.
            if let progress = item.progress, progress < 100 {
                CircularProgressIndicator(progress: progress, size: 19, color: accent)
            } else {
                IndeterminateRing(size: 19, color: accent)
            }
        case .failed:
            ZStack {
                Circle().fill(palette.error)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 19, height: 19)
        default:
            Circle().stroke(palette.text.opacity(0.25), lineWidth: 1.5)
                .frame(width: 17, height: 17)
        }
    }
}

/// The list: one rounded container of hairline-separated rows with icon, name, `version · size`
/// and the state disc.
struct InstallRowsList: View {
    @Environment(\.palette) private var palette
    let items: [InstallationItemData]
    let accent: Color

    var body: some View {
        // The icon column exists for every row or none, so the list stays aligned.
        let hasIcons = items.contains { $0.icon != nil || $0.iconPath != nil }
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Rectangle().fill(palette.text.opacity(0.08))
                        .frame(height: 0.5)
                        .padding(.leading, hasIcons ? 57 : 16)
                }
                HStack(spacing: 13) {
                    if hasIcons {
                        InstallRowIcon(item: item, accent: accent, side: 28)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.text.opacity(0.9))
                        // Subline: live status message, else authored facts, else the state word.
                        if let message = item.statusMessage, !message.isEmpty {
                            Text(message)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(palette.text.opacity(0.5))
                        } else if let facts = factsLine(item) {
                            Text(facts)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(palette.text.opacity(0.5))
                        } else {
                            Text(rowStateWord(item.status))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(item.status == .active
                                    ? accent.opacity(0.9) : palette.text.opacity(0.5))
                        }
                    }
                    Spacer(minLength: 8)
                    InstallStateCluster(item: item, accent: accent, showsWord: false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .id(item.id)   // the scroll target `InstallMath.focusRow` names
            }
        }
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.text.opacity(0.035)))
    }
}

/// The grid: 2-up tiles with icon, name, `version · size` and a state line; the active tile
/// shows its bar and percentage.
struct InstallTilesGrid: View {
    @Environment(\.palette) private var palette
    let items: [InstallationItemData]
    let accent: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                  spacing: 12) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        InstallRowIcon(item: item, accent: accent, side: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.text.opacity(0.9))
                            if let facts = factsLine(item) {
                                Text(facts)
                                    .font(.system(size: 11.5, design: .monospaced))
                                    .foregroundStyle(palette.text.opacity(0.5))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if item.status == .active, let progress = item.progress {
                        VStack(alignment: .leading, spacing: 7) {
                            AccentProgressCapsule(progress: progress / 100, accent: accent, height: 4, animation: nil)
                            Text("installing · \(Int(progress.rounded()))%")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(accent.opacity(0.9))
                        }
                    } else {
                        InstallStateCluster(item: item, accent: accent, discFirst: true)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(palette.text.opacity(0.035)))
            }
        }
    }
}

/// The state word a row's subline falls back to: installed / installing / failed / queued.
func rowStateWord(_ status: StepStatus) -> String {
    switch status {
    case .completed: return "installed"
    case .active:    return "installing"
    case .failed:    return "failed"
    default:         return "queued"
    }
}

/// The row's fine print: `version · size` when stated, else the `claim`, else nil.
private func factsLine(_ item: InstallationItemData) -> String? {
    let parts = [item.version, item.size].compactMap { $0 }
    if !parts.isEmpty { return parts.joined(separator: " · ") }
    return item.claim
}

/// A rotation read from the clock each frame rather than animated, so no view transaction can
/// cancel or restart it. The only spinner idiom for installing rows.
private struct ClockSpin: ViewModifier {
    let period: Double
    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            content.rotationEffect(.degrees(
                context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period * 360))
        }
    }
}

extension View {
    func clockSpin(period: Double = 1) -> some View { modifier(ClockSpin(period: period)) }
}
