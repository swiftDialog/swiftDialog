//
//  Preset6StepAdoptionTests.swift
//  dialogTests
//
//  Preset 6's root list decodes as steps, one for one. Resume is index-based, so decoding must
//  never merge, split or synthesise a step.
//

import XCTest
@testable import Dialog

final class Preset6StepAdoptionTests: XCTestCase {

    private func config(_ json: String,
                        file: StaticString = #filePath, line: UInt = #line) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    // MARK: - Count preservation

    /// Same entries in, same steps out, same order.
    func testPreset6RootItemsDecodeAsStepsOneForOne() throws {
        let c = try config("""
        {"preset": "6", "items": [
          {"id": "welcome", "displayName": "Welcome", "stepType": "intro"},
          {"id": "config", "displayName": "Configure"},
          {"id": "install", "displayName": "Install", "stepType": "processing"},
          {"id": "done", "displayName": "Done", "stepType": "outro"}
        ]}
        """)
        let steps = try XCTUnwrap(c.steps)
        XCTAssertEqual(steps.count, 4, "four entries in, four steps out")
        XCTAssertEqual(steps.map(\.id), ["welcome", "config", "install", "done"],
                       "order is the authored order")
        XCTAssertEqual(c.items.count, 4, "the row list still decodes too, for one release")
    }

    /// `guiIndex` sets the display order (documented as required in 3.1.1); ties keep file order.
    func testPreset6ItemsFollowGuiIndex() throws {
        let c = try config("""
        {"preset": "6", "items": [
          {"id": "done", "displayName": "Done", "guiIndex": 3},
          {"id": "welcome", "displayName": "Welcome", "guiIndex": 0},
          {"id": "b", "displayName": "B", "guiIndex": 1},
          {"id": "a", "displayName": "A", "guiIndex": 1}
        ]}
        """)
        XCTAssertEqual(try XCTUnwrap(c.steps).map(\.id), ["welcome", "b", "a", "done"])
    }

    /// `steps[]` and `items[]` decode to the same steps.
    func testStepsKeyAndItemsKeyAgree() throws {
        let body = """
        [{"id": "a", "displayName": "A", "phase": "intro"},
         {"id": "b", "displayName": "B"},
         {"id": "c", "displayName": "C", "phase": "outro"}]
        """
        let viaItems = try XCTUnwrap(try config(#"{"preset": "6", "items": \#(body)}"#).steps)
        let viaSteps = try XCTUnwrap(try config(#"{"preset": "6", "steps": \#(body)}"#).steps)
        XCTAssertEqual(viaItems.map(\.id), viaSteps.map(\.id))
        XCTAssertEqual(viaItems.map(\.resolvedPhase), viaSteps.map(\.resolvedPhase))
        XCTAssertEqual(viaItems.map(\.title), viaSteps.map(\.title))
    }

    /// In presets 1-4 root `items[]` is a row list, not steps.
    func testPresets1To4RootItemsAreNotSteps() throws {
        for preset in ["1", "2", "3", "4"] {
            let c = try config(#"{"preset": "\#(preset)", "items": [{"id": "a", "displayName": "A"}, {"id": "b", "displayName": "B"}]}"#)
            XCTAssertNil(c.steps, "preset \(preset)'s items[] are rows, not steps")
            XCTAssertEqual(c.items.count, 2)
        }
    }

    /// Named P6 aliases ("guidance") decode steps too.
    func testNamedPreset6AliasesAlsoDecodeSteps() throws {
        for alias in ["6", "preset6", "guidance", "modern-sidebar"] {
            let c = try config(#"{"preset": "\#(alias)", "items": [{"id": "a", "displayName": "A"}]}"#)
            XCTAssertEqual(c.steps?.count, 1, "'\(alias)' is preset 6")
        }
    }

    // MARK: - Item vocabulary folds onto step fields

    /// A P6 item's keys become step fields at decode, so renderers see one dialect.
    func testItemVocabularyFoldsOntoStepFields() throws {
        let c = try config("""
        {"preset": "6", "items": [{
          "id": "a", "displayName": "Configure Settings", "icon": "SF=gear",
          "guidanceContent": [{"type": "text", "content": "Body"}],
          "itemOverlay": {"enabled": true, "title": "More"}
        }]}
        """)
        let step = try XCTUnwrap(c.steps?.first)
        XCTAssertEqual(step.heroImage, "SF=gear", "icon fed IntroHeroImage — so it IS heroImage")
        XCTAssertEqual(step.content?.count, 1, "guidanceContent is content")
        XCTAssertNotNil(step.stepOverlay, "itemOverlay is the step's disclosure")

        // Consumed, so only one spelling survives canonicalization.
        XCTAssertNil(step.icon)
        XCTAssertNil(step.itemOverlay)
    }

    /// `displayName` (rail label) and `title` (heading) stay separate; configs author both with different values.
    func testDisplayNameAndTitleAreSeparateFacts() throws {
        let c = try config("""
        {"preset": "6", "items": [{
          "id": "detected", "displayName": "Migration", "guidanceTitle": "Device Migration"
        }]}
        """)
        let step = try XCTUnwrap(c.steps?.first)
        XCTAssertEqual(step.displayName, "Migration", "the short rail label survives")
        XCTAssertEqual(step.title, "Device Migration", "the long heading survives")
        XCTAssertNotEqual(step.displayName, step.title,
                          "these are two facts, and the UI renders both at once")
    }

    /// A real config whose short rail labels depend on that.
    func testSecurityComplianceKeepsItsShortRailLabels() throws {
        let file = URL(fileURLWithPath: "/Users/Shared/Demos/preset6-security-compliance.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file.path),
                          "corpus fixture not present on this machine")
        let c = try JSONDecoder().decode(InspectConfig.self, from: Data(contentsOf: file))
        let dashboard = try XCTUnwrap(c.steps?.first { $0.id == "dashboard" })
        XCTAssertEqual(dashboard.displayName, "Dashboard", "the rail label")
        XCTAssertEqual(dashboard.title, "Compliance Dashboard", "the screen heading")
    }

    /// `completedStatus` stays under its own name; no step field means the same thing.
    func testCompletedStatusSurvivesUnderItsOwnName() throws {
        let c = try config(#"{"preset": "6", "items": [{"id": "a", "completedStatus": "Ready"}]}"#)
        XCTAssertEqual(c.steps?.first?.completedStatus, "Ready")
    }

    /// The per-step engine flags P6 depends on decode on a step.
    func testEngineFlagsDecodeOnAStep() throws {
        let c = try config("""
        {"preset": "6", "items": [{"id": "a", "observeOnly": true,
          "allowNavigationDuringProcessing": false, "group": "Setup"}]}
        """)
        let step = try XCTUnwrap(c.steps?.first)
        XCTAssertEqual(step.observeOnly, true)
        XCTAssertEqual(step.allowNavigationDuringProcessing, false)
        XCTAssertEqual(step.group, "Setup")
    }

    // MARK: - Row kinds do not become steps

    /// `confirm`/`done` row kinds on a P6 item do not change the screen count.
    func testRowKindValuesDoNotChangeTheStepCount() throws {
        let c = try config("""
        {"preset": "6", "items": [
          {"id": "guide", "displayName": "Guide"},
          {"id": "confirm", "displayName": "Confirm", "stepType": "confirmation"},
          {"id": "done", "displayName": "Done", "stepType": "completion"}
        ]}
        """)
        XCTAssertEqual(c.steps?.count, 3, "a row kind is not a reason to add or drop a screen")
        XCTAssertEqual(c.steps?.map(\.id), ["guide", "confirm", "done"])
    }

    /// The one real config that authors row kinds keeps its step count.
    func testCapabilityTourKeepsItsStepCount() throws {
        let file = URL(fileURLWithPath: "/Users/Shared/Demos/preset6-capability-tour.json")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: file.path),
                          "corpus fixture not present on this machine")
        let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        let authored = (raw?["items"] as? [[String: Any]])?.count
            ?? (raw?["steps"] as? [[String: Any]])?.count
        let c = try JSONDecoder().decode(InspectConfig.self, from: Data(contentsOf: file))
        XCTAssertEqual(c.steps?.count, authored,
                       "decoded step count must equal the authored entry count")
    }

    // MARK: - Nothing is synthesised

    /// Canonicalization may rewrite a step but never insert one.
    func testCanonicalizationNeverChangesTheStepCount() throws {
        let c = try config("""
        {"preset": "6", "items": [
          {"id": "a", "phase": "intro"}, {"id": "b"}, {"id": "c"},
          {"id": "d", "stepType": "processing"}, {"id": "e", "phase": "outro"}
        ]}
        """)
        XCTAssertEqual(c.steps?.count, 5)
        var advisories: [String] = []
        let again = InspectConfig.canonicalizeSteps(c.steps)
        XCTAssertEqual(again?.count, 5, "a second pass adds nothing")
        _ = advisories
    }

    /// P6's sidebar, outside `Preset Layouts/`, reads the role axis too.
    func testPreset6SidebarReadsTheRoleAxisToo() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("dialog/Views/Inspect/Core Framework/Modules/SidebarNavigationModule.swift"),
            encoding: .utf8)
        XCTAssertFalse(source.contains(#"stepType != "intro""#),
                       "the sidebar's bookend filter must ask the role axis")
        XCTAssertTrue(source.contains(#"resolvedPhase == "main""#))
    }
}
