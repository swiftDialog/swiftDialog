//
//  WindowAndButtonActionConfigTests.swift
//  dialogTests
//

import XCTest
@testable import Dialog

/// The `options` window flags and button actions a config can author instead of CLI flags.
final class WindowAndButtonActionConfigTests: XCTestCase {
    private func config(_ json: String) throws -> InspectConfig {
        try JSONDecoder().decode(InspectConfig.self, from: Data(json.utf8))
    }

    func testWindowOptionsAndButtonKeysDecode() throws {
        let c = try config(#"{"preset":"1","options":{"moveable":true,"ontop":true,"windowbuttons":"min,max"},"button1Action":"minimize","button2Action":"exit","items":[]}"#)
        XCTAssertEqual(c.options?["moveable"]?.boolValue, true)
        XCTAssertEqual(c.options?["ontop"]?.boolValue, true)
        XCTAssertEqual(c.options?["windowbuttons"]?.stringValue, "min,max")
        XCTAssertEqual(c.button1Action, "minimize")
        XCTAssertEqual(c.button2Action, "exit")
        let bare = try config(#"{"preset":"1","items":[]}"#)
        XCTAssertNil(bare.options); XCTAssertNil(bare.button1Action)
    }

    /// Quoted booleans inside `options` read as flags: "true"/"yes"/1 and "false"/"no"/0.
    func testQuotedBooleansReadAsFlagsInsideOptions() throws {
        let c = try config(#"{"preset":"1","options":{"ontop":"true","moveable":"yes","resizable":1,"windowbuttons":"no"},"items":[]}"#)
        XCTAssertEqual(c.options?["ontop"]?.boolValue, true)
        XCTAssertEqual(c.options?["moveable"]?.boolValue, true)
        XCTAssertEqual(c.options?["resizable"]?.boolValue, true)
        XCTAssertEqual(c.options?["windowbuttons"]?.boolValue, false)
        XCTAssertNil(OptionValue.string("maybe").boolValue)
    }

    func testOnlyMinimizeReplacesAnExit() {
        XCTAssertTrue(ButtonExit.minimizes("minimize"))
        XCTAssertTrue(ButtonExit.minimizes("Minimise"))
        XCTAssertFalse(ButtonExit.minimizes("exit"))
        XCTAssertFalse(ButtonExit.minimizes(nil))
        XCTAssertFalse(ButtonExit.minimizes("close"))
    }
}
