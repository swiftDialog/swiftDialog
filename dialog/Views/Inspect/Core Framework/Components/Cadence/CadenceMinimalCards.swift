//
//  CadenceMinimalCards.swift
//  dialog
//
//  The minimal cadence reads, chosen by `cadenceStyle`: `manifest` (finished work rolled up, the
//  running step tall, two queued, the rest counted) and `spotlight` (the running step as the
//  headline, the last receipts beneath it). One glass card over the sheet; the machine and the
//  count sit above it.
//

import SwiftUI

/// Which minimal read a step asks for, or nil for neither.
enum CadenceMinimalKind: String {
    case manifest
    case spotlight

    init?(authored: String?) {
        switch authored?.lowercased() {
        case "manifest": self = .manifest
        case "spotlight": self = .spotlight
        default: return nil
        }
    }

    /// The read for an authored word; absent or unknown is the manifest. `bento` is the caller's
    /// arm and never reaches here.
    static func forStep(authored: String?) -> CadenceMinimalKind {
        CadenceMinimalKind(authored: authored) ?? .manifest
    }
}

// MARK: - The sheet's numbers

/// The minimal reads' geometry.
enum CadenceMinimalM {
    static let cardRadius: CGFloat = 18
    /// The manifest's rows; the running row is the tall one.
    static let rolledUpRow: CGFloat = 44
    static let runningRow: CGFloat = 72
    static let queuedRow: CGFloat = 44
    /// The spotlight's headline icon and receipt rows.
    static let headlineIcon: CGFloat = 46
    static let receiptRow: CGFloat = 40
    /// The running step's icon, and the chip every other icon sits in.
    static let runningIcon: CGFloat = 38
    static let chip: CGFloat = 26
    /// How far rolled-up icons overlap; each mark stays legible.
    static let iconOverlap: CGFloat = 10
    /// How many finished steps either card names before the rest become a count.
    static let namedReceipts: Int = 3
    static let cardPadding: CGFloat = 14
    static let rowGap: CGFloat = 6
    /// The machine picture's height at most; `CadenceMinimalFit` shrinks it first.
    static let machineImage: CGFloat = 128
    /// The picture's box is wider than tall, as a machine is.
    static let machineImageAspect: CGFloat = 170.0 / 96.0
    static let sheetGap: CGFloat = 10
}

/// How much of a minimal sheet fits the height the shell hands it: the machine picture shrinks
/// first, down to its floor; past that a named row goes and the card's rollup count absorbs it.
/// Pure, so the budget is testable without SwiftUI.
struct CadenceMinimalFit: Equatable {
    let machineImage: CGFloat
    /// Queued rows (manifest) or named receipts (spotlight).
    let rows: Int

    /// The smallest the machine picture goes before a row is given up instead.
    static let machineImageFloor: CGFloat = 72
    static let sheetOverhead: CGFloat = CadenceMinimalM.sheetGap
    static let cardPadding: CGFloat = 2 * CadenceMinimalM.cardPadding

    /// The rows that never go, each with its gap: the manifest's rolled-up line, running row and
    /// "more to go" line; the spotlight's headline and "before that" line.
    static func fixedRows(_ kind: CadenceMinimalKind) -> CGFloat {
        let gap = CadenceMinimalM.rowGap
        switch kind {
        case .manifest: return CadenceMinimalM.rolledUpRow + gap + CadenceMinimalM.runningRow + gap + 17
        case .spotlight: return 76 + gap + 16
        }
    }

    static func perRow(_ kind: CadenceMinimalKind) -> CGFloat {
        switch kind {
        case .manifest: return CadenceMinimalM.queuedRow + CadenceMinimalM.rowGap
        case .spotlight: return CadenceMinimalM.receiptRow + CadenceMinimalM.rowGap
        }
    }

    static func maxRows(_ kind: CadenceMinimalKind) -> Int {
        switch kind {
        case .manifest: return 2
        case .spotlight: return CadenceMinimalM.namedReceipts
        }
    }

    static func resolve(height: CGFloat, kind: CadenceMinimalKind) -> CadenceMinimalFit {
        for rows in stride(from: maxRows(kind), through: 0, by: -1) {
            let room = height - sheetOverhead - cardPadding - fixedRows(kind) - CGFloat(rows) * perRow(kind)
            if room >= machineImageFloor {
                return CadenceMinimalFit(machineImage: min(CadenceMinimalM.machineImage, room), rows: rows)
            }
        }
        return CadenceMinimalFit(machineImage: machineImageFloor, rows: 0)
    }

    /// The sheet's height at this fit.
    func height(_ kind: CadenceMinimalKind) -> CGFloat {
        machineImage + Self.sheetOverhead + Self.cardPadding + Self.fixedRows(kind)
            + CGFloat(rows) * Self.perRow(kind)
    }
}

/// What a minimal card shows of a run, bounded: at most `named` finished and `queued` waiting
/// steps by name, the rest as counts, so a long run draws as many rows as a short one. Pure.
enum CadenceRollup {
    /// The finished entries, newest last; only the last `named` are drawn. Failed entries are
    /// not done: they leave this count and are named by `failures`.
    static func finished(_ entries: [InspectConfig.CadenceEntry], position: Int,
                         named: Int = CadenceMinimalM.namedReceipts,
                         failed: Set<Int> = [])
        -> (shown: [InspectConfig.CadenceEntry], total: Int) {
        let done = entries.prefix(max(0, position)).enumerated()
            .filter { !failed.contains($0.offset) }.map(\.element)
        return (Array(done.suffix(named)), done.count)
    }

    /// The failed entries the run has passed, in run order; every one is named.
    static func failures(_ entries: [InspectConfig.CadenceEntry], position: Int,
                         failed: Set<Int>) -> [InspectConfig.CadenceEntry] {
        entries.prefix(max(0, position)).enumerated()
            .filter { failed.contains($0.offset) }.map(\.element)
    }

    /// The entries waiting behind the running one: at most `queued` named, the rest counted.
    static func waiting(_ entries: [InspectConfig.CadenceEntry], position: Int, queued: Int)
        -> (shown: [InspectConfig.CadenceEntry], beyond: Int) {
        let ahead = Array(entries.dropFirst(min(entries.count, max(0, position) + 1)))
        return (Array(ahead.prefix(queued)), max(0, ahead.count - queued))
    }
}

// MARK: - The pieces both cards share

/// A step's mark in its chip: an authored image, else an authored symbol, else the initial.
struct CadenceStepMark: View {
    let entry: InspectConfig.CadenceEntry
    var side: CGFloat = CadenceMinimalM.chip
    var accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
                .fill(palette.cardSurface.opacity(0.9))
            mark
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private var mark: some View {
        if let path = entry.imagePath, !path.isEmpty, ProvisioningRowIcon.handles(path) {
            // An app icon fills more of the chip than a line-art mark.
            ProvisioningRowIcon(path: path, symbol: entry.sfSymbol ?? "circle", on: true,
                                accent: accent, size: side * 0.78)
        } else if let path = entry.imagePath, !path.isEmpty {
            BrandMark(path: path, box: BrandMarkBox(height: side * 0.62, maxWidth: side * 0.62))
        } else if let symbol = entry.sfSymbol, !symbol.isEmpty {
            Image(systemName: symbol)
                .font(.system(size: side * 0.46, weight: .medium))
                .foregroundStyle(accent)
        } else {
            Text(String((entry.label ?? entry.id).prefix(1)).uppercased())
                .font(.system(size: side * 0.44, weight: .semibold))
                .foregroundStyle(accent)
        }
    }
}

/// The run's progress in words, on the machine's row.
enum CadenceMinimalMeter {

    /// "5 of 12 complete", with the failed count when there is one.
    static func countLine(_ run: CadenceProgress) -> String {
        let line = "\(run.satisfied) of \(run.total) complete"
        return run.failed.isEmpty ? line : line + " · \(run.failed.count) failed"
    }

    /// The sum of the authored `timeEstimate`s still ahead; nil when nothing is estimated.
    static func timeRemaining(_ run: CadenceProgress) -> String? {
        let ahead = run.entries.enumerated()
            .filter { $0.offset >= run.position }
            .compactMap { $0.element.timeEstimate }
        guard !ahead.isEmpty else { return nil }
        let seconds = Int(ahead.reduce(0, +))
        guard seconds > 0 else { return nil }
        if seconds < 60 { return "about \(seconds)s left" }
        return "about \(Int((Double(seconds) / 60).rounded())) min left"
    }
}

/// The machine's picture and the line naming it, from `MachineIdentity`.
struct CadenceMachineStrip: View {
    var imageHeight: CGFloat = CadenceMinimalM.machineImage

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            MachineImage()
                // Leading, or the wide box opens a gap before the name.
                .frame(width: imageHeight * CadenceMinimalM.machineImageAspect, height: imageHeight,
                       alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(MachineIdentity.current.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(MachineIdentity.current.shortSpecLine)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

/// The frosted glass the work sits on. It fills the whole payload with rows anchored to the top;
/// the frame sits inside the background so the material grows with it.
struct CadenceGlassCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        content()
            .padding(CadenceMinimalM.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: CadenceMinimalM.cardRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CadenceMinimalM.cardRadius, style: .continuous)
                    .strokeBorder(palette.text.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - The manifest

/// Finished work rolled up, failures named, the running step tall, a few queued, the rest counted.
struct CadenceManifestCard: View {
    let run: CadenceProgress
    let haltedIndex: Int?
    let accent: Color
    /// How many queued steps are named; the rest join "N more to go". `CadenceMinimalFit` sets it.
    var queued: Int = 2

    @Environment(\.palette) private var palette

    private var finished: (shown: [InspectConfig.CadenceEntry], total: Int) {
        CadenceRollup.finished(run.entries, position: run.position, failed: run.failed)
    }

    private var failures: [InspectConfig.CadenceEntry] {
        CadenceRollup.failures(run.entries, position: run.position, failed: run.failed)
    }

    private func failureDetail(_ entry: InspectConfig.CadenceEntry) -> String {
        run.entries.firstIndex(where: { $0.id == entry.id }).map(run.message(at:)) ?? entry.message
    }

    private var waiting: (shown: [InspectConfig.CadenceEntry], beyond: Int) {
        CadenceRollup.waiting(run.entries, position: run.position, queued: queued)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceMinimalM.rowGap) {
            if finished.total > 0 { finishedRollup }
            ForEach(failures, id: \.id) { entry in
                CadenceFailedRow(entry: entry, detail: failureDetail(entry))
            }
            if let current = run.current { runningRow(current) }
            ForEach(waiting.shown, id: \.id) { entry in
                queuedRow(entry)
            }
            if waiting.beyond > 0 {
                Text("\(waiting.beyond) more to go")
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.textMuted)
                    .frame(height: 17)
            }
        }
    }

    /// Finished work as one line: the last marks overlapped, and the count.
    private var finishedRollup: some View {
        HStack(spacing: 10) {
            HStack(spacing: -CadenceMinimalM.iconOverlap) {
                ForEach(finished.shown, id: \.id) { entry in
                    CadenceStepMark(entry: entry, accent: accent)
                }
            }
            Text(finished.total == 1 ? "1 step done" : "\(finished.total) steps done")
                .font(.system(size: 13))
                .foregroundStyle(palette.textMuted)
            Spacer(minLength: 0)
        }
        .frame(height: CadenceMinimalM.rolledUpRow)
    }

    private func runningRow(_ entry: InspectConfig.CadenceEntry) -> some View {
        HStack(spacing: 14) {
            CadenceStepMark(entry: entry, side: CadenceMinimalM.runningIcon, accent: accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.label ?? entry.id)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(entry.message)
                    .font(.system(size: 13))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            ProgressView().controlSize(.small)
        }
        .frame(height: CadenceMinimalM.runningRow)
    }

    private func queuedRow(_ entry: InspectConfig.CadenceEntry) -> some View {
        HStack(spacing: 12) {
            CadenceStepMark(entry: entry, accent: palette.textMuted)
            Text(entry.label ?? entry.id)
                .font(.system(size: 14))
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: CadenceMinimalM.queuedRow)
    }
}

/// A step that did not finish: its mark, its name, and the script's last line for it.
struct CadenceFailedRow: View {
    let entry: InspectConfig.CadenceEntry
    let detail: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            CadenceStepMark(entry: entry, accent: palette.error)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(palette.cardSurface, palette.error)
                        .offset(x: 4, y: 4)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.label ?? entry.id)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.error)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .frame(height: CadenceMinimalM.queuedRow)
    }
}

// MARK: - The spotlight

/// The running step as the headline, with the last receipts beneath it.
struct CadenceSpotlightCard: View {
    let run: CadenceProgress
    let haltedIndex: Int?
    let accent: Color
    /// How many receipts are named; older ones join "and N before that". `CadenceMinimalFit` sets it.
    var named: Int = CadenceMinimalM.namedReceipts

    @Environment(\.palette) private var palette

    /// Named receipts, newest first.
    private var receipts: [InspectConfig.CadenceEntry] {
        CadenceRollup.finished(run.entries, position: run.position, named: named,
                               failed: run.failed).shown.reversed()
    }

    private var failures: [InspectConfig.CadenceEntry] {
        CadenceRollup.failures(run.entries, position: run.position, failed: run.failed)
    }

    private func failureDetail(_ entry: InspectConfig.CadenceEntry) -> String {
        run.entries.firstIndex(where: { $0.id == entry.id }).map(run.message(at:)) ?? entry.message
    }

    private var older: Int {
        let done = CadenceRollup.finished(run.entries, position: run.position, named: named,
                                          failed: run.failed)
        return max(0, done.total - done.shown.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceMinimalM.rowGap) {
            if let current = run.current { headline(current) }
            ForEach(failures, id: \.id) { entry in
                CadenceFailedRow(entry: entry, detail: failureDetail(entry))
            }
            ForEach(receipts, id: \.id) { entry in
                receiptRow(entry)
            }
            if older > 0 {
                Text("and \(older) before that")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textMuted)
                    .frame(height: 16)
            }
        }
    }

    private func headline(_ entry: InspectConfig.CadenceEntry) -> some View {
        HStack(alignment: .center, spacing: 16) {
            CadenceStepMark(entry: entry, side: CadenceMinimalM.headlineIcon, accent: accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.label ?? entry.id)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.message)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private func receiptRow(_ entry: InspectConfig.CadenceEntry) -> some View {
        HStack(spacing: 12) {
            CadenceStepMark(entry: entry, accent: palette.success)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.label ?? entry.id)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                Text(entry.subtitle ?? entry.message)
                    .font(.system(size: 11.5))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.success)
        }
        .frame(height: CadenceMinimalM.receiptRow)
    }
}

// MARK: - The sheet

/// The machine strip, the count and the glass: the frame both minimal cards sit in.
struct CadenceMinimalSheet<Card: View>: View {
    let run: CadenceProgress
    let accent: Color
    let size: CGSize
    /// The machine picture's height, from `CadenceMinimalFit` for this payload.
    var machineImage: CGFloat = CadenceMinimalM.machineImage
    @ViewBuilder var card: () -> Card

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CadenceMinimalM.sheetGap) {
            HStack(alignment: .center, spacing: 12) {
                CadenceMachineStrip(imageHeight: machineImage)
                Spacer(minLength: 16)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CadenceMinimalMeter.countLine(run))
                        .font(.system(size: 12.5))
                        .foregroundStyle(palette.textMuted)
                    if let remaining = CadenceMinimalMeter.timeRemaining(run) {
                        Text(remaining)
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.textMuted)
                    }
                }
            }
            // No Spacer: the card fills what the strip leaves.
            CadenceGlassCard(content: card)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    // No wash panel here; the shell's ground shows through the glass.
}
