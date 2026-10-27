//
//  SpecimenFrameTests.swift
//  dialogTests
//
//  The specimen frame: a block in the reference catalogue labelled with its own JSON name.
//

import XCTest
import SwiftUI
@testable import Dialog

final class SpecimenFrameTests: XCTestCase {

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

    /// Both keys decode onto any block.
    func testSpecimenKeysDecodeOnAnyBlock() throws {
        let block = try firstBlock(#"""
        {"type": "bullets", "items": ["a"],
         "specimen": "bullets", "specimenNote": "a short list of facts"}
        """#)
        XCTAssertEqual(block.specimen, "bullets")
        XCTAssertEqual(block.specimenNote, "a short list of facts")
        XCTAssertEqual(block.type, "bullets", "the block keeps its own type")
    }

    /// Specimen keys are registered, so they raise no unknown-key warning.
    func testSpecimenKeysAreNotReportedUnknown() throws {
        _ = try firstBlock(#"""
        {"type": "text", "content": "x", "specimen": "text", "specimenNote": "prose"}
        """#)
        let noise = InspectConfig.unknownKeyWarnings.filter {
            $0.contains("specimen") || $0.contains("specimenNote")
        }
        XCTAssertEqual(noise, [], "both keys must be in knownBlockKeys")
    }

    /// The schema declares both specimen keys.
    func testSchemaDeclaresBothSpecimenKeys() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let defs = schema?["definitions"] as? [String: Any]
        let guidance = defs?["GuidanceContent"] as? [String: Any]
        let props = guidance?["properties"] as? [String: Any]
        XCTAssertNotNil(props?["specimen"], "schema declares specimen")
        XCTAssertNotNil(props?["specimenNote"], "schema declares specimenNote")
    }

    /// A block that authors neither carries neither.
    func testABlockWithoutSpecimenCarriesNeitherKey() throws {
        let block = try firstBlock(#"{"type": "text", "content": "x"}"#)
        XCTAssertNil(block.specimen)
        XCTAssertNil(block.specimenNote)
    }

    /// The chip shows the authored name verbatim; it is a JSON literal.
    func testFrameChipUsesTheAuthoredNameVerbatim() {
        let frame = SpecimenFrame(name: "handoff-list", note: "handing work over",
                                  scaleFactor: 1) { EmptyView() }
        XCTAssertEqual(frame.name, "handoff-list")
        XCTAssertEqual(frame.note, "handing work over")
    }

    /// `wrappedContentBlockView` branches on `block.wantsSpecimenFrame` and builds `SpecimenFrame`
    /// only in the true arm. The view is private, so this reads the source.
    func testWrappedContentBlockViewFramesOnlyWhenTheKeyIsPresent() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Core Framework/Components/GuidanceContentView.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        guard let signatureRange = source.range(
            of: "private func wrappedContentBlockView(for block: InspectConfig.GuidanceContent) -> some View {"
        ) else {
            XCTFail("wrappedContentBlockView(for:) not found — has it moved or been renamed?")
            return
        }
        guard let closeRange = source.range(of: "\n    }", range: signatureRange.upperBound..<source.endIndex) else {
            XCTFail("Could not find the end of wrappedContentBlockView(for:)")
            return
        }
        let body = source[signatureRange.upperBound..<closeRange.lowerBound]

        guard let ifRange = body.range(of: "if block.wantsSpecimenFrame {") else {
            XCTFail("wrappedContentBlockView must branch on `if block.wantsSpecimenFrame {` — " +
                     "found body:\n\(body)")
            return
        }
        guard let elseRange = body.range(of: "} else {", range: ifRange.upperBound..<body.endIndex) else {
            XCTFail("Expected an `} else {` closing the wantsSpecimenFrame branch")
            return
        }
        guard let specimenRange = body.range(of: "SpecimenFrame(name:") else {
            XCTFail("The wantsSpecimenFrame branch must construct a SpecimenFrame — " +
                     "otherwise the frame is never applied regardless of the key")
            return
        }
        XCTAssertTrue(
            ifRange.upperBound <= specimenRange.lowerBound && specimenRange.upperBound <= elseRange.lowerBound,
            "SpecimenFrame(name:...) must be constructed strictly inside the " +
            "`if block.wantsSpecimenFrame` branch, not in the fallback `else`"
        )
    }

    /// A note is optional; a frame without one is still a frame.
    func testFrameAcceptsNoNote() {
        let frame = SpecimenFrame(name: "text", note: nil, scaleFactor: 1) { EmptyView() }
        XCTAssertNil(frame.note)
    }

    /// The renderer frames a block only when a name is present.
    func testFramingDecisionFollowsTheSpecimenKey() throws {
        let framed = try firstBlock(#"{"type": "text", "content": "x", "specimen": "text"}"#)
        let plain = try firstBlock(#"{"type": "text", "content": "x"}"#)
        XCTAssertTrue(framed.wantsSpecimenFrame)
        XCTAssertFalse(plain.wantsSpecimenFrame, "fail-open: no key, no frame")
    }

    /// An empty name does not frame.
    func testEmptySpecimenDoesNotFrame() throws {
        let empty = try firstBlock(#"{"type": "text", "content": "x", "specimen": ""}"#)
        XCTAssertFalse(empty.wantsSpecimenFrame)
    }

    /// `specimenNote` resolves through the per-block sidecar (`<step>.content.<index>.specimenNote`);
    /// `specimen` stays the raw authored string even when a translation exists.
    @MainActor
    func testSpecimenNoteIsLocalizedButNameIsNot() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("specimen-loc-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sidecar: [String: Any] = [
            "probe.content.0.specimenNote": "eine kurze Info-Notiz"
        ]
        let data = try JSONSerialization.data(withJSONObject: sidecar)
        try data.write(to: tempDir.appendingPathComponent("de.json"))

        let locConfig = InspectConfig.LocalizationConfig(
            languages: ["de": "de.json"], selectionKey: nil,
            defaultLanguage: "de")

        let json = #"""
        {"preset": "5",
         "localization": {"languages": {"de": "de.json"}, "defaultLanguage": "de"},
         "introSteps": [{"id": "probe", "content": [
            {"type": "info", "content": "x", "specimen": "info",
             "specimenNote": "a short informational note"}
         ]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let block = try XCTUnwrap(config.introSteps?.first?.content?.first)

        let state = InspectState()
        state.config = config
        let view = Preset5View(inspectState: state)
        view.localizationService.loadLanguages(from: locConfig, iconBasePath: tempDir.path, configPath: nil)

        let localized = view.localizedContentBlock(block, stepId: "probe", blockIndex: 0)
        XCTAssertEqual(localized.specimenNote, "eine kurze Info-Notiz",
                       "specimenNote must resolve through the per-block sidecar mapping, "
                       + "the same idiom caption/label/helpText use")
        XCTAssertEqual(localized.specimen, "info",
                       "specimen is a JSON literal and must never translate, even though a "
                       + "sidecar translation exists on the very same block")
    }
}
