//
//  BentoFillTests.swift
//  dialogTests
//
//  The bento fill grid.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - Bento fills its band

/// `BentoFillGrid` sizes rows from the band it is given, so a third row never runs under the footer.
final class BentoFillTests: XCTestCase {
    private func cell(_ id: String, row: Int, rowSpan: Int? = nil) throws -> InspectConfig.GuidanceContent.BentoCellConfig {
        let json = """
        {"id": "\(id)", "contentType": "text", "column": 0, "row": \(row)\(rowSpan.map { ", \"rowSpan\": \($0)" } ?? "")}
        """
        return try JSONDecoder().decode(InspectConfig.GuidanceContent.BentoCellConfig.self,
                                         from: Data(json.utf8))
    }

    /// Three 1fr rows share the band: (availableHeight − 2×12) / 3.
    func testThreeRowsShareTheBandWithTwoGaps() {
        XCTAssertEqual(BentoFillM.rowHeight(available: 438, rows: 3, gap: 12), 138)
    }

    /// Rows plus gaps never exceed the band: 467 available with a 14 gap gives 146, not 180.
    func testTheGridNeverOverrunsItsBand() {
        for (available, rows, gap) in [(200.0, 3, 12.0), (467, 3, 14), (900, 3, 12), (364, 2, 14)] {
            let row = BentoFillM.rowHeight(available: available, rows: rows, gap: gap)
            XCTAssertLessThanOrEqual(row * CGFloat(rows) + gap * CGFloat(rows - 1), available)
        }
        XCTAssertEqual(BentoFillM.rowHeight(available: 467, rows: 3, gap: 14), 146)
    }

    /// The row count is the last row any cell reaches, spans included, and at least one.
    func testRowCountFollowsTheCells() {
        XCTAssertEqual(BentoFillM.rows([try cell("a", row: 0), try cell("b", row: 2)]), 3)
        XCTAssertEqual(BentoFillM.rows([try cell("a", row: 0, rowSpan: 2)]), 2)
        XCTAssertEqual(BentoFillM.rows([]), 1)
    }
}
