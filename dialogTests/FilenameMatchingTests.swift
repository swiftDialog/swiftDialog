//
//  FilenameMatchingTests.swift
//  dialogTests
//
//  The shared filename heuristics in FilenameMatching, on both sides of the `brandFuzzy` fork.
//

import XCTest
@testable import Dialog

final class FilenameMatchingTests: XCTestCase {

    func testDownloadFileByExtensionMarkerAndPartial() {
        XCTAssertTrue(FilenameMatching.isDownloadFile("Firefox.dmg.partial", cacheExtensions: ["pkg", "dmg"]))
        XCTAssertTrue(FilenameMatching.isDownloadFile("VendorSetup.exe", cacheExtensions: []))
        XCTAssertTrue(FilenameMatching.isDownloadFile("Thing_Installer.zip", cacheExtensions: []))
        XCTAssertFalse(FilenameMatching.isDownloadFile("notes.txt", cacheExtensions: ["pkg"]))
    }

    func testDirectAndComponentMatching() {
        XCTAssertTrue(FilenameMatching.matches(
            itemId: "microsoft_outlook", displayName: "Microsoft Outlook",
            filename: "Microsoft_Outlook_16.101.25091314_Installer.pkg", brandFuzzy: false))
        XCTAssertFalse(FilenameMatching.matches(
            itemId: "google_chrome", displayName: "Google Chrome",
            filename: "Firefox_141.dmg", brandFuzzy: false))
    }

    func testBrandFuzzyOnlyFiresWhenEnabled() {
        XCTAssertFalse(FilenameMatching.matches(
            itemId: "microsoft_office", displayName: "Microsoft Office",
            filename: "Office_365_Installer_2026.pkg", brandFuzzy: false))
        XCTAssertTrue(FilenameMatching.matches(
            itemId: "microsoft_office", displayName: "Microsoft Office",
            filename: "Office_365_Installer_2026.pkg", brandFuzzy: true))
    }

    func testInstallerMarkersCanBeExcluded() {
        // MonitoringModule passes false: only cache extensions and .partial/.tmp residue count.
        XCTAssertFalse(FilenameMatching.isDownloadFile(
            "VendorSetup.exe", cacheExtensions: [], includeInstallerMarkers: false))
        XCTAssertFalse(FilenameMatching.isDownloadFile(
            "Thing_Installer.zip", cacheExtensions: [], includeInstallerMarkers: false))
        XCTAssertTrue(FilenameMatching.isDownloadFile(
            "Firefox.dmg.partial", cacheExtensions: ["pkg", "dmg"], includeInstallerMarkers: false))
        XCTAssertTrue(FilenameMatching.isDownloadFile(
            "app.pkg", cacheExtensions: ["pkg"], includeInstallerMarkers: false))
    }

    func testDirectMatchIsStrategyOneLite() {
        // directMatch checks itemId and the space-stripped display name only; the
        // underscore-stripped name is the full matcher's.
        XCTAssertTrue(FilenameMatching.directMatch(
            itemId: "google_chrome", displayName: "Google Chrome",
            filename: "google_chrome_141.dmg"))
        XCTAssertFalse(FilenameMatching.directMatch(
            itemId: "cr_tool", displayName: "Card_Reader",
            filename: "cardreader_1.0.pkg"))
        XCTAssertTrue(FilenameMatching.matches(
            itemId: "cr_tool", displayName: "Card_Reader",
            filename: "cardreader_1.0.pkg", brandFuzzy: false))
    }
}
