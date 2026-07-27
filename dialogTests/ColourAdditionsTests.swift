//
//  ColourAdditionsTests.swift
//  dialogTests
//
//  Unit tests for Color parsing/derivation helpers (backlog M5, Tier 1).
//  Comparisons use hexValue round-trips and sRGB-constructed colours to avoid
//  the monochrome-colourspace pitfall of Color.black/.white.
//

import XCTest
import SwiftUI
@testable import Dialog

final class ColourAdditionsTests: XCTestCase {

    // MARK: - Color(argument:)

    func testArgumentHexRoundTrips() {
        XCTAssertEqual(Color(argument: "#FF0000").hexValue, "#FF0000")
        XCTAssertEqual(Color(argument: "#00FF00").hexValue, "#00FF00")
        XCTAssertEqual(Color(argument: "#0000FF").hexValue, "#0000FF")
        XCTAssertEqual(Color(argument: "#808080").hexValue, "#808080")
    }

    func testArgumentNamedColoursMapToSwiftUIColors() {
        XCTAssertEqual(Color(argument: "red"), Color.red)
        XCTAssertEqual(Color(argument: "blue"), Color.blue)
        XCTAssertEqual(Color(argument: "clear"), Color.clear)
    }

    func testArgumentUnknownFallsBackToClear() {
        XCTAssertEqual(Color(argument: "notacolour"), Color.clear)
    }

    func testArgumentRejectsMalformedHex() {
        // Not a 6-digit hex, so it falls through to the name switch -> clear.
        XCTAssertEqual(Color(argument: "#FFF"), Color.clear)
        XCTAssertEqual(Color(argument: "#GGGGGG"), Color.clear)
    }

    // MARK: - Color(hex:)

    func testHexSixDigit() {
        XCTAssertEqual(Color(hex: "#FF0000").hexValue, "#FF0000")
        XCTAssertEqual(Color(hex: "00FF00").hexValue, "#00FF00")
    }

    func testHexThreeDigitExpands() {
        // "F00" -> each nibble * 17 -> FF0000
        XCTAssertEqual(Color(hex: "F00").hexValue, "#FF0000")
    }

    func testHexEightDigitIgnoresAlphaInHexValue() {
        // ARGB with alpha 0x80; hexValue reports RGB only.
        XCTAssertEqual(Color(hex: "80FF0000").hexValue, "#FF0000")
    }

    func testHexInvalidFallsBackToBlack() {
        XCTAssertEqual(Color(hex: "nothex").hexValue, "#000000")
    }

    // MARK: - luminance / isDark

    func testLuminanceBounds() {
        XCTAssertEqual(Color(hex: "#000000").luminance, 0.0, accuracy: 0.001)
        XCTAssertEqual(Color(hex: "#FFFFFF").luminance, 1.0, accuracy: 0.001)
    }

    func testIsDark() {
        XCTAssertTrue(Color(hex: "#000000").isDark)
        XCTAssertFalse(Color(hex: "#FFFFFF").isDark)
    }

    // MARK: - lightened / darkModeAdapted

    func testLightenedByZeroIsUnchanged() {
        XCTAssertEqual(Color(hex: "#336699").lightened(by: 0).hexValue, "#336699")
    }

    func testLightenedByOneIsWhite() {
        XCTAssertEqual(Color(hex: "#336699").lightened(by: 1).hexValue, "#FFFFFF")
    }

    func testDarkModeAdaptedLiftsVeryDarkColours() {
        let veryDark = Color(hex: "#050505")
        XCTAssertGreaterThan(veryDark.darkModeAdapted.luminance, veryDark.luminance,
                             "A near-black colour should be lightened for dark mode")
    }

    func testDarkModeAdaptedLeavesBrightColoursUnchanged() {
        let bright = Color(hex: "#CCCCCC")
        XCTAssertEqual(bright.darkModeAdapted.luminance, bright.luminance, accuracy: 0.001,
                       "A bright colour should pass through unchanged")
    }
}
