//
//  FormBlockTests.swift
//  dialogTests
//
//  Form blocks: drop zones, dropped apps and the colour picker.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog


// The drop zone: what it accepts.
@MainActor
final class DropZoneTests: XCTestCase {

    func testItAcceptsWhatFileTypeSays() {
        let app = URL(fileURLWithPath: "/Applications/Safari.app")
        let png = URL(fileURLWithPath: "/tmp/logo.png")
        let txt = URL(fileURLWithPath: "/tmp/notes.txt")
        XCTAssertTrue(GuidanceDropZoneBlock<InspectState>.accepts(app, accepted: ["app"]))
        XCTAssertFalse(GuidanceDropZoneBlock<InspectState>.accepts(png, accepted: ["app"]))
        XCTAssertTrue(GuidanceDropZoneBlock<InspectState>.accepts(png, accepted: ["app", "image"]))
        XCTAssertFalse(GuidanceDropZoneBlock<InspectState>.accepts(txt, accepted: ["app", "image"]))
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.hint(for: ["app"]), "Drop apps here, or click to choose")
    }
}



// Dropped apps: several at once, and what they say about themselves.
@MainActor
final class DroppedAppsTests: XCTestCase {

    func testMultipleZonesCollectAndSingleZonesReplace() {
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/a.app"], dropped: ["/b.app", "/a.app", "/c.app"], multiple: true),
                       ["/a.app", "/b.app", "/c.app"], "several drops collect, no duplicates, drop order kept")
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/a.app"], dropped: ["/b.app", "/c.app"], multiple: false),
                       ["/c.app"], "a single zone holds the last one")
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/a.app"], dropped: [], multiple: false), ["/a.app"])
        XCTAssertEqual(GuidanceDropZoneBlock<InspectState>.merged(existing: ["/light.png"], dropped: ["/dark.png", "/extra.png"],
                                                                 multiple: true, limit: 2),
                       ["/light.png", "/dark.png"], "a limit keeps the first ones dropped")
    }

    func testAnAppSaysWhatItIs() throws {
        let info = try XCTUnwrap(AppBundleInfo.read("/System/Library/CoreServices/Finder.app"))
        XCTAssertEqual(info.bundleId, "com.apple.finder")
        XCTAssertEqual(info.name, "Finder")
        XCTAssertNotNil(info.version)
        XCTAssertNil(AppBundleInfo.read("/tmp/not-a-bundle-\(UUID().uuidString)"))
    }

    func testASignedThirdPartyAppNamesItsTeam() throws {
        // Apple's own apps carry no Team ID; a Developer ID app does. Skipped where none is installed.
        let candidates = ["/Applications/Microsoft Teams.app", "/Applications/Microsoft Outlook.app",
                          "/Applications/Slack.app", "/Applications/Google Chrome.app"]
        guard let path = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            throw XCTSkip("no signed third-party app installed")
        }
        let info = try XCTUnwrap(AppBundleInfo.read(path))
        XCTAssertNotNil(info.teamId, "\(path) is Developer-ID signed")
        XCTAssertEqual(info.teamId?.count, 10, "a Team ID is ten characters")
    }
}


// The colour picker: any colour, stored as hex.
@MainActor
final class ColorPickerTests: XCTestCase {

    func testAColourIsStoredAsHex() {
        XCTAssertEqual(GuidanceColorPickerBlock<InspectState>.hexString(Color(hex: "#6A67FE")), "#6A67FE")
    }
}
