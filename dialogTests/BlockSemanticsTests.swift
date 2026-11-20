//
//  BlockSemanticsTests.swift
//  dialogTests
//
//  Which mark and tint each block status earns, as a truth table, and where callers adopt it.
//

import XCTest
import SwiftUI
@testable import Dialog

/// Distinct hues per slot, so a mis-mapped role fails instead of matching by coincidence.
extension ResolvedPalette {
    static let fixture = ResolvedPalette(
        primary: .purple,
        secondary: .gray,
        accent: .blue,
        success: .green,
        warning: .orange,
        error: .red,
        info: .cyan
    )
}

final class BlockSemanticsTests: XCTestCase {

    /// A pass earns no mark and no tint, so it never puts a second hue beside the accent.
    func testPassEarnsNoMarkAndNoTint() {
        XCTAssertNil(BlockSemantics.mark(for: .pass),
                     "the value beside the row already says it passed")
        XCTAssertNil(BlockSemantics.tint(for: .pass, palette: .fixture),
                     "a pass is not severity")
    }

    /// A disabled feature is a legitimate state, not an error: no xmark, no tint.
    func testDisabledAndInactiveEarnNoErrorMark() {
        for state in [BlockSemantics.State.disabled, .inactive] {
            let mark = BlockSemantics.mark(for: state)
            XCTAssertNotEqual(mark, "xmark.circle.fill",
                              "\(state) is legitimate, not an error")
            XCTAssertNil(BlockSemantics.tint(for: state, palette: .fixture))
        }
    }

    /// Genuine severity keeps its mark and its colour — the rules remove decoration only.
    func testFailKeepsItsMarkAndErrorTint() {
        XCTAssertNotNil(BlockSemantics.mark(for: .fail))
        XCTAssertEqual(BlockSemantics.tint(for: .fail, palette: .fixture), ResolvedPalette.fixture.error)
    }

    /// The active phase is accent, not warning: it is going fine.
    func testActivePhaseIsAccentNotWarning() {
        let tint = BlockSemantics.tint(for: .active, palette: .fixture)
        XCTAssertNotEqual(tint, ResolvedPalette.fixture.warning,
                          "a phase in progress is not a warning")
    }

    func testWarningEarnsNoTriangle() {
        XCTAssertNotEqual(BlockSemantics.mark(for: .warning), "exclamationmark.triangle.fill",
                          "a deadline is a quantity, never an alert glyph")
    }

    /// What each of the seven states earns, including `pending`.
    func testTruthTablePinned() {
        let palette = ResolvedPalette.fixture

        XCTAssertNil(BlockSemantics.mark(for: .pass))
        XCTAssertNil(BlockSemantics.tint(for: .pass, palette: palette))

        XCTAssertEqual(BlockSemantics.mark(for: .fail), "xmark.circle.fill")
        XCTAssertEqual(BlockSemantics.tint(for: .fail, palette: palette), palette.error)

        XCTAssertNil(BlockSemantics.mark(for: .pending))
        XCTAssertNil(BlockSemantics.tint(for: .pending, palette: palette),
                     "pending is queued, not severe")

        XCTAssertNil(BlockSemantics.mark(for: .active))
        XCTAssertEqual(BlockSemantics.tint(for: .active, palette: palette), palette.accent)

        XCTAssertNil(BlockSemantics.mark(for: .inactive))
        XCTAssertNil(BlockSemantics.tint(for: .inactive, palette: palette))

        XCTAssertNil(BlockSemantics.mark(for: .disabled))
        XCTAssertNil(BlockSemantics.tint(for: .disabled, palette: palette))

        XCTAssertNil(BlockSemantics.mark(for: .warning),
                     "the quantity beside it is the mark; no glyph duplicates it")
        XCTAssertEqual(BlockSemantics.tint(for: .warning, palette: palette), palette.warning)
    }

    // MARK: - Adoption

    private func comparisonCheck(_ json: String) throws -> InspectConfig.GuidanceContent.ComparisonCheck {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.ComparisonCheck.self,
                                 from: Data(json.utf8))
    }

    /// A passing comparison row renders no glyph at all.
    func testAPassingComparisonRowRendersNoGlyphAtAll() throws {
        let row = try comparisonCheck(#"{"check":"FileVault","required":"On","found":"On"}"#)
        XCTAssertNil(ComparisonChecksTable.rowSignal(for: row, palette: .fixture),
                     "the value beside the row already says it passed")
    }

    func testAFailingComparisonRowKeepsItsMarkAndItsErrorHue() throws {
        let row = try comparisonCheck(#"{"check":"FileVault","required":"On","found":"Off"}"#)
        let signal = try XCTUnwrap(ComparisonChecksTable.rowSignal(for: row, palette: .fixture))
        XCTAssertEqual(signal.symbol, "xmark.circle.fill")
        XCTAssertEqual(signal.tint, ResolvedPalette.fixture.error,
                       "this branch removed decoration; nothing about failure got quieter")
    }

    /// An authored `pass` overrides the derived comparison (required `14.0`, found `14.2` still passes).
    func testAnAuthoredPassOverridesTheDerivedComparison() throws {
        let row = try comparisonCheck(#"{"check":"macOS","required":"14.0","found":"14.2","pass":true}"#)
        XCTAssertNil(ComparisonChecksTable.rowSignal(for: row, palette: .fixture))
    }

    func testAnAuthoredFailOverridesAMatchingComparison() throws {
        let row = try comparisonCheck(#"{"check":"macOS","required":"On","found":"On","pass":false}"#)
        XCTAssertNotNil(ComparisonChecksTable.rowSignal(for: row, palette: .fixture))
    }
}
