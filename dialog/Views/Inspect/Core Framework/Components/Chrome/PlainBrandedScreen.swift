//
//  PlainBrandedScreen.swift
//  dialog
//
//  Body of the `plain-branded` construction: a left-aligned 500pt column (title, subtitle, item
//  card, guidance blocks) centred as a block in the region `PlainBrandedShell` offers. The shell
//  owns the action pill and any footer band; this view fills whatever height it is given.
//
//  Layout rules: every element starts on the column's one left edge; title and subtitle have zero
//  gap; the card grows uncapped and the whole column is the single scroll surface.
//

import SwiftUI

struct PlainBrandedScreen: View {
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let model: ItemSetModel
    let title: String
    let subtitle: String
    /// The flow's branded colour. Reaches only the migration bodies; the guidance payload is handed
    /// `palette.textMuted` so the shell's action pill stays the one accent-coloured object.
    let accent: Color
    /// Same lookup the sibling screens use, so a `localization` block applies here too.
    let loc: PresetLocalization

    @Environment(\.palette) private var palette

    /// Content height and scroll offset for `ScrollHintOverlay`, read via `onScrollGeometryChange`
    /// (macOS 15+); the background-GeometryReader preference trick reports 0 for this column.
    @State private var hintContentHeight: CGFloat = 0
    @State private var hintScrollOffset: CGFloat = 0

    /// The whole column scrolls as a unit; short content stays top-anchored and leaves the void
    /// below untouched. The bottom fade runs whenever content overflows, footer or not, because in
    /// the no-footer mode the pill floats over this region.
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Default indicators stay on, matching the sibling plain screens.
                ScrollView(.vertical) {
                    columnStack
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentSize.height
                } action: { _, newHeight in
                    hintContentHeight = newHeight
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, newOffsetY in
                    // `ScrollHintOverlay` expects `trackScrollForHint`'s sign (negative when
                    // scrolled); `contentOffset.y` is positive, so negate.
                    hintScrollOffset = -newOffsetY
                }

                ScrollHintOverlay(
                    containerHeight: geo.size.height,
                    contentHeight: hintContentHeight,
                    scrollOffset: hintScrollOffset
                )
            }
        }
    }

    /// Header pair, card and guidance blocks, without `body`'s scroll and fade wrapping.
    private var columnStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: PlainBrandedM.titleFontSize, weight: .bold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            // An absent subtitle must cost no space.
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: PlainBrandedM.subtitleFontSize))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }

            // A config with no `items` gets no card at all; one whose items are all filtered
            // or unresolved keeps the card and its empty state.
            if authorsItems {
                card
                    .padding(.top, PlainBrandedM.groupGap)
            }

            // An empty block array must cost no space. Migration bodies pick their stacked arm
            // at this width; `usesMigrationBodies` gates them because `resolve` matches block
            // roles nearly every step carries, and a body drops blocks it has no concept of.
            if inspectState.config?.usesMigrationBodies == true,
               let kind = MigrationBodyKind.resolve(blocks: guidanceBlocks) {
                migrationBody(kind)
                    .padding(.top, PlainBrandedM.groupGap)
            } else if !guidanceBlocks.isEmpty {
                GuidanceContentView(
                    contentBlocks: guidanceBlocks,
                    scaleFactor: 1,
                    iconBasePath: inspectState.config?.iconBasePath,
                    inspectState: inspectState,
                    itemId: "plain-branded-guidance",
                    // Muted, not `accent`: the shell's pill stays the one accent-coloured object.
                    // Palette-derived so a tenant's `textSecondary` moves the payload too.
                    accentColor: palette.textMuted,
                    contentAlignment: .leading,
                    // Half the group gap, so the column keeps one vertical measure as a ratio.
                    blockSpacing: PlainBrandedM.payloadBlockGap,
                    // `contentAlignment` is text-only; media needs its own leading alignment.
                    mediaAlignment: .leading
                )
                .environment(\.brandedControls, true)
                .padding(.top, PlainBrandedM.groupGap)
            }
        }
        .frame(width: PlainBrandedM.columnWidth, alignment: .leading)
        // Centres the column as a block; the `.leading` frame above governs content within it.
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, authorsItems ? PlainBrandedM.topOffset(forRowCount: model.rows.count)
                                    : PlainBrandedM.topOffset)
    }

    /// Whether the config authored any items; distinct from `model.rows.isEmpty`, which is also
    /// true when every item is filtered or unresolved.
    private var authorsItems: Bool {
        !(inspectState.config?.items.isEmpty ?? true)
    }

    // MARK: - Guidance blocks

    /// Root-level `guidanceContent` (this construction has no step machine), already filtered to
    /// `InspectConfig.plainBrandedAllowedBlockTypes` by the decoder; nothing is re-checked here.
    private var guidanceBlocks: [InspectConfig.GuidanceContent] {
        inspectState.config?.guidanceContent ?? []
    }

    /// A migration body at the plain-branded column, built with the same `MigrationPayload`
    /// readers the other hosts use so every host reads authored blocks identically.
    @ViewBuilder private func migrationBody(_ kind: MigrationBodyKind) -> some View {
        let blocks = guidanceBlocks.map(InspectConfig.GuidanceContent.normalized)
        switch kind {
        case .receipt:
            MigrationReceiptBody(
                rows: MigrationPayload.rows(from: blocks),
                facts: MigrationPayload.facts(from: blocks),
                caption: MigrationPayload.caption(from: blocks, role: .list),
                width: PlainBrandedM.columnWidth, accent: accent)
        case .mediaSplit:
            MigrationMediaSplit(
                steps: MigrationPayload.actionSteps(from: blocks),
                mediaURL: MigrationPayload.mediaURL(from: blocks),
                caption: MigrationPayload.caption(from: blocks, role: .list),
                mediaCaption: MigrationPayload.caption(from: blocks, role: .media),
                width: PlainBrandedM.columnWidth, accent: accent)
        case .taskList:
            MigrationTaskListBody(
                rows: MigrationPayload.rows(from: blocks),
                caption: MigrationPayload.caption(from: blocks, role: .list),
                width: PlainBrandedM.columnWidth, accent: accent)
        }
    }

    // MARK: - Card

    /// Hugs its rows and grows uncapped; the column-level scroll in `body` is the only scroll.
    private var card: some View {
        cardRows
            .frame(height: PlainBrandedM.cardHeight(forRowCount: model.rows.count))
            .background(
                RoundedRectangle(cornerRadius: PlainBrandedM.cardRadius, style: .continuous)
                    .fill(palette.surfaceRaised)
            )
            .clipShape(RoundedRectangle(cornerRadius: PlainBrandedM.cardRadius, style: .continuous))
    }

    private var cardRows: some View {
        VStack(alignment: .leading, spacing: PlainBrandedM.cardGutter) {
            if model.rows.isEmpty {
                emptyState
            } else {
                // Keyed on position: `ItemSetModel.build` can emit one item twice.
                ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                    rowView(row)
                }
            }
        }
        .padding(.vertical, PlainBrandedM.cardPaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rowView(_ row: ItemSetModel.Row) -> some View {
        HStack(alignment: .center, spacing: PlainBrandedM.cardGutter) {
            // `IconView`'s fixed 10pt SF-symbol inset would crush a 22pt glyph to a few points.
            IconView(image: iconCache.getItemIconPath(for: row.item, state: inspectState),
                      sfPaddingEnabled: false)
                .frame(width: PlainBrandedM.cardIconSize, height: PlainBrandedM.cardIconSize)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(loc.string("\(row.item.id).displayName", fallback: row.item.displayName) ?? row.item.displayName)
                    .font(.system(size: PlainBrandedM.cardTitleFontSize, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                // The word stays beside the trailing mark: only it carries an author's
                // `uiLabels` wording.
                Text(loc.itemStatus(for: row.item, baseStatus: row.statusText))
                    .font(.system(size: PlainBrandedM.cardDetailFontSize))
                    .foregroundStyle(ItemSetModel.itemStatusColor(row.status,
                                                                   hasWarning: row.hasWarning,
                                                                   palette: palette))
                    .lineLimit(1)
            }
            // A frame, not a `Spacer`: a spacer child would cost a second `cardGutter` and take
            // it out of the name's truncation budget.
            .frame(maxWidth: .infinity, alignment: .leading)

            statusMark(row)
        }
        .padding(.horizontal, PlainBrandedM.cardPaddingHorizontal)
        .frame(minHeight: PlainBrandedM.cardRowContentHeight)
    }

    // MARK: - Trailing status mark

    /// A bare tinted SF Symbol at the row's title size, tinted by `itemStatusColor` like the word; the symbol
    /// separates `.pending` from `.skipped` and `.active` spins. Tooltips match `StatusIndicatorCircle`.
    @ViewBuilder
    private func statusMark(_ row: ItemSetModel.Row) -> some View {
        let tint = ItemSetModel.itemStatusColor(row.status,
                                                hasWarning: row.hasWarning,
                                                palette: palette)
        switch row.status {
        case .failed:
            glyphMark(StatusGlyph.failure, tint: tint, label: "Installation failed")
        case .completed:
            if row.hasWarning {
                glyphMark(StatusGlyph.warning, tint: tint,
                          label: "Installed, but a setting couldn't be verified")
            } else {
                glyphMark(StatusGlyph.success, tint: tint, label: "Installed and validated")
            }
        case .skipped:
            glyphMark(StatusGlyph.success, tint: tint, label: "Skipped")
        case .active:
            // The small spinner measures 16pt, so it is scaled to `cardMarkSize`. No `.tint`:
            // macOS draws a circular `ProgressView` as a spinning `NSProgressIndicator`, which
            // ignores it; the word beside it carries the colour.
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.small)
                .scaleEffect(PlainBrandedM.cardMarkSize / 16)
                .frame(width: PlainBrandedM.cardMarkSize, height: PlainBrandedM.cardMarkSize)
                .help("Installing…")
                .accessibilityLabel("Installing")
        case .pending:
            glyphMark(StatusGlyph.pending, tint: tint, label: "Waiting")
        }
    }

    /// One glyph in a fixed 14pt layout box, unclipped. `label` is both the tooltip and the
    /// accessibility label; without the latter macOS announces the symbol's generic name.
    private func glyphMark(_ glyph: StatusGlyph, tint: Color, label: String) -> some View {
        Image(systemName: glyph.symbol)
            .font(.system(size: PlainBrandedM.cardTitleFontSize))
            .foregroundStyle(tint)
            .frame(width: PlainBrandedM.cardMarkSize, height: PlainBrandedM.cardMarkSize)
            .help(label)
            .accessibilityLabel(label)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: PlainBrandedM.cardIconSize))
                Text("Nothing to install.")
                    .font(.system(size: PlainBrandedM.cardDetailFontSize))
            }
            .foregroundStyle(palette.textMuted)
            Spacer()
        }
        .frame(minHeight: PlainBrandedM.cardRowContentHeight)
    }
}
