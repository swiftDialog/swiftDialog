//
//  StringProcessingTests.swift
//  dialogTests
//
//  Unit tests for pure string/text-processing helpers (backlog M5, Tier 1).
//

import XCTest
@testable import Dialog

final class StringProcessingTests: XCTestCase {

    // MARK: - processTextString

    func testProcessTextStringSubstitutesTags() {
        let result = processTextString("Hello {name}, welcome to {place}",
                                       tags: ["name": "Bart", "place": "swiftDialog"])
        XCTAssertEqual(result, "Hello Bart, welcome to swiftDialog")
    }

    func testProcessTextStringLeavesUnknownTagsUntouched() {
        let result = processTextString("Value is {unknown}", tags: ["name": "Bart"])
        XCTAssertEqual(result, "Value is {unknown}")
    }

    func testProcessTextStringConvertsEscapedNewline() {
        // Source contains a literal backslash-n, which should become a real newline.
        let result = processTextString("line1\\nline2", tags: [:])
        XCTAssertEqual(result, "line1\nline2")
    }

    func testProcessTextStringConvertsBrToHardLineBreak() {
        // <br> becomes two spaces + newline (a Markdown hard break).
        XCTAssertEqual(processTextString("a<br>b", tags: [:]), "a  \nb")
    }

    func testProcessTextStringConvertsHrToRule() {
        XCTAssertEqual(processTextString("a<hr>b", tags: [:]), "a****b")
    }

    func testProcessTextStringPassthroughWhenNothingToReplace() {
        XCTAssertEqual(processTextString("plain text", tags: [:]), "plain text")
    }

    // MARK: - reorderViewArray

    func testReorderMovesListedItemsToFrontThenAppendsRemainder() {
        let result = reorderViewArray(orderList: "dropdown,textfield",
                                      viewOrderArray: ["textfield", "checkbox", "dropdown"])
        XCTAssertEqual(result, ["dropdown", "textfield", "checkbox"])
    }

    func testReorderTrimsWhitespaceAroundItems() {
        let result = reorderViewArray(orderList: " dropdown , textfield ",
                                      viewOrderArray: ["textfield", "checkbox", "dropdown"])
        XCTAssertEqual(result, ["dropdown", "textfield", "checkbox"])
    }

    func testReorderIgnoresItemsNotInSourceArray() {
        let result = reorderViewArray(orderList: "notpresent,checkbox",
                                      viewOrderArray: ["textfield", "checkbox"])
        XCTAssertEqual(result, ["checkbox", "textfield"])
    }

    func testReorderEmptyOrderListPreservesOriginalOrder() {
        let result = reorderViewArray(orderList: "",
                                      viewOrderArray: ["a", "b", "c"])
        XCTAssertEqual(result, ["a", "b", "c"])
    }

    // MARK: - checkRegexPattern

    func testRegexMatchesSubstring() {
        XCTAssertTrue(checkRegexPattern(regexPattern: "[0-9]+", textToValidate: "abc123"))
    }

    func testRegexAnchoredNoMatch() {
        XCTAssertFalse(checkRegexPattern(regexPattern: "^[0-9]+$", textToValidate: "abc123"))
    }

    func testRegexAnchoredMatch() {
        XCTAssertTrue(checkRegexPattern(regexPattern: "^[0-9]+$", textToValidate: "12345"))
    }

    func testRegexInvalidPatternReturnsFalse() {
        // An unbalanced group is an invalid pattern; the function must not throw.
        XCTAssertFalse(checkRegexPattern(regexPattern: "([a-z", textToValidate: "abc"))
    }

    // MARK: - parseBoundaryTime

    func testParseBoundaryTimePM() {
        let comps = parseBoundaryTime("4:30pm")
        XCTAssertEqual(comps?.hour, 16)
        XCTAssertEqual(comps?.minute, 30)
    }

    func testParseBoundaryTimeAM() {
        let comps = parseBoundaryTime("9am")
        XCTAssertEqual(comps?.hour, 9)
        XCTAssertEqual(comps?.minute, 0)
    }

    func testParseBoundaryTimeBareIsTwentyFourHour() {
        // No am/pm suffix: taken literally as 24-hour, so 4:30 is 04:30 and 16:30 is 16:30.
        XCTAssertEqual(parseBoundaryTime("4:30")?.hour, 4)
        XCTAssertEqual(parseBoundaryTime("16:30")?.hour, 16)
        XCTAssertEqual(parseBoundaryTime("16:30")?.minute, 30)
    }

    func testParseBoundaryTimeMidnightNoon() {
        // 12am is midnight (00:00); 12pm is noon (12:00).
        XCTAssertEqual(parseBoundaryTime("12am")?.hour, 0)
        XCTAssertEqual(parseBoundaryTime("12pm")?.hour, 12)
    }

    func testParseBoundaryTimeHourOnly() {
        let comps = parseBoundaryTime("17")
        XCTAssertEqual(comps?.hour, 17)
        XCTAssertEqual(comps?.minute, 0)
    }

    func testParseBoundaryTimeWhitespaceAndCase() {
        let comps = parseBoundaryTime("  4:05 PM  ")
        XCTAssertEqual(comps?.hour, 16)
        XCTAssertEqual(comps?.minute, 5)
    }

    func testParseBoundaryTimeInvalidReturnsNil() {
        XCTAssertNil(parseBoundaryTime(""))
        XCTAssertNil(parseBoundaryTime("noon"))
        XCTAssertNil(parseBoundaryTime("25:00"))
        XCTAssertNil(parseBoundaryTime("10:75"))
    }

    // MARK: - anchorTime

    func testAnchorTimePinsToSameDay() {
        var dayComps = DateComponents()
        dayComps.year = 2026; dayComps.month = 3; dayComps.day = 14
        dayComps.hour = 8; dayComps.minute = 15
        let day = Calendar.current.date(from: dayComps)!

        let anchored = anchorTime(DateComponents(hour: 16, minute: 30), to: day)
        let result = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: anchored!)
        XCTAssertEqual(result.year, 2026)
        XCTAssertEqual(result.month, 3)
        XCTAssertEqual(result.day, 14)
        XCTAssertEqual(result.hour, 16)
        XCTAssertEqual(result.minute, 30)
    }

    func testAnchorTimeNilPassesThrough() {
        XCTAssertNil(anchorTime(nil, to: Date()))
    }
}
