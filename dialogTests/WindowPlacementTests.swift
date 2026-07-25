//
//  WindowPlacementTests.swift
//  dialogTests
//
//  Unit tests for windowPlacementFrame — the screen area a dialog is positioned
//  within (GitHub #630).
//
//  The dock inset is derived by differencing a screen's frame against its
//  visibleFrame, so these tests use rects rather than a real NSScreen. That also
//  covers displays offset within the virtual desktop, which cannot be exercised
//  on a single-display machine.
//
//  The bottom/left figures below are real measurements from a 1920x1080 display
//  (dock at the bottom reserved 55pt; moved to the left it reserved 51pt; the
//  menu bar reserved 30pt in both cases).
//

import XCTest
import AppKit
@testable import Dialog

final class WindowPlacementTests: XCTestCase {

    private let screen        = NSRect(x: 0, y: 0, width: 1920, height: 1080)
    private let dockAtBottom  = NSRect(x: 0, y: 55, width: 1920, height: 995)
    private let dockAtLeft    = NSRect(x: 51, y: 0, width: 1869, height: 1050)
    private let dockAtRight   = NSRect(x: 0, y: 0, width: 1869, height: 1050)

    private func placement(_ full: NSRect, _ visible: NSRect,
                           fullScreen: Bool = false, dock: Bool = false) -> NSRect {
        windowPlacementFrame(fullFrame: full, visibleFrame: visible,
                             useFullScreen: fullScreen, respectDock: dock)
    }

    // MARK: - Plain windows and --blurscreen keep their existing behaviour

    func testPlainWindowUsesVisibleFrame() {
        XCTAssertEqual(placement(screen, dockAtBottom), dockAtBottom)
        XCTAssertEqual(placement(screen, dockAtLeft), dockAtLeft)
    }

    /// --blurscreen draws an overlay above the dock, so the whole frame is available.
    func testFullScreenUsesWholeFrameAndOutranksRespectDock() {
        XCTAssertEqual(placement(screen, dockAtBottom, fullScreen: true), screen)
        // --blurscreen implies --ontop, so both flags arrive together: full frame must win.
        XCTAssertEqual(placement(screen, dockAtBottom, fullScreen: true, dock: true), screen)
    }

    // MARK: - --ontop reserves the dock but not the menu bar

    func testOnTopReservesDockAtBottomButNotMenuBar() {
        let result = placement(screen, dockAtBottom, dock: true)
        XCTAssertEqual(result.minY, 55, "bottom dock should be reserved")
        XCTAssertEqual(result.maxY, 1080, "menu bar must stay available — AppKit clamps it")
        XCTAssertEqual(result.minX, 0)
        XCTAssertEqual(result.width, 1920)
    }

    func testOnTopReservesDockAtLeft() {
        let result = placement(screen, dockAtLeft, dock: true)
        XCTAssertEqual(result.minX, 51, "left dock should be reserved")
        XCTAssertEqual(result.width, 1869)
        XCTAssertEqual(result.minY, 0, "no bottom dock, so no bottom inset")
        XCTAssertEqual(result.maxY, 1080)
    }

    func testOnTopReservesDockAtRight() {
        let result = placement(screen, dockAtRight, dock: true)
        XCTAssertEqual(result.minX, 0, "a right dock must not move the left edge")
        XCTAssertEqual(result.maxX, 1869, "right dock should be reserved")
        XCTAssertEqual(result.maxY, 1080)
    }

    /// An autohidden dock reserves only a few points, which should be given back.
    func testOnTopWithAutohiddenDockReclaimsSpace() {
        let autohidden = NSRect(x: 0, y: 4, width: 1920, height: 1046)
        let result = placement(screen, autohidden, dock: true)
        XCTAssertEqual(result.minY, 4)
        XCTAssertEqual(result.height, 1076, "only the reserved strip is lost, not a full dock")
    }

    /// A screen with neither dock nor menu bar is unchanged.
    func testOnTopWithNoDockIsWholeFrame() {
        XCTAssertEqual(placement(screen, screen, dock: true), screen)
    }

    // MARK: - Displays offset within the virtual desktop

    /// A display to the left of the primary has a negative origin. Insets must be
    /// applied relative to that origin, not to the virtual desktop's 0,0.
    func testOnTopOnDisplayWithNegativeOrigin() {
        let full = NSRect(x: -1920, y: 0, width: 1920, height: 1080)
        let visible = NSRect(x: -1869, y: 0, width: 1869, height: 1050)  // dock on its left edge
        let result = placement(full, visible, dock: true)
        XCTAssertEqual(result.minX, -1869, "inset is relative to this screen's own origin")
        XCTAssertEqual(result.width, 1869)
        XCTAssertEqual(result.maxY, 1080)
    }

    /// A display offset below and to the right of the primary.
    func testOnTopOnDisplayOffsetBelowAndRight() {
        let full = NSRect(x: 1920, y: -1080, width: 1920, height: 1080)
        let visible = NSRect(x: 1920, y: -1025, width: 1920, height: 1025)  // dock along its bottom
        let result = placement(full, visible, dock: true)
        XCTAssertEqual(result.minX, 1920)
        XCTAssertEqual(result.minY, -1025, "bottom inset applied from this screen's own origin")
        XCTAssertEqual(result.maxY, 0, "top edge stays at this screen's top")
    }

    /// The placement frame must never extend past the screen it belongs to.
    func testPlacementFrameStaysWithinItsScreen() {
        for visible in [dockAtBottom, dockAtLeft, dockAtRight] {
            let result = placement(screen, visible, dock: true)
            XCTAssertTrue(screen.contains(result), "\(result) escaped \(screen)")
        }
    }
}
