//
//  PayloadAlignmentTests.swift
//  dialogTests
//
//  Where payload content sits in its band: top-aligned, except a payload that is one
//  self-contained media object, which centres. `PayloadAlignment` decides from the block list.
//

import XCTest
import SwiftUI
@testable import Dialog

final class PayloadAlignmentTests: XCTestCase {

    private func blocks(_ types: [String]) throws -> [InspectConfig.GuidanceContent] {
        try types.map { type in
            let json = #"{"type":"\#(type)"}"#
            return try JSONDecoder().decode(InspectConfig.GuidanceContent.self,
                                             from: Data(json.utf8))
        }
    }

    // MARK: - The rule

    func testOrdinaryContentIsTopAligned() {
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["text"])), .topLeading)
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["text", "bullets"])), .topLeading)
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["comparison-table"])), .topLeading)
    }

    func testAnEmptyPayloadIsTopAligned() {
        XCTAssertEqual(PayloadAlignment.alignment(for: []), .topLeading,
                       "nothing to centre, and a fallback must not invent a second rule")
    }

    // MARK: - The exception

    func testALoneMediaBlockCentres() {
        for type in ["video", "image-carousel", "portal-webview", "image"] {
            XCTAssertEqual(PayloadAlignment.alignment(for: try blocks([type])), .leading,
                           "\(type) alone is the band's content")
        }
    }

    /// Media sharing the band with anything else takes the ordinary rule.
    func testMediaAlongsideOtherContentIsTopAligned() {
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["video", "text"])), .topLeading)
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["text", "image-carousel"])), .topLeading)
    }

    func testTwoMediaBlocksAreNotOneSelfContainedObject() {
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["image", "image"])), .topLeading)
    }

    /// Both arms lead horizontally; they differ on the vertical axis only.
    func testHorizontalAlignmentIsAlwaysLeading() {
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["text"])).horizontal, .leading)
        XCTAssertEqual(PayloadAlignment.alignment(for: try blocks(["video"])).horizontal, .leading)
    }
}
