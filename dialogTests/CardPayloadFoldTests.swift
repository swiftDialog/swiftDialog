//
//  CardPayloadFoldTests.swift
//  dialogTests
//
//  Covers CardStepBlocks.foldMedia / foldGrid (step-level mediaItems and gridItems become trailing
//  blocks on card chrome) and the CardRecapModel arithmetic.
//

import XCTest
@testable import Dialog

final class CardPayloadFoldTests: XCTestCase {

    private func block(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    /// GridItemConfig has no usable memberwise init; decoding is how one is built.
    private func gridItem(_ json: String) throws -> InspectConfig.GridItemConfig {
        try JSONDecoder().decode(InspectConfig.GridItemConfig.self, from: Data(json.utf8))
    }

    private func mediaItem(_ url: String) -> InspectConfig.MediaItemConfig {
        InspectConfig.MediaItemConfig(url: url, caption: nil, title: nil)
    }

    // MARK: - media

    func testStepMediaItemsBecomeAMediaCarouselBlock() throws {
        let blocks = CardStepBlocks.foldMedia(content: [], items: [mediaItem("a.png")],
                                              height: 320, autoplay: false,
                                              showArrows: false, showDots: false, fit: "fill")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, "media-carousel")
        XCTAssertEqual(blocks[0].mediaItems?.compactMap(\.url), ["a.png"])
        XCTAssertEqual(blocks[0].mediaHeight, 320)
        XCTAssertEqual(blocks[0].mediaAutoplay, false)
        XCTAssertEqual(blocks[0].mediaShowArrows, false)
        XCTAssertEqual(blocks[0].mediaShowDots, false)
        XCTAssertEqual(blocks[0].mediaFit, "fill")
    }

    func testTheItemsKeepTheirCaptionsAndTitles() throws {
        let item = InspectConfig.MediaItemConfig(url: "a.png", caption: "Step one", title: "Enrol")
        let blocks = CardStepBlocks.foldMedia(content: [], items: [item], height: nil,
                                              autoplay: nil, showArrows: nil, showDots: nil,
                                              fit: nil)
        XCTAssertEqual(blocks[0].mediaItems?.first?.caption, "Step one")
        XCTAssertEqual(blocks[0].mediaItems?.first?.title, "Enrol")
    }

    /// Media trails the content (unlike the stats fold, which leads).
    func testTheCarouselFollowsTheAuthoredContent() throws {
        let prose = try block(#"{"type":"text","content":"hello"}"#)
        let blocks = CardStepBlocks.foldMedia(content: [prose], items: [mediaItem("a.png")],
                                              height: nil, autoplay: nil,
                                              showArrows: nil, showDots: nil, fit: nil)
        XCTAssertEqual(blocks.map(\.type), ["text", "media-carousel"])
    }

    /// Unauthored knobs stay nil so the block renderer's defaults remain the single source.
    func testUnauthoredMediaKnobsAreNotInvented() throws {
        let blocks = CardStepBlocks.foldMedia(content: [], items: [mediaItem("a.png")],
                                              height: nil, autoplay: nil,
                                              showArrows: nil, showDots: nil, fit: nil)
        XCTAssertNil(blocks[0].mediaHeight)
        XCTAssertNil(blocks[0].mediaAutoplay)
        XCTAssertNil(blocks[0].mediaShowArrows)
        XCTAssertNil(blocks[0].mediaShowDots)
        XCTAssertNil(blocks[0].mediaFit)
    }

    func testAnAuthoredCarouselBlockWinsOverTheStepKey() throws {
        let authored = try block(#"{"type":"media-carousel","mediaItems":[{"url":"authored.png"}]}"#)
        let blocks = CardStepBlocks.foldMedia(content: [authored], items: [mediaItem("step.png")],
                                              height: nil, autoplay: nil,
                                              showArrows: nil, showDots: nil, fit: nil)
        XCTAssertEqual(blocks.count, 1, "the authored block wins; no synthesized duplicate")
        XCTAssertEqual(blocks[0].mediaItems?.compactMap(\.url), ["authored.png"])
    }

    func testNoMediaChangesNothing() throws {
        let prose = try block(#"{"type":"text","content":"hello"}"#)
        XCTAssertEqual(CardStepBlocks.foldMedia(content: [prose], items: nil, height: nil,
                                                autoplay: nil, showArrows: nil, showDots: nil,
                                                fit: nil).count, 1)
        XCTAssertEqual(CardStepBlocks.foldMedia(content: [prose], items: [], height: nil,
                                                autoplay: nil, showArrows: nil, showDots: nil,
                                                fit: nil).count, 1)
    }

    // MARK: - grid

    func testStepGridItemsBecomeAGridPickerBlock() throws {
        let item = try gridItem(#"{"id":"g1","title":"One","sfSymbol":"star","value":"v1"}"#)
        let blocks = CardStepBlocks.foldGrid(content: [], items: [item], columns: 4,
                                             selectionMode: "multiple", selectionKey: "theme")
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].type, "grid-picker")
        XCTAssertEqual(blocks[0].gridItems?.map(\.id), ["g1"])
        XCTAssertEqual(blocks[0].gridItems?.first?.title, "One")
        XCTAssertEqual(blocks[0].gridItems?.first?.sfSymbol, "star")
        XCTAssertEqual(blocks[0].gridItems?.first?.value, "v1")
        XCTAssertEqual(blocks[0].gridColumns, 4)
        XCTAssertEqual(blocks[0].gridSelectionMode, "multiple")
        XCTAssertEqual(blocks[0].gridSelectionKey, "theme")
    }

    /// grid-picker matches selections by id, so the folded item must keep the resolved id.
    func testAnItemWithNoAuthoredIdKeepsTheIdentityItResolvesTo() throws {
        let item = try gridItem(#"{"title":"Only a title"}"#)
        let blocks = CardStepBlocks.foldGrid(content: [], items: [item], columns: nil,
                                             selectionMode: nil, selectionKey: nil)
        XCTAssertEqual(blocks[0].gridItems?.map(\.id), [item.id])
        XCTAssertEqual(item.id, "Only a title", "the documented fallback chain")
    }

    func testTheGridFollowsTheAuthoredContent() throws {
        let item = try gridItem(#"{"id":"g1","title":"One"}"#)
        let prose = try block(#"{"type":"text","content":"hello"}"#)
        let blocks = CardStepBlocks.foldGrid(content: [prose], items: [item], columns: nil,
                                             selectionMode: nil, selectionKey: nil)
        XCTAssertEqual(blocks.map(\.type), ["text", "grid-picker"])
    }

    func testUnauthoredGridKnobsAreNotInvented() throws {
        let item = try gridItem(#"{"id":"g1","title":"One"}"#)
        let blocks = CardStepBlocks.foldGrid(content: [], items: [item], columns: nil,
                                             selectionMode: nil, selectionKey: nil)
        XCTAssertNil(blocks[0].gridColumns)
        XCTAssertNil(blocks[0].gridSelectionMode)
        XCTAssertNil(blocks[0].gridSelectionKey)
    }

    func testAnAuthoredGridBlockWinsOverTheStepKey() throws {
        let item = try gridItem(#"{"id":"step","title":"S"}"#)
        let authored = try block(#"{"type":"grid-picker","gridItems":[{"id":"authored"}]}"#)
        let blocks = CardStepBlocks.foldGrid(content: [authored], items: [item], columns: nil,
                                             selectionMode: nil, selectionKey: nil)
        XCTAssertEqual(blocks.count, 1, "the authored block wins; no synthesized duplicate")
        XCTAssertEqual(blocks[0].gridItems?.map(\.id), ["authored"])
    }

    func testNoGridChangesNothing() throws {
        let prose = try block(#"{"type":"text","content":"hello"}"#)
        XCTAssertEqual(CardStepBlocks.foldGrid(content: [prose], items: nil, columns: nil,
                                               selectionMode: nil, selectionKey: nil).count, 1)
        XCTAssertEqual(CardStepBlocks.foldGrid(content: [prose], items: [], columns: nil,
                                               selectionMode: nil, selectionKey: nil).count, 1)
    }
}

/// The cadence recap arithmetic behind CardStepModel.recap.
final class CardRecapModelTests: XCTestCase {

    /// A timed-out entry advances the cursor but is not proven; the recap counts proven ones.
    func testTheRecapCountsProvenEntriesNotThePassedCursor() {
        XCTAssertEqual(CardRecapModel.satisfiedCount(total: 3, timedOut: [1]), 2)
        XCTAssertEqual(CardRecapModel.satisfiedCount(total: 3, timedOut: []), 3)
        XCTAssertEqual(CardRecapModel.satisfiedCount(total: 3, timedOut: [0, 1, 2]), 0)
    }

    func testMoreTimeoutsThanEntriesStillReadsZero() {
        XCTAssertEqual(CardRecapModel.satisfiedCount(total: 1, timedOut: [0, 1, 2]), 0)
    }

    /// The closing segment is a claim that nothing is still running; an unclean run drops it.
    func testTheClosingClaimSurvivesOnlyACleanRun() {
        XCTAssertEqual(CardRecapModel.segments(passed: "All 3 checks passed",
                                               duration: "12 seconds",
                                               closing: "nothing else to do", clean: true),
                       ["All 3 checks passed", "12 seconds", "nothing else to do"])
        XCTAssertEqual(CardRecapModel.segments(passed: "2 of 3 checks passed · 1 still finishing",
                                               duration: "12 seconds",
                                               closing: "nothing else to do", clean: false),
                       ["2 of 3 checks passed · 1 still finishing", "12 seconds"])
    }

    /// Segments drop independently; a missing or empty duration leaves no separator behind.
    func testAnUnmeasuredDurationDropsItsSegmentRatherThanEstimating() {
        XCTAssertEqual(CardRecapModel.segments(passed: "All 2 checks passed", duration: nil,
                                               closing: "nothing else to do", clean: true),
                       ["All 2 checks passed", "nothing else to do"])
        XCTAssertEqual(CardRecapModel.segments(passed: "All 2 checks passed", duration: "",
                                               closing: nil, clean: true),
                       ["All 2 checks passed"], "an empty string is not a segment")
    }
}
