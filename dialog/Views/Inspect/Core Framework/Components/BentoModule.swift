//
//  BentoModule.swift
//  dialog
//
//  The bento module: `.heroRow` (hero over supporting tiles) and `.heroColumn` (stat tiles beside
//  a hero) over one cell vocabulary. A cell with `detailOverlay` expands in place through
//  `ExpandableTileLayer`, never as a sheet; `detailPresentation` is ignored here.
//

import SwiftUI

/// Two arrangements over one tile vocabulary, knowing nothing about the host: a step arm hands
/// it a window band, a content block a column. `BentoBandFloor` supplies a height when a
/// scrolling host proposes none. Generic over `Context` because the expanded detail hosts
/// `GuidanceContentView`.
struct BentoModule<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    @Environment(\.palette) private var palette
    @Environment(\.inspectLocalization) private var l10n
    let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    var kind: BentoArrangementKind = .heroRow
    let accent: Color
    let iconBasePath: String?
    @ObservedObject var inspectState: Context
    var onAction: (InspectConfig.GuidanceContent.BentoCellConfig) -> Void = { _ in }

    /// The cell currently expanded in place, if any.
    @State private var expandedCellID: String?

    var body: some View {
        BentoBandFloor(
            minimum: BentoHeroArrangement.minimumBandHeight(for: cells, kind: kind)
        ) {
            ExpandableTileLayer(expandedId: $expandedCellID) { isHidden in
                let placements = BentoHeroArrangement.placements(for: cells, kind: kind)
                switch kind {
                case .heroRow:    heroRowBody(placements, isHidden: isHidden)
                case .heroColumn: heroColumnBody(placements, isHidden: isHidden)
                }
            } detail: { id in
                if let cell = cells.first(where: { $0.id == id }),
                   let overlay = cell.detailOverlay {
                    BentoExpandedCell(
                        cell: cell,
                        overlay: overlay,
                        accent: accent,
                        iconBasePath: iconBasePath,
                        inspectState: inspectState,
                        onClose: {
                            withAnimation(ExpandInPlaceMotion.spring) {
                                expandedCellID = nil
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            BentoHeroArrangement.logDetailPresentationAdvisoryOnce(cells: cells)
            BentoHeroArrangement.logDroppedFieldAdvisoryOnce(cells: cells, kind: kind)
        }
    }

    /// Same spring `ExpandableTileLayer` uses to collapse, so open and close read as one motion.
    private func expand(_ id: String) {
        withAnimation(ExpandInPlaceMotion.spring) {
            expandedCellID = id
        }
    }

    // MARK: - Hero row over supporting row
    //
    // The split is computed from the weight constants; `layoutPriority` is an ordering, not a ratio.

    @ViewBuilder
    private func heroRowBody(_ placements: [BentoHeroPlacement],
                             isHidden: @escaping (String) -> Bool) -> some View {
        let heroRow = placements.filter { $0.row == 0 }
        let supportingRow = placements.filter { $0.row != 0 }
        let heroPresent = !heroRow.isEmpty
        let supportingPresent = !supportingRow.isEmpty
        let weightSum = (heroPresent ? BentoHeroArrangement.heroRowWeight : 0)
            + (supportingPresent ? BentoHeroArrangement.supportingRowWeight : 0)

        GeometryReader { geo in
            let gap: CGFloat = (heroPresent && supportingPresent) ? 12 : 0
            let available = max(0, geo.size.height - gap)
            let heroHeight = (heroPresent && weightSum > 0)
                ? available * (BentoHeroArrangement.heroRowWeight / weightSum) : 0
            let supportingHeight = (supportingPresent && weightSum > 0)
                ? available * (BentoHeroArrangement.supportingRowWeight / weightSum) : 0

            VStack(spacing: 12) {
                if heroPresent {
                    HStack(spacing: 12) {
                        ForEach(heroRow, id: \.cellIndex) { placement in
                            let cell = cells[placement.cellIndex]
                            heroCell(cell)
                                .opacity(isHidden(cell.id) ? 0 : 1)
                                .tileTap(enabled: BentoHeroArrangement.isExpandable(cell)) {
                                    expand(cell.id)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: heroHeight)
                }
                if supportingPresent {
                    HStack(spacing: 12) {
                        ForEach(supportingRow, id: \.cellIndex) { placement in
                            let cell = cells[placement.cellIndex]
                            supportingCell(cell)
                                .opacity(isHidden(cell.id) ? 0 : 1)
                                .tileTap(enabled: BentoHeroArrangement.isExpandable(cell)) {
                                    expand(cell.id)
                                }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: supportingHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Hero on the left, the rest stacked on the right, split by the column weights. The hero is
    /// selected by `row == 0`, not array order.
    @ViewBuilder
    private func heroColumnBody(_ placements: [BentoHeroPlacement],
                                isHidden: @escaping (String) -> Bool) -> some View {
        let hero = BentoHeroArrangement.heroPlacement(in: placements)
        let stacked = BentoHeroArrangement.stackedPlacements(in: placements)
        let heroPresent = hero != nil
        let stackedPresent = !stacked.isEmpty
        let weightSum = (heroPresent ? BentoHeroArrangement.heroColumnWeight : 0)
            + (stackedPresent ? BentoHeroArrangement.supportingColumnWeight : 0)

        GeometryReader { geo in
            let gap: CGFloat = (heroPresent && stackedPresent) ? 12 : 0
            let available = max(0, geo.size.width - gap)
            let heroWidth = (heroPresent && weightSum > 0)
                ? available * (BentoHeroArrangement.heroColumnWeight / weightSum) : 0
            let stackedWidth = (stackedPresent && weightSum > 0)
                ? available * (BentoHeroArrangement.supportingColumnWeight / weightSum) : 0

            HStack(spacing: 12) {
                if let hero {
                    let heroCellConfig = cells[hero.cellIndex]
                    statTile(heroCellConfig, prominent: true)
                        .opacity(isHidden(heroCellConfig.id) ? 0 : 1)
                        .tileTap(enabled: BentoHeroArrangement.isExpandable(heroCellConfig)) {
                            expand(heroCellConfig.id)
                        }
                        .frame(width: heroWidth, height: geo.size.height)
                }
                if stackedPresent {
                    VStack(spacing: 12) {
                        ForEach(stacked, id: \.cellIndex) { placement in
                            let cell = cells[placement.cellIndex]
                            statTile(cell, prominent: false)
                                .opacity(isHidden(cell.id) ? 0 : 1)
                                .tileTap(enabled: BentoHeroArrangement.isExpandable(cell)) {
                                    expand(cell.id)
                                }
                        }
                    }
                    .frame(width: stackedWidth, height: geo.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Hero cell

    @ViewBuilder
    private func heroCell(_ cell: InspectConfig.GuidanceContent.BentoCellConfig) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    if let title = cell.title {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(palette.text)
                    }
                    if let subtitle = cell.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if let rows = cell.rows, !rows.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            BentoHeroAppRow(row: row, accent: accent,
                                            iconBasePath: iconBasePath)
                        }
                    }
                }
            }
            .padding(.init(top: 18, leading: 20, bottom: 18, trailing: 20))
            .frame(maxWidth: .infinity, alignment: .leading)

            if let path = cell.imagePath {
                // Image column: 40% of the width, bottom-aligned, never taller than wide so a
                // narrow host does not propose a portrait slot that crops a landscape picture.
                GeometryReader { geo in
                    let slotWidth = geo.size.width * 0.40
                    let slotHeight = min(max(0, geo.size.height - 16), slotWidth)
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        AsyncBentoImageView(imagePath: path,
                                            basePath: iconBasePath,
                                            width: slotWidth,
                                            height: slotHeight,
                                            imageFit: cell.imageFit ?? "fill")
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                }
                .frame(maxWidth: .infinity)
                .padding(.init(top: 16, leading: 0, bottom: 0, trailing: 16))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.09))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(accent.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: Supporting cell

    @ViewBuilder
    private func supportingCell(_ cell: InspectConfig.GuidanceContent.BentoCellConfig) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                if let title = cell.title {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(palette.text)
                }
                if let badge = cell.badge {
                    Text(badge.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .kerning(0.6)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(accent.opacity(0.18)))
                }
                // With both a button and a detail, the chevron marks the detail affordance. A
                // plain glyph, not a Button, so the tile's own tap still expands.
                if cell.detailOverlay != nil && cell.actionLabel != nil {
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textMuted)
                        .accessibilityLabel(l10n("ui.bentoExpandDetail", "Show detail"))
                }
            }
            if let subtitle = cell.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            HStack(spacing: 10) {
                if let label = cell.actionLabel {
                    Button { onAction(cell) } label: {
                        Text(label)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(palette.text)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(palette.text.opacity(0.09)))
                    }
                    .buttonStyle(.plain)
                }
                if let meta = cell.meta {
                    Text(meta)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(palette.textMuted.opacity(0.75))
                }
            }
        }
        .padding(.init(top: 16, leading: 18, bottom: 16, trailing: 18))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.text.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: Stat tile

    @ViewBuilder
    private func statTile(_ cell: InspectConfig.GuidanceContent.BentoCellConfig,
                          prominent: Bool) -> some View {
        let surface = BentoSurface(configValue: cell.surface, fallback: .accent)
        let tint = surface.tint(accent: accent, palette: palette)
        VStack(alignment: .leading, spacing: prominent ? 12 : 8) {
            BentoTileIdentity.iconChip(symbol: cell.sfSymbol, tint: tint, prominent: prominent)
            Spacer(minLength: 0)
            BentoTileIdentity.textBlock(.init(label: cell.label, title: cell.title, subtitle: cell.subtitle),
                                        tint: tint, palette: palette,
                                        prominent: prominent, showsSubtitle: prominent)
        }
        .padding(prominent ? 22 : 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(tint.opacity(0.24), lineWidth: 1))
    }
}

// MARK: - The band floor

/// Passes the host's height proposal through, substituting `minimum` only when the proposal is
/// nil. A `Layout` rather than `.frame(minHeight:)` because only a layout can change the
/// proposal its subview's `GeometryReader` reads.
private struct BentoBandFloor<Content: View>: View {
    let minimum: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        BandFloorLayout(minimum: minimum) { content() }
    }
}

private struct BandFloorLayout: Layout {
    let minimum: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = resolved(proposal.height)
        let inner = ProposedViewSize(width: proposal.width, height: height)
        let subviewSize = subviews.first?.sizeThatFits(inner) ?? .zero
        return CGSize(width: proposal.width ?? subviewSize.width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        // `bounds` carries the resolved height, so the subview gets the band it was measured at.
        for subview in subviews {
            subview.place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
            )
        }
    }

    /// `nil` → `minimum`; every finite or infinite proposal passes through unchanged. Clamping a
    /// short finite proposal would move the step hosts' layouts, and answering `inf` with
    /// `minimum` would make a `VStack` treat the module as fixed-height.
    private func resolved(_ proposed: CGFloat?) -> CGFloat {
        proposed ?? minimum
    }
}


// MARK: - Shared tile identity

/// The icon chip and label/title/subtitle block a tile's identity is built from, shared by the
/// collapsed `statTile` and the expanded `BentoExpandedCell` so a tile looks like itself as it
/// grows. Takes plain values; the caller decides which source each field comes from.
enum BentoTileIdentity {
    @ViewBuilder
    static func iconChip(symbol: String?, tint: Color, prominent: Bool) -> some View {
        if let symbol {
            ZStack {
                RoundedRectangle(cornerRadius: prominent ? 11 : 10, style: .continuous)
                    .fill(tint.opacity(0.18))
                Image(systemName: symbol)
                    .font(.system(size: prominent ? 22 : 18, weight: .medium))
                    .foregroundStyle(tint)
            }
            .frame(width: prominent ? 42 : 36, height: prominent ? 42 : 36)
        }
    }

    /// The three lines of a tile: eyebrow (`label`), value (`title`) and subhead (`subtitle`).
    struct Copy {
        var label: String?
        var title: String?
        var subtitle: String?
    }

    /// Eyebrow `label` (tinted), `title`, and `subtitle` when `showsSubtitle`.
    @ViewBuilder
    static func textBlock(_ copy: Copy, tint: Color, palette: ResolvedPalette,
                          prominent: Bool, showsSubtitle: Bool) -> some View {
        let label = copy.label, title = copy.title, subtitle = copy.subtitle
        VStack(alignment: .leading, spacing: prominent ? 5 : 3) {
            if let label {
                Text(label.uppercased())
                    .font(.system(size: prominent ? 11 : 10.5, weight: .semibold))
                    .kerning(0.66)
                    .foregroundStyle(tint)
            }
            if let title {
                Text(title)
                    .font(.system(size: prominent ? 19 : 16, weight: .bold))
                    .foregroundStyle(palette.text)
            }
            if showsSubtitle, let subtitle {
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(palette.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Expanded-card header resolver

/// The expanded card's header fields: `detailOverlay`'s title/subtitle/icon when non-empty, else
/// the cell's. The eyebrow `label` has no overlay equivalent and is always the cell's.
enum BentoExpandedCellHeader {
    static func title(cell: InspectConfig.GuidanceContent.BentoCellConfig,
                      overlay: InspectConfig.DetailOverlayConfig) -> String? {
        nonEmpty(overlay.title) ?? cell.title
    }

    static func subtitle(cell: InspectConfig.GuidanceContent.BentoCellConfig,
                         overlay: InspectConfig.DetailOverlayConfig) -> String? {
        nonEmpty(overlay.subtitle) ?? cell.subtitle
    }

    static func sfSymbol(cell: InspectConfig.GuidanceContent.BentoCellConfig,
                         overlay: InspectConfig.DetailOverlayConfig) -> String? {
        nonEmpty(overlay.icon) ?? cell.sfSymbol
    }

    /// An authored-but-empty string counts as unauthored.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}

// MARK: - Expanded cell

/// The tapped tile grown to fill the band, keeping its own identity as the header and
/// `detailOverlay.content` below. No sheet chrome: the corner `xmark` is the stated dismissal;
/// Esc also collapses via `ExpandableTileLayer`.
private struct BentoExpandedCell<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    @Environment(\.palette) private var palette
    @Environment(\.inspectLocalization) private var l10n
    let cell: InspectConfig.GuidanceContent.BentoCellConfig
    let overlay: InspectConfig.DetailOverlayConfig
    let accent: Color
    let iconBasePath: String?
    @ObservedObject var inspectState: Context
    let onClose: () -> Void

    var body: some View {
        let surface = BentoSurface(configValue: cell.surface, fallback: .accent)
        let tint = surface.tint(accent: accent, palette: palette)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                BentoTileIdentity.iconChip(
                    symbol: BentoExpandedCellHeader.sfSymbol(cell: cell, overlay: overlay),
                    tint: tint, prominent: true)
                Spacer(minLength: 8)
                closeButton(tint: tint)
            }
            BentoTileIdentity.textBlock(
                .init(label: cell.label,
                      title: BentoExpandedCellHeader.title(cell: cell, overlay: overlay),
                      subtitle: BentoExpandedCellHeader.subtitle(cell: cell, overlay: overlay)),
                tint: tint, palette: palette, prominent: true, showsSubtitle: true)

            // Only the content scrolls; the card keeps the band's fixed frame.
            if let content = overlay.content, !content.isEmpty {
                ScrollView {
                    GuidanceContentView(
                        contentBlocks: content,
                        scaleFactor: 1.0,
                        iconBasePath: iconBasePath,
                        inspectState: inspectState,
                        itemId: "bento-expanded-\(cell.id)",
                        onOverlayTap: nil,
                        accentColor: tint
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Opaque ground: the card covers tiles, which must not read through.
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.10)))
        )
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(tint.opacity(0.24), lineWidth: 1))
    }

    private func closeButton(tint: Color) -> some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.14)))
        }
        .buttonStyle(.plain)
        // Same localization key as the plist detail sheet's Close button.
        .help(l10n("ui.bentoPlistClose", "Close"))
    }
}

/// One app row inside the hero cell: icon, name, and `stateLabel` or a `progress` percentage.
private struct BentoHeroAppRow: View {
    @Environment(\.palette) private var palette
    let row: InspectConfig.GuidanceContent.InstallItem
    let accent: Color
    let iconBasePath: String?

    var body: some View {
        HStack(spacing: 10) {
            if row.icon != nil {
                // `status: nil`: the state is the trailing word, not a badge on the icon.
                AppIconView(iconPath: row.icon, bundleId: nil, paths: [],
                            size: 20, status: nil, accent: accent, basePath: iconBasePath)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            Text(row.title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(isPending ? palette.textMuted : palette.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(stateText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(stateColor)
        }
    }

    private var isPending: Bool {
        row.stateLabel == nil && row.progress == nil
    }

    private var stateText: String {
        if let label = row.stateLabel { return label }
        if let progress = row.progress { return "\(Int(progress))%" }
        return ""
    }

    private var stateColor: Color {
        if row.progress != nil && row.stateLabel == nil { return accent }
        if row.stateLabel != nil { return palette.success }
        return palette.textMuted
    }
}
