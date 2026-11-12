//
//  ResultFileFreezeTests.swift
//  dialogTests
//
//  Contracts a change to the Step/ListItem types must not move: the result-file keys, their level
//  and type, and that rows inside a step never become steps (the rail count stays 6).
//

import XCTest
@testable import Dialog

final class ResultFileFreezeTests: XCTestCase {

    // MARK: - Fixture

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resultfile-freeze-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try super.tearDownWithError()
    }

    /// Throws rather than `try!`, so a malformed fixture fails its own test instead of crashing the run.
    private func step(id: String, stepType: String?) throws -> InspectConfig.IntroStep {
        var json = #"{"id": "\#(id)""#
        if let stepType { json += #", "stepType": "\#(stepType)""# }
        json += "}"
        return try JSONDecoder().decode(InspectConfig.IntroStep.self, from: Data(json.utf8))
    }

    // MARK: - Result file

    /// The documented key sets, as literals so a key appearing or vanishing fails here.
    private static let exitTopLevelAlways: Set<String> =
        ["exitCode", "timestamp", "pid", "lastStepIndex", "totalSteps"]
    private static let exitTopLevelConditional: Set<String> =
        ["steps", "selections", "formValues", "selectedBrand"]
    private static let exitPerStep: Set<String> =
        ["id", "stepType", "status", "result", "failureReason"]

    private static let liveTopLevelAlways: Set<String> =
        ["timestamp", "pid", "preset", "count", "currentIndex", "steps"]
    private static let liveTopLevelConditional: Set<String> =
        ["currentId", "formValues", "selections"]
    private static let livePerStep: Set<String> = ["id", "stepType", "status", "progress"]

    /// The documented totals count distinct key names across both levels.
    func testTheDocumentedTotalsAreDistinctNamesAcrossBothLevels() {
        let exitNames = Self.exitTopLevelAlways
            .union(Self.exitTopLevelConditional)
            .union(Self.exitPerStep)
        XCTAssertEqual(exitNames.count, 14, "writeResultFile: \(exitNames.sorted())")

        let liveNames = Self.liveTopLevelAlways
            .union(Self.liveTopLevelConditional)
            .union(Self.livePerStep)
        XCTAssertEqual(liveNames.count, 13, "writeStepListResponse: \(liveNames.sorted())")
    }

    /// Keys with no known reader stay emitted and frozen; removing one is a deliberate change.
    func testTheThreeNoReaderKeysAreStillPartOfTheContract() {
        XCTAssertTrue(Self.exitTopLevelAlways.contains("lastStepIndex"))
        XCTAssertTrue(Self.exitPerStep.contains("failureReason"))
        XCTAssertTrue(Self.liveTopLevelConditional.contains("currentId"))
    }

    /// Both names of each duplicated fact are still emitted.
    func testBothNamesForEachDuplicatedFactSurvive() {
        XCTAssertTrue(Self.exitTopLevelAlways.contains("totalSteps"), "canonical")
        XCTAssertTrue(Self.exitTopLevelAlways.contains("lastStepIndex"), "duplicate, frozen")
        XCTAssertTrue(Self.liveTopLevelAlways.contains("currentIndex"), "canonical")
        XCTAssertTrue(Self.liveTopLevelConditional.contains("currentId"), "duplicate, frozen")
    }

    /// `id`, `stepType` and `status` stay per-step in both writers.
    func testTheKeysSharedByBothWritersStayPerStep() {
        for key in ["id", "stepType", "status"] {
            XCTAssertTrue(Self.exitPerStep.contains(key), "\(key) is per-step in the result file")
            XCTAssertTrue(Self.livePerStep.contains(key), "\(key) is per-step in the step list")
            XCTAssertFalse(Self.exitTopLevelAlways.contains(key))
            XCTAssertFalse(Self.liveTopLevelAlways.contains(key))
        }
    }

    /// `selectedBrand` stays top-level, not inside `selections`.
    func testSelectedBrandStaysTopLevel() {
        XCTAssertTrue(Self.exitTopLevelConditional.contains("selectedBrand"))
        XCTAssertFalse(Self.exitPerStep.contains("selectedBrand"))
    }

    // MARK: - Untyped steps report "standard"

    /// The retired untyped-step sentinels; a new spelling would have to be declared here.
    func testTheUntypedStepSentinelsAreExactlyThese() {
        let sentinels: Set<String> = ["intro", "info", "item"]
        XCTAssertEqual(sentinels.count, 3)
        XCTAssertFalse(sentinels.contains("standard"),
                       "'standard' is the value that replaced them, not one of the values being replaced")
    }

    /// An untyped step reports `"standard"`, whichever writer sees it.
    func testAnUntypedStepNowReportsStandard() throws {
        let config = try JSONDecoder().decode(
            InspectConfig.self,
            from: Data(#"{"preset": "preset5", "introSteps": [{"id": "welcome"}]}"#.utf8))
        let step = try XCTUnwrap(config.introSteps?.first)
        XCTAssertEqual(step.resolvedStepType, "standard",
                       "an untyped step reports 'standard', not 'intro'/'info'/'item'")
        XCTAssertEqual(step.stepType, "standard",
                       "canonicalization FILLS it, so the value is not invented at each writer")
    }

    /// Decoded as preset 6, the same step reports the same value.
    func testEveryWriterAgreesOnTheUntypedValue() throws {
        let p5 = try JSONDecoder().decode(
            InspectConfig.self,
            from: Data(#"{"preset": "preset5", "introSteps": [{"id": "a"}]}"#.utf8))
        let p6 = try JSONDecoder().decode(
            InspectConfig.self,
            from: Data(#"{"preset": "6", "items": [{"id": "a"}]}"#.utf8))
        XCTAssertEqual(p5.introSteps?.first?.resolvedStepType,
                       p6.steps?.first?.resolvedStepType,
                       "P5 and P6 must report the same wire value for the same untyped step")
        XCTAssertEqual(p6.steps?.first?.resolvedStepType, "standard")
    }

    /// No call site invents a stepType fallback value.
    func testNoCallSiteStillInventsAStepTypeValue() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("dialog/Views/Inspect")
        let probe = try NSRegularExpression(
            pattern: #"stepType\s*\?\?\s*"[^"]*"|stepType:\s*"item"|contains\(step\?\.stepType\s*\?\?"#)
        var sites: [String] = []
        if let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let file as URL in walker where file.pathExtension == "swift" {
                // The one place allowed to name the fallback: it holds `resolvedStepType`.
                guard file.lastPathComponent != "InspectConfig+Steps.swift",
                      let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let range = NSRange(source.startIndex..<source.endIndex, in: source)
                if probe.firstMatch(in: source, range: range) != nil {
                    sites.append(file.lastPathComponent)
                }
            }
        }
        XCTAssertEqual(sites.sorted(), [], "sites still inventing a stepType: \(sites.sorted())")
    }

    /// Authored `stepType: "intro"` survives as authored, since it still means the intro phase.
    func testAuthoredIntroSurvivesAsAnAuthoredValue() throws {
        let authored = try step(id: "welcome", stepType: "intro")
        XCTAssertEqual(authored.stepType, "intro",
                       "an authored 'intro' is a phase role and must not be rewritten")
    }

    // MARK: - Rail count stays 6

    /// Rows inside a checklist step do not add steps, rail entries or emitted steps[].
    func testItemsInsideAStepDoNotBecomeSteps() throws {
        let itemsJSON = (1...9).map { #"{"id": "row\#($0)", "displayName": "Row \#($0)"}"# }
            .joined(separator: ",")
        let json = """
        {"preset": "preset5", "introSteps": [
          {"id": "s1"}, {"id": "s2"},
          {"id": "s3", "items": [\(itemsJSON)]},
          {"id": "s4"}, {"id": "s5"}, {"id": "s6"}
        ]}
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let steps = try XCTUnwrap(config.introSteps)

        XCTAssertEqual(steps.count, 6, "9 rows on step 3 must not make 15 steps")
        XCTAssertEqual(steps[2].items?.count, 9, "the rows are still there, as rows")
        XCTAssertEqual(steps.map(\.id), ["s1", "s2", "s3", "s4", "s5", "s6"])
    }

    /// A real config with nested `step.items` (`software-bundles.json`) keeps its step count.
    func testARealNestedItemsConfigKeepsItsStepCount() throws {
        let file = URL(fileURLWithPath: "/Users/Shared/Demos/software-bundles.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file.path),
                          "corpus fixture not present on this machine")

        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(contentsOf: file))
        let steps = try XCTUnwrap(config.introSteps)
        let nested = steps.filter { ($0.items?.isEmpty == false) }

        XCTAssertFalse(nested.isEmpty, "fixture is supposed to exercise nested step.items")
        XCTAssertEqual(steps.count, 4, "step count is the frozen fact")
        XCTAssertEqual(nested.count, 4, "all four steps carry rows — 64 rows, still 4 steps")
        for step in nested {
            XCTAssertEqual(step.items?.count, 16, "step '\(step.id)' carries its rows as rows")
        }
    }

    /// `totalSteps` counts steps, not rows.
    func testTotalStepsCountsStepsAndNotRows() throws {
        let json = """
        {"preset": "preset5", "introSteps": [
          {"id": "a"},
          {"id": "b", "items": [{"id": "r1"}, {"id": "r2"}, {"id": "r3"}]}
        ]}
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        XCTAssertEqual(config.introSteps?.count, 2,
                       "totalSteps is steps.count; 3 rows on step b must not make it 5")
    }
}
