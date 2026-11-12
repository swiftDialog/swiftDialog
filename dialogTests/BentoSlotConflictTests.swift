//
//  BentoSlotConflictTests.swift
//  dialogTests
//
//  BentoLayoutEngine authoring checks (slot conflicts, slot-map budget, off-grid cells, row fit),
//  per-row heights, and the bento row model built from `InstallItem`.
//

import XCTest
@testable import Dialog

final class BentoSlotConflictTests: XCTestCase {

    private func placement(_ id: String, row: Int, col: Int,
                           colSpan: Int = 1, rowSpan: Int = 1) -> BentoLayoutEngine.CellPlacement {
        BentoLayoutEngine.CellPlacement(
            id: id, cellId: id, row: row, column: col,
            columnSpan: colSpan, rowSpan: rowSpan,
            x: 0, y: 0, width: 0, height: 0
        )
    }

    func testCleanSlotMapReportsNothing() {
        let cells = [
            placement("sofa", row: 0, col: 0, colSpan: 2),
            placement("outset", row: 0, col: 2),
            placement("pique", row: 1, col: 0),
            placement("carafe", row: 1, col: 1, colSpan: 2),
            placement("munki", row: 2, col: 0, colSpan: 2),
            placement("nanohub", row: 2, col: 2)
        ]
        XCTAssertEqual(BentoLayoutEngine.slotConflicts(cells), [])
    }

    /// A cell inside another cell's span is a conflict, not just an exact duplicate slot.
    func testCellLandingInsideAnotherCellsSpanIsCaught() {
        let conflicts = BentoLayoutEngine.slotConflicts([
            placement("sofa", row: 0, col: 0, colSpan: 2),
            placement("outset", row: 0, col: 1)
        ])
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertTrue(conflicts[0].contains("r0 c1"), conflicts[0])
        XCTAssertTrue(conflicts[0].contains("sofa"), conflicts[0])
        XCTAssertTrue(conflicts[0].contains("outset"), conflicts[0])
    }

    func testExactDuplicateSlotIsCaught() {
        let conflicts = BentoLayoutEngine.slotConflicts([
            placement("a", row: 1, col: 1),
            placement("b", row: 1, col: 1)
        ])
        XCTAssertEqual(conflicts.count, 1)
    }

    /// rowSpan is not clamped by the engine, so vertical overlap is reported like horizontal.
    func testRowSpanOverlapIsCaught() {
        let conflicts = BentoLayoutEngine.slotConflicts([
            placement("tall", row: 0, col: 0, rowSpan: 2),
            placement("under", row: 1, col: 0)
        ])
        XCTAssertEqual(conflicts.count, 1)
        XCTAssertTrue(conflicts[0].contains("r1 c0"), conflicts[0])
    }

    /// Every overlapping slot is reported, not just the first.
    func testEveryOverlappingSlotIsReported() {
        let conflicts = BentoLayoutEngine.slotConflicts([
            placement("big", row: 0, col: 0, colSpan: 2, rowSpan: 2),
            placement("alsoBig", row: 0, col: 0, colSpan: 2, rowSpan: 2)
        ])
        XCTAssertEqual(conflicts.count, 4)
    }
}

// MARK: - Slot-map budget (three rows, three shapes)

extension BentoSlotConflictTests {

    func testThreeRowsAndThreeShapesIsWithinBudget() {
        let cells = [
            placement("a", row: 0, col: 0, colSpan: 2),
            placement("b", row: 0, col: 2),
            placement("c", row: 1, col: 0, rowSpan: 2)
        ]
        XCTAssertEqual(BentoLayoutEngine.slotMapWarnings(cells), [])
    }

    /// A fourth row scrolls off a 600pt window, so it is warned.
    func testFourthRowIsWarned() {
        let warnings = BentoLayoutEngine.slotMapWarnings([
            placement("a", row: 0, col: 0),
            placement("d", row: 3, col: 0)
        ])
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("4 rows"), warnings[0])
    }

    func testFourthSpanShapeIsWarned() {
        let warnings = BentoLayoutEngine.slotMapWarnings([
            placement("a", row: 0, col: 0),
            placement("b", row: 0, col: 1, colSpan: 2),
            placement("c", row: 1, col: 0, rowSpan: 2),
            placement("d", row: 1, col: 1, colSpan: 2, rowSpan: 2)
        ])
        XCTAssertTrue(warnings.contains { $0.contains("4 span shapes") }, "\(warnings)")
    }

    /// A rowSpan running past row three counts as a fourth row.
    func testRowSpanRunningPastThreeRowsIsWarned() {
        let warnings = BentoLayoutEngine.slotMapWarnings([
            placement("tall", row: 2, col: 0, rowSpan: 2)
        ])
        XCTAssertTrue(warnings.contains { $0.contains("4 rows") }, "\(warnings)")
    }

    // MARK: - Per-row heights

    private func cell(_ id: String, row: Int, col: Int,
                      colSpan: Int = 1, rowSpan: Int = 1) throws -> InspectConfig.GuidanceContent.BentoCellConfig {
        let json = """
        {"id":"\(id)","row":\(row),"column":\(col),
         "columnSpan":\(colSpan),"rowSpan":\(rowSpan),"contentType":"text"}
        """
        return try JSONDecoder().decode(
            InspectConfig.GuidanceContent.BentoCellConfig.self, from: Data(json.utf8)
        )
    }

    /// A cell starting past the last column draws nothing (span clamps to 0), so it is named.
    func testCellsStartingPastTheLastColumnAreNamed() throws {
        let cells = [
            try cell("sofa", row: 0, col: 0, colSpan: 2), try cell("outset", row: 0, col: 2),
            try cell("pique", row: 1, col: 0), try cell("carafe", row: 1, col: 1, colSpan: 2),
            try cell("munki", row: 2, col: 0, colSpan: 2), try cell("nanohub", row: 2, col: 2)
        ]
        let warnings = BentoLayoutEngine.offGridCells(cells: cells, columns: 2)
        XCTAssertEqual(warnings.count, 2, "\(warnings)")
        XCTAssertTrue(warnings[0].contains("'outset'") && warnings[0].contains("columns: 3"), warnings[0])
        XCTAssertTrue(warnings[1].contains("'nanohub'"), warnings[1])

        let placed = BentoLayoutEngine.calculate(cells: cells, columns: 2, cellWidth: 100,
                                                 rowHeights: [100, 100, 100], gap: 12)
        XCTAssertLessThanOrEqual(try XCTUnwrap(placed.first { $0.cellId == "outset" }).width, 0)

        XCTAssertEqual(BentoLayoutEngine.offGridCells(cells: cells, columns: 3), [],
                       "the grid it was written for holds every cell")
    }

    /// A span clamped at the edge still draws, so only a cell with nothing to draw is reported.
    func testASpanClampedAtTheEdgeIsNotReported() {
        XCTAssertEqual(BentoLayoutEngine.offGridCells(cells: [try cell("wide", row: 0, col: 1, colSpan: 3)],
                                                      columns: 2), [])
        XCTAssertEqual(BentoLayoutEngine.offGridCells(cells: [try cell("neg", row: 0, col: -1)], columns: 2).count, 1,
                       "a negative column is off the grid too")
    }

    /// A row's origin is the sum of the row heights above it plus gaps.
    func testRowOriginIsThePrefixSumOfTheRowsAbove() throws {
        let placements = BentoLayoutEngine.calculate(
            cells: [try cell("top", row: 0, col: 0), try cell("bottom", row: 1, col: 0)],
            columns: 2, cellWidth: 100, rowHeights: [200, 100], gap: 10
        )
        XCTAssertEqual(placements.first { $0.cellId == "top" }?.y, 0)
        XCTAssertEqual(placements.first { $0.cellId == "bottom" }?.y, 210)
    }

    /// A spanning cell is as tall as every row it covers plus the gaps between them.
    func testCellSpanningRowsTakesTheHeightOfEveryRowItCovers() throws {
        let placements = BentoLayoutEngine.calculate(
            cells: [try cell("hero", row: 0, col: 0, rowSpan: 2)],
            columns: 2, cellWidth: 100, rowHeights: [200, 100], gap: 10
        )
        XCTAssertEqual(placements.first?.height, 310)
    }

    /// Uniform row heights reproduce the single-rowHeight arithmetic, so shipped grids do not move.
    func testUniformRowHeightsReproduceTheOriginalArithmetic() throws {
        let cells = [try cell("a", row: 0, col: 0), try cell("b", row: 1, col: 1, colSpan: 2, rowSpan: 2)]
        let uniform = BentoLayoutEngine.calculate(
            cells: cells, columns: 3, cellWidth: 241.5, rowHeights: [128, 128, 128], gap: 14
        )
        for p in uniform {
            XCTAssertEqual(p.y, CGFloat(p.row) * (128 + 14), "y for \(p.cellId)")
            XCTAssertEqual(p.height, CGFloat(p.rowSpan) * 128 + CGFloat(p.rowSpan - 1) * 14,
                           "height for \(p.cellId)")
        }
    }

    // MARK: - Bento rows

    // Row state uses the `OptionCard.state` vocabulary (nil, installed, pending, unavailable);
    // an unknown name falls through to the plain rendering.

    private func row(_ id: String, title: String = "Excel",
                     state: String? = nil, verb: String? = nil) -> BentoRowModel {
        BentoRowModel(id: id, title: title, detail: nil, badge: nil,
                      iconName: nil, state: state, verb: verb)
    }

    /// The verb is authored, not guessed.
    func testRowWithNoStateOffersItsAuthoredVerb() {
        XCTAssertEqual(row("vscode", verb: "Download for macOS").affordance,
                       .action(verb: "Download for macOS"))
    }

    /// An installed row shows a statement, not a button.
    func testInstalledRowOffersNoActionToTake() {
        XCTAssertEqual(row("clt", state: "installed", verb: "Install").affordance, .installed)
    }

    /// A misspelled state keeps its button rather than hiding the row.
    func testUnknownStateFallsThroughToActionRatherThanHidingTheRow() {
        XCTAssertEqual(row("mystery", state: "sparkly", verb: "Install").affordance,
                       .action(verb: "Install"))
    }

    /// Hairlines go between rows: every row but the last draws one.
    func testEveryRowButTheLastDrawsAHairline() {
        XCTAssertEqual((0 ..< 4).map { BentoRowModel.showsHairline(at: $0, of: 4) },
                       [true, true, true, false])
    }

    func testALoneRowDrawsNoHairline() {
        XCTAssertFalse(BentoRowModel.showsHairline(at: 0, of: 1))
    }

    // MARK: - Row geometry

    /// Row height is derived from icon size and padding, not a literal.
    func testRowHeightIsTheIconPlusItsVerticalPadding() {
        XCTAssertEqual(BentoRowM.rowHeight, BentoRowM.iconSize + 2 * BentoRowM.verticalPadding)
    }

    /// Hairlines cost no height: the zone is row count times row height.
    func testRowsZoneHeightIsRowCountTimesRowHeight() {
        XCTAssertEqual(BentoRowM.rowsZoneHeight(count: 4), 4 * BentoRowM.rowHeight)
        XCTAssertEqual(BentoRowM.rowsZoneHeight(count: 1), BentoRowM.rowHeight)
    }

    func testNoRowsMeansNoRowsZone() {
        XCTAssertEqual(BentoRowM.rowsZoneHeight(count: 0), 0)
    }

    /// The 8pt button radius is shared with every other installer button.
    func testActionButtonUsesTheSquarishRadius() {
        XCTAssertEqual(BentoRowM.buttonRadius, 8)
    }

    // MARK: - Authoring rows

    // A bento row is an `InstallItem`: `actionLabel` is the verb, `state` the catalogue state.
    // `InstallItem.status` is the run state and must not decide the affordance.

    private func decodeCell(_ json: String) throws -> InspectConfig.GuidanceContent.BentoCellConfig {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.BentoCellConfig.self,
                                 from: Data(json.utf8))
    }

    func testBentoCellDecodesItsRows() throws {
        let cell = try decodeCell("""
        {"id":"m365","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel","actionLabel":"Install"},
                 {"title":"Command line tools","state":"installed"}]}
        """)
        XCTAssertEqual(cell.rows?.count, 2)
        XCTAssertEqual(cell.rows?.first?.title, "Excel")
        XCTAssertEqual(cell.rows?.last?.state, "installed")
    }

    func testACellWithNoRowsStillDecodes() throws {
        let cell = try decodeCell("""
        {"id":"plain","row":1,"column":2,"contentType":"icon"}
        """)
        XCTAssertNil(cell.rows)
    }

    /// `itemId` is the row id; `actionLabel` becomes the action verb.
    func testBentoRowIsBuiltFromAnInstallItem() throws {
        let cell = try decodeCell("""
        {"id":"dev","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Docker","subtitle":"mail migrated","badge":"1.2 GB",
                  "actionLabel":"Download for macOS","itemId":"docker","icon":"shippingbox"}]}
        """)
        let row = BentoRowModel(from: try XCTUnwrap(cell.rows?.first))
        XCTAssertEqual(row.id, "docker")
        XCTAssertEqual(row.title, "Docker")
        XCTAssertEqual(row.iconName, "shippingbox")
        XCTAssertEqual(row.badge, "1.2 GB")
        XCTAssertEqual(row.affordance, .action(verb: "Download for macOS"))
    }

    /// `subtitle` wins over `detail`; a row is one line tall.
    func testTheShortClarifierWinsOverTheParagraph() throws {
        let both = try decodeCell("""
        {"id":"a","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Outlook","subtitle":"mail migrated","detail":"A long paragraph."}]}
        """)
        XCTAssertEqual(BentoRowModel(from: try XCTUnwrap(both.rows?.first)).detail, "mail migrated")

        let paragraphOnly = try decodeCell("""
        {"id":"b","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Outlook","detail":"A long paragraph."}]}
        """)
        XCTAssertEqual(BentoRowModel(from: try XCTUnwrap(paragraphOnly.rows?.first)).detail,
                       "A long paragraph.")
    }

    func testARowWithNoItemIdIsIdentifiedByItsTitle() throws {
        let cell = try decodeCell("""
        {"id":"x","row":0,"column":0,"contentType":"text","rows":[{"title":"Word"}]}
        """)
        XCTAssertEqual(BentoRowModel(from: try XCTUnwrap(cell.rows?.first)).id, "Word")
    }

    // MARK: - Intrinsic height from row count

    // `intrinsicRowHeights` only grows a row; the authored height is the floor. The heading
    // allowance is generous because the engine places absolutely and cannot measure wrapped text.

    func testAGridWhoseCellsHaveNoRowsKeepsEveryAuthoredHeight() throws {
        let cells = [try decodeCell("""
        {"id":"a","row":0,"column":0,"contentType":"text"}
        """), try decodeCell("""
        {"id":"b","row":1,"column":0,"contentType":"icon"}
        """)]
        XCTAssertEqual(
            BentoLayoutEngine.intrinsicRowHeights(cells: cells, authored: 118, gap: 12),
            [118, 118]
        )
    }

    /// A grid row is as tall as the tallest tile in it, and only that row grows.
    func testOnlyTheRowHoldingTallContentGrows() throws {
        let cells = [try decodeCell("""
        {"id":"tall","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"},{"title":"Outlook"}]}
        """), try decodeCell("""
        {"id":"plain","row":1,"column":0,"contentType":"text"}
        """)]
        let heights = BentoLayoutEngine.intrinsicRowHeights(cells: cells, authored: 118, gap: 12)
        XCTAssertEqual(heights[0], BentoRowM.headingAllowance + BentoRowM.rowsZoneHeight(count: 3))
        XCTAssertEqual(heights[1], 118, "a row with no rows in it must not move")
    }

    func testTheAuthoredHeightIsAFloor() throws {
        let cell = try decodeCell("""
        {"id":"roomy","row":0,"column":0,"contentType":"text","rows":[{"title":"Excel"}]}
        """)
        XCTAssertEqual(
            BentoLayoutEngine.intrinsicRowHeights(cells: [cell], authored: 400, gap: 12),
            [400]
        )
    }

    /// The grid container grows with its tallest row, or the frame clips the last tile.
    func testTheGridContainerGrowsWithItsTallestRow() throws {
        let plain = try decodeCell("""
        {"id":"plain","row":0,"column":0,"contentType":"text"}
        """)
        let withRows = try decodeCell("""
        {"id":"m365","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"},{"title":"Outlook"}]}
        """)
        XCTAssertEqual(BentoLayoutEngine.calculateGridHeight(cells: [plain], rowHeight: 118, gap: 12), 118)
        XCTAssertEqual(
            BentoLayoutEngine.calculateGridHeight(cells: [withRows], rowHeight: 118, gap: 12),
            BentoRowM.headingAllowance + BentoRowM.rowsZoneHeight(count: 3)
        )
    }

    /// Placements and the container are computed from the same heights.
    func testPlacementsAgreeWithTheContainerHeight() throws {
        let cells = [try decodeCell("""
        {"id":"m365","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"},{"title":"Outlook"}]}
        """), try decodeCell("""
        {"id":"dev","row":1,"column":0,"contentType":"text",
         "rows":[{"title":"Docker"},{"title":"Command line tools"}]}
        """)]
        let placements = BentoLayoutEngine.calculate(
            cells: cells, columns: 1, cellWidth: 400, rowHeight: 118, gap: 12
        )
        let bottom = placements.map { $0.y + $0.height }.max() ?? 0
        XCTAssertEqual(bottom, BentoLayoutEngine.calculateGridHeight(cells: cells, rowHeight: 118, gap: 12))
    }

    /// Intrinsic heights always satisfy the fit warning.
    func testIntrinsicHeightsLeaveNothingForTheFitWarningToReport() throws {
        let cell = try decodeCell("""
        {"id":"m365","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"},{"title":"Outlook"}]}
        """)
        let heights = BentoLayoutEngine.intrinsicRowHeights(cells: [cell], authored: 100, gap: 12)
        XCTAssertEqual(BentoLayoutEngine.rowFitWarnings(cells: [cell], rowHeights: heights, gap: 12), [])
    }

    /// The fit warning allows nothing for the heading, so it fires only when the rows alone
    /// cannot fit.
    func testATileTooShortForItsRowsIsReported() throws {
        let cell = try decodeCell("""
        {"id":"m365","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"},{"title":"Outlook"}]}
        """)
        let warnings = BentoLayoutEngine.rowFitWarnings(cells: [cell], rowHeights: [100], gap: 12)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertTrue(warnings[0].contains("m365"), warnings[0])
        XCTAssertTrue(warnings[0].contains("144"), warnings[0])
    }

    func testATileWithRoomForItsRowsIsNotReported() throws {
        let cell = try decodeCell("""
        {"id":"ok","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"}]}
        """)
        XCTAssertEqual(BentoLayoutEngine.rowFitWarnings(cells: [cell], rowHeights: [244], gap: 12), [])
    }

    func testACellWithNoRowsYieldsNoRowModels() throws {
        let cell = try decodeCell("""
        {"id":"plain","row":0,"column":0,"contentType":"text"}
        """)
        XCTAssertTrue(cell.bentoRows.isEmpty)
    }

    func testCellRowsBecomeModelsInAuthoredOrder() throws {
        let cell = try decodeCell("""
        {"id":"m365","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel"},{"title":"Word"},{"title":"Outlook","state":"installed"}]}
        """)
        XCTAssertEqual(cell.bentoRows.map(\.title), ["Excel", "Word", "Outlook"])
        XCTAssertEqual(cell.bentoRows.last?.affordance, .installed)
        XCTAssertEqual((0 ..< cell.bentoRows.count)
                        .map { BentoRowModel.showsHairline(at: $0, of: cell.bentoRows.count) },
                       [true, true, false])
    }

    /// Run status never decides the catalogue affordance.
    func testRunStatusDoesNotDecideTheCatalogueAffordance() throws {
        let cell = try decodeCell("""
        {"id":"y","row":0,"column":0,"contentType":"text",
         "rows":[{"title":"Excel","status":"success","actionLabel":"Install"}]}
        """)
        XCTAssertEqual(BentoRowModel(from: try XCTUnwrap(cell.rows?.first)).affordance,
                       .action(verb: "Install"))
    }
}
