//
//  GuidanceViewTests.swift
//  dialogTests
//
//  The guidance block view and its text pieces: prose streams, inline markdown and the glow.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// MARK: - Prose stream

/// The `prose` block, written to while the window is open: the trigger-file escape, the append
/// accumulator, the stream flag, and the key's decode.
@MainActor
final class ProseStreamTests: XCTestCase {

    private func decodeBlock(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    func testUnescapeTurnsTheTwoEscapesAndKeepsEverythingElse() {
        XCTAssertEqual(InspectDynamicState.unescapeIPCText(#"one\ntwo"#), "one\ntwo")
        XCTAssertEqual(InspectDynamicState.unescapeIPCText(#"C:\\Users"#), #"C:\Users"#)
        XCTAssertEqual(InspectDynamicState.unescapeIPCText(#"a\tb \d+"#), #"a\tb \d+"#,
                       "an unknown escape is kept as typed — a regex in a message must survive")
        XCTAssertEqual(InspectDynamicState.unescapeIPCText(#"trailing\"#), #"trailing\"#)
        XCTAssertEqual(InspectDynamicState.unescapeIPCText("plain"), "plain")
    }

    @MainActor
    func testAppendAccumulatesAcrossLinesAndOpensTheStream() throws {
        let state = InspectDynamicState()
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "First. ")
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "Second.\n")
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "Third.")
        XCTAssertEqual(state.dynamicGuidanceProperties["answer"]?[0]?["content"], "First. Second.\nThird.")
        XCTAssertEqual(state.dynamicGuidanceProperties["answer"]?[0]?["stream"], "open")
        // One store, one reader: what Presets 5 and 6 both draw.
        let block = try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(#"{"type":"prose","content":""}"#.utf8))
        XCTAssertEqual(state.applied(to: block, blockIndex: 0, stepId: "answer").content, "First. Second.\nThird.")
    }

    @MainActor
    func testAppendContinuesFromAReplacedContent() {
        let state = InspectDynamicState()
        state.updateGuidanceProperty(stepId: "answer", blockIndex: 2, property: "content", value: "Start")
        state.appendGuidanceContent(stepId: "answer", blockIndex: 2, text: " and on")
        XCTAssertEqual(state.dynamicGuidanceProperties["answer"]?[2]?["content"], "Start and on")
    }

    func testLineVerbAddsANewlineAndAppendDoesNot() {
        XCTAssertEqual(InspectDynamicState.streamedText(property: "append", value: #"a\nb"#), "a\nb")
        XCTAssertEqual(InspectDynamicState.streamedText(property: "line", value: "- item"), "- item\n",
                       "one trigger line, one text line — the Markdown splitter needs the newline to see a list item")
        XCTAssertNil(InspectDynamicState.streamedText(property: "content", value: "x"), "content= is a replace, not a stream verb")
        XCTAssertNil(InspectDynamicState.streamedText(property: "state", value: "success"))
    }

    func testStreamPropertyOpensAndClosesTheStateAndAbsenceLeavesItNil() throws {
        let block = try decodeBlock(#"{"type":"prose","content":"x"}"#)
        XCTAssertNil(GuidanceProseBlock.streaming(from: block.state),
                     "a block that never streamed must not read as open or ended — that is what keeps a static prose block byte-identical to text")
        XCTAssertEqual(GuidanceProseBlock.streaming(from: block.applyingDynamicProperties(["stream": "open"]).state), true)
        XCTAssertEqual(GuidanceProseBlock.streaming(from: block.applyingDynamicProperties(["stream": "end"]).state), false)
        XCTAssertEqual(GuidanceProseBlock.streaming(from: block.applyingDynamicProperties(["stream": "END"]).state), false)
    }

    @MainActor
    func testAppendCollapsesRunsOfBlankLinesToOneParagraphBreak() {
        let state = InspectDynamicState()
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "one\n")
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "\n")
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "\n")
        state.appendGuidanceContent(stepId: "answer", blockIndex: 0, text: "\ntwo")
        XCTAssertEqual(state.dynamicGuidanceProperties["answer"]?[0]?["content"], "one\n\ntwo",
                       "a run of blank lines is one paragraph break, not a gap the size of the run")
    }

    func testProseBlockDecodesWithFollowAndPlaceholderAndNoUnknownKeyAdvisory() throws {
        InspectConfig.unknownKeyWarnings = []
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(#"""
        {"preset": "5", "chrome": "card", "introSteps": [{
            "id": "answer", "title": "Answer", "stepType": "standard",
            "content": [{"type": "prose", "id": "body", "content": "", "placeholder": "Thinking…", "follow": false}]
        }]}
        """#.utf8))
        let block = try XCTUnwrap(config.introSteps?.first?.content?.first)
        XCTAssertEqual(block.type, "prose")
        XCTAssertEqual(block.follow, false)
        XCTAssertEqual(block.placeholder, "Thinking…")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter { $0.contains("follow") }, [],
                       "follow must be in knownBlockKeys or every prose config logs a false warning")
    }
}

// One inline-markdown renderer for cards, rails, sub-steps, the state line and guidance blocks.
final class InlineMarkdownTests: XCTestCase {
    func testTextIsRenderedAsWritten() {
        XCTAssertEqual(String(guidanceAttributedMarkdown("100% done — %d left").characters), "100% done — %d left",
                       "a % is text, not a format specifier (LocalizedStringKey's reading)")
        XCTAssertEqual(String(guidanceAttributedMarkdown("Continue").characters), "Continue",
                       "never looked up as a localization key")
        let bold = guidanceAttributedMarkdown("Install **now**")
        XCTAssertEqual(String(bold.characters), "Install now")
        XCTAssertTrue(bold.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        XCTAssertEqual(String(guidanceAttributedMarkdown("line one\nline two").characters), "line one\nline two",
                       "whitespace kept")
    }
}

// `glow`: the designed accent glow, stepped down to none, the same on every preset.
final class InspectGlowTests: XCTestCase {
    func testLevels() throws {
        XCTAssertEqual(InspectGlow(nil), .full, "absent keeps the designed look")
        XCTAssertEqual(InspectGlow("SOFT"), .soft)
        XCTAssertEqual(InspectGlow("bogus"), .full)
        XCTAssertEqual([InspectGlow.full, .soft, .subtle, .none].map(\.factor), [1, 0.6, 0.3, 0])
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset":"2","items":[],"glow":"none"}"#.utf8))
        XCTAssertEqual(InspectGlow(config.glow), .none)
    }
}
