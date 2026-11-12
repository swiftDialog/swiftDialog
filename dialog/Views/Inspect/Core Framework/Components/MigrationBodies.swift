//
//  MigrationBodies.swift
//  dialog
//
//  The four migration bodies (receipt, media split, task list, footer bar) as portable
//  components. The representation is chosen per element class, not per screen: facts panels and
//  instruction blocks are filled tiles, lists of state are hairline rows, media is a split. Every
//  body takes `width: CGFloat?` (nil fills the container) so any shell can host it.
//

import SwiftUI

/// The bodies' figures at 1×, kept apart from the window metrics so a body can be read at a width
/// without owning a window.
enum MigrationM {
    // MARK: - The receipt split (M1, M4)

    /// List, gap and panel sum to the 740 column.
    static let receiptListWidth: CGFloat = 416
    static let receiptGap: CGFloat = 20
    static let panelWidth: CGFloat = 296
    static var receiptWidth: CGFloat { receiptListWidth + receiptGap + panelWidth }

    // MARK: - The media split (M2)

    static let mediaStepsWidth: CGFloat = 332
    static let mediaGap: CGFloat = 16
    static let mediaColumnWidth: CGFloat = 384
    static var mediaSplitWidth: CGFloat { mediaStepsWidth + mediaGap + mediaColumnWidth }
    /// 16:10, inside the media column's margin.
    static let mediaWidth: CGFloat = 356
    static let mediaHeight: CGFloat = 222
    static let mediaRadius: CGFloat = 8

    // MARK: - The panel (M1, M4 right)

    /// The fill is `surfaceRaised`, which resolves in both appearances.
    static let panelRadius: CGFloat = 12
    static let panelPadV: CGFloat = 22
    static let panelPadH: CGFloat = 24
    static let figureSize: CGFloat = 27
    static let factLabelSize: CGFloat = 11.5
    static let factLabelTracking: CGFloat = 0.575   // .05em at 11.5pt
    static let factValueSize: CGFloat = 13.5
    static let factGap: CGFloat = 18
    /// A label binds tightly to the value under it.
    static let factLabelGap: CGFloat = 3

    // MARK: - Body geometry

    static let bodyTop: CGFloat = 152
    static let bodyHeight: CGFloat = 324
    static let containerRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let captionSize: CGFloat = 12.5
    static let captionGap: CGFloat = 14
    /// The M3 footer bar, which replaces the counter; no screen carries both.
    static let barWidth: CGFloat = 240
    static let barHeight: CGFloat = 5
    static let barRadius: CGFloat = 3

    /// Does the receipt split fit, or must the two columns stack?
    static func fitsReceiptSplit(in width: CGFloat) -> Bool { width >= receiptWidth }

    /// Does the media split fit?
    static func fitsMediaSplit(in width: CGFloat) -> Bool { width >= mediaSplitWidth }

    // MARK: - The narrow split
    //
    // Between the full split and stacking, the step text wraps in a fixed narrow column and the
    // walkthrough takes the remainder up to its authored width.

    static let narrowStepsWidth: CGFloat = 260
    /// Below this the walkthrough is not worth drawing beside anything; the host stacks.
    static let narrowMediaMin: CGFloat = 240
    static var narrowSplitWidth: CGFloat { narrowStepsWidth + mediaGap + narrowMediaMin }
    static func fitsNarrowSplit(in width: CGFloat) -> Bool {
        width >= narrowSplitWidth && !fitsMediaSplit(in: width)
    }
    /// The remainder beside a narrow instruction column, capped at the authored width.
    static func narrowMediaWidth(in width: CGFloat) -> CGFloat {
        min(mediaWidth, width - mediaGap - narrowStepsWidth)
    }
    /// Whatever the capped walkthrough leaves.
    static func narrowStepsColumn(in width: CGFloat) -> CGFloat {
        width - mediaGap - narrowMediaWidth(in: width)
    }

    /// The numbered chip on an instruction step.
    static let stepChip: CGFloat = 22
    static let stepChipGap: CGFloat = 12
    static let stepGap: CGFloat = 14
    static let stepTextSize: CGFloat = 13.5
}

/// One fact in the panel: a label above its value. `isFigure` draws the value at the large size,
/// for the one fact per panel that answers at a glance.
struct MigrationFact: Equatable, Identifiable {
    let id: String
    let label: String
    let value: String
    var isFigure: Bool = false

    init(id: String? = nil, label: String, value: String, isFigure: Bool = false) {
        self.id = id ?? label
        self.label = label
        self.value = value
        self.isFigure = isFigure
    }
}

/// The facts panel: a filled tile, because a fill is what separates a panel of answers from the
/// prose beside it.
struct MigrationFactsPanel: View {
    /// `.column` beside the list; `.row` when a narrow host stacks the panel under it and the
    /// tile is wide rather than tall.
    enum Axis { case column, row }

    let facts: [MigrationFact]
    /// nil fills the container.
    let width: CGFloat?
    var axis: Axis = .column

    @Environment(\.palette) private var palette

    var body: some View {
        if axis == .row { rowBody } else { columnBody }
    }

    private var rowBody: some View {
        HStack(alignment: .top, spacing: MigrationM.factGap) {
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: MigrationM.factLabelGap) {
                    Text(fact.label.uppercased())
                        .font(.system(size: MigrationM.factLabelSize, weight: .semibold))
                        .tracking(MigrationM.factLabelTracking)
                        .foregroundStyle(palette.textFaint)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(fact.value)
                        .font(.system(size: fact.isFigure ? MigrationM.figureSize
                                                          : MigrationM.factValueSize,
                                      weight: fact.isFigure ? .bold : .semibold))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, MigrationM.panelPadV)
        .padding(.horizontal, MigrationM.panelPadH)
        .frame(width: width, alignment: .topLeading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: MigrationM.panelRadius, style: .continuous)
            .fill(palette.surfaceRaised))
    }

    private var columnBody: some View {
        VStack(alignment: .leading, spacing: MigrationM.factGap) {
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: MigrationM.factLabelGap) {
                    Text(fact.label.uppercased())
                        .font(.system(size: MigrationM.factLabelSize, weight: .semibold))
                        .tracking(MigrationM.factLabelTracking)
                        .foregroundStyle(palette.textFaint)
                    Text(fact.value)
                        .font(.system(size: fact.isFigure ? MigrationM.figureSize
                                                          : MigrationM.factValueSize,
                                      weight: fact.isFigure ? .bold : .semibold))
                        .foregroundStyle(palette.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, MigrationM.panelPadV)
        .padding(.horizontal, MigrationM.panelPadH)
        .frame(width: width, alignment: .topLeading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: MigrationM.panelRadius, style: .continuous)
            .fill(palette.surfaceRaised))
    }
}

/// The receipt body, used for both the promise (M1) and the receipt read back (M4): a list of
/// state beside the facts panel. Rows are `ProvisioningRowModel`, so the mark vocabulary and the
/// shared row height are the app's own.
struct MigrationReceiptBody: View {
    let rows: [ProvisioningRowModel]
    let facts: [MigrationFact]
    /// The caption under the list.
    var caption: String?
    /// nil fills the container.
    let width: CGFloat?
    let accent: Color

    @Environment(\.palette) private var palette

    /// The panel keeps its fixed width; the list's sentences rewrap in what is left.
    private func listWidth(_ total: CGFloat) -> CGFloat {
        max(total - MigrationM.receiptGap - MigrationM.panelWidth, 0)
    }

    var body: some View {
        if let width {
            if MigrationM.fitsReceiptSplit(in: width) {
                split(listWidth: listWidth(width))
            } else {
                stacked(width: width)
            }
        } else {
            GeometryReader { geo in
                if MigrationM.fitsReceiptSplit(in: geo.size.width) {
                    split(listWidth: listWidth(geo.size.width))
                } else {
                    stacked(width: geo.size.width)
                }
            }
        }
    }

    private func split(listWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: MigrationM.receiptGap) {
            listColumn(width: listWidth)
            MigrationFactsPanel(facts: facts, width: MigrationM.panelWidth)
        }
    }

    private func stacked(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: MigrationM.receiptGap) {
            listColumn(width: width)
            // Across, not down: a host narrow enough to stack is rarely tall enough to absorb a
            // column of facts.
            MigrationFactsPanel(facts: facts, width: width, axis: .row)
        }
    }

    /// Green marks only when every row is done; derived, so no flag can be set on the wrong screen.
    private var marksCelebrate: Bool {
        !rows.isEmpty && rows.allSatisfy { $0.mark == .done }
    }

    var marksCelebrateForTesting: Bool { marksCelebrate }

    @ViewBuilder private func listColumn(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ProvisioningRowStack(rows: rows, width: width, accent: accent)
                .environment(\.provisioningMarksCelebrate, marksCelebrate)
            if let caption {
                Text(caption)
                    .font(.system(size: MigrationM.captionSize))
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, MigrationM.captionGap)
                    .frame(width: width, alignment: .leading)
            }
        }
    }
}

/// One numbered action inside the instruction tile. The number is the index, not a stored field.
struct MigrationActionStep: Equatable, Identifiable {
    let id: String
    let text: String

    init(id: String? = nil, text: String) {
        self.id = id ?? text
        self.text = text
    }
}

/// The numbered actions as one filled tile: hairline rows are for things that change state, and
/// these never do.
struct MigrationInstructionTile: View {
    let steps: [MigrationActionStep]
    /// nil fills the container.
    let width: CGFloat?
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: MigrationM.stepGap) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: MigrationM.stepChipGap) {
                    chip(index + 1)
                    Text(step.text)
                        .font(.system(size: MigrationM.stepTextSize))
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, MigrationM.panelPadV)
        .padding(.horizontal, MigrationM.panelPadH)
        .frame(width: width, alignment: .topLeading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: MigrationM.panelRadius, style: .continuous)
            .fill(palette.surfaceRaised))
    }

    /// The accent marks the primary button and the sequence that leads to it.
    private func chip(_ n: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: MigrationM.controlRadius - 2, style: .continuous)
                .fill(accent)
            Text("\(n)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: MigrationM.stepChip, height: MigrationM.stepChip)
    }
}

/// Instructions left, one looping walkthrough right. A split, never a preview grid: the frames
/// are one dialog at several moments, not alternatives.
struct MigrationMediaSplit: View {
    let steps: [MigrationActionStep]
    /// Runs through `IntroMediaPlayer`, so a movie, a GIF and a still all work.
    let mediaURL: URL?
    /// Caption under the instructions.
    var caption: String?
    /// Caption under the walkthrough.
    var mediaCaption: String?
    let width: CGFloat?
    /// The height the host has when stacking, or nil for as much as the body wants. The
    /// walkthrough is what yields, keeping its ratio: cropped, it would stop showing the button
    /// it points at.
    var maxHeight: CGFloat?
    let accent: Color

    @Environment(\.palette) private var palette
    /// Measured height of the instruction column, so the walkthrough can take the remainder.
    @State private var stepsHeight: CGFloat = 0

    /// What is left for the walkthrough once the instructions and its caption are paid for; nil
    /// without a budget.
    private var mediaBudget: CGFloat? {
        guard let maxHeight else { return nil }
        // Computed first, because the measurement lands after the first frame is drawn; the
        // measured value only refines it.
        let tile = MigrationM.panelPadV * 2
            + CGFloat(steps.count) * MigrationM.stepChip
            + CGFloat(max(steps.count - 1, 0)) * MigrationM.stepGap
        let listCaption = caption == nil ? 0
            : MigrationM.captionGap + MigrationM.captionSize * 1.6
        let estimated = tile + listCaption
        let used = stepsHeight > 0 ? stepsHeight : estimated
        let captionAllowance = mediaCaption == nil ? 0
            : MigrationM.captionGap + MigrationM.captionSize * 1.6
        let left = maxHeight - used - MigrationM.mediaGap - captionAllowance
        // A floor rather than a vanishing frame.
        return max(left, 96)
    }

    var body: some View {
        if let width {
            content(width: width)
        } else {
            GeometryReader { geo in content(width: geo.size.width) }
        }
    }

    /// In the narrow split the instructions sit beside the walkthrough, so only its caption is paid.
    private var narrowMediaBudget: CGFloat? {
        guard let maxHeight else { return nil }
        let captionAllowance = mediaCaption == nil ? 0
            : MigrationM.captionGap + MigrationM.captionSize * 1.6
        return max(maxHeight - captionAllowance, 96)
    }

    @ViewBuilder private func content(width: CGFloat) -> some View {
        if MigrationM.fitsMediaSplit(in: width) {
            HStack(alignment: .top, spacing: MigrationM.mediaGap) {
                stepsColumn(width: MigrationM.mediaStepsWidth)
                mediaColumn(width: MigrationM.mediaColumnWidth, budget: nil)
            }
        } else if MigrationM.fitsNarrowSplit(in: width) {
            HStack(alignment: .top, spacing: MigrationM.mediaGap) {
                stepsColumn(width: MigrationM.narrowStepsColumn(in: width))
                mediaColumn(width: MigrationM.narrowMediaWidth(in: width), budget: narrowMediaBudget)
            }
        } else {
            // Stacked. `IntroMediaPlayer` fixes its own height, so an outer `.frame(maxHeight:)`
            // cannot squeeze it; the instructions are measured and the remainder passed as height.
            VStack(alignment: .leading, spacing: MigrationM.mediaGap) {
                stepsColumn(width: width)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: MigrationStepsHeightKey.self,
                                               value: g.size.height)
                    })
                mediaColumn(width: width, budget: mediaBudget)
            }
            .onPreferenceChange(MigrationStepsHeightKey.self) { stepsHeight = $0 }
        }
    }

    @ViewBuilder private func stepsColumn(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MigrationInstructionTile(steps: steps, width: width, accent: accent)
            if let caption {
                Text(caption)
                    .font(.system(size: MigrationM.captionSize))
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, MigrationM.captionGap)
                    .frame(width: width, alignment: .leading)
            }
        }
    }

    @ViewBuilder private func mediaColumn(width: CGFloat, budget: CGFloat?) -> some View {
        // A budget caps the height and the width follows the ratio: the same picture, smaller.
        let naturalW = min(MigrationM.mediaWidth, width)
        let naturalH = naturalW * (MigrationM.mediaHeight / MigrationM.mediaWidth)
        let mediaH = min(naturalH, budget ?? naturalH)
        let mediaW = mediaH * (MigrationM.mediaWidth / MigrationM.mediaHeight)
        VStack(alignment: .leading, spacing: 0) {
            IntroMediaPlayer(url: mediaURL, autoplay: true, height: mediaH,
                             cornerRadius: MigrationM.mediaRadius, fit: .fit)
                .frame(width: mediaW, height: mediaH)
                .clipShape(RoundedRectangle(cornerRadius: MigrationM.mediaRadius,
                                            style: .continuous))
            if let mediaCaption {
                Text(mediaCaption)
                    .font(.system(size: MigrationM.captionSize))
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, MigrationM.captionGap)
                    .frame(width: mediaW, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }
}

/// The task list: rows at the full column with a caption, and nothing else. The screen advances
/// itself, so no disabled primary; its footer bar replaces the counter, never both.
struct MigrationTaskListBody: View {
    let rows: [ProvisioningRowModel]
    var caption: String?
    let width: CGFloat?
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProvisioningRowStack(rows: rows, width: width, accent: accent)
            if let caption {
                Text(caption)
                    .font(.system(size: MigrationM.captionSize))
                    .foregroundStyle(palette.textFaint)
                    .padding(.top, MigrationM.captionGap)
                    .frame(width: width, alignment: .leading)
                    .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            }
        }
    }
}

/// The task list's progress bar, placed by the shell in the footer rather than under the lede,
/// where it would compete with the title.
struct MigrationFooterBar: View {
    let fraction: Double
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: MigrationM.barRadius)
                .fill(palette.text.opacity(0.18))
                .frame(width: MigrationM.barWidth, height: MigrationM.barHeight)
            RoundedRectangle(cornerRadius: MigrationM.barRadius)
                .fill(accent)
                .frame(width: MigrationM.barWidth * clamped, height: MigrationM.barHeight)
        }
    }
}

/// Which body a step draws, decided by the roles of the blocks it contains rather than a step
/// type, so existing configs need no new key and a new block type inherits a body.
enum MigrationBodyKind: Equatable {
    /// A list of state beside a facts panel.
    case receipt
    /// Instructions beside one looping walkthrough.
    case mediaSplit
    /// Rows at the full column, and nothing else.
    case taskList

    /// nil means the step is not a migration body and the host draws it. Media wins, then facts,
    /// then rows: the walkthrough is kept over the instructions, and a facts panel is what makes
    /// a receipt.
    static func resolve(roles: [GuidanceBlockRole]) -> MigrationBodyKind? {
        if roles.contains(.media) { return .mediaSplit }
        if roles.contains(.data) { return .receipt }
        if roles.contains(.list) || roles.contains(.state) { return .taskList }
        return nil
    }

    /// The config-facing spelling; the roles overload keeps the decision testable without a
    /// decoded config.
    static func resolve(blocks: [InspectConfig.GuidanceContent]?) -> MigrationBodyKind? {
        guard let blocks, !blocks.isEmpty else { return nil }
        guard let kind = resolve(roles: blocks.map { GuidanceBlockRole(blockType: $0.type) })
        else { return nil }
        return canPopulate(kind, from: blocks) ? kind : nil
    }

    /// A body that cannot fill itself does not claim the step: the right role with the wrong
    /// fields would render an empty frame. The fields are the ones `MigrationPayload` reads, and
    /// must stay in step with it.
    static func canPopulate(_ kind: MigrationBodyKind,
                            from blocks: [InspectConfig.GuidanceContent]) -> Bool {
        switch kind {
        case .mediaSplit:
            return blocks.contains {
                GuidanceBlockRole(blockType: $0.type) == .media
                    && !(($0.content ?? $0.text) ?? "").isEmpty
            }
        case .receipt:
            return blocks.contains { !($0.stats?.isEmpty ?? true) }
        case .taskList:
            // A `phase-tracker` carries the `.state` role and neither field.
            return blocks.contains {
                !($0.checklist?.isEmpty ?? true) || !($0.items?.isEmpty ?? true)
            }
        }
    }
}

/// The measured height of the instruction column, so the walkthrough can take the remainder.
private struct MigrationStepsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
