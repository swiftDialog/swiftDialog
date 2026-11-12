//
//  CalloutCardTests.swift
//  dialogTests
//
//  The callout's second weight: `title` promotes warning/info/success to a card.
//

import XCTest
import SwiftUI
@testable import Dialog

final class CalloutCardTests: XCTestCase {

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

    /// `cadenceStatNote` and `safeToKeepWorking` are not decoded and are reported as unknown keys.
    func testTheGateStripKeysAreUnknownNow() throws {
        let json = #"""
        {"preset": "5", "introSteps": [{"id": "s", "stepType": "cadence",
          "cadenceStatNote": {"label": "Safe to keep working", "value": "Yes"},
          "safeToKeepWorking": "Yes"}]}
        """#
        _ = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertFalse(InspectConfig.unknownKeyWarnings.filter { $0.contains("cadenceStatNote") }.isEmpty,
                       "cadenceStatNote is a deleted key and must be reported")
        XCTAssertFalse(InspectConfig.unknownKeyWarnings.filter { $0.contains("safeToKeepWorking") }.isEmpty,
                       "safeToKeepWorking is a deleted key and must be reported")
    }

    /// `title` decodes on a callout and is not reported unknown.
    func testCalloutTitleDecodesAndIsAKnownBlockKey() throws {
        let block = try firstBlock(#"""
        {"type": "warning", "title": "Your Mac will restart",
         "content": "Save any open work now."}
        """#)
        XCTAssertEqual(block.title, "Your Mac will restart")
        XCTAssertEqual(block.content, "Save any open work now.")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("title") }, [],
                       "`title` must be in knownBlockKeys or every load logs a false warning")
    }

    /// No `title`, no card.
    func testACalloutWithoutTitleIsNotACard() throws {
        let plain = try firstBlock(#"{"type": "warning", "content": "Your Mac will restart"}"#)
        XCTAssertFalse(GuidanceCalloutBlock.isCard(plain))

        let card = try firstBlock(#"""
        {"type": "warning", "title": "Your Mac will restart", "content": "Save your work."}
        """#)
        XCTAssertTrue(GuidanceCalloutBlock.isCard(card))
    }

    /// An empty or whitespace title is not a title.
    func testAnEmptyTitleIsNotACard() throws {
        XCTAssertFalse(GuidanceCalloutBlock.isCard(
            try firstBlock(#"{"type": "info", "title": "", "content": "x"}"#)))
        XCTAssertFalse(GuidanceCalloutBlock.isCard(
            try firstBlock(#"{"type": "info", "title": "   ", "content": "x"}"#)))
    }

    /// An explicit chip style wins over a title.
    func testChipBeatsCardWhenBothAreAuthored() throws {
        let both = try firstBlock(#"""
        {"type": "info", "style": "chip", "title": "Heads up", "content": "x"}
        """#)
        XCTAssertFalse(GuidanceCalloutBlock.isCard(both),
                       "style:chip is an explicit demotion and wins over the card")
    }

    /// A title beats `info`'s defaulted chip; asserted on `resolveForm`, which the render uses.
    func testInfoWithTitleAndNoStyleIsACardNotTheDefaultChip() throws {
        let block = try firstBlock(#"{"type": "info", "title": "Heads up", "content": "x"}"#)
        XCTAssertNil(block.style)
        XCTAssertTrue(GuidanceCalloutBlock.isCard(block))
        XCTAssertEqual(
            GuidanceCalloutBlock.resolveForm(style: .info, rawStyle: block.style, title: block.title),
            .card)
    }

    /// An explicit chip style on `info` resolves to `.chip` even with a title.
    func testExplicitChipStillBeatsTitleOnInfo() throws {
        let block = try firstBlock(#"""
        {"type": "info", "style": "chip", "title": "Heads up", "content": "x"}
        """#)
        XCTAssertFalse(GuidanceCalloutBlock.isCard(block))
        XCTAssertEqual(
            GuidanceCalloutBlock.resolveForm(style: .info, rawStyle: block.style, title: block.title),
            .chip)
    }

    /// A card with no authored `icon` takes the style's default glyph; an authored icon wins.
    func testCardWithNoIconResolvesToStyleDefaultGlyph() throws {
        XCTAssertEqual(GuidanceCalloutBlock.resolveCardIcon(style: .warning, iconOverride: nil),
                       "exclamationmark.triangle.fill")
        XCTAssertEqual(GuidanceCalloutBlock.resolveCardIcon(style: .success, iconOverride: nil),
                       "checkmark.circle.fill")
        XCTAssertEqual(GuidanceCalloutBlock.resolveCardIcon(style: .info, iconOverride: nil),
                       "info.circle.fill")
        XCTAssertEqual(
            GuidanceCalloutBlock.resolveCardIcon(style: .warning, iconOverride: "bolt.fill"),
            "bolt.fill")
    }

    /// The schema declares what the renderer honours.
    func testSchemaDeclaresCalloutTitle() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let props = ((schema?["definitions"] as? [String: Any])?["GuidanceContent"]
                     as? [String: Any])?["properties"] as? [String: Any]
        XCTAssertNotNil(props?["title"], "schema declares the callout's title")
    }
}
