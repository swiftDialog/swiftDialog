//
//  ChecklistLineMonitorTests.swift
//  dialogTests
//
//  The per-line checklist watch Preset5View and Preset6View share: the watch gate, the
//  `hasWork` short-circuit, and how `evaluate` keeps its baseline.
//

import XCTest
@testable import Dialog

final class ChecklistLineMonitorTests: XCTestCase {

    private func line(_ text: String, paths: [String]? = nil) -> InspectConfig.GuidanceContent.ChecklistLine {
        InspectConfig.GuidanceContent.ChecklistLine(text: text, marker: nil, hint: nil,
                                                    paths: paths, plistKey: nil, context: nil)
    }

    /// `IntroStep` is only `Decodable`, so build one from JSON with a single checklist block.
    private func step(withPaths paths: [[String]?]) throws -> InspectConfig.IntroStep {
        let checklist = paths.enumerated().map { index, p -> [String: Any] in
            var dict: [String: Any] = ["text": "line \(index)"]
            if let p { dict["paths"] = p }
            return dict
        }
        let json: [String: Any] = [
            "preset": "6",
            "introSteps": [[
                "id": "s",
                "content": [["type": "checklist", "checklist": checklist]]
            ]]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let config = try JSONDecoder().decode(InspectConfig.self, from: data)
        return try XCTUnwrap(config.introSteps?.first)
    }

    private func guideStep(paths: [String]) throws -> InspectConfig.IntroStep {
        let json: [String: Any] = ["preset": "5", "introSteps": [["id": "g", "stepType": "guide", "paths": paths]]]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try XCTUnwrap(try JSONDecoder().decode(InspectConfig.self, from: data).introSteps?.first)
    }

    // MARK: - Watch gate

    /// A watched line on any step counts, whatever the step's type.
    func testHasWatchedLinesTrueForAWatchedLineOnAnyStep() throws {
        XCTAssertTrue(ChecklistLineMonitor.hasWatchedLines(in: [try step(withPaths: [nil, ["/Applications/Tunnelblick.app"]])]))
    }

    func testHasWatchedLinesFalseWhenNoLineIsWatched() throws {
        XCTAssertFalse(ChecklistLineMonitor.hasWatchedLines(in: [try step(withPaths: [nil, nil])]))
        XCTAssertFalse(ChecklistLineMonitor.hasWatchedLines(in: []))
    }

    /// A watched line on a standard step starts the watch, not only a guide step with `paths`.
    func testPreset5StartsItsWatchForAWatchedLineOnAStandardStep() throws {
        XCTAssertTrue(Preset5View.needsGuideWatch([try step(withPaths: [nil, ["/tmp/vpn.app"]])]))
        XCTAssertFalse(Preset5View.needsGuideWatch([try step(withPaths: [nil])]))
    }

    /// A guide step with `paths` starts it too.
    func testPreset5StillStartsItsWatchForAGuideStepWithPaths() throws {
        XCTAssertTrue(Preset5View.needsGuideWatch([try guideStep(paths: ["/tmp/gate"])]))
    }

    // MARK: - hasWork

    /// A checklist with no watched line never has work, so the timer never starts.
    func testHasWorkFalseWhenNoLineIsWatched() {
        let lines = [line("one"), line("two")]
        XCTAssertFalse(ChecklistLineMonitor.hasWork(lines: lines, baseline: [false, false]))
    }

    /// A watched line still unsatisfied in the baseline is work.
    func testHasWorkTrueWhenAWatchedLineIsUnsatisfied() {
        let lines = [line("one", paths: ["/a"]), line("two", paths: ["/b"])]
        XCTAssertTrue(ChecklistLineMonitor.hasWork(lines: lines, baseline: [true, false]))
    }

    /// Once every watched line has ticked there is nothing left to check.
    func testHasWorkFalseWhenEveryWatchedLineIsSatisfied() {
        let lines = [line("one", paths: ["/a"]), line("two", paths: ["/b"])]
        XCTAssertFalse(ChecklistLineMonitor.hasWork(lines: lines, baseline: [true, true]))
    }

    /// Indices missing from a shorter baseline read as unsatisfied, not as ticked.
    func testHasWorkTrueWhenBaselineIsShorterThanLines() {
        let lines = [line("one", paths: ["/a"]), line("two", paths: ["/b"])]
        XCTAssertTrue(ChecklistLineMonitor.hasWork(lines: lines, baseline: [true]))
    }

    // MARK: - evaluate

    /// A watched line whose path exists resolves true.
    func testEvaluateResolvesTrueForAnExistingPath() throws {
        let exp = expectation(description: "evaluate")
        let s = try step(withPaths: [["/System/Library/CoreServices"]])
        ChecklistLineMonitor.evaluate(step: s, baseline: [false]) { results in
            XCTAssertEqual(results, [true])
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    /// A watched line whose path does not exist resolves false.
    func testEvaluateResolvesFalseForAMissingPath() throws {
        let exp = expectation(description: "evaluate")
        let s = try step(withPaths: [["/definitely/does/not/exist-\(UUID())"]])
        ChecklistLineMonitor.evaluate(step: s, baseline: [false]) { results in
            XCTAssertEqual(results, [false])
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    /// A line already true in the baseline is never re-evaluated; a ticked line never un-ticks.
    func testEvaluateNeverRechecksAnAlreadySatisfiedLine() throws {
        let exp = expectation(description: "evaluate")
        let s = try step(withPaths: [["/definitely/does/not/exist-\(UUID())"]])
        ChecklistLineMonitor.evaluate(step: s, baseline: [true]) { results in
            XCTAssertEqual(results, [true], "a satisfied line must stay satisfied even though its path is now missing")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    /// Baseline ticks and fresh checks merge in one pass.
    func testEvaluateMergesBaselineWithFreshChecks() throws {
        let exp = expectation(description: "evaluate")
        let s = try step(withPaths: [["/definitely/does/not/exist-\(UUID())"], ["/System/Library/CoreServices"]])
        ChecklistLineMonitor.evaluate(step: s, baseline: [true, false]) { results in
            XCTAssertEqual(results, [true, true])
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }
}
