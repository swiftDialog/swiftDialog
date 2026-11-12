//
//  PhaseSpecTests.swift
//  dialogTests
//
//  What a phase may say about itself: a plain name, or a rich element carrying its own time and
//  state. Both shapes stay legal and mix in one array.
//

import XCTest
@testable import Dialog

final class PhaseSpecTests: XCTestCase {

    private func block(_ json: String) throws -> InspectConfig.GuidanceContent {
        try JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: Data(json.utf8))
    }

    // MARK: - Legacy shape

    func testAStringArrayStillDecodes() throws {
        let b = try block(#"{"type":"phase-tracker","phases":["Available","Downloaded","Done"]}"#)
        XCTAssertEqual(b.phases?.map(\.label), ["Available", "Downloaded", "Done"])
    }

    func testAStringPhaseCarriesNothingElse() throws {
        let b = try block(#"{"type":"phase-tracker","phases":["Available"]}"#)
        let phase = try XCTUnwrap(b.phases?.first)
        XCTAssertNil(phase.time, "a string phase has no time — that is the point")
        XCTAssertNil(phase.detail)
        XCTAssertNil(phase.state)
    }

    // MARK: - Rich shape

    func testAnObjectPhaseCarriesTimeDetailAndState() throws {
        let b = try block("""
        {"type":"phase-tracker","phases":[
          {"label":"Downloading","time":"now · 62%","state":"current",
           "detail":"3.4 of 5.5 GB. Nothing changes on the Mac until tonight."}]}
        """)
        let phase = try XCTUnwrap(b.phases?.first)
        XCTAssertEqual(phase.label, "Downloading")
        XCTAssertEqual(phase.time, "now · 62%")
        XCTAssertEqual(phase.state, .current)
        XCTAssertEqual(phase.detail, "3.4 of 5.5 GB. Nothing changes on the Mac until tonight.")
    }

    /// Strings and rich elements mix in one array.
    func testTheTwoShapesMixInOneArray() throws {
        let b = try block("""
        {"type":"phase-tracker","phases":[
          "Available",
          {"label":"Downloading","time":"now · 62%"},
          "Done"]}
        """)
        XCTAssertEqual(b.phases?.map(\.label), ["Available", "Downloading", "Done"])
        XCTAssertNil(b.phases?[0].time)
        XCTAssertEqual(b.phases?[1].time, "now · 62%")
    }

    func testAnObjectWithOnlyALabelIsTheSameAsAString() throws {
        let a = try block(#"{"type":"phase-tracker","phases":["Install"]}"#)
        let b = try block(#"{"type":"phase-tracker","phases":[{"label":"Install"}]}"#)
        XCTAssertEqual(a.phases, b.phases)
    }

    // MARK: - State vocabulary
    // Failure is a state of a real phase, never an extra phase, so the track length never changes.

    func testEveryAuthoredStateDecodes() throws {
        for raw in ["done", "current", "pending", "blocked", "failed"] {
            let b = try block("""
            {"type":"phase-tracker","phases":[{"label":"X","state":"\(raw)"}]}
            """)
            XCTAssertEqual(b.phases?.first?.state?.rawValue, raw)
        }
    }

    /// An unknown state is nil, so position derives from `currentPhase`.
    func testAnUnknownStateIsNil() throws {
        let b = try block(#"{"type":"phase-tracker","phases":[{"label":"X","state":"exploded"}]}"#)
        XCTAssertNil(b.phases?.first?.state)
    }

    /// An element that is neither string nor object is skipped, not fatal to the block.
    func testAnElementThatIsNeitherStringNorObjectIsSkipped() throws {
        let b = try block(#"{"type":"phase-tracker","phases":["Available",42,"Done"]}"#)
        XCTAssertEqual(b.phases?.map(\.label), ["Available", "Done"])
    }

    // MARK: - Schema allows both shapes

    func testTheSchemaDeclaresBothPhaseShapes() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("dialog/Views/Inspect/inspect-config.schema.json")
        let schema = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let defs = try XCTUnwrap((schema as? [String: Any])?["definitions"] as? [String: Any])
        let gc = try XCTUnwrap(defs["GuidanceContent"] as? [String: Any])
        let props = try XCTUnwrap(gc["properties"] as? [String: Any])
        let phases = try XCTUnwrap(props["phases"] as? [String: Any])
        let items = try XCTUnwrap(phases["items"] as? [String: Any])
        let oneOf = try XCTUnwrap(items["oneOf"] as? [[String: Any]],
                                  "phases items must accept a string OR an object, or the rich "
                                  + "form is unauthorable")
        XCTAssertEqual(oneOf.count, 2)
        XCTAssertTrue(oneOf.contains { $0["type"] as? String == "string" })
        XCTAssertTrue(oneOf.contains { $0["type"] as? String == "object" })
    }
}
