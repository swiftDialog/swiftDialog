//
//  ListItemDecodeTests.swift
//  dialogTests
//
//  How a `ListItem` (a row in `IntroStep.items`) decodes: its own `kind` axis, and the detection
//  payload that makes it watchable.
//

import XCTest
@testable import Dialog

final class ListItemDecodeTests: XCTestCase {

    override func setUp() {
        super.setUp()
        InspectConfig.unknownKeyWarnings = []
    }

    override func tearDown() {
        InspectConfig.unknownKeyWarnings = []
        super.tearDown()
    }

    // MARK: - Helpers

    /// Decodes one row through a real config, the path the app uses.
    private func row(_ itemJSON: String,
                     file: StaticString = #filePath, line: UInt = #line) throws -> InspectConfig.ListItem {
        let json = #"{"preset": "preset5", "introSteps": [{"id": "s1", "items": [\#(itemJSON)]}]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
        let items = try XCTUnwrap(config.introSteps?.first?.items, file: file, line: line)
        return try XCTUnwrap(items.first, file: file, line: line)
    }

    private var warnings: [String] { InspectConfig.unknownKeyWarnings }

    private func warned(containing needle: String) -> Bool {
        warnings.contains { $0.contains(needle) }
    }

    // MARK: - kind

    /// Absent `kind` is a plain row.
    func testKindIsAbsentByDefault() throws {
        let item = try row(#"{"id": "r1", "displayName": "Row"}"#)
        XCTAssertNil(item.kind, "an unmarked row has no kind")
        XCTAssertTrue(warnings.isEmpty, "a plain row must not produce advisories: \(warnings)")
    }

    func testEachKindValueDecodes() throws {
        for kind in InspectConfig.ListItem.Kind.allCases {
            InspectConfig.unknownKeyWarnings = []
            let item = try row(#"{"id": "r1", "kind": "\#(kind.rawValue)"}"#)
            XCTAssertEqual(item.kind, kind, "'\(kind.rawValue)' must decode to itself")
            XCTAssertTrue(warnings.isEmpty, "a well-formed kind must not warn: \(warnings)")
        }
    }

    /// An unknown `kind` becomes a plain row with an advisory.
    func testUnknownKindFallsBackToPlainRowWithAnAdvisory() throws {
        let item = try row(#"{"id": "r1", "kind": "sparkle"}"#)
        XCTAssertNil(item.kind, "an unknown kind must not survive as a kind")
        XCTAssertTrue(warned(containing: "kind 'sparkle'"),
                      "the unknown value must be named in an advisory: \(warnings)")
    }

    // MARK: - Legacy stepType

    /// Legacy `stepType` spellings of the row kinds fold onto `kind` with an advisory.
    func testLegacyStepTypeSpellingsFoldOntoKind() throws {
        let cases: [(String, InspectConfig.ListItem.Kind)] = [
            ("info", .info), ("confirmation", .confirmation), ("completion", .completion)
        ]
        for (legacy, expected) in cases {
            InspectConfig.unknownKeyWarnings = []
            let item = try row(#"{"id": "r1", "stepType": "\#(legacy)"}"#)
            XCTAssertEqual(item.kind, expected, "'stepType: \(legacy)' is a row kind")
            XCTAssertTrue(warned(containing: "folded to 'kind'"),
                          "the fold must be advisory, not silent: \(warnings)")
        }
    }

    /// A renderer or phase-role `stepType` on a row is inert and reported as such.
    func testNonKindStepTypeOnARowIsReportedInert() throws {
        for legacy in ["processing", "intro", "outro", "installation"] {
            InspectConfig.unknownKeyWarnings = []
            let item = try row(#"{"id": "r1", "stepType": "\#(legacy)"}"#)
            XCTAssertNil(item.kind, "'\(legacy)' is not a row kind")
            XCTAssertTrue(warned(containing: "inert"),
                          "'\(legacy)' on a row must be reported inert: \(warnings)")
        }
    }

    func testKindWinsOverLegacyStepTypeAndSaysSo() throws {
        let item = try row(#"{"id": "r1", "kind": "completion", "stepType": "info"}"#)
        XCTAssertEqual(item.kind, .completion, "'kind' is the canonical axis")
        XCTAssertTrue(warned(containing: "'kind' wins"),
                      "authoring both must be advisory: \(warnings)")
    }

    // MARK: - Row shape

    /// `title` aliases displayName; a row with only a path falls back to its id.
    func testDisplayNameAliasAndFallback() throws {
        XCTAssertEqual(try row(#"{"id": "r1", "title": "From title"}"#).displayName, "From title")
        XCTAssertEqual(try row(#"{"id": "r1"}"#).displayName, "r1",
                       "no name and no alias falls back to the id")
    }

    func testDefaultsMatchTheItemContract() throws {
        let item = try row(#"{"id": "r1"}"#)
        XCTAssertEqual(item.guiIndex, 0, "guiIndex defaults to 0")
        XCTAssertEqual(item.paths, [], "paths defaults to empty, not nil")
    }

    /// The detection fields `MonitoredItem` exposes decode on a row.
    func testDetectionPayloadDecodes() throws {
        let item = try row("""
        {"id": "slack", "displayName": "Slack", "paths": ["/Applications/Slack.app"],
         "plistKey": "Installed", "expectedValue": "true", "evaluation": "boolean",
         "showBundleInfo": "version", "openURL": "slack://open", "satisfy": "any",
         "requirements": [{"type": "app", "bundleId": "com.tinyspeck.slackmacgap"}]}
        """)
        XCTAssertEqual(item.paths, ["/Applications/Slack.app"])
        XCTAssertEqual(item.plistKey, "Installed")
        XCTAssertEqual(item.evaluation, "boolean")
        XCTAssertEqual(item.showBundleInfo, "version")
        XCTAssertEqual(item.openURL, "slack://open")
        XCTAssertEqual(item.satisfy, "any")
        XCTAssertEqual(item.requirements?.count, 1)
        XCTAssertEqual(item.requirements?.first?.bundleId, "com.tinyspeck.slackmacgap")
    }

    /// A `ListItem` is a `MonitoredItem`, watched by the same services as an `ItemConfig`.
    func testARowIsAMonitoredItem() throws {
        let item = try row(#"{"id": "r1", "paths": ["/tmp/x"]}"#)
        let watched: any MonitoredItem = item
        XCTAssertEqual(watched.id, "r1")
        XCTAssertEqual(watched.paths, ["/tmp/x"])
    }

    // MARK: - Unknown keys

    /// A misspelled key on a row is reported, as on a step.
    func testUnknownKeyOnARowIsReported() throws {
        _ = try row(#"{"id": "r1", "wallpaperCategories": ["a"]}"#)
        XCTAssertTrue(warned(containing: "Unknown key 'wallpaperCategories' in row 'r1'"),
                      "unknown row keys must be reported: \(warnings)")
    }

    /// Step-only keys (`cardPanel`, `footerNote`) are unknown on a row.
    func testStepOnlyKeysAreUnknownOnARow() throws {
        _ = try row(#"{"id": "r1", "cardPanel": {}, "footerNote": "x"}"#)
        XCTAssertTrue(warned(containing: "'cardPanel' in row 'r1'"), "\(warnings)")
        XCTAssertTrue(warned(containing: "'footerNote' in row 'r1'"), "\(warnings)")
    }
}
