//
//  SummaryBlockTests.swift
//  dialogTests
//
//  Three opt-in pieces: `stat-row` `style: "card"`, `bullets` `style: "rows"`, and the per-step
//  `headerIconTile`. All three are additive; a block with no `style` keeps its form.
//

import XCTest
import SwiftUI
@testable import Dialog

final class SummaryBlockTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InspectConfig.unknownKeyWarnings = []
    }

    override func tearDown() {
        InspectConfig.unknownKeyWarnings = []
        super.tearDown()
    }

    private func firstBlock(_ blockJSON: String) throws -> InspectConfig.GuidanceContent {
        let json = #"{"preset": "5", "introSteps": [{"id": "s", "content": [\#(blockJSON)]}]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        return try XCTUnwrap(config.introSteps?.first?.content?.first)
    }

    private func firstStep(_ stepJSON: String) throws -> InspectConfig.IntroStep {
        let json = #"{"preset": "6", "steps": [\#(stepJSON)]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        return try XCTUnwrap(config.steps?.first)
    }

    // MARK: - stat-row: style: "card"

    /// No `style`, the row strip.
    func testStatRowWithNoStyleResolvesToTodaysRowForm() throws {
        let block = try firstBlock(#"""
        {"type": "stat-row", "stats": [{"value": "7", "label": "checks run"}]}
        """#)
        XCTAssertNil(block.style)
        XCTAssertEqual(GuidanceStatRowBlock.resolveForm(style: block.style), .row)
    }

    /// An explicit `style: "card"` resolves to the card form.
    func testStatRowWithCardStyleResolvesToCardForm() throws {
        let block = try firstBlock(#"""
        {"type": "stat-row", "style": "card", "stats": [{"value": "7", "label": "checks run"}]}
        """#)
        XCTAssertEqual(block.style, "card")
        XCTAssertEqual(GuidanceStatRowBlock.resolveForm(style: block.style), .card)
    }

    /// Any other style value stays the row form.
    func testStatRowWithUnrelatedStyleStaysTheRowForm() throws {
        XCTAssertEqual(GuidanceStatRowBlock.resolveForm(style: "chip"), .row)
    }

    // MARK: - bullets: style: "rows"

    /// No `style`, the bulleted list.
    func testBulletsWithNoStyleResolvesToTodaysListForm() throws {
        let block = try firstBlock(#"""
        {"type": "bullets", "items": ["One", "Two"]}
        """#)
        XCTAssertNil(block.style)
        XCTAssertEqual(GuidanceBulletsBlock.resolveForm(style: block.style), .list)
    }

    /// An explicit `style: "rows"` resolves to the bordered-row form.
    func testBulletsWithRowsStyleResolvesToRowsForm() throws {
        let block = try firstBlock(#"""
        {"type": "bullets", "style": "rows", "icon": "checkmark.seal.fill", "items": ["One", "Two"]}
        """#)
        XCTAssertEqual(block.style, "rows")
        XCTAssertEqual(GuidanceBulletsBlock.resolveForm(style: block.style), .rows)
        // `rows` reuses the block's own icon key.
        XCTAssertEqual(block.icon, "checkmark.seal.fill")
    }

    /// `numbered` and `style` are independent axes.
    func testNumberedBulletsWithNoStyleStaysTheListForm() throws {
        let block = try firstBlock(#"""
        {"type": "bullets", "numbered": true, "items": ["One", "Two"]}
        """#)
        XCTAssertEqual(GuidanceBulletsBlock.resolveForm(style: block.style), .list)
    }

    // MARK: - The header icon tile step key

    /// `headerIconTile` decodes on a step and is not reported unknown.
    func testHeaderIconTileDecodesAndIsAKnownStepKey() throws {
        let step = try firstStep(#"""
        {"id": "s", "headerIconTile": true, "icon": "gearshape.fill", "guidanceTitle": "Settings"}
        """#)
        XCTAssertTrue(InspectConfig.knownStepKeys.contains("headerIconTile"))
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("headerIconTile") }, [],
                       "`headerIconTile` must be in knownStepKeys or every load logs a false warning")
        // canonicalizeStep folds `icon` into `heroImage`, which the tile reads.
        XCTAssertEqual(step.heroImage, "gearshape.fill")
        XCTAssertEqual(step.headerIconTile, true)
    }

    /// Unauthored is `nil`, which the render treats as off.
    func testHeaderIconTileDefaultsToOff() throws {
        let step = try firstStep(#"""
        {"id": "s", "icon": "gearshape.fill", "guidanceTitle": "Settings"}
        """#)
        XCTAssertNil(step.headerIconTile)
    }

    // MARK: - Schema

    private func schema() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        return try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    /// The schema's `GuidanceContent.style` enum accepts both new values.
    func testSchemaDeclaresCardAndRowsStyleValues() throws {
        let definitions = try XCTUnwrap(schema()["definitions"] as? [String: Any])
        let guidance = try XCTUnwrap(definitions["GuidanceContent"] as? [String: Any])
        let properties = try XCTUnwrap(guidance["properties"] as? [String: Any])
        let style = try XCTUnwrap(properties["style"] as? [String: Any])
        let values = try XCTUnwrap(style["enum"] as? [String])
        XCTAssertTrue(values.contains("card"), "GuidanceContent.style must accept 'card'")
        XCTAssertTrue(values.contains("rows"), "GuidanceContent.style must accept 'rows'")
    }

    /// The schema declares `headerIconTile` as a boolean, defaulting to false.
    func testSchemaDeclaresHeaderIconTile() throws {
        let definitions = try XCTUnwrap(schema()["definitions"] as? [String: Any])
        let stepBase = try XCTUnwrap(definitions["StepBase"] as? [String: Any])
        let properties = try XCTUnwrap(stepBase["properties"] as? [String: Any])
        let declared = try XCTUnwrap(properties["headerIconTile"] as? [String: Any])
        XCTAssertEqual(declared["type"] as? String, "boolean")
        XCTAssertEqual(declared["default"] as? Bool, false)
    }
}
