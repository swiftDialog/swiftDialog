//
//  PlainSimpleListScreen.swift
//  dialog
//
//  The list body of the plain-simple construction: hero, title and subtitle on fixed bands, then
//  a pinned item card that hugs whole rows and scrolls past its ceiling. Item icons draw
//  through `IconView`, which handles `SF=` symbols and app bundles.
//

import SwiftUI

struct PlainSimpleListScreen: View {
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let model: ItemSetModel
    let title: String
    let subtitle: String
    /// The flow's accent, shared with the shell's primary button.
    let accent: Color
    /// The same lookup Preset 1 rows use, so an authored `localization` block applies here too.
    let loc: PresetLocalization
    /// When set, this migration body takes the content box in place of the card; the bands
    /// above it stay where they are.
    var migrationKind: MigrationBodyKind?

    @Environment(\.palette) private var palette

    /// Read off the `ScrollView`'s own geometry for the fade overlay.
    @State private var hintContentHeight: CGFloat = 0
    @State private var hintScrollOffset: CGFloat = 0

    /// Rows that fit under the card ceiling; the rest scroll and are counted by the queued line.
    private var displayedRowCount: Int {
        let budget = PlainSimpleM.cardMaxHeight - PlainSimpleM.queuedLineHeight
        var used: CGFloat = 0
        var shown = 0
        for row in model.rows {
            let h = rowHeight(row)
            if used + h > budget { break }
            used += h
            shown += 1
        }
        return max(shown, 1)
    }

    private var hiddenRowCount: Int { max(model.rows.count - displayedRowCount, 0) }
    private func rowHeight(_ row: ItemSetModel.Row) -> CGFloat {
        row.status == .active
            ? PlainSimpleM.activeRowHeight + PlainSimpleM.activeRowMargin * 2
            : PlainSimpleM.cardRowHeight
    }

    /// Whole rows plus the queued line when needed, so no row is sliced at the card edge.
    private var cardHeight: CGFloat {
        guard !model.rows.isEmpty else { return PlainSimpleM.cardRowHeight }
        var h = model.rows.prefix(displayedRowCount).reduce(CGFloat(0)) { $0 + rowHeight($1) }
        if hiddenRowCount > 0 { h += PlainSimpleM.queuedLineHeight }
        return min(h, PlainSimpleM.cardMaxHeight)
    }

    private var hasActiveRow: Bool { model.rows.contains { $0.status == .active } }

    /// Absolute offsets, not a stack: every plain-simple screen shares these anchors, so a flow
    /// can step between them without the window appearing to resize.
    var body: some View {
        ZStack(alignment: .topLeading) {
            heroMark
                .frame(width: PlainSimpleM.heroSize, height: PlainSimpleM.heroSize)
                .onAppear { iconCache.cacheMainIcon(for: inspectState) }
                .offset(x: PlainSimpleM.textRail, y: PlainSimpleM.heroTop)

            Text(title)
                .font(.system(size: PlainSimpleM.titleSize, weight: .bold))
                .foregroundStyle(palette.text)
                // One line: a second would push the title off the hero's optical centre.
                .lineLimit(1)
                .frame(width: PlainSimpleM.mirror - PlainSimpleM.titleRail, alignment: .leading)
                .offset(x: PlainSimpleM.titleRail, y: PlainSimpleM.titleTop)

            // The card stays pinned whether or not this draws.
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: PlainSimpleM.subtitleSize))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                    .frame(width: PlainSimpleM.textColumn, alignment: .leading)
                    .offset(x: PlainSimpleM.textRail, y: PlainSimpleM.subtitleTop)
            }

            Group {
                if let migrationKind {
                    migrationBody(migrationKind)
                } else {
                    card
                }
            }
            .frame(width: PlainSimpleM.cardWidth, alignment: .topLeading)
            .offset(x: PlainSimpleM.mediaRail, y: PlainSimpleM.contentBoxTop)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Hero mark

    /// The hero, sized by its visible content: bitmaps are trimmed of transparent margin so an app
    /// icon, the `computer` image and a brand mark fill the slot alike. SF symbols stay on `IconView`.
    /// Trimmed once per image version: this view redraws on every poll.
    @ViewBuilder
    private var heroMark: some View {
        let path = iconCache.getMainIconPath(for: inspectState)
        if let trimmed = InspectImageCache.shared.derivedImage("trimmed-hero", fromPath: path,
                                                               make: { Self.trimmedHeroImage(for: path) }) {
            Image(nsImage: trimmed)
                .resizable()
                .scaledToFit()
        } else {
            IconView(image: path,
                     overlay: iconCache.getOverlayIconPath(for: inspectState),
                     sfPaddingEnabled: false,
                     defaultImage: "computer",
                     defaultColour: "accent")
        }
    }

    /// A trimmed bitmap for the `computer` keyword, an app bundle or an image file; nil for
    /// `SF=`, `http` and `default`, which fall back to `IconView`.
    private static func trimmedHeroImage(for path: String) -> NSImage? {
        let lower = path.lowercased()
        guard !lower.hasPrefix("sf="), !lower.hasPrefix("http"), lower != "default" else { return nil }

        let resolved: NSImage?
        if lower == "computer" {
            resolved = NSImage(named: NSImage.computerName)
        } else if lower.hasSuffix(".app") || lower.hasSuffix(".app/") {
            resolved = NSWorkspace.shared.icon(forFile: (path as NSString).expandingTildeInPath)
        } else {
            resolved = InspectImageCache.shared.image(atPath: (path as NSString).expandingTildeInPath)
        }
        guard let resolved, resolved.size.width > 0, resolved.size.height > 0 else { return nil }
        return resolved.trimmingTransparentBorder()
    }

    /// The item card: as tall as its rows up to the ceiling, then scrolling behind a fade with
    /// the queued line counting the rest.
    private var card: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.rows.isEmpty {
                        emptyState
                    } else {
                        // Keyed on position: a duplicate item id would make SwiftUI drop a row.
                        ForEach(Array(model.rows.enumerated()), id: \.offset) { _, row in
                            rowView(row)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height
            } action: { _, newHeight in
                hintContentHeight = newHeight
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newOffsetY in
                // `ScrollHintOverlay` expects the `.frame(in:).minY` sign convention (negative when scrolled).
                hintScrollOffset = -newOffsetY
            }
            // Draws nothing until the content overflows.
            .overlay(
                GeometryReader { geo in
                    ScrollHintOverlay(containerHeight: geo.size.height,
                                      contentHeight: hintContentHeight,
                                      scrollOffset: hintScrollOffset)
                }
            )

            if hiddenRowCount > 0 {
                queuedLine
            }
        }
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: PlainSimpleM.cardRadius, style: .continuous)
                // `surfaceRaised` is relative to the text colour, so the fill survives dark mode.
                .fill(palette.surfaceRaised)
        )
        // Keeps scrolled rows inside the corner radius.
        .clipShape(RoundedRectangle(cornerRadius: PlainSimpleM.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PlainSimpleM.cardRadius, style: .continuous)
                .strokeBorder(palette.text.opacity(0.08), lineWidth: 1)
        )
    }

    /// "3 more items queued", pinned below the scroll area so it cannot scroll out of sight.
    private var queuedLine: some View {
        HStack(spacing: 0) {
            Text("\(hiddenRowCount) more item\(hiddenRowCount == 1 ? "" : "s") queued")
                .font(.system(size: 13))
                .foregroundStyle(palette.textMuted)
            Spacer(minLength: 0)
        }
        .frame(height: PlainSimpleM.queuedLineHeight)
        .padding(.horizontal, PlainSimpleM.cardInset)
    }

    /// One item row; the active row is taller and sits on a raised fill.
    private func rowView(_ row: ItemSetModel.Row) -> some View {
        let isActive = row.status == .active
        return HStack(alignment: .center, spacing: PlainSimpleM.rowGutter) {
            IconView(image: iconCache.getItemIconPath(for: row.item, state: inspectState))
                .frame(width: PlainSimpleM.rowIconSize, height: PlainSimpleM.rowIconSize)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(loc.string("\(row.item.id).displayName", fallback: row.item.displayName) ?? row.item.displayName)
                    .font(.system(size: 15))
                    // One line: the card height is derived from fixed row heights.
                    .lineLimit(1)
                    .foregroundStyle(palette.text)
                Text(loc.itemStatus(for: row.item, baseStatus: row.statusText))
                    .font(.system(size: 12))
                    .foregroundStyle(ItemSetModel.itemStatusColor(row.status,
                                                                   hasWarning: row.hasWarning,
                                                                   palette: palette))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            StatusIndicatorCircle(status: row.status, hasWarning: row.hasWarning, accent: accent, size: 18)
        }
        .padding(.horizontal, PlainSimpleM.cardInset)
        .frame(height: isActive ? PlainSimpleM.activeRowHeight : PlainSimpleM.cardRowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? palette.surfaceRaised : Color.clear)
                .padding(.horizontal, isActive ? PlainSimpleM.activeRowInset : 0)
        )
        .padding(.vertical, isActive ? PlainSimpleM.activeRowMargin : 0)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 22))
                Text("Nothing to install.")
            }
            .foregroundStyle(palette.textMuted)
            Spacer()
        }
        .padding(.vertical, 40)
    }

    /// A migration body at the card column's width, built from the same `MigrationPayload` as other hosts.
    @ViewBuilder private func migrationBody(_ kind: MigrationBodyKind) -> some View {
        let blocks = (inspectState.config?.guidanceContent ?? [])
            .map(InspectConfig.GuidanceContent.normalized)
        switch kind {
        case .receipt:
            MigrationReceiptBody(
                rows: MigrationPayload.rows(from: blocks),
                facts: MigrationPayload.facts(from: blocks),
                caption: MigrationPayload.caption(from: blocks, role: .list),
                width: PlainSimpleM.cardWidth, accent: accent)
        case .mediaSplit:
            MigrationMediaSplit(
                steps: MigrationPayload.actionSteps(from: blocks),
                mediaURL: MigrationPayload.mediaURL(from: blocks),
                caption: MigrationPayload.caption(from: blocks, role: .list),
                mediaCaption: MigrationPayload.caption(from: blocks, role: .media),
                width: PlainSimpleM.cardWidth,
                // The content box does not scroll, so the body obeys the card ceiling.
                maxHeight: PlainSimpleM.cardMaxHeight, accent: accent)
        case .taskList:
            MigrationTaskListBody(
                rows: MigrationPayload.rows(from: blocks),
                caption: MigrationPayload.caption(from: blocks, role: .list),
                width: PlainSimpleM.cardWidth, accent: accent)
        }
    }
}
