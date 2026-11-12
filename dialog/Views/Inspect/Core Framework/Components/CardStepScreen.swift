//
//  CardStepScreen.swift
//  dialog
//
//  CardStepScreen renders a whole card from CardStepModel; CardContentBlocks is its left-column block renderer.
//

import SwiftUI

// MARK: - Screen

struct CardStepScreen: View {
    let model: CardStepModel
    let accent: Color
    /// Fallback context: blocks the card does not style render through `GuidanceContentView`.
    @ObservedObject var inspectState: InspectState
    let scaleFactor: CGFloat
    let iconBasePath: String?
    let stepId: String
    /// Per-line checklist watch results, stepId → satisfied flags, passed to `CardContentBlocks`.
    /// Empty for callers that do not own this cache.
    let checklistLineSatisfied: [String: [Bool]]

    // Explicit init: a stored default does not become an optional parameter of the synthesized memberwise init.
    init(model: CardStepModel, accent: Color, inspectState: InspectState, scaleFactor: CGFloat,
        iconBasePath: String?, stepId: String, checklistLineSatisfied: [String: [Bool]] = [:]) {
        self.model = model
        self.accent = accent
        self.inspectState = inspectState
        self.scaleFactor = scaleFactor
        self.iconBasePath = iconBasePath
        self.stepId = stepId
        self.checklistLineSatisfied = checklistLineSatisfied
    }

    var body: some View {
        CardStepShell(
            eyebrow: model.eyebrow,
            eyebrowIcon: model.eyebrowIcon,
            stepLabel: model.stepLabel,
            hero: model.hero,
            title: model.title,
            onTitleInfo: model.onTitleInfo,
            titleBadge: model.titleBadge,
            titleBadgeFailed: model.titleBadgeFailed,
            subtitle: model.subtitle,
            progress: model.progress,
            accent: accent,
            footer: model.footer
        ) {
            // Content taller than the payload band scrolls, never clips. The reader lets a `prose` block
            // keep its newest line in view.
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    HStack(alignment: .top, spacing: InspectMetrics.unit.cardColGap) {
                        if model.panelLeading, let panel = model.panel {
                            CardPanelView(panel: panel, accent: accent)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            leftColumn(scrollProxy: scrollProxy)
                                .frame(width: InspectMetrics.unit.cardListWidth, alignment: .leading)
                        } else if let panel = model.panel {
                            leftColumn(scrollProxy: scrollProxy)
                                .frame(width: InspectMetrics.unit.cardListWidth, alignment: .leading)
                            CardPanelView(panel: panel, accent: accent)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        } else {
                            // No panel: the column takes the whole width, so wide blocks (dock-picker
                            // cards) do not overlap. Copy keeps its measure via `cardCopyMax`.
                            leftColumn(scrollProxy: scrollProxy)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func leftColumn(scrollProxy: ScrollViewProxy?) -> some View {
        if let substeps = model.substeps {
            VStack(alignment: .leading, spacing: 13) {
                ForEach(substeps.indices, id: \.self) { i in
                    CardSubstepRow(state: substeps[i].state,
                                   label: substeps[i].label,
                                   accent: accent)
                }
                if let escape = model.escape {
                    RailEscapeHatch(model: escape)
                        .padding(.top, 8)
                }
            }
            // Substep rows are copy and keep their measure; no-op beside a panel.
            .frame(maxWidth: InspectMetrics.unit.cardCopyMax, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                CardContentBlocks(blocks: model.blocks,
                                  accent: accent,
                                  inspectState: inspectState,
                                  scaleFactor: scaleFactor,
                                  iconBasePath: iconBasePath,
                                  stepId: stepId,
                                  checklistLineSatisfied: checklistLineSatisfied,
                                  scrollProxy: scrollProxy)
                // After the blocks, before the failures: the legacy outro's order.
                if !model.receipt.isEmpty {
                    ChoiceReceipt(rows: model.receipt,
                                  accent: accent,
                                  scaleFactor: scaleFactor,
                                  changeLabel: model.receiptChangeLabel,
                                  onChange: { model.onReceiptChange?($0) })
                        .frame(maxWidth: InspectMetrics.unit.cardCopyMax, alignment: .leading)
                }
                // After the receipt, as in the legacy closer: decisions made, then the checks that ran.
                if let recap = model.recap {
                    CadenceRecapView(model: recap)
                }
                ForEach(model.failures.indices, id: \.self) { i in
                    CardSubstepRow(state: .failed,
                                   label: model.failures[i].detail.map {
                                       "\(model.failures[i].label) — \($0)"
                                   } ?? model.failures[i].label,
                                   accent: accent)
                        .frame(maxWidth: InspectMetrics.unit.cardCopyMax, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - Left-column block renderer

/// GuidanceContent → card rows: bullets → promise rows, numbered bullets → numbered rows, warning → amber
/// box, text → paragraph. Everything else goes through `GuidanceContentView`. `checklist` has no arm here,
/// so `GuidanceChecklistBlock` draws it with the same `checklistLineSatisfied` cache and never fakes a check.
struct CardContentBlocks: View {
    @Environment(\.palette) private var palette
    let blocks: [InspectConfig.GuidanceContent]
    let accent: Color
    @ObservedObject var inspectState: InspectState
    let scaleFactor: CGFloat
    let iconBasePath: String?
    let stepId: String
    let checklistLineSatisfied: [String: [Bool]]
    /// The enclosing ScrollView's proxy, for the `prose` arm's follow behaviour.
    let scrollProxy: ScrollViewProxy?

    // Explicit init: a stored default does not become an optional memberwise-init parameter.
    init(blocks: [InspectConfig.GuidanceContent], accent: Color, inspectState: InspectState,
        scaleFactor: CGFloat, iconBasePath: String?, stepId: String,
        checklistLineSatisfied: [String: [Bool]] = [:], scrollProxy: ScrollViewProxy? = nil) {
        self.blocks = blocks
        self.accent = accent
        self.inspectState = inspectState
        self.scaleFactor = scaleFactor
        self.iconBasePath = iconBasePath
        self.stepId = stepId
        self.checklistLineSatisfied = checklistLineSatisfied
        self.scrollProxy = scrollProxy
    }

    /// The measure for copy-bearing arms; it binds only when the panel-less column grows. The `default:`
    /// arm (pickers, grids, media) is uncapped.
    private var copyMax: CGFloat { InspectMetrics.unit.cardCopyMax }

    var body: some View {
        ForEach(blocks.indices, id: \.self) { i in
            let block = blocks[i]
            switch block.type {
            case "bullets" where block.numbered == true:
                VStack(alignment: .leading, spacing: 15) {
                    ForEach((block.items ?? []).indices, id: \.self) { j in
                        CardNumberedRow(index: j + 1, text: (block.items ?? [])[j],
                                        accent: accent)
                    }
                }
                .frame(maxWidth: copyMax, alignment: .leading)
            case "bullets":
                VStack(alignment: .leading, spacing: 14) {
                    ForEach((block.items ?? []).indices, id: \.self) { j in
                        CardPromiseRow(text: (block.items ?? [])[j], accent: accent)
                    }
                }
                .frame(maxWidth: copyMax, alignment: .leading)
            case "warning":
                CardWarningBox(text: block.content ?? "")
                    .frame(maxWidth: copyMax, alignment: .leading)
                    .padding(.top, 4)
            case "prose":
                // The scroll owner follows the block's tail as it changes, unless `follow` is off.
                let anchor = "prose-tail-\(stepId)-\(i)"
                VStack(alignment: .leading, spacing: 0) {
                    GuidanceProseBlock(content: block.content ?? "", placeholder: block.placeholder,
                                       streaming: GuidanceProseBlock.streaming(from: block.state), scaleFactor: scaleFactor)
                    Color.clear.frame(height: 1).id(anchor).accessibilityHidden(true)
                }
                .frame(maxWidth: copyMax, alignment: .leading)
                .onChange(of: block.content ?? "") { _, _ in
                    guard block.follow ?? true, let scrollProxy else { return }
                    withAnimation(.easeOut(duration: 0.15)) { scrollProxy.scrollTo(anchor, anchor: .bottom) }
                }
            case "text":
                if let text = block.content {
                    Text(guidanceAttributedMarkdown(text))
                        .font(.system(size: 14.5, weight: block.bold == true ? .semibold : .regular))
                        .foregroundStyle(palette.text.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: copyMax, alignment: .leading)
                }
            default:
                GuidanceContentView(
                    contentBlocks: [block],
                    scaleFactor: scaleFactor,
                    iconBasePath: iconBasePath,
                    inspectState: inspectState,
                    itemId: stepId,
                    accentColor: accent,
                    checklistLineSatisfied: block.type == "checklist" ? checklistLineSatisfied[stepId] : nil
                )
            }
        }
    }
}
