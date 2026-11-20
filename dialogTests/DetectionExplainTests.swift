//
//  DetectionExplainTests.swift
//  dialogTests
//
//  The detection explainer behind --inspect-lint --explain.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - The explain report

/// `--explain` answers "why does my row never move" using the product's own matcher.
final class DetectionExplainTests: XCTestCase {

    private func config(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    /// An absent path is reported.
    func testAnAbsentPathIsReported() throws {
        let c = try config(#"{"preset":"5","items":[{"id":"ghost","displayName":"Ghost","paths":["/private/tmp/definitely-not-here.app"]}]}"#)
        let report = DetectionExplain.report(for: c)
        XCTAssertTrue(report.contains("ghost"))
        XCTAssertTrue(report.uppercased().contains("ABSENT"))
    }

    /// A present path is not reported as a fault.
    func testAPresentPathIsNotAFault() throws {
        let c = try config(#"{"preset":"5","items":[{"id":"apps","displayName":"Applications","paths":["/Applications"]}]}"#)
        XCTAssertFalse(DetectionExplain.report(for: c).uppercased().contains("ABSENT"))
    }

    /// The report offers a filename the real matcher accepts.
    func testItOffersAFilenameTheRealMatcherAccepts() throws {
        let c = try config(#"{"preset":"5","cachePaths":["/private/tmp"],"items":[{"id":"edr","displayName":"Endpoint Detection and Response Agent","paths":["/private/tmp/EDR.app"]}]}"#)
        let report = DetectionExplain.report(for: c)
        let suggested = report.split(separator: "\n")
            .first { $0.contains("accepts") }.map(String.init)
        let name = try XCTUnwrap(suggested, "the report must offer an accepted filename")
        // The real matcher has to accept it.
        let candidate = name.split(separator: " ").last.map(String.init) ?? ""
        XCTAssertTrue(FilenameMatching.matches(itemId: "edr",
                                               displayName: "Endpoint Detection and Response Agent",
                                               filename: candidate, brandFuzzy: true, log: { _ in }),
                      "the report offered \(candidate), which the product's own matcher rejects")
    }

    /// Requirements are evaluated with the runtime evaluator: met or not, what decides, and a waiting row is a
    /// fault. Paths are then not checked, so an absent one is no fault of its own.
    func testRequirementsAreEvaluatedAndDecideTheRow() throws {
        let waiting = try config(#"{"preset":"1","items":[{"id":"wins","displayName":"Wins","paths":["/Applications"],"#
            + #""requirements":[{"type":"path","paths":["/private/tmp/explain-not-here.marker"]}]}]}"#)
        let report = DetectionExplain.evaluate(for: waiting)
        XCTAssertTrue(report.text.contains("(not used: requirements decide)"), report.text)
        XCTAssertTrue(report.text.contains("NOT MET"), report.text)
        XCTAssertTrue(report.text.contains("all must pass: 0 of 1 met, the row WAITS"), report.text)
        XCTAssertEqual(report.faults, 1, "the waiting row is the one fault; its present path is not counted")

        let anyOne = try config(#"{"preset":"1","items":[{"id":"any","displayName":"Any","paths":["/private/tmp/gone.app"],"#
            + #""satisfy":"any","requirements":[{"type":"path","paths":["/Applications"]},"#
            + #"{"type":"path","paths":["/private/tmp/explain-not-here.marker"]}]}]}"#)
        let done = DetectionExplain.evaluate(for: anyOne)
        XCTAssertTrue(done.text.contains("any one must pass: 1 of 2 met, the row completes"), done.text)
        XCTAssertEqual(done.faults, 0, "an absent path does not count when requirements decide")
    }

    /// Step items are reported too.
    func testStepItemsAreReportedToo() throws {
        let c = try config(#"{"preset":"5","introSteps":[{"id":"deploy","stepType":"carousel","items":[{"id":"ghost","displayName":"Ghost","paths":["/private/tmp/definitely-not-here.app"]}]}]}"#)
        let report = DetectionExplain.report(for: c)
        XCTAssertTrue(report.contains("items: 1"), "a stepped config's rows must be counted")
        XCTAssertTrue(report.uppercased().contains("ABSENT"))
    }
}
