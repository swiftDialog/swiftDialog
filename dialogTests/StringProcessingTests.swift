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
}
