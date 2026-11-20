//
//  GuidanceButtonStyleTests.swift
//  dialogTests
//
//  The button block's style vocabulary.
//

import XCTest
@testable import Dialog

/// `GuidanceButtonStyle(lenient:)` maps an authored `style` onto a SwiftUI button style; unknown
/// spellings fall back to `.bordered`, so every authored spelling must resolve on purpose.
final class GuidanceButtonStyleTests: XCTestCase {

    /// The canonical spellings are the schema's, and each resolves to itself.
    func testCanonicalSpellingsRoundTrip() {
        for style in GuidanceButtonStyle.allCases {
            XCTAssertEqual(GuidanceButtonStyle(lenient: style.rawValue), style,
                           "'\(style.rawValue)' must resolve to itself")
        }
    }

    /// `prominent` is a synonym; `link` is a style of its own.
    func testTheTwoCorpusSpellingsThatUsedToDefaultSilently() {
        XCTAssertEqual(GuidanceButtonStyle(lenient: "prominent"), .borderedProminent,
                       "'prominent' is a synonym of 'borderedProminent', not a fourth style")
        XCTAssertEqual(GuidanceButtonStyle(lenient: "link"), .link,
                       "'link' is a real style — SwiftUI has .link, and a link looks like a link")
    }

    /// Case and stray whitespace are not new vocabulary.
    func testSpellingIsCaseAndWhitespaceInsensitive() {
        XCTAssertEqual(GuidanceButtonStyle(lenient: "BorderedProminent"), .borderedProminent)
        XCTAssertEqual(GuidanceButtonStyle(lenient: "  link  "), .link)
    }

    /// Absent and unknown both land on the `.bordered` default.
    func testAbsentAndUnknownFallBackToBordered() {
        XCTAssertEqual(GuidanceButtonStyle(lenient: nil), .bordered)
        XCTAssertEqual(GuidanceButtonStyle(lenient: ""), .bordered)
        XCTAssertEqual(GuidanceButtonStyle(lenient: "destructive"), .bordered)
    }

    /// The synonyms table is lowercase; the lenient init lowercases its input before matching.
    func testSynonymTableIsLowercased() {
        for (style, spellings) in GuidanceButtonStyle.synonyms {
            for spelling in spellings {
                XCTAssertEqual(spelling, spelling.lowercased(),
                               "'\(spelling)' under .\(style) is unreachable while it carries capitals")
            }
        }
    }

    /// Every declared style has at least one spelling.
    func testEveryStyleIsReachable() {
        for style in GuidanceButtonStyle.allCases {
            XCTAssertFalse(GuidanceButtonStyle.synonyms[style, default: []].isEmpty,
                           ".\(style) has no spelling, so no config can select it")
        }
    }
}
