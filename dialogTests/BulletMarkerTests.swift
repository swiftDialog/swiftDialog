//
//  BulletMarkerTests.swift
//  dialogTests
//
//  Which marker a bullet row draws (numbered beats icon beats bullet) and how wide its column
//  is. One column for every marker keeps the text edge still across lists.
//

import XCTest
import SwiftUI
@testable import Dialog

final class BulletMarkerTests: XCTestCase {

    // MARK: - Precedence

    func testNumberedWinsOverAnAuthoredIcon() {
        XCTAssertEqual(BulletMarker.resolve(numbered: true, icon: "checkmark.circle.fill", index: 0),
                       .numbered(1),
                       "an ordered list is ordered even if the config also names an icon")
    }

    func testAnAuthoredIconIsUsedWhenTheListIsNotNumbered() {
        XCTAssertEqual(BulletMarker.resolve(numbered: false, icon: "checkmark.circle.fill", index: 3),
                       .icon("checkmark.circle.fill"))
    }

    func testWithNeitherTheListTakesThePlainBullet() {
        XCTAssertEqual(BulletMarker.resolve(numbered: false, icon: nil, index: 0), .bullet)
    }

    /// An empty icon string is schema-legal and must not render an invisible marker.
    func testAnEmptyIconStringFallsBackToTheBullet() {
        XCTAssertEqual(BulletMarker.resolve(numbered: false, icon: "", index: 0), .bullet)
    }

    /// The numeral is 1-based from the row's position.
    func testTheNumeralIsOneBased() {
        XCTAssertEqual(BulletMarker.resolve(numbered: true, icon: nil, index: 0), .numbered(1))
        XCTAssertEqual(BulletMarker.resolve(numbered: true, icon: nil, index: 4), .numbered(5))
    }

    // MARK: - The column

    func testTheColumnIsOneWidthForEveryMarker() {
        let w = BulletMarker.columnWidth(scaleFactor: 1)
        XCTAssertGreaterThan(w, 0)
        XCTAssertEqual(BulletMarker.columnWidth(scaleFactor: 1), w)
    }

    func testTheColumnScalesWithTheTypeRamp() {
        // The column holds a glyph, so it is a type-axis measure.
        XCTAssertEqual(BulletMarker.columnWidth(scaleFactor: 2),
                       BulletMarker.columnWidth(scaleFactor: 1) * 2)
    }

    /// Wide enough for "10." without pushing its text right.
    func testTheColumnFitsATwoDigitNumeral() {
        XCTAssertGreaterThanOrEqual(BulletMarker.columnWidth(scaleFactor: 1), 18)
    }
}
