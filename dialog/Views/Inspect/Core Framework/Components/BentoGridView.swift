//
//  BentoGridView.swift
//  dialog
//
//  Bento grid for the card presets: grid-like layouts with variable cell spans, and the detail
//  routes (popover, inline sheet, sheet) a tapped cell opens.
//

import SwiftUI

// MARK: - Bento Layout Engine

/// Absolute placer for bento cells; it does not reflow, so overlaps and off-grid cells are logged.
struct BentoLayoutEngine {
    /// Placement for a single cell.
    struct CellPlacement: Identifiable {
        let id: String
        let cellId: String
        let row: Int
        let column: Int
        let columnSpan: Int
        let rowSpan: Int
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    /// Placements for all cells. `rowHeight` is the floor every row starts at; a row holding a
    /// tile with rows grows to fit them.
    static func calculate(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        columns: Int,
        cellWidth: CGFloat,
        rowHeight: CGFloat,
        gap: CGFloat
    ) -> [CellPlacement] {
        return calculate(
            cells: cells,
            columns: columns,
            cellWidth: cellWidth,
            rowHeights: intrinsicRowHeights(cells: cells, authored: rowHeight, gap: gap),
            gap: gap
        )
    }

    /// Rows past the end of the array reuse the last height rather than trapping.
    private static func height(ofRow row: Int, in rowHeights: [CGFloat]) -> CGFloat {
        guard let last = rowHeights.last else { return 0 }
        return row < rowHeights.count ? rowHeights[row] : last
    }

    /// Places cells on a grid whose rows may each have their own height. Uniform heights reduce
    /// to the single-`rowHeight` arithmetic.
    static func calculate(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        columns: Int,
        cellWidth: CGFloat,
        rowHeights: [CGFloat],
        gap: CGFloat
    ) -> [CellPlacement] {
        var placements: [CellPlacement] = []

        for cell in cells {
            let colSpan = min(cell.columnSpan ?? 1, columns - cell.column)
            let rowSpan = cell.rowSpan ?? 1

            // `y` is a prefix sum of the actual row heights above, not a multiple of one height.
            let x = CGFloat(cell.column) * (cellWidth + gap)
            let y = (0 ..< cell.row).reduce(CGFloat(0)) { $0 + Self.height(ofRow: $1, in: rowHeights) }
                + CGFloat(cell.row) * gap

            // Spanning cells absorb the gaps between the spanned columns and rows.
            let width = CGFloat(colSpan) * cellWidth + CGFloat(colSpan - 1) * gap
            let height = (cell.row ..< (cell.row + rowSpan))
                .reduce(CGFloat(0)) { $0 + Self.height(ofRow: $1, in: rowHeights) }
                + CGFloat(rowSpan - 1) * gap

            let placement = CellPlacement(
                id: cell.id,
                cellId: cell.id,
                row: cell.row,
                column: cell.column,
                columnSpan: colSpan,
                rowSpan: rowSpan,
                x: x,
                y: y,
                width: width,
                height: height
            )

            placements.append(placement)
        }

        for cell in offGridCells(cells: cells, columns: columns) {
            writeLog("BentoGrid: \(cell)", logLevel: .error)
        }
        for conflict in slotConflicts(placements) {
            writeLog("BentoGrid: \(conflict)", logLevel: .error)
        }
        for warning in slotMapWarnings(placements) {
            writeLog("BentoGrid: \(warning)", logLevel: .info)
        }
        for warning in rowFitWarnings(cells: cells, rowHeights: rowHeights, gap: gap) {
            writeLog("BentoGrid: \(warning)", logLevel: .error)
        }
        return placements
    }

    /// The slot-map budget (three rows, at most three span shapes), as warnings: a layout past it
    /// still renders. A fourth row scrolls off a 600pt window and nothing else says so.
    static func slotMapWarnings(_ placements: [CellPlacement]) -> [String] {
        var warnings: [String] = []
        let rows = placements.map { $0.row + $0.rowSpan }.max() ?? 0
        if rows > 3 {
            warnings.append("slot map uses \(rows) rows — a fourth row scrolls off 600pt, so it is present but unseen")
        }
        let shapes = Set(placements.map { "\($0.columnSpan)x\($0.rowSpan)" })
        if shapes.count > 3 {
            warnings.append("slot map uses \(shapes.count) span shapes (\(shapes.sorted().joined(separator: ", "))) — the design budgets three")
        }
        return warnings
    }

    /// One line per cell that starts outside the grid's columns: the span clamp leaves it in the
    /// tree with no area, so it draws nothing silently.
    static func offGridCells(cells: [InspectConfig.GuidanceContent.BentoCellConfig],
                             columns: Int) -> [String] {
        cells.compactMap { cell in
            guard cell.column < 0 || cell.column >= columns else { return nil }
            return "cell '\(cell.id)' starts at column \(cell.column) of a \(columns)-column grid "
                + "and draws nothing — author `columns: \(max(cell.column + (cell.columnSpan ?? 1), 1))` "
                + "or move the cell"
        }
    }

    /// One description per slot claimed by two cells; overlapping cells paint over each other
    /// and look fine in a screenshot.
    static func slotConflicts(_ placements: [CellPlacement]) -> [String] {
        var owner: [String: String] = [:]     // "row,col" -> cell id
        var conflicts: [String] = []
        for p in placements {
            for r in p.row ..< (p.row + p.rowSpan) {
                for c in p.column ..< (p.column + p.columnSpan) {
                    let slot = "\(r),\(c)"
                    if let first = owner[slot] {
                        conflicts.append("slot r\(r) c\(c) claimed by both '\(first)' and '\(p.cellId)' — one is painting over the other")
                    } else {
                        owner[slot] = p.cellId
                    }
                }
            }
        }
        return conflicts
    }

    /// A grid row is as tall as the tallest tile in it; the authored height is a floor, never a
    /// ceiling. Row-spanning tiles are left out (no single right split); `rowFitWarnings` still
    /// reports one that cannot fit its rows.
    static func intrinsicRowHeights(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        authored: CGFloat,
        gap: CGFloat
    ) -> [CGFloat] {
        let rowCount = max(1, cells.map { $0.row + ($0.rowSpan ?? 1) }.max() ?? 1)
        var heights = Array(repeating: authored, count: rowCount)
        for cell in cells {
            let count = (cell.rows ?? []).count
            guard count > 0, (cell.rowSpan ?? 1) == 1, cell.row < heights.count else { continue }
            let needed = BentoRowM.headingAllowance + BentoRowM.rowsZoneHeight(count: count)
            heights[cell.row] = max(heights[cell.row], needed)
        }
        return heights
    }

    /// Any tile whose rows alone cannot fit the height it was given; a short tile clips its last
    /// row rather than reflowing. Allows nothing for the heading, so it fires only when certain.
    static func rowFitWarnings(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        rowHeights: [CGFloat],
        gap: CGFloat
    ) -> [String] {
        var warnings: [String] = []
        for cell in cells {
            let count = (cell.rows ?? []).count
            guard count > 0 else { continue }
            let rowSpan = cell.rowSpan ?? 1
            let available = (cell.row ..< (cell.row + rowSpan))
                .reduce(CGFloat(0)) { $0 + height(ofRow: $1, in: rowHeights) }
                + CGFloat(rowSpan - 1) * gap
            let needed = BentoRowM.rowsZoneHeight(count: count)
            if needed > available {
                warnings.append(
                    "cell '\(cell.id)' has \(count) rows needing \(Int(needed))pt before its heading, "
                    + "but its tile is \(Int(available))pt — the last row is clipped, not reflowed"
                )
            }
        }
        return warnings
    }

    /// Total grid height, from the same `intrinsicRowHeights` the placements use so the container
    /// can never be shorter than its tiles.
    static func calculateGridHeight(cells: [InspectConfig.GuidanceContent.BentoCellConfig], rowHeight: CGFloat, gap: CGFloat) -> CGFloat {
        guard !cells.isEmpty else { return 0 }
        let heights = intrinsicRowHeights(cells: cells, authored: rowHeight, gap: gap)
        return heights.reduce(0, +) + CGFloat(heights.count - 1) * gap
    }
}


// MARK: - Bento Grid View

/// Where a tapped cell's detail opens. The cell's `detailPresentation` decides first, then the
/// grid's `inlineExpansion`, else the sheet. A cell without an overlay always opens the sheet.
enum BentoDetailRoute: Equatable {
    case popover, inline, sheet

    static func resolve(presentation: String?, gridInline: Bool, hasOverlay: Bool) -> BentoDetailRoute {
        guard hasOverlay else { return .sheet }
        switch presentation?.lowercased() {
        case "popover": return .popover
        case "inline":  return .inline
        case "sheet":   return .sheet
        default:        return gridInline ? .inline : .sheet
        }
    }
}

/// The bento grid container; sizes cells from its own geometry.
struct BentoGridView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    let columns: Int
    let rowHeight: CGFloat
    let gap: CGFloat
    let scaleFactor: CGFloat
    let accentColor: Color
    let iconBasePath: String?
    let tintColor: Color?
    let inlineExpansion: Bool
    /// Opt-in layout debugging: prints each cell's slot and measured width on the cell.
    var showSlots: Bool = false
    let containerHeight: CGFloat?
    @ObservedObject var inspectState: Context

    @State private var selectedCell: InspectConfig.GuidanceContent.BentoCellConfig?
    @State private var showDetail: Bool = false
    @State private var expandedCellId: String?
    @State private var visibleCells: Set<String> = []
    @State private var sheetContext: BentoSheetContext?
    /// Separate from the sheet state because a popover anchors to its cell.
    @State private var popoverCellId: String?
    /// The room the inline detail sheet may occupy, measured from the grid's own geometry once it
    /// appears; the initial value stands only until then.
    @State private var detailBudget = CGSize(width: 720, height: 540)

    @Environment(\.complianceAggregator) private var complianceAggregator

    /// Seconds between each cell appearing.
    private let staggerDelay: Double = 0.12

    /// The live compliance item bound to a cell: a cell auto-binds when its `id` matches a plist
    /// key in the injected aggregator.
    private func boundItem(for cell: InspectConfig.GuidanceContent.BentoCellConfig) -> PlistAggregator.ComplianceItem? {
        guard let aggregator = complianceAggregator else { return nil }
        return aggregator.allItems.first(where: { $0.id == cell.id })
    }

    init(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        columns: Int,
        rowHeight: CGFloat,
        gap: CGFloat,
        scaleFactor: CGFloat,
        accentColor: Color,
        iconBasePath: String?,
        tintColor: Color?,
        inspectState: Context,
        inlineExpansion: Bool = false,
        showSlots: Bool = false,
        containerHeight: CGFloat? = nil
    ) {
        self.cells = cells
        self.columns = columns
        self.rowHeight = rowHeight
        self.gap = gap
        self.scaleFactor = scaleFactor
        self.accentColor = accentColor
        self.iconBasePath = iconBasePath
        self.tintColor = tintColor
        self.inlineExpansion = inlineExpansion
        self.showSlots = showSlots
        self.containerHeight = containerHeight
        self._inspectState = ObservedObject(wrappedValue: inspectState)
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let cellWidth = (availableWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let placements = BentoLayoutEngine.calculate(
                cells: cells,
                columns: columns,
                cellWidth: cellWidth,
                rowHeight: rowHeight * scaleFactor,
                gap: gap * scaleFactor
            )
            let gridHeight = BentoLayoutEngine.calculateGridHeight(
                cells: cells,
                rowHeight: rowHeight * scaleFactor,
                gap: gap * scaleFactor
            )
            ZStack(alignment: .topLeading) {
                ForEach(Array(placements.enumerated()), id: \.element.id) { index, placement in
                    if let cellConfig = cells.first(where: { $0.id == placement.cellId }) {
                        let isVisible = visibleCells.contains(cellConfig.id)
                        let isExpanded = expandedCellId == cellConfig.id
                        let isDimmed = expandedCellId != nil && !isExpanded

                        BentoCell(
                            config: cellConfig,
                            width: placement.width,
                            height: placement.height,
                            scaleFactor: scaleFactor,
                            accentColor: accentColor,
                            iconBasePath: iconBasePath,
                            tintColor: tintColor,
                            cellIndex: index,
                            onTap: {
                                switch BentoDetailRoute.resolve(
                                    presentation: cellConfig.detailPresentation,
                                    gridInline: inlineExpansion,
                                    hasOverlay: cellConfig.detailOverlay != nil
                                ) {
                                case .popover:
                                    popoverCellId = cellConfig.id
                                case .inline:
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        expandedCellId = cellConfig.id
                                    }
                                case .sheet:
                                    // Built at click time so the sheet's content closure receives
                                    // the payload directly.
                                    if let overlay = cellConfig.detailOverlay {
                                        sheetContext = BentoSheetContext(id: cellConfig.id, cell: cellConfig, payload: .overlay(overlay))
                                    } else if let bound = boundItem(for: cellConfig) {
                                        sheetContext = BentoSheetContext(id: cellConfig.id, cell: cellConfig, payload: .plistBinding(bound))
                                    }
                                }
                            }
                        )
                        .popover(isPresented: Binding(
                            get: { popoverCellId == cellConfig.id },
                            set: { if !$0 { popoverCellId = nil } }
                        ), arrowEdge: .bottom) {
                            if let overlay = cellConfig.detailOverlay {
                                VStack(alignment: .leading, spacing: 8) {
                                    // The popover keeps the sheet's label and title so it has a
                                    // subject.
                                    if let label = cellConfig.label, !label.isEmpty {
                                        Text(label)
                                            .font(.system(size: 10, weight: .semibold))
                                            .textCase(.uppercase)
                                            .tracking(1.1)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let heading = overlay.title ?? cellConfig.title {
                                        Text(heading)
                                            .font(.system(size: 15, weight: .semibold))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    GuidanceContentView(
                                        contentBlocks: overlay.content ?? [],
                                        scaleFactor: scaleFactor,
                                        iconBasePath: iconBasePath,
                                        inspectState: inspectState,
                                        itemId: "bento-popover-\(cellConfig.id)",
                                        accentColor: accentColor,
                                        contentAlignment: .leading
                                    )
                                }
                                .padding(18)
                                // A reading measure and a height ceiling, so a long detail
                                // scrolls instead of pushing the popover off screen.
                                .frame(width: 340, alignment: .leading)
                                .frame(maxHeight: 420)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .overlay(alignment: .bottomLeading) {
                            if showSlots {
                                Text("col \(placement.column) · row \(placement.row) · span \(placement.columnSpan)x\(placement.rowSpan) · \(Int(placement.width.rounded()))pt")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.65))
                                    .padding(4)
                            }
                        }
                        .offset(x: placement.x, y: placement.y)
                        .opacity(isVisible ? (isDimmed ? 0.0 : 1) : 0)
                        .scaleEffect(isVisible ? 1 : 0.85)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isVisible)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isDimmed)
                        .allowsHitTesting(!isDimmed && expandedCellId == nil)
                    }
                }

            }
            .frame(width: availableWidth, height: gridHeight, alignment: .topLeading)
            .onAppear {
                detailBudget = CGSize(width: availableWidth,
                                      height: containerHeight ?? max(gridHeight, 480))
            }
            .onChange(of: availableWidth) { _, newWidth in
                detailBudget = CGSize(width: newWidth,
                                      height: containerHeight ?? max(gridHeight, 480))
            }
        }
        .frame(height: BentoLayoutEngine.calculateGridHeight(cells: cells, rowHeight: rowHeight * scaleFactor, gap: gap * scaleFactor))
        // Inline detail is presented as a sheet so it centres on the window.
        .sheet(isPresented: Binding(
            get: { expandedCellId != nil },
            set: { if !$0 { expandedCellId = nil } }
        )) {
            if let expandedId = expandedCellId,
               let cellConfig = cells.first(where: { $0.id == expandedId }),
               let detailConfig = cellConfig.detailOverlay {
                BentoInlineDetailView(
                    cellConfig: cellConfig,
                    overlay: detailConfig,
                    gridSize: detailBudget,
                    accentColor: accentColor,
                    iconBasePath: iconBasePath,
                    subjectIndex: cells.firstIndex(where: { $0.id == expandedId }),
                    subjectTotal: cells.count,
                    inspectState: inspectState,
                    onClose: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            expandedCellId = nil
                        }
                    }
                )
                // No minimum size: the sheet sizes itself to its measure.
            }
        }
        .onAppear {
            staggerCellAppearance()
        }
        // Driven by an Identifiable payload so the content closure never reads `@State`.
        .sheet(item: $sheetContext) { context in
            switch context.payload {
            case .overlay(let overlay):
                BentoDetailView(
                    cellConfig: context.cell,
                    overlay: overlay,
                    accentColor: accentColor,
                    iconBasePath: iconBasePath,
                    subjectIndex: cells.firstIndex(where: { $0.id == context.cell.id }),
                    subjectTotal: cells.count,
                    inspectState: inspectState,
                    onClose: { sheetContext = nil }
                )
            case .plistBinding(let item):
                BentoPlistDetailSheet(
                    cellConfig: context.cell,
                    item: item,
                    healthyLabel: complianceAggregator?.healthyLabel ?? "Healthy",
                    attentionLabel: complianceAggregator?.attentionLabel ?? "Needs Attention",
                    scaleFactor: scaleFactor,
                    inspectState: inspectState,
                    onClose: { sheetContext = nil }
                )
            }
        }
    }

    /// Cells appear one by one in reading order.
    private func staggerCellAppearance() {
        let sorted = cells.sorted { a, b in
            if a.row != b.row { return a.row < b.row }
            return a.column < b.column
        }

        for (index, cell) in sorted.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelay * Double(index)) {
                withAnimation {
                    _ = visibleCells.insert(cell.id)
                }
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct BentoGridView_Previews: PreviewProvider {
    static var previews: some View {
        BentoGridView(
            cells: [
                InspectConfig.GuidanceContent.BentoCellConfig(
                    id: "hero",
                    column: 0,
                    row: 0,
                    columnSpan: 2,
                    rowSpan: 2,
                    rows: nil,
                    contentType: "text",
                    imagePath: nil,
                    imageFit: nil,
                    title: "Welcome",
                    subtitle: "Getting Started",
                    textSize: "large",
                    textColor: nil,
                    surface: nil,
                    detailPresentation: nil,
                    sfSymbol: nil,
                    iconSize: nil,
                    iconColor: nil,
                    iconWeight: nil,
                    backgroundColor: "#E8F4FD",
                    cornerRadius: nil,
                    backgroundStyle: "gradient",
                    gradientStyle: "ethereal",
                    gradientPalette: nil,
                    label: nil,
                    detailOverlay: nil
                ),
                InspectConfig.GuidanceContent.BentoCellConfig(
                    id: "apps",
                    column: 2,
                    row: 0,
                    columnSpan: nil,
                    rowSpan: nil,
                    rows: nil,
                    contentType: "icon",
                    imagePath: nil,
                    imageFit: nil,
                    title: "Apps",
                    subtitle: nil,
                    textSize: nil,
                    textColor: nil,
                    surface: nil,
                    detailPresentation: nil,
                    sfSymbol: "square.grid.2x2",
                    iconSize: 48,
                    iconColor: nil,
                    iconWeight: nil,
                    backgroundColor: "#F5F5F5",
                    cornerRadius: nil,
                    backgroundStyle: nil,
                    gradientStyle: nil,
                    gradientPalette: nil,
                    label: nil,
                    detailOverlay: nil
                ),
                InspectConfig.GuidanceContent.BentoCellConfig(
                    id: "year",
                    column: 3,
                    row: 0,
                    columnSpan: nil,
                    rowSpan: nil,
                    rows: nil,
                    contentType: "text",
                    imagePath: nil,
                    imageFit: nil,
                    title: "2025",
                    subtitle: nil,
                    textSize: "large",
                    textColor: nil,
                    surface: nil,
                    detailPresentation: nil,
                    sfSymbol: nil,
                    iconSize: nil,
                    iconColor: nil,
                    iconWeight: nil,
                    backgroundColor: "#E8FDE8",
                    cornerRadius: nil,
                    backgroundStyle: "gradient",
                    gradientStyle: "vivid",
                    gradientPalette: ["#22C55E", "#10B981"],
                    label: nil,
                    detailOverlay: nil
                )
            ],
            columns: 4,
            rowHeight: 140,
            gap: 12,
            scaleFactor: 1.0,
            accentColor: .accentColor,
            iconBasePath: nil,
            tintColor: nil,
            inspectState: InspectState()
        )
        .frame(width: 600, height: 400)
        .padding()
    }
}
#endif
