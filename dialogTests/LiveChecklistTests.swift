//
//  LiveChecklistTests.swift
//  dialogTests
//
//  Checklist line state is derived from the watch: satisfied lines tick, the first unsatisfied
//  watched line is active, unwatched lines make no claim.
//

import XCTest
@testable import Dialog

final class LiveChecklistTests: XCTestCase {

    private func line(_ text: String, paths: [String]? = nil) -> InspectConfig.GuidanceContent.ChecklistLine {
        InspectConfig.GuidanceContent.ChecklistLine(text: text, marker: nil, hint: nil,
                                                    paths: paths, plistKey: nil, context: nil)
    }

    /// Only the first unsatisfied watched line is active; an unwatched line takes no part.
    func testActiveIsTheFirstUnsatisfiedWatchedLine() {
        let lines = [line("instruction only"),
                     line("a", paths: ["/a"]), line("b", paths: ["/b"]),
                     line("c", paths: ["/c"]), line("d", paths: ["/d"])]
        let states = ChecklistState.resolve(lines: lines, satisfied: [true, true, false, true, false])
        XCTAssertEqual(states, [.unwatched, .satisfied, .active, .satisfied, .pending],
                       "unwatched makes no claim; only the FIRST unsatisfied WATCHED line is active")
    }

    /// Every line satisfied: nothing is active.
    func testAllSatisfiedLeavesNoActiveLine() {
        let lines = [line("one", paths: ["/a"]), line("two", paths: ["/b"])]
        let states = ChecklistState.resolve(lines: lines, satisfied: [true, true])
        XCTAssertEqual(states, [.satisfied, .satisfied])
        XCTAssertFalse(states.contains(.active))
    }

    /// Nothing satisfied: the first line is the active one.
    func testNothingSatisfiedMakesTheFirstWatchedLineActive() {
        let lines = [line("one", paths: ["/a"]), line("two", paths: ["/b"])]
        let states = ChecklistState.resolve(lines: lines, satisfied: [false, false])
        XCTAssertEqual(states, [.active, .pending])
    }

    /// A line with no watch is unwatched, never satisfied: nothing verified it.
    func testALineWithNoWatchMakesNoClaim() {
        let states = ChecklistState.resolve(lines: [line("no watch here")], satisfied: [true])
        XCTAssertEqual(states, [.unwatched],
                       "absence of a watch is not evidence of completion")
    }

    /// A watched line takes the evaluator's answer.
    func testALineWithAWatchTakesTheEvaluatorsAnswer() {
        let lines = [line("watched", paths: ["/definitely/missing"])]
        XCTAssertEqual(ChecklistState.evaluate(lines: lines) { _, _ in false }, [false])
        XCTAssertEqual(ChecklistState.evaluate(lines: lines) { _, _ in true }, [true])
    }

    /// The three watch keys decode and are not reported unknown.
    func testChecklistLineKeysDecodeAndAreKnown() throws {
        InspectConfig.unknownKeyWarnings = []
        let json = #"""
        {"preset": "5", "introSteps": [{"id": "s", "content": [
          {"type": "checklist", "checklist": [
            {"text": "Turn on FileVault", "context": "Encryption",
             "paths": ["/System/Library/CoreServices"], "plistKey": "Enabled"}
          ]}
        ]}]}
        """#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let l = try XCTUnwrap(config.introSteps?.first?.content?.first?.checklist?.first)
        XCTAssertEqual(l.context, "Encryption")
        XCTAssertEqual(l.paths, ["/System/Library/CoreServices"])
        XCTAssertEqual(l.plistKey, "Enabled")
        XCTAssertEqual(InspectConfig.unknownKeyWarnings.filter {
            $0.contains("context") || $0.contains("paths") || $0.contains("plistKey") }, [])
        InspectConfig.unknownKeyWarnings = []
    }
}
