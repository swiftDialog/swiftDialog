//
//  InspectPresetNameTests.swift
//  dialogTests
//

import XCTest
@testable import Dialog

/// One table names the presets: every spelling the router opens sizes as its engine and validates.
final class InspectPresetNameTests: XCTestCase {
    func testEverySpellingSizesAsItsEngineAndValidatesAsKnown() throws {
        for (number, names) in InspectPresetName.spellings {
            let engine = number == 7 ? 5 : number
            for name in names + names.map { $0.uppercased() } {
                XCTAssertEqual(InspectPresetName.number(name), number, name)
                XCTAssertEqual(InspectSizes.normalizePreset(name), "preset\(engine)", name)
                let config = try JSONDecoder().decode(InspectConfig.self,
                    from: Data(#"{"preset":"\#(name)","items":[]}"#.utf8))
                let warnings = Config().validateConfiguration(config)
                XCTAssertFalse(warnings.contains { $0.contains("Unknown preset") }, "\(name): \(warnings)")
            }
        }
    }

    func testAnUnknownNameIsReportedAndOpensPreset1() throws {
        XCTAssertNil(InspectPresetName.number("dashboard"))
        let config = try JSONDecoder().decode(InspectConfig.self, from: Data(#"{"preset":"dashboard","items":[]}"#.utf8))
        XCTAssertTrue(Config().validateConfiguration(config).contains { $0.contains("Unknown preset") })
        XCTAssertEqual(Config().normalizePreset("dashboard"), "1")
    }
}
