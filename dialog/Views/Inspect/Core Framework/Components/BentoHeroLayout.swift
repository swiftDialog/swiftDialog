//
//  BentoHeroLayout.swift
//  dialog
//
//  Geometry and advisories for the `hero` and `summary` bento arrangements: where each cell
//  lands, the band height the module needs, and the keys a tile will not draw. Pure functions;
//  `BentoModule` renders the result.
//

import SwiftUI

/// Where one cell sits. The meaning of `row` depends on the arrangement kind.
struct BentoHeroPlacement: Equatable {
    let cellIndex: Int
    /// Under `.heroRow` a grid row (0 hero, 1 supporting); under `.heroColumn` a stack position
    /// (0 hero column, 1..n tiles beside it top to bottom). Authored `row` values pass through.
    let row: Int
    let columnSpan: Int
}

/// Which axis the hero cell owns.
enum BentoArrangementKind {
    /// Hero spans the top row, supporting cells divide the row below (`bentoLayout "hero"`).
    case heroRow
    /// Hero owns the left column, supporting cells stack beside it (`bentoLayout "summary"`).
    case heroColumn
}

enum BentoHeroArrangement {
    static let heroRowWeight: CGFloat = 1.35
    static let supportingRowWeight: CGFloat = 1
    static let heroColumnWeight: CGFloat = 1.2
    static let supportingColumnWeight: CGFloat = 1
    /// Past this many supporting cells an advisory names the grid layout; nothing is refused.
    static let supportingSoftMax = 4

    // MARK: - Band insets

    /// Gap between the header's subtitle and the top of the payload.
    static let bandTop: CGFloat = 22
    /// Clearance between the bottom of the payload and the action bar.
    static let bandBottom: CGFloat = 32

    /// What the host adds to the card shell's own inset to land on `bandTop`; negative when the
    /// shell's inset is larger.
    static func bandTopAdjustment(shellInset: CGFloat) -> CGFloat { bandTop - shellInset }

    // MARK: - The band the module needs

    // Floors apply only when a host proposes no height (scrolling hosts); an unconstrained
    // `GeometryReader` would otherwise size rows from a 10pt placeholder.

    /// `heroCell` / `supportingCell` under `.heroRow`; the schema's `bentoRowHeight` default.
    static let rowTileFloor: CGFloat = 140
    /// `statTile(prominent: false)`.
    static let statTileFloor: CGFloat = 123
    /// `statTile(prominent: true)`; binds only when a summary authors no stack.
    static let statHeroTileFloor: CGFloat = 156
    /// The gap `BentoModule` puts between rows and between stacked tiles.
    static let bandGap: CGFloat = 12

    /// The height this module claims when its host proposes none. `.heroRow` divides the band by
    /// weight, so the row that runs out of floor first sets it; `.heroColumn` takes the taller of
    /// the hero and the stack.
    static func minimumBandHeight(
        for cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        kind: BentoArrangementKind
    ) -> CGFloat {
        let placements = placements(for: cells, kind: kind)
        guard !placements.isEmpty else { return 0 }

        switch kind {
        case .heroRow:
            let heroPresent = placements.contains { $0.row == 0 }
            let supportingPresent = placements.contains { $0.row != 0 }
            let weightSum = (heroPresent ? heroRowWeight : 0)
                + (supportingPresent ? supportingRowWeight : 0)
            guard weightSum > 0 else { return 0 }
            var band: CGFloat = 0
            if heroPresent { band = max(band, rowTileFloor * weightSum / heroRowWeight) }
            if supportingPresent { band = max(band, rowTileFloor * weightSum / supportingRowWeight) }
            return band + ((heroPresent && supportingPresent) ? bandGap : 0)

        case .heroColumn:
            let stacked = stackedPlacements(in: placements)
            var band: CGFloat = heroPlacement(in: placements) != nil ? statHeroTileFloor : 0
            if !stacked.isEmpty {
                band = max(band, CGFloat(stacked.count) * statTileFloor
                    + CGFloat(stacked.count - 1) * bandGap)
            }
            return band
        }
    }

    /// `.heroRow` placements. A config that states spans is obeyed verbatim; only when nothing
    /// is stated does the arrangement impose itself.
    static func placements(
        for cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    ) -> [BentoHeroPlacement] {
        placements(for: cells, kind: .heroRow)
    }

    static func placements(
        for cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        kind: BentoArrangementKind
    ) -> [BentoHeroPlacement] {
        guard !cells.isEmpty else { return [] }

        let authored = cells.contains { $0.columnSpan != nil || $0.rowSpan != nil }
        if authored {
            return cells.enumerated().map { index, cell in
                BentoHeroPlacement(cellIndex: index, row: cell.row,
                                   columnSpan: max(1, cell.columnSpan ?? 1))
            }
        }

        switch kind {
        case .heroRow:
            let supporting = max(0, cells.count - 1)
            return cells.indices.map { index in
                index == 0
                    ? BentoHeroPlacement(cellIndex: 0, row: 0, columnSpan: max(1, supporting))
                    : BentoHeroPlacement(cellIndex: index, row: 1, columnSpan: 1)
            }
        case .heroColumn:
            // `row` is the stack position: 0 the hero, 1..n the tiles beside it.
            return cells.indices.map { index in
                BentoHeroPlacement(cellIndex: index, row: index, columnSpan: 1)
            }
        }
    }

    /// One advisory when unauthored spans leave more supporting cells than `supportingSoftMax`.
    static func advisories(
        for cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    ) -> [String] {
        guard !cells.isEmpty else { return [] }

        let authored = cells.contains { $0.columnSpan != nil || $0.rowSpan != nil }
        guard !authored else { return [] }

        let supporting = max(0, cells.count - 1)
        guard supporting > supportingSoftMax else { return [] }

        return ["bento hero: \(supporting) supporting cells is past this layout's design "
                + "(soft max \(supportingSoftMax)) — consider bentoLayout \"grid\""]
    }

    /// `bentoColumns` is read by the grid layout only; names the ignored key on `hero`/`summary`.
    static func bentoColumnsAdvisory(layout: String, bentoColumns: Int?) -> String? {
        guard bentoColumns != nil else { return nil }
        guard layout == "hero" || layout == "summary" else { return nil }
        return "bento \(layout): bentoColumns is read by the grid layout only — the \(layout) "
            + "arrangement derives its columns from the cells; key ignored"
    }

    // MARK: - Expand-in-place detail

    /// A `detailOverlay` is the only thing that makes a tile tappable in this module.
    static func isExpandable(_ cell: InspectConfig.GuidanceContent.BentoCellConfig) -> Bool {
        cell.detailOverlay != nil
    }

    /// `detailPresentation` belongs to the grid layout; this module always expands in place, so
    /// an authored value decodes but is ignored.
    static func detailPresentationAdvisory(
        for cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    ) -> String? {
        guard cells.contains(where: { $0.detailPresentation != nil }) else { return nil }
        return "bento (hero/summary): detailPresentation is read by the legacy grid only — this "
            + "bento has a single presentation (expand in place); key ignored"
    }

    /// Process-lifetime latch. Lives on this non-generic enum because a static on
    /// `BentoModule<Context>` would be per-specialization.
    private static let _detailPresentationAdvisoryLogged = LockedValue(false)
    static var detailPresentationAdvisoryLogged: Bool {
        get { _detailPresentationAdvisoryLogged.value }
        set { _detailPresentationAdvisoryLogged.value = newValue }
    }

    /// Logs the advisory at most once per process.
    static func logDetailPresentationAdvisoryOnce(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    ) {
        guard !detailPresentationAdvisoryLogged,
              let advisory = detailPresentationAdvisory(for: cells) else { return }
        detailPresentationAdvisoryLogged = true
        writeLog(advisory, logLevel: .info)
    }

    // MARK: - Splitting a heroColumn into its hero and its stack

    /// The hero of a `.heroColumn` arrangement: the first placement at row 0.
    static func heroPlacement(in placements: [BentoHeroPlacement]) -> BentoHeroPlacement? {
        placements.first { $0.row == 0 }
    }

    /// Everything that is not the hero, top to bottom. Excludes by cell index rather than
    /// `row != 0` so a second authored `row: 0` cell still renders; hero plus stack must
    /// contain every placement exactly once.
    static func stackedPlacements(in placements: [BentoHeroPlacement]) -> [BentoHeroPlacement] {
        let hero = heroPlacement(in: placements)
        return placements
            .filter { $0.cellIndex != hero?.cellIndex }
            .sorted { $0.row < $1.row }
    }

    // MARK: - Keys the tile a cell lands on never draws

    /// Which of `BentoModule`'s tile renderers a placement gets; must match the module's layout
    /// bodies.
    enum TileRenderer: Equatable {
        case hero
        case supporting
        case statProminent
        case statStacked
    }

    static func renderer(row: Int, kind: BentoArrangementKind) -> TileRenderer {
        switch kind {
        case .heroRow:    return row == 0 ? .hero : .supporting
        case .heroColumn: return row == 0 ? .statProminent : .statStacked
        }
    }

    /// The authored keys `renderer` will not draw for this cell. Names them; changes nothing.
    static func ignoredFields(
        _ cell: InspectConfig.GuidanceContent.BentoCellConfig,
        renderer: TileRenderer
    ) -> [String] {
        var ignored: [String] = []
        func note(_ name: String, _ authored: Bool) { if authored { ignored.append(name) } }

        switch renderer {
        case .hero:
            // heroCell draws title, subtitle, rows, imagePath.
            note("label", cell.label != nil)
            note("sfSymbol", cell.sfSymbol != nil)
            note("badge", cell.badge != nil)
            note("meta", cell.meta != nil)
            note("actionLabel", cell.actionLabel != nil)
        case .supporting:
            // supportingCell draws title, badge, subtitle, actionLabel, meta.
            note("label", cell.label != nil)
            note("sfSymbol", cell.sfSymbol != nil)
            note("rows", !(cell.rows ?? []).isEmpty)
            note("imagePath", cell.imagePath != nil)
        case .statProminent, .statStacked:
            // statTile draws the icon chip plus label/title, and subtitle only when prominent.
            note("badge", cell.badge != nil)
            note("meta", cell.meta != nil)
            note("actionLabel", cell.actionLabel != nil)
            note("rows", !(cell.rows ?? []).isEmpty)
            note("imagePath", cell.imagePath != nil)
            note("subtitle", renderer == .statStacked && cell.subtitle != nil)
        }
        return ignored
    }

    /// One line naming every cell that authored a key its tile will not draw.
    static func droppedFieldAdvisory(
        for cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        kind: BentoArrangementKind
    ) -> String? {
        let parts: [String] = placements(for: cells, kind: kind).compactMap { placement in
            guard cells.indices.contains(placement.cellIndex) else { return nil }
            let cell = cells[placement.cellIndex]
            let ignored = ignoredFields(cell, renderer: renderer(row: placement.row, kind: kind))
            guard !ignored.isEmpty else { return nil }
            return "\(cell.id): \(ignored.joined(separator: ", "))"
        }
        guard !parts.isEmpty else { return nil }

        let layout = (kind == .heroRow) ? "hero" : "summary"
        return "bento \(layout): authored keys the tile each cell lands on does not draw — "
            + parts.joined(separator: "; ")
    }

    /// Process-lifetime latch, as `detailPresentationAdvisoryLogged`.
    private static let _droppedFieldAdvisoryLogged = LockedValue(false)
    static var droppedFieldAdvisoryLogged: Bool {
        get { _droppedFieldAdvisoryLogged.value }
        set { _droppedFieldAdvisoryLogged.value = newValue }
    }

    static func logDroppedFieldAdvisoryOnce(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        kind: BentoArrangementKind
    ) {
        guard !droppedFieldAdvisoryLogged,
              let advisory = droppedFieldAdvisory(for: cells, kind: kind) else { return }
        droppedFieldAdvisoryLogged = true
        writeLog(advisory, logLevel: .info)
    }
}
