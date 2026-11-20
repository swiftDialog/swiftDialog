//
//  BentoDetailRouteTests.swift
//  dialogTests
//
//  A bento cell's `detailPresentation` wins; the grid's inline setting answers only for cells
//  that state none. Covers BentoDetailRoute.resolve.
//

import XCTest
@testable import Dialog

final class BentoDetailRouteTests: XCTestCase {

    private func route(_ presentation: String?, gridInline: Bool = false,
                       hasOverlay: Bool = true) -> BentoDetailRoute {
        BentoDetailRoute.resolve(presentation: presentation, gridInline: gridInline, hasOverlay: hasOverlay)
    }

    func testEachAuthoredValueReachesItsContainer() {
        XCTAssertEqual(route("sheet"), .sheet)
        XCTAssertEqual(route("popover"), .popover)
        XCTAssertEqual(route("inline"), .inline)
        XCTAssertEqual(route("Inline"), .inline)
    }

    func testTheCellsChoiceWinsOverTheGrid() {
        XCTAssertEqual(route("sheet", gridInline: true), .sheet)
        XCTAssertEqual(route("popover", gridInline: true), .popover)
    }

    func testUnstatedFollowsTheGrid() {
        XCTAssertEqual(route(nil, gridInline: true), .inline)
        XCTAssertEqual(route(nil, gridInline: false), .sheet)
        XCTAssertEqual(route("unknown", gridInline: false), .sheet)
    }

    func testACellWithoutAnOverlayAlwaysOpensTheSheet() {
        XCTAssertEqual(route("popover", hasOverlay: false), .sheet)
        XCTAssertEqual(route("inline", gridInline: true, hasOverlay: false), .sheet)
    }
}
