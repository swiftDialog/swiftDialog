//
//  IconJSONTests.swift
//  dialogTests
//
//  Covers the JSON-object icon value converter (IconJSON.swift): JSON objects map to the legacy
//  icon string, and every non-JSON value passes through unchanged (backward compatibility).
//

import XCTest
@testable import Dialog

final class IconJSONTests: XCTestCase {

    // MARK: - JSON object -> legacy string

    func testSymbolWithColourAndWeight() {
        XCTAssertEqual(normalizedIconValue(#"{"sf":"gear","colour":"blue","weight":"bold"}"#),
                       "SF=gear,weight=bold,colour=blue")
    }

    func testColorAmericanSpellingAccepted() {
        XCTAssertEqual(normalizedIconValue(##"{"sf":"gear","color":"#00A4C7"}"##),
                       "SF=gear,colour=#00A4C7")
    }

    func testNameAliasForSymbol() {
        XCTAssertEqual(normalizedIconValue(#"{"name":"bolt.fill"}"#), "SF=bolt.fill")
    }

    // Regression guard: palette must be comma-joined (the parser splits palette on ",").
    func testPaletteArrayIsCommaJoined() {
        XCTAssertEqual(normalizedIconValue(#"{"sf":"gear","palette":["red","green","blue"]}"#),
                       "SF=gear,palette=red,green,blue")
    }

    func testAutoBecomesColourAuto() {
        XCTAssertEqual(normalizedIconValue(#"{"sf":"gear","auto":true}"#), "SF=gear,colour=auto")
    }

    func testExplicitColourWinsOverAuto() {
        XCTAssertEqual(normalizedIconValue(#"{"sf":"gear","auto":true,"colour":"red"}"#),
                       "SF=gear,colour=red")
    }

    func testNonSymbolPathPassthrough() {
        XCTAssertEqual(normalizedIconValue(#"{"path":"/Applications/Chess.app"}"#),
                       "/Applications/Chess.app")
        XCTAssertEqual(normalizedIconValue(#"{"icon":"none"}"#), "none")
    }

    func testLightDarkObjects() {
        XCTAssertEqual(normalizedIconValue(#"{"light":{"sf":"sun.max"},"dark":{"sf":"moon","colour":"white"}}"#),
                       "SF=sun.max:dark=SF=moon,colour=white")
    }

    func testLightDarkPlainStrings() {
        XCTAssertEqual(normalizedIconValue(#"{"light":"a.png","dark":"b.png"}"#), "a.png:dark=b.png")
    }

    // MARK: - Fall-through: non-JSON values returned unchanged (backward compatibility)

    func testExistingStringFormsUnchanged() {
        let unchanged = [
            "SF=gear,colour=blue",
            "/path/to/image.png",
            "qr=https://example.com",
            "text={hi}",              // starts with text=, not {
            "warning",
            "a.png:dark=b.png",
            "{nope",                  // invalid JSON
            #"["a","b"]"#,            // JSON array, not an object
            "{"                        // bare brace
        ]
        for value in unchanged {
            XCTAssertEqual(normalizedIconValue(value), value, "should pass through unchanged: \(value)")
        }
    }

    func testEmptyObjectYieldsEmpty() {
        XCTAssertEqual(normalizedIconValue("{}"), "")
    }
}

final class ButtonSymbolJSONTests: XCTestCase {

    func testNameColourPosition() {
        XCTAssertEqual(normalizedButtonSymbol(#"{"name":"checkmark.circle","colour":"green","position":"trailing"}"#),
                       "checkmark.circle,trailing,colour=green")
    }

    // Button palettes are dash-joined (the parser splits button palettes on "-").
    func testPaletteIsDashJoined() {
        XCTAssertEqual(normalizedButtonSymbol(#"{"name":"paintpalette","rendering":"palette","palette":["red","green","blue"]}"#),
                       "paintpalette,palette,palette=red-green-blue")
    }

    func testSizeAndSfAlias() {
        XCTAssertEqual(normalizedButtonSymbol(#"{"sf":"gear","size":20}"#), "gear,size=20")
    }

    func testNonJSONUnchanged() {
        for value in ["gear,trailing,colour=red", "gear", "{nope", #"["a"]"#] {
            XCTAssertEqual(normalizedButtonSymbol(value), value, "should pass through: \(value)")
        }
    }
}
