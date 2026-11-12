//
//  JourneyCardGridTests.swift
//  dialogTests
//
//  The journey rows as a card grid: the authored switch, artwork on the row, which window of rows
//  the grid shows, division pacing and card geometry. Rendering is verified on captured frames.
//

import XCTest
@testable import Dialog

final class JourneyCardGridTests: XCTestCase {

    private struct Item: MonitoredItem {
        let id: String
        let displayName: String
        var icon: String?
        var claim: String?
        var paths: [String] { [] }
        var plistKey: String? { nil }
        var expectedValue: String? { nil }
        var evaluation: String? { nil }
        var plistRecheckInterval: Int? { nil }
        var useUserDefaults: Bool? { nil }
        var jsonMonitors: [InspectConfig.JsonMonitor]? { nil }
        var requirements: [InspectConfig.ItemConfig.Requirement]? { nil }
        var satisfy: String? { nil }
        var showBundleInfo: String? { nil }
        var logAliases: [String]? { nil }
    }

    private func row(_ id: String, _ mark: ProvisioningRowMark) -> ProvisioningRowModel {
        ProvisioningRowModel(id: id, name: id, mark: mark)
    }

    // MARK: - Authored switch

    /// Only `layout: "grid"` selects the grid; the checklist stays the default.
    func testOnlyGridSelectsTheGrid() {
        XCTAssertTrue(JourneyLayout.isGrid("grid"))
        XCTAssertTrue(JourneyLayout.isGrid(" Grid "))
        XCTAssertFalse(JourneyLayout.isGrid(nil))
        XCTAssertFalse(JourneyLayout.isGrid(""))
        XCTAssertFalse(JourneyLayout.isGrid("centered"))
        XCTAssertFalse(JourneyLayout.isGrid("cards"))
    }

    // MARK: - Artwork reaches the row

    /// The item's authored icon reaches the row untouched; no icon yields nil.
    func testTheAuthoredIconReachesTheRow() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "figma", displayName: "Figma", icon: "/x/figma.png"),
                    Item(id: "slack", displayName: "Slack", icon: nil)],
            statuses: [.pending, .completed],
            vocabulary: .packages)
        XCTAssertEqual(rows[0].art, "/x/figma.png")
        XCTAssertNil(rows[1].art)
        // Nothing else about the row moved.
        XCTAssertEqual(rows[0].mark, .queued)
        XCTAssertEqual(rows[1].mark, .done)
    }

    // MARK: - Visible window

    /// Four or fewer rows: all shown, in order.
    func testFourOrFewerRowsAreAllShown() {
        let rows = ["a", "b", "c", "d"].map { row($0, .queued) }
        XCTAssertEqual(JourneyScroll.window(rows: rows, size: 4).map(\.id), ["a", "b", "c", "d"])
        XCTAssertEqual(JourneyScroll.window(rows: Array(rows.prefix(2)), size: 4).map(\.id), ["a", "b"])
    }

    /// More than four: the window slides, the active card holding the third slot (`JourneyGridM.anchorSlot`)
    /// until the end clamps.
    func testTheWindowSlidesSoTheActiveCardSitsInTheLastSlot() {
        func rows(active: Int) -> [ProvisioningRowModel] {
            (0..<8).map { i in row("r\(i)", i < active ? .done : (i == active ? .active : .queued)) }
        }
        XCTAssertEqual(JourneyScroll.window(rows: rows(active: 0), size: 4).map(\.id), ["r0", "r1", "r2", "r3"])
        XCTAssertEqual(JourneyScroll.window(rows: rows(active: 2), size: 4).map(\.id), ["r0", "r1", "r2", "r3"])
        XCTAssertEqual(JourneyScroll.window(rows: rows(active: 3), size: 4).map(\.id), ["r1", "r2", "r3", "r4"])
        XCTAssertEqual(JourneyScroll.window(rows: rows(active: 4), size: 4).map(\.id), ["r2", "r3", "r4", "r5"])
        XCTAssertEqual(JourneyScroll.window(rows: rows(active: 5), size: 4).map(\.id), ["r3", "r4", "r5", "r6"])
        XCTAssertEqual(JourneyScroll.window(rows: rows(active: 7), size: 4).map(\.id), ["r4", "r5", "r6", "r7"])
    }

    /// With no active card between steps, the window holds at the last finished card.
    func testTheWindowHoldsAtTheFrontierWhenNoCardIsActive() {
        var rows = (0..<8).map { row("r\($0)", .queued) }
        for i in 0..<5 { rows[i] = row("r\(i)", .done) }
        XCTAssertEqual(JourneyScroll.window(rows: rows, size: 4).map(\.id), ["r2", "r3", "r4", "r5"])
        rows[5] = row("r5", .active)
        XCTAssertEqual(JourneyScroll.window(rows: rows, size: 4).map(\.id), ["r3", "r4", "r5", "r6"])
        rows[5] = row("r5", .done)
        XCTAssertEqual(JourneyScroll.window(rows: rows, size: 4).map(\.id), ["r3", "r4", "r5", "r6"])
    }

    /// Before anything moves: the first four. All terminal: the last four.
    func testFirstFourBeforeAnythingMovesAndLastFourWhenAllTerminal() {
        let queued = ["a", "b", "c", "d", "e", "f"].map { row($0, .queued) }
        XCTAssertEqual(JourneyScroll.window(rows: queued, size: 4).map(\.id), ["a", "b", "c", "d"])
        let done = ["a", "b", "c", "d", "e", "f"].map { row($0, .done) }
        XCTAssertEqual(JourneyScroll.window(rows: done, size: 4).map(\.id), ["c", "d", "e", "f"])
    }

    // MARK: - State words

    /// `stateWords` merges over the package vocabulary: present keys replace, absent or blank keep.
    func testStateWordsMergeOverThePackageVocabulary() {
        let v = ProvisioningVocabulary.packages.merged(with: ["done": "Processed", "queued": "  ", "nonsense": "x"])
        XCTAssertEqual(v.done, "Processed")
        XCTAssertEqual(v.active, "Installing")
        XCTAssertEqual(v.queued, "Queued")
        XCTAssertEqual(v.removed, "Removed")
        XCTAssertEqual(ProvisioningVocabulary.packages.merged(with: nil).done, "Installed")
        XCTAssertEqual(ProvisioningVocabulary.packages.merged(with: [:]).done, "Installed")
        // The author's done word reaches a completed row.
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "a", displayName: "A", icon: nil)], statuses: [.completed], vocabulary: v)
        guard case .state(let word, _) = rows[0].trailing else { return XCTFail("expected a state") }
        XCTAssertEqual(word, "Processed")
    }

    /// `stateWords` decodes on a step and is a known key.
    func testStateWordsDecodesAndIsAKnownStepKey() throws {
        InspectConfig.unknownKeyWarnings = []
        let json = #"""
        {"preset": "5", "chrome": "setup-assistant",
         "introSteps": [{"id": "deploy", "stepType": "carousel", "title": "T", "layout": "grid",
                         "stateWords": {"done": "Processed"},
                         "items": [{"id": "a", "displayName": "A"}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.introSteps?.first?.stateWords?["done"], "Processed")
        XCTAssertEqual(config.introSteps?.first?.layout, "grid")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("stateWords") }, [],
                       "a new step key must be registered or every load logs a false warning")
    }

    /// A zero or negative page size shows everything.
    func testAZeroOrNegativePageShowsEverything() {
        let rows = ["a", "b", "c", "d", "e"].map { row($0, .queued) }
        XCTAssertEqual(JourneyScroll.window(rows: rows, size: 0).count, 5)
        XCTAssertEqual(JourneyScroll.window(rows: rows, size: -1).count, 5)
    }

    // MARK: - Claim

    /// The card shows the claim until it finishes, then the state word; a notice outranks the claim.
    func testTheClaimIsTheLineUntilTheCardFinishes() {
        let rows = ProvisioningRowBuilder.itemRows(
            items: [Item(id: "a", displayName: "Welcome Kit", icon: nil, claim: "Walk-around inspection…"),
                    Item(id: "b", displayName: "Backgrounds", icon: nil, claim: "Walk-around inspection…"),
                    Item(id: "c", displayName: "Company Portal", icon: nil, claim: nil)],
            statuses: [.pending, .completed, .pending],
            vocabulary: .packages)
        XCTAssertEqual(rows[0].claim, "Walk-around inspection…")
        XCTAssertEqual(JourneyCardTile.secondLine(for: rows[0]), "Walk-around inspection…")
        XCTAssertEqual(JourneyCardTile.secondLine(for: rows[1]), "Installed")
        XCTAssertEqual(JourneyCardTile.secondLine(for: rows[2]), "Queued")

        var active = rows[0]; active.mark = .active
        XCTAssertEqual(JourneyCardTile.secondLine(for: active), "Walk-around inspection…")
        var failed = rows[0]; failed.mark = .failed; failed.trailing = .state("Not found", failed: true)
        XCTAssertEqual(JourneyCardTile.secondLine(for: failed), "Not found")
        var removed = rows[0]; removed.trailing = .notice("Removed")
        XCTAssertEqual(JourneyCardTile.secondLine(for: removed), "Removed")
        var blank = rows[0]; blank.claim = "   "
        XCTAssertEqual(JourneyCardTile.secondLine(for: blank), "Queued")
    }

    // MARK: - Division mode

    /// Fractional shares: 20 items over 8 cards end at ceil((k+1) × 20 / 8), the last on the last item.
    func testFractionalSharesEightCardsOverTwentyItems() {
        XCTAssertEqual(JourneyPacing.boundaries(cards: 8, total: 20, wholeShares: false),
                       [3, 5, 8, 10, 13, 15, 18, 20])
        XCTAssertEqual(JourneyPacing.boundaries(cards: 5, total: 20, wholeShares: false),
                       [4, 8, 12, 16, 20])
        XCTAssertEqual(JourneyPacing.boundaries(cards: 8, total: 3, wholeShares: false),
                       [1, 1, 2, 2, 2, 3, 3, 3], "fewer items than cards: cards share a boundary")
        XCTAssertEqual(JourneyPacing.boundaries(cards: 8, total: 0, wholeShares: false),
                       Array(repeating: 0, count: 8))
        XCTAssertEqual(JourneyPacing.boundaries(cards: 0, total: 20, wholeShares: false), [])
    }

    /// Whole shares: 23 items over 8 cards end at 16; items 17–23 are a final stretch that holds the primary.
    func testWholeSharesLeaveAFinalStretch() {
        let b = JourneyPacing.boundaries(cards: 8, total: 23, wholeShares: true)
        XCTAssertEqual(b, [2, 4, 6, 8, 10, 12, 14, 16])
        XCTAssertFalse(JourneyPacing.inFinalStretch(completed: 15, total: 23, boundaries: b))
        XCTAssertTrue(JourneyPacing.inFinalStretch(completed: 16, total: 23, boundaries: b))
        XCTAssertTrue(JourneyPacing.inFinalStretch(completed: 22, total: 23, boundaries: b))
        XCTAssertFalse(JourneyPacing.inFinalStretch(completed: 23, total: 23, boundaries: b))
        // Fewer items than cards falls back to fractional shares.
        XCTAssertEqual(JourneyPacing.boundaries(cards: 8, total: 3, wholeShares: true),
                       JourneyPacing.boundaries(cards: 8, total: 3, wholeShares: false))
    }

    /// Done past the boundary, the frontier card active once anything moved, the rest queued.
    func testMarksWalkTheCards() {
        let b = JourneyPacing.boundaries(cards: 8, total: 20, wholeShares: false)   // 3,5,8,…
        XCTAssertEqual(JourneyPacing.marks(completed: 0, total: 20, anyActive: false, boundaries: b),
                       [.queued, .queued, .queued, .queued, .queued, .queued, .queued, .queued])
        XCTAssertEqual(JourneyPacing.marks(completed: 0, total: 20, anyActive: true, boundaries: b).first, .active)
        XCTAssertEqual(JourneyPacing.marks(completed: 2, total: 20, anyActive: false, boundaries: b),
                       [.active, .queued, .queued, .queued, .queued, .queued, .queued, .queued])
        XCTAssertEqual(JourneyPacing.marks(completed: 3, total: 20, anyActive: false, boundaries: b),
                       [.done, .active, .queued, .queued, .queued, .queued, .queued, .queued])
        XCTAssertEqual(JourneyPacing.marks(completed: 13, total: 20, anyActive: false, boundaries: b),
                       [.done, .done, .done, .done, .done, .active, .queued, .queued])
        XCTAssertEqual(JourneyPacing.marks(completed: 20, total: 20, anyActive: false, boundaries: b),
                       Array(repeating: .done, count: 8))
        XCTAssertEqual(JourneyPacing.marks(completed: 0, total: 0, anyActive: true, boundaries: b),
                       Array(repeating: .queued, count: 8), "an empty manifest claims nothing")
        let w = JourneyPacing.boundaries(cards: 8, total: 23, wholeShares: true)      // …,16
        XCTAssertEqual(JourneyPacing.marks(completed: 19, total: 23, anyActive: false, boundaries: w).last, .active,
                       "final stretch: the last card stays active")
        XCTAssertEqual(JourneyPacing.marks(completed: 23, total: 23, anyActive: false, boundaries: w).last, .done)
    }

    /// Division rows: message as name, icon as art, final message on the last card in the final stretch.
    func testDivisionRowsAndResolver() throws {
        let json = #"""
        {"preset": "5", "chrome": "setup-assistant",
         "introSteps": [{"id": "deploy", "stepType": "carousel", "layout": "grid", "divisionMode": true,
                         "finalMessage": "Final checks…", "title": "T",
                         "cadence": [{"id": "client", "message": "Connecting to ground power…", "imagePath": "/x/a.png", "attribute": {"source": "ipc"}},
                                     {"id": "santa",  "message": "Marshalling the apron…",     "imagePath": "/x/b.png", "attribute": {"source": "ipc"}}],
                         "items": [{"id": "p", "displayName": "P"}]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let step = try XCTUnwrap(config.introSteps?.first)
        XCTAssertEqual(step.divisionMode, true)
        XCTAssertEqual(step.finalMessage, "Final checks…")
        // Five rows, three done: 2 cards, boundaries 2 and 4, final stretch at 4.
        var rows = (0..<5).map { ProvisioningRowModel(id: "r\($0)", name: "r\($0)", mark: .done) }
        rows[3].mark = .active; rows[4].mark = .queued
        let r = try XCTUnwrap(JourneyDivision.resolve(step: step, rows: rows, vocabulary: .packages.merged(with: ["done": "Processed"])))
        XCTAssertEqual(r.total, 5); XCTAssertEqual(r.completed, 3)
        XCTAssertEqual(r.cardRows.map(\.name), ["Connecting to ground power…", "Marshalling the apron…"])
        XCTAssertEqual(r.cardRows.map(\.art), ["/x/a.png", "/x/b.png"])
        XCTAssertEqual(r.cardRows.map(\.mark), [.done, .active])
        guard case .state(let w0, _) = r.cardRows[0].trailing else { return XCTFail("first row should trail a state word") }
        XCTAssertEqual(w0, "Processed")
        XCTAssertTrue(r.primaryDisabled, "a final message keeps the door shut until every item is processed")
        // Final stretch: the last card carries the final message.
        rows[3].mark = .done
        let f = try XCTUnwrap(JourneyDivision.resolve(step: step, rows: rows, vocabulary: .packages))
        XCTAssertEqual(f.cardRows.last?.mark, .active)
        XCTAssertEqual(f.cardRows.last?.claim, "Final checks…")
        XCTAssertTrue(f.primaryDisabled)
        rows[4].mark = .done
        let d = try XCTUnwrap(JourneyDivision.resolve(step: step, rows: rows, vocabulary: .packages))
        XCTAssertEqual(d.cardRows.map(\.mark), [.done, .done]); XCTAssertFalse(d.primaryDisabled)
        // Not division mode: no rows.
        let plain = try JSONDecoder().decode(InspectConfig.self, from: Data(json.replacingOccurrences(of: "\"divisionMode\": true", with: "\"divisionMode\": false").utf8))
        XCTAssertNil(JourneyDivision.resolve(step: try XCTUnwrap(plain.introSteps?.first), rows: rows, vocabulary: .packages))
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("divisionMode") || $0.contains("finalMessage") }, [])
    }

    /// `holdPrimary`: "disabled" holds while items remain, "none" releases, absent follows the final message.
    func testHoldPrimaryIsItsOwnSwitch() throws {
        func step(_ extra: String) throws -> InspectConfig.IntroStep {
            let json = #"{"preset":"5","introSteps":[{"id":"d","stepType":"carousel","divisionMode":true,"cadence":[{"id":"a","message":"A","attribute":{"source":"ipc"}}],"items":[{"id":"p","displayName":"P"}]"# + extra + "}]}"
            return try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8)).introSteps?.first)
        }
        let rows = [ProvisioningRowModel(id: "r0", name: "r0", mark: .done), ProvisioningRowModel(id: "r1", name: "r1", mark: .queued)]
        XCTAssertTrue(try XCTUnwrap(JourneyDivision.resolve(step: step(#","holdPrimary":"disabled""#), rows: rows, vocabulary: .packages)).primaryDisabled)
        XCTAssertFalse(try XCTUnwrap(JourneyDivision.resolve(step: step(#","finalMessage":"F","holdPrimary":"none""#), rows: rows, vocabulary: .packages)).primaryDisabled)
        XCTAssertTrue(try XCTUnwrap(JourneyDivision.resolve(step: step(#","finalMessage":"F""#), rows: rows, vocabulary: .packages)).primaryDisabled)
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("holdPrimary") }, [])
    }

    /// `holdPrimary: "hidden"` hides the primary while items remain and shows it enabled at the end.
    func testHoldPrimaryHiddenIsARealHiddenState() throws {
        func step(_ extra: String) throws -> InspectConfig.IntroStep {
            let json = #"{"preset":"5","introSteps":[{"id":"d","stepType":"carousel","divisionMode":true,"cadence":[{"id":"a","message":"A","attribute":{"source":"ipc"}}],"items":[{"id":"p","displayName":"P"}]"# + extra + "}]}"
            return try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8)).introSteps?.first)
        }
        let open = [ProvisioningRowModel(id: "r0", name: "r0", mark: .done), ProvisioningRowModel(id: "r1", name: "r1", mark: .queued)]
        let closed = [ProvisioningRowModel(id: "r0", name: "r0", mark: .done), ProvisioningRowModel(id: "r1", name: "r1", mark: .done)]
        let held = try XCTUnwrap(JourneyDivision.resolve(step: step(#","holdPrimary":"hidden""#), rows: open, vocabulary: .packages))
        XCTAssertTrue(held.primaryHidden); XCTAssertFalse(held.primaryDisabled, "hidden is not also disabled")
        let released = try XCTUnwrap(JourneyDivision.resolve(step: step(#","holdPrimary":"hidden""#), rows: closed, vocabulary: .packages))
        XCTAssertFalse(released.primaryHidden); XCTAssertFalse(released.primaryDisabled)
        XCTAssertFalse(try XCTUnwrap(JourneyDivision.resolve(step: step(#","holdPrimary":"disabled""#), rows: open, vocabulary: .packages)).primaryHidden)
        XCTAssertFalse(try XCTUnwrap(JourneyDivision.resolve(step: step(#","holdPrimary":"none""#), rows: open, vocabulary: .packages)).primaryHidden)
    }

    // MARK: - Five columns

    /// Five columns shrink the tile to 127.2 in the 700-wide capsule; five cards never slide.
    func testFiveColumnsShrinkTheTileAndNeverSlide() {
        XCTAssertEqual(JourneyGridM.tileSide(width: 700), 163, accuracy: 0.01)
        XCTAssertEqual(JourneyGridM.tileSide(width: 700, columns: 5), 127.2, accuracy: 0.01)
        let five = (0..<5).map { ProvisioningRowModel(id: "r\($0)", name: "r\($0)", mark: $0 == 4 ? .active : .done) }
        XCTAssertEqual(JourneyScroll.window(rows: five, size: 5).map(\.id), five.map(\.id))
        XCTAssertEqual(JourneyScroll.window(rows: five, size: 4).count, 4, "four columns still page")
    }

    // MARK: - Glass card

    /// Five glass cards span rail to rail at 133.6; only `glass` selects them.
    func testTheGlassRowIsRailToRailAndOnlyGlassSelectsIt() {
        XCTAssertEqual(JourneyGlassM.column, 724, "ONB7: 48 leading / 48 trailing")
        XCTAssertEqual(JourneyGlassM.cardWidth(width: JourneyGlassM.column, columns: 5), 133.6, accuracy: 0.01)
        XCTAssertEqual(JourneyGlassM.cardWidth(width: JourneyGlassM.column, columns: 4), 170.5, accuracy: 0.01)
        XCTAssertEqual(JourneyGridStyle.resolve("glass"), .glass)
        XCTAssertEqual(JourneyGridStyle.resolve(" Glass "), .glass)
        XCTAssertEqual(JourneyGridStyle.resolve(nil), .tile)
        XCTAssertEqual(JourneyGridStyle.resolve("tile"), .tile)
        // The section's positions, pinned: header 48 · row 207.
        XCTAssertEqual(JourneyGlassM.headerTop, 48); XCTAssertEqual(JourneyGlassM.rowTop, 207)
        // Gaps below the card, not positions, since the card height varies.
        XCTAssertEqual(JourneyGlassM.trackGap, 24); XCTAssertEqual(JourneyGlassM.supportGap, 24)
        XCTAssertEqual(JourneyGlassM.trackHeight, 6, "the canvas's 3, doubled on the first frame")
    }

    /// The name seat is three lines on every card under a 148 floor, so sliding never changes the height.
    func testTheNameSeatIsThreeLinesUnderAOneFortyEightFloor() {
        let w = JourneyGlassM.cardWidth(width: JourneyGlassM.column, columns: 5)   // 133.6
        let shipped = "Checking the emergency equipment"
        let retired = "Checking the emergency equipment in the cockpit"
        let short = "Loading the baggage"
        XCTAssertEqual(JourneyGlassM.nameSeat, 3)
        XCTAssertEqual(JourneyGlassM.minHeight, 148, "ONB7's card")
        XCTAssertEqual(JourneyGlassM.lines(for: shipped, cardWidth: w), 3, "the deck's longest label fits the seat")
        XCTAssertEqual(JourneyGlassM.lines(for: retired, cardWidth: w), 4, "the wording that did not, and why it changed")
        XCTAssertLessThanOrEqual(JourneyGlassM.lines(for: short, cardWidth: w), 3)
        // Content alone is 139.8; the 148 floor sets the height.
        let content = JourneyGlassM.padTop + JourneyGlassM.glyph + JourneyGlassM.innerGap
            + JourneyGlassM.nameSize * JourneyGlassM.nameLineHeight * CGFloat(JourneyGlassM.nameSeat)
            + JourneyGlassM.innerGap + JourneyGlassM.statusSize + JourneyGlassM.padBottom
        XCTAssertLessThan(content, JourneyGlassM.minHeight, "the floor, not the content, sets the height")
    }

    /// The name wraps rather than shrinking; the glyph stays 36.
    func testTheGlassCardWrapsItsNameInsteadOfShrinkingIt() {
        XCTAssertEqual(JourneyGlassM.glyph, 36, "ONB7's larger-proportion pass")
        XCTAssertEqual(JourneyGlassM.nameMaxLines, 4, "the ceiling: a four-line label still wraps, never truncates")
    }

    /// Each card reports its own share's progress (20 items, 5 cards, 9 done: 1, 1, 1/4, 0, 0).
    func testEachCardCarriesItsShareProgress() throws {
        let json = #"{"preset":"5","introSteps":[{"id":"d","stepType":"carousel","divisionMode":true,"cadence":[{"id":"a","message":"A","attribute":{"source":"ipc"}},{"id":"b","message":"B","attribute":{"source":"ipc"}},{"id":"c","message":"C","attribute":{"source":"ipc"}},{"id":"d","message":"D","attribute":{"source":"ipc"}},{"id":"e","message":"E","attribute":{"source":"ipc"}}],"items":[{"id":"p","displayName":"P"}]}]}"#
        let step = try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8)).introSteps?.first)
        let rows = (0..<20).map { ProvisioningRowModel(id: "r\($0)", name: "r\($0)", mark: $0 < 9 ? .done : ($0 == 9 ? .active : .queued)) }
        let d = try XCTUnwrap(JourneyDivision.resolve(step: step, rows: rows, vocabulary: .packages))
        XCTAssertEqual(d.cardRows.map { $0.share ?? -1 }, [1, 1, 0.25, 0, 0])
        XCTAssertEqual(d.cardRows.map(\.mark), [.done, .done, .active, .queued, .queued])
    }

    // MARK: - Geometry

    /// At 820 wide: column 740, capsule inner 700, four 163 tiles; two items keep that tile size.
    func testTileSideAtTheRecommendedWidth() {
        let inner = SetupAssistantM.column - SetupAssistantM.capsulePadH * 2
        XCTAssertEqual(inner, 700, accuracy: 0.01)
        XCTAssertEqual(JourneyGridM.tileSide(width: inner), 163, accuracy: 0.01)
    }

    /// Under a height cap the tile shrinks and the text block never does.
    func testTheTileShrinksToAHeightCapAndTheTextNeverDoes() {
        let text = JourneyGridM.textBlockHeight
        XCTAssertEqual(text, 13 * 1.2 + 16 + 8 + 14 * 1.2 * 2 + 8 + 12.5 * 1.2 * 3, accuracy: 0.01)
        XCTAssertEqual(JourneyGridM.tileSide(width: 700, maxHeight: nil), 163, accuracy: 0.01)
        XCTAssertEqual(JourneyGridM.tileSide(width: 700, maxHeight: 240), 240 - text, accuracy: 0.01)
        XCTAssertEqual(JourneyGridM.tileSide(width: 700, maxHeight: 1000), 163, accuracy: 0.01)
        XCTAssertEqual(JourneyGridM.tileSide(width: 700, maxHeight: 50), JourneyGridM.minTileSide, accuracy: 0.01)
        // The tile at the recommended provisioning window.
        let metrics = ProvisioningM(size: ProvisioningM.recommended)
        let cap = metrics.listRegionHeight - JourneyGridM.capsulePadV * 2
        let side = JourneyGridM.tileSide(width: metrics.column - JourneyGridM.capsulePadH * 2, maxHeight: cap)
        XCTAssertLessThan(side, 163)
        XCTAssertLessThanOrEqual(side + text, cap, "the grid must end above the status band")
    }
}
