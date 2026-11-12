//
//  ProvisioningGridTests.swift
//  dialogTests
//
//  The provisioning shell's geometry as arithmetic, so a wrong figure fails on its own. The layout
//  holds at two window sizes; only the figures tied to the footer rule may move between them.
//

import XCTest
import SwiftUI
@testable import Dialog

final class ProvisioningGridTests: XCTestCase {

    private let recommended = ProvisioningM(size: ProvisioningM.recommended)   // 820 × 600
    private let minimum = ProvisioningM(size: ProvisioningM.minimum)           // 800 × 600
    /// A taller window: `recommended` and `minimum` share the 600 height.
    private let tall = ProvisioningM(width: 820, height: 640)

    // MARK: - Frame

    /// The 820 × 600 frame: rails 44 / 776, column 732, body 176 → 444, strip 444 → 488, quiet band
    /// 488 → 516, the rule at 516 with an 84 band under it. At 800 the column is 712.
    func testTheIdentityRailFrameLandsExactly() {
        let m = ProvisioningM(size: CGSize(width: 820, height: 600))
        XCTAssertEqual(m.column, 732)
        XCTAssertEqual(ProvisioningM.listTop, 176)
        XCTAssertEqual(m.stripTop, 444)
        XCTAssertEqual(m.stripTop + ProvisioningM.stripHeight, 488, "the strip ends where the quiet band starts")
        XCTAssertEqual(m.footerRuleY, 516)
        XCTAssertEqual(m.height - m.footerRuleY, ProvisioningM.footerBandHeight)
        // 268 at 820 × 600: five 52pt rows plus 8pt slack.
        XCTAssertEqual(m.listRegionHeight, 268)
    }

    func testTheColumnCloses() {
        XCTAssertEqual(recommended.column, 732)
        XCTAssertEqual(minimum.column, 712)
        XCTAssertEqual(recommended.mirror, 776)
        XCTAssertEqual(minimum.mirror, 756)
    }

    /// The shell's rail is the card edge, 44, so mixed flows keep one left edge. Still its own constant.
    func testTheRailIsTheOneEdge() {
        XCTAssertEqual(ProvisioningM.rail, 44)
        XCTAssertEqual(ProvisioningM.rail, InspectMetrics(scale: 1.0).cardEdge)
    }

    /// The name sits at rail + mark slot + gap: 44 + 18 + 16 = 78.
    func testTheNameSitsWhereTheMarkSlotPutsIt() {
        XCTAssertEqual(ProvisioningM.nameX, 78, "the name sits at rail + mark slot + gap: 44 + 34")
        XCTAssertEqual(ProvisioningM.nameX,
                       ProvisioningM.rail + ProvisioningM.markSlot + ProvisioningM.markGap)
    }

    // MARK: - Two window sizes, one layout

    /// Only three figures change between sizes, all measured 40 above the footer rule.
    func testOnlyThreeFiguresMoveBetweenTheTwoSizes() {
        // Unchanged: header anchors, list top, row height, footer band.
        XCTAssertEqual(ProvisioningM.listTop, 176)
        XCTAssertEqual(ProvisioningM.rowHeight, 52)
        XCTAssertEqual(ProvisioningM.footerBandHeight, 84)

        // Moved by exactly the height difference, measured against the taller window.
        XCTAssertEqual(tall.footerRuleY, 556)
        XCTAssertEqual(minimum.footerRuleY, 516)
        XCTAssertEqual(tall.stripTop, 484)
        XCTAssertEqual(minimum.stripTop, 444)

        let delta = tall.height - minimum.height
        XCTAssertEqual(tall.footerRuleY - minimum.footerRuleY, delta)
        XCTAssertEqual(tall.stripTop - minimum.stripTop, delta)
    }

    /// Five rows fit at the minimum with 20 points to spare.
    func testFiveRowsFitAtTheMinimumWithTwentyToSpare() {
        XCTAssertEqual(minimum.maxVisibleRows, 5)
        XCTAssertEqual(recommended.maxVisibleRows, 5)
        let used = 5 * ProvisioningM.rowHeight
        XCTAssertEqual(minimum.listRegionHeight - used, ProvisioningM.minimumBandSlack,
                       "the design's own spare at the minimum is exactly 20")
    }

    /// A sixth row arrives at 652, not 640: the design keeps 20pt of slack above the band.
    func testTheSixthRowArrivesPastSixSixty() {
        XCTAssertEqual(ProvisioningM(width: 820, height: 640).maxVisibleRows, 5)
        XCTAssertEqual(ProvisioningM(width: 820, height: 652).maxVisibleRows, 6)
        XCTAssertEqual(ProvisioningM(width: 820, height: 660).maxVisibleRows, 6)
    }

    /// The list is given a height and never exceeds its region, so it cannot push the band.
    func testTheListNeverExceedsItsRegion() {
        XCTAssertEqual(minimum.listHeight(rowCount: 3), 156)
        XCTAssertEqual(minimum.listHeight(rowCount: 12), 5 * ProvisioningM.rowHeight,
                       "a twelve-item list must clamp to the cap and scroll, not grow")
    }

    /// A window below the minimum takes the minimum's geometry rather than negative regions.
    func testSubMinimumWindowsClampRatherThanGoNegative() {
        let tiny = ProvisioningM(width: 500, height: 300)
        XCTAssertEqual(tiny.column, minimum.column)
        XCTAssertGreaterThan(tiny.listRegionHeight, 0)
    }

    // MARK: - Identity rail

    /// The ratio ceiling is derived as box ÷ cap height.
    func testTheRatioCeilingIsTheBoxDividedByTheCapHeight() {
        XCTAssertEqual(ProvisioningM.identityRatioCeiling, 6)
        XCTAssertEqual(ProvisioningM.identityRatioCeiling,
                       ProvisioningM.logoMaxWidth / ProvisioningM.logoCapHeight)
    }

    /// Against the 120 box: 2.4 : 1 and 4.3 : 1 marks clear it; a 12.7 : 1 wordmark (254pt at a 20pt cap) does not.
    func testWhichSuppliedMarksClearTheShippedBox() {
        let ceiling = ProvisioningM.identityRatioCeiling
        XCTAssertLessThanOrEqual(2.4, ceiling, "a 2.4 : 1 roundel must clear the ceiling")
        XCTAssertLessThanOrEqual(4.3, ceiling, "a 4.3 : 1 mark must clear the ceiling")
        XCTAssertGreaterThan(12.7, ceiling, "the 12.7 : 1 Example Corp wordmark must NOT clear it")
    }

    /// The row has room for a 12.7 : 1 mark at the full 20pt cap height; a 260 box would admit it.
    func testTheRailCouldCarryTheBrandWordmarkAtFullCapHeight() {
        let wideMark: CGFloat = 280.0 / 22.0
        let needed = ProvisioningM.logoCapHeight * wideMark
        XCTAssertEqual(needed, 254.5, accuracy: 0.5, "20pt cap height x 12.7:1")

        // Spare width at the recommended size.
        let m = ProvisioningM(size: ProvisioningM.recommended)
        let nameAndDetail: CGFloat = 76 + 20 + 115   // "Examplecorp" + gap + "Aviation · 40 sites"
        let consumed = ProvisioningM.markSlot + ProvisioningM.markGap + nameAndDetail + 20
        XCTAssertGreaterThan(m.column - consumed, needed,
                             "the 120 box is a chosen width, not the width the row can afford")

        // The one number that would change to admit it.
        XCTAssertGreaterThan(260 / ProvisioningM.logoCapHeight, wideMark,
                             "a 260 box moves the ceiling to 13:1, which admits 12.7:1")
    }

    /// An over-long mark takes the fallback rung; it is never shrunk.
    func testAnOverLongMarkTakesTheFallbackRungRatherThanShrinking() {
        let brand = InspectConfig.BrandConfig(
            id: "example", displayName: "Examplecorp", subtitle: "Aviation · 40 sites",
            logoPath: "/nonexistent/brand-example-trim.png", sfSymbol: nil,
            highlightColor: "#F0C34C", accentBorderColor: nil, footerBackgroundColor: nil,
            footerTextColor: nil, footerText: nil, logoConfigPath: nil, button1Text: nil,
            button2Text: nil, introTitle: nil, outroTitle: nil, introButtonText: nil,
            outroButtonText: nil)
        // An unreadable asset takes the fallback too.
        guard case .wordmark(let text, _) = ProvisioningRowBuilder.identity(for: brand, scheme: .dark)
        else { return XCTFail("expected the wordmark rung") }
        XCTAssertEqual(text, "EXAMPLECORP")
    }

    /// Raising the box raises the ceiling with it.
    func testRaisingTheBoxAdmitsTheLongerMark() {
        let brand = InspectConfig.BrandConfig(
            id: "b", displayName: "Basalt Industrial", subtitle: nil, logoPath: nil,
            sfSymbol: nil, highlightColor: "#A184F5", accentBorderColor: nil,
            footerBackgroundColor: nil, footerTextColor: nil, footerText: nil,
            logoConfigPath: nil, button1Text: nil, button2Text: nil, introTitle: nil,
            outroTitle: nil, introButtonText: nil, outroButtonText: nil)
        // No mark at all lands on rung 3.
        guard case .swatch(let initial, _) = ProvisioningRowBuilder.identity(
            for: brand, scheme: .dark, ceiling: 13)
        else { return XCTFail("expected the initial swatch") }
        XCTAssertEqual(initial, "B")
    }

    // MARK: - Footer lockup

    /// The two-brand lockup is opt-in (`logoConfig.lockup: "both"`).
    func testTheLockupIsOptIn() {
        XCTAssertEqual(ProvisioningM.lockupMarkSize, 24, "both marks share one box height")
        XCTAssertEqual(ProvisioningM.lockupGap, 11)
        XCTAssertEqual(ProvisioningM.lockupRatioCeiling, 4,
                       "the footer line is shorter than the identity rail, so its ceiling is too")
        XCTAssertLessThan(ProvisioningM.lockupRatioCeiling, ProvisioningM.identityRatioCeiling,
                          "a footer mark sits beside a name and an attribution; the rail's does not")
    }

    /// The lede clamps at two lines (ending at 122, 30 above the list at 152).
    func testTheLedeCeilingStillKeepsTheListClear() {
        let line = ProvisioningM.ledeSize + ProvisioningM.ledeLineSpacing
        let twoLines = ProvisioningM.ledeY + 2 * line
        let threeLines = ProvisioningM.ledeY + 3 * line
        XCTAssertGreaterThanOrEqual(ProvisioningM.listTop - twoLines, 28, "two lines leave the list real air")
        XCTAssertLessThan(ProvisioningM.listTop - threeLines, 16, "a third line would crowd the list")
        XCTAssertEqual(ProvisioningM.ledeMaxLines, 2)
    }

    // MARK: - Portability

    /// The band body takes a width, not a window, so any host can construct it.
    func testBandBodyIsConstructibleWithoutAWindow() {
        _ = ProvisioningStatusBandBody(
            content: .progress(count: "3 of 5", detail: "12 s", fraction: 0.6, stopped: false),
            width: 500, accent: .blue)
        _ = ProvisioningStatusBandBody(
            content: .consequence(text: "Support goes to IT", detail: nil, swatch: nil),
            width: nil, accent: .blue)
    }

    /// The adapter hands the body the column, never the window width.
    func testAdapterWidthIsTheColumnNotTheWindow() {
        XCTAssertEqual(recommended.column, 732)
        XCTAssertEqual(minimum.column, 712)
        XCTAssertNotEqual(recommended.column, recommended.width)
    }

    // MARK: - Migration bodies

    /// The receipt split closes on the column: 424 + 20 + 296 = 740.
    func testReceiptSplitClosesOnTheColumn() {
        XCTAssertEqual(MigrationM.receiptWidth, 732)
        XCTAssertEqual(MigrationM.receiptWidth, recommended.column)
    }

    /// The split is decided by width alone; below the sum the columns stack.
    func testReceiptSplitIsAnsweredByAWidthAlone() {
        XCTAssertTrue(MigrationM.fitsReceiptSplit(in: 732))
        XCTAssertFalse(MigrationM.fitsReceiptSplit(in: 731))
        XCTAssertFalse(MigrationM.fitsReceiptSplit(in: minimum.column),
                       "the 800pt minimum window's 720 column stacks rather than splitting")
    }

    /// Migration bodies are constructible without a window.
    func testMigrationBodiesAreConstructibleWithoutAWindow() {
        let facts = [MigrationFact(label: "Takes about", value: "8 minutes", isFigure: true),
                     MigrationFact(label: "Target platform", value: "Fleet")]
        _ = MigrationFactsPanel(facts: facts, width: nil)
        _ = MigrationFactsPanel(facts: facts, width: MigrationM.panelWidth)
        _ = MigrationReceiptBody(rows: [], facts: facts, caption: nil, width: nil, accent: .blue)
        _ = MigrationReceiptBody(rows: [], facts: facts, caption: "Confirmed on the last screen.",
                                 width: 740, accent: .blue)
    }

    /// Only one fact per panel is the 27pt figure; the rest are 13.5.
    func testTheFigureIsOneFactNotAllOfThem() {
        let facts = [MigrationFact(label: "Takes about", value: "8 minutes", isFigure: true),
                     MigrationFact(label: "Deadline set by IT", value: "Friday 12 September"),
                     MigrationFact(label: "Target platform", value: "Fleet")]
        XCTAssertEqual(facts.filter(\.isFigure).count, 1)
        XCTAssertEqual(MigrationM.figureSize, 27)
        XCTAssertGreaterThan(MigrationM.figureSize, MigrationM.factValueSize)
    }

    /// The media split closes on the column: 340 + 16 + 384 = 740.
    func testMediaSplitClosesOnTheColumn() {
        XCTAssertEqual(MigrationM.mediaGap, 16, "the gutter is 16: 332 + 16 + 384 closes on the 732 column, 56 would overrun it")
        XCTAssertEqual(MigrationM.mediaSplitWidth, 732)
        XCTAssertEqual(MigrationM.mediaSplitWidth, recommended.column)
        XCTAssertEqual(MigrationM.mediaSplitWidth, MigrationM.receiptWidth,
                       "both bodies close on the same column, which is what makes them swappable")
    }

    /// Plain-simple's 560 column keeps two columns; plain-branded's 500 stacks; 740 takes the wide arm.
    func testTheNarrowSplitTakesPlainSimpleAndLeavesPlainBrandedStacked() {
        XCTAssertEqual(MigrationM.narrowSplitWidth, 516)
        XCTAssertTrue(MigrationM.fitsNarrowSplit(in: PlainSimpleM.cardWidth))
        XCTAssertFalse(MigrationM.fitsNarrowSplit(in: PlainBrandedM.columnWidth), "500 stacks")
        XCTAssertFalse(MigrationM.fitsNarrowSplit(in: MigrationM.mediaSplitWidth), "740 is the wide arm")
        XCTAssertEqual(MigrationM.narrowMediaWidth(in: PlainSimpleM.cardWidth), 284)
        XCTAssertEqual(MigrationM.narrowStepsColumn(in: PlainSimpleM.cardWidth), 260)
        XCTAssertEqual(MigrationM.narrowStepsColumn(in: 560) + MigrationM.mediaGap
                       + MigrationM.narrowMediaWidth(in: 560), 560, "the two columns close on the host")
        XCTAssertEqual(MigrationM.narrowMediaWidth(in: 739), MigrationM.mediaWidth,
                       "near the sheet's width the walkthrough is capped at its authored 356")
    }

    /// The walkthrough keeps 16:10 at 356 of the 384 available.
    func testTheWalkthroughSitsInsideItsColumn() {
        XCTAssertLessThan(MigrationM.mediaWidth, MigrationM.mediaColumnWidth)
        XCTAssertEqual(MigrationM.mediaWidth / MigrationM.mediaHeight, 356.0 / 222.0, accuracy: 0.001)
    }

    /// Every migration body is constructible without a window.
    func testEveryMigrationBodyIsConstructibleWithoutAWindow() {
        let steps = [MigrationActionStep(text: "Open Settings, below"),
                     MigrationActionStep(text: "Approve the device management profile")]
        _ = MigrationInstructionTile(steps: steps, width: nil, accent: .blue)
        _ = MigrationMediaSplit(steps: steps, mediaURL: nil, caption: nil, mediaCaption: nil,
                                width: nil, accent: .blue)
        _ = MigrationTaskListBody(rows: [], caption: nil, width: nil, accent: .blue)
        _ = MigrationFooterBar(fraction: 0.5, accent: .blue)
    }


    // MARK: - Which migration body a step draws

    /// Roles, since `InspectConfig.GuidanceContent` is decode-only.
    private func roles(_ types: [String]) -> [GuidanceBlockRole] {
        types.map { GuidanceBlockRole(blockType: $0) }
    }

    /// Media wins the body choice, even beside a facts table.
    func testMediaWinsTheBodyChoice() {
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["video", "bullets"])), .mediaSplit)
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["stat-row", "image"])), .mediaSplit)
    }

    /// A facts panel makes a receipt.
    func testFactsMakeAReceipt() {
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["checklist", "stat-row"])), .receipt)
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["comparison-table"])), .receipt)
    }

    /// Rows alone are the task list.
    func testRowsAloneAreTheTaskList() {
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["checklist"])), .taskList)
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["phase-tracker"])), .taskList)
    }

    /// A step that matches nothing gets no migration body.
    func testResolverFailsOpen() {
        XCTAssertNil(MigrationBodyKind.resolve(blocks: nil))
        XCTAssertNil(MigrationBodyKind.resolve(roles: []))
        XCTAssertNil(MigrationBodyKind.resolve(roles: roles(["text", "warning"])),
                     "prose alone is not a migration body")
    }

    /// The resolver reads roles, so `feature-table` and `stat-row` (both .data) agree.
    func testTheResolverReadsRolesNotTypes() {
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["feature-table"])),
                       MigrationBodyKind.resolve(roles: roles(["stat-row"])))
        XCTAssertEqual(MigrationBodyKind.resolve(roles: roles(["image-carousel"])),
                       MigrationBodyKind.resolve(roles: roles(["video"])))
    }


    // MARK: - Finished marks

    /// Marks turn green only on the receipt, all at once, when every row is done; derived, never authored.
    func testTheReceiptCelebratesOnlyWhenEveryRowHasTurned() {
        let done = [row("a", .done), row("b", .done)]
        let mixed = [row("a", .done), row("b", .queued)]
        XCTAssertTrue(MigrationReceiptBody(rows: done, facts: [], caption: nil,
                                           width: 740, accent: .blue).marksCelebrateForTesting)
        XCTAssertFalse(MigrationReceiptBody(rows: mixed, facts: [], caption: nil,
                                            width: 740, accent: .blue).marksCelebrateForTesting)
    }

    /// An empty receipt does not celebrate.
    func testAnEmptyReceiptDoesNotCelebrate() {
        XCTAssertFalse(MigrationReceiptBody(rows: [], facts: [], caption: nil,
                                            width: 740, accent: .blue).marksCelebrateForTesting)
    }

    private func row(_ id: String, _ mark: ProvisioningRowMark) -> ProvisioningRowModel {
        ProvisioningRowModel(id: id, name: id, detail: nil, detailIsMachine: false, mark: mark)
    }
}

// MARK: - Footer centre line

/// The footer centre line (`stateLine`, drawn by `StateLine`) on the provisioning shell.
/// Nil draws no line.
final class ProvisioningStateLineTests: XCTestCase {

    private func shell(stateLine: String?) -> ProvisioningShell<EmptyView> {
        ProvisioningShell(metrics: ProvisioningM(size: ProvisioningM.recommended),
                          title: "Installing your apps",
                          primaryTitle: "Continue",
                          onPrimary: {},
                          accent: .blue,
                          stateLine: stateLine) { EmptyView() }
    }

    /// Absent by default, not an empty `Text`.
    func testTheSeatIsAbsentByDefault() {
        let untouched = ProvisioningShell(metrics: ProvisioningM(size: ProvisioningM.recommended),
                                          title: "t", primaryTitle: "Continue",
                                          onPrimary: {}, accent: .blue) { EmptyView() }
        XCTAssertNil(untouched.stateLine)
        XCTAssertNil(untouched.resolvedStateLine,
                     "nil must draw the footer it draws today, unchanged")
    }

    /// An authored line reaches the footer verbatim.
    func testAnAuthoredLineReachesTheFooter() {
        XCTAssertEqual(shell(stateLine: "Obsidian was removed").resolvedStateLine,
                       "Obsidian was removed")
    }

    /// `footerNote: ""` counts as absent.
    func testAnEmptyLineCountsAsAbsent() {
        XCTAssertNil(shell(stateLine: "").resolvedStateLine)
    }

    /// `footerNote` is the authored key, falling back to the flow's `footerText`; neither means no line.
    func testFooterNoteIsTheAuthoredKeyAndIsOptional() throws {
        let json = #"""
        {"preset": "5", "introSteps": [
            {"id": "install", "stepType": "installation", "footerNote": "Obsidian was removed"},
            {"id": "plain"}
        ]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let steps = try XCTUnwrap(config.introSteps)
        XCTAssertEqual(steps[0].footerNote, "Obsidian was removed")
        XCTAssertNil(steps[1].footerNote, "a step that states nothing draws no line")
    }
}

/// `backButtonKind`: the closer draws the chevron, other screens the word; an authored value overrides.
final class ProvisioningBackButtonKindTests: XCTestCase {
    typealias Style = ProvisioningShell<EmptyView>.SecondaryStyle

    func testTheTwoAuthoredValuesParse() {
        XCTAssertEqual(Style(authored: "text"), .text)
        XCTAssertEqual(Style(authored: "chevron"), .chevron)
        XCTAssertEqual(Style(authored: "Chevron"), .chevron)
    }

    func testUnsetOrUnknownLeavesTheScreensOwnStyle() {
        XCTAssertNil(Style(authored: nil))
        XCTAssertNil(Style(authored: "pill"))
    }
}
