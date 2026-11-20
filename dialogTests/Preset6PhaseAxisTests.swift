//
//  Preset6PhaseAxisTests.swift
//  dialogTests
//
//  `phase` in Preset 6: `phase` carries the role (which end of the flow), `stepType` the renderer.
//  Decode is unit-tested; that no P6 site reads a role off stepType is checked on the source.
//

import XCTest
@testable import Dialog

final class Preset6PhaseAxisTests: XCTestCase {

    // MARK: - Phase on an item

    private func item(_ json: String,
                      file: StaticString = #filePath, line: UInt = #line) throws -> InspectConfig.ItemConfig {
        let cfg = #"{"preset": "6", "items": [\#(json)]}"#
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(cfg.utf8))
        return try XCTUnwrap(config.items.first, file: file, line: line)
    }

    /// Absent phase is `main`.
    func testAbsentPhaseResolvesToMain() throws {
        XCTAssertEqual(try item(#"{"id": "a", "displayName": "A"}"#).resolvedPhase, "main")
    }

    func testAuthoredPhaseWins() throws {
        XCTAssertEqual(try item(#"{"id": "a", "phase": "intro"}"#).resolvedPhase, "intro")
        XCTAssertEqual(try item(#"{"id": "a", "phase": "outro"}"#).resolvedPhase, "outro")
        XCTAssertEqual(try item(#"{"id": "a", "phase": "main"}"#).resolvedPhase, "main")
    }

    /// Legacy `stepType: "intro"|"outro"` still carries the role.
    func testLegacyStepTypeStillCarriesTheRole() throws {
        XCTAssertEqual(try item(#"{"id": "a", "stepType": "intro"}"#).resolvedPhase, "intro")
        XCTAssertEqual(try item(#"{"id": "a", "stepType": "outro"}"#).resolvedPhase, "outro")
    }

    /// A renderer in `stepType` implies no phase.
    func testRendererStepTypeDoesNotImplyAPhase() throws {
        XCTAssertEqual(try item(#"{"id": "a", "stepType": "processing"}"#).resolvedPhase, "main")
        XCTAssertEqual(try item(#"{"id": "a", "stepType": "info"}"#).resolvedPhase, "main")
    }

    /// Phase and renderer are independent: an outro can show a processing screen.
    func testPhaseAndRendererAreIndependent() throws {
        let outroProcessing = try item(#"{"id": "a", "phase": "outro", "stepType": "processing"}"#)
        XCTAssertEqual(outroProcessing.resolvedPhase, "outro")
        XCTAssertEqual(outroProcessing.stepType, "processing")
    }

    /// `phase` is a known item key, so authoring it raises no unknown-key warning.
    func testPhaseIsAKnownItemKey() {
        XCTAssertTrue(InspectConfig.knownItemKeys.contains("phase"))
    }

    // MARK: - No P6 site reads a role off stepType

    /// `stepType` may be compared to renderer names in P6, never to "intro" or "outro".
    func testNoPreset6SiteReadsARoleOffStepType() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/Preset Layouts")

        // `stepType` compared against a phase word, in any direction, plus switch arms.
        let probe = try NSRegularExpression(
            pattern: #"stepType\s*(?:==|!=)\s*"(?:intro|outro)"|case\s+"(?:intro|outro)""#)

        var sites: [String] = []
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "swift"
            && file.lastPathComponent.hasPrefix("Preset6") {
            guard let source = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            if probe.firstMatch(in: source, range: range) != nil {
                sites.append(file.lastPathComponent)
            }
        }
        XCTAssertEqual(sites.sorted(), [],
                       "P6 sites still reading a role off stepType: \(sites.sorted())")
    }

    // MARK: - Stale validator

    /// `Config+Helpers.swift` has no P6 stepType allow-list that would call `intro`/`outro` invalid.
    func testTheStaleP6StepTypeValidatorIsGone() throws {
        let source = try String(
            contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("dialog/Views/Inspect/Services/Config+Helpers.swift"),
            encoding: .utf8)
        XCTAssertFalse(source.contains(#""confirmation", "processing", "completion""#),
                       "the stale P6 stepType allow-list must not come back")
    }

    /// A P6 item authoring its phase role is not warned about.
    func testAuthoringAPhaseRoleProducesNoWarning() throws {
        let cfg = """
        {"preset": "6", "items": [
          {"id": "welcome", "displayName": "Welcome", "phase": "intro"},
          {"id": "work", "displayName": "Work"},
          {"id": "done", "displayName": "Done", "phase": "outro"}
        ]}
        """
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(cfg.utf8))
        let warnings = Config().validateItems(config.items, preset: "6")
        let stepTypeWarnings = warnings.filter { $0.contains("stepType") }
        XCTAssertEqual(stepTypeWarnings, [],
                       "a P6 item naming its phase must not be warned about: \(stepTypeWarnings)")
    }
}
