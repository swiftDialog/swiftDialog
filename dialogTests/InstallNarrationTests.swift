//
//  InstallNarrationTests.swift
//  dialogTests
//
//  Installation narration, the item icon ladder and the item result text.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - Narration to rows

/// `InstallNarration` turns `cadence:message:…Installing X…` narration into a row update for steps that
/// only speak `listitem:`.
final class InstallNarrationTests: XCTestCase {

    private struct Row: MonitoredItem {
        let id: String
        let displayName: String
        var icon: String? { nil }
        var paths: [String] { [] }
        var plistKey: String? { nil }
        var expectedValue: String? { nil }
        var evaluation: String? { nil }
        var plistRecheckInterval: Int? { nil }
        var useUserDefaults: Bool? { nil }
        var jsonMonitors: [InspectConfig.JsonMonitor]? { nil }
        var requirements: [InspectConfig.ItemConfig.Requirement]? { nil }
        var satisfy: String? { nil }
        var showBundleInfo: String? { nil }
        var logAliases: [String]?
    }

    func testItTakesTheSubjectOutOfARealBridgeLine() {
        XCTAssertEqual(InstallNarration.subject(of: "Installing Microsoft Teams…"), "Microsoft Teams")
        XCTAssertEqual(InstallNarration.subject(of: "Installing Santa…"), "Santa")
        // The size suffix is not part of the name.
        XCTAssertEqual(InstallNarration.subject(of: "Installing ECAM_11.0.11_LH_defaultv2_signed · 101 MB…"),
                       "ECAM_11.0.11_LH_defaultv2_signed")
    }

    /// A line that is not a narration narrates nothing.
    func testAnOrdinaryLineNarratesNothing() {
        XCTAssertNil(InstallNarration.subject(of: "Preparing this Mac. You can keep working."))
        XCTAssertNil(InstallNarration.subject(of: "Your Mac is ready"))
        XCTAssertNil(InstallNarration.subject(of: "Installing"), "a verb with no subject is not a subject")
    }

    func testItFindsTheRowByDisplayName() {
        let rows: [any MonitoredItem] = [Row(id: "teams", displayName: "Microsoft Teams", logAliases: nil),
                                         Row(id: "santa", displayName: "Santa", logAliases: nil)]
        let update = InstallNarration.rowUpdate(for: "Installing Microsoft Teams…", items: rows)
        XCTAssertEqual(update?.id, "teams")
        XCTAssertEqual(update?.status, .active)
    }

    /// Installer-style names reach their row through the fuzzy ladder.
    func testAnInstallerStyleNameStillReachesItsRow() {
        let rows: [any MonitoredItem] = [Row(id: "lea-launcher", displayName: "LEA Launcher", logAliases: nil),
                                         Row(id: "santa", displayName: "Santa", logAliases: nil)]
        XCTAssertEqual(InstallNarration.rowUpdate(for: "Installing lea-launcher…", items: rows)?.id,
                       "lea-launcher")
    }

    /// A subject the step does not list moves nothing.
    func testAnUnknownSubjectMovesNothing() {
        let rows: [any MonitoredItem] = [Row(id: "santa", displayName: "Santa", logAliases: nil)]
        XCTAssertNil(InstallNarration.rowUpdate(for: "Installing Something Else Entirely…", items: rows))
    }

    /// A narration never completes a row; completion belongs to the path check.
    func testANarrationNeverCompletesARow() {
        let rows: [any MonitoredItem] = [Row(id: "santa", displayName: "Santa", logAliases: nil)]
        for line in ["Installing Santa…", "Downloading Santa…", "Configuring Santa…"] {
            XCTAssertEqual(InstallNarration.rowUpdate(for: line, items: rows)?.status, .active, line)
        }
    }
}

extension InstallNarrationTests {
    /// An authored `logAliases` entry wins before any fuzzy matching.
    func testAnAuthoredLogAliasWinsBeforeTheGuessing() {
        let rows: [any MonitoredItem] = [
            Row(id: "ecam", displayName: "ECAM", logAliases: ["ECAM_11.0.11_LH_defaultv2_signed"]),
            Row(id: "santa", displayName: "Santa", logAliases: nil)
        ]
        let update = InstallNarration.rowUpdate(
            for: "Installing ECAM_11.0.11_LH_defaultv2_signed · 101 MB…", items: rows)
        XCTAssertEqual(update?.id, "ecam")
    }
}

// MARK: - Item icon ladder

/// A row's icon: authored `icon`, then an `app` requirement's bundle id, then the first existing
/// `paths` entry, then the renderer default. Safari is the fixture because every test Mac has it.
final class ItemIconLadderTests: XCTestCase {

    private let safariPath = "/Applications/Safari.app"

    func testBundleIdResolvesBeforePaths() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: safariPath),
                          "Safari is the fixture for an app that is certainly installed")
        // A wrong path beside a right bundle id: the bundle id rung must run first.
        let resolved = ItemIconLadder.installedAppPath(
            bundleIds: ["com.apple.Safari"],
            paths: ["/nonexistent/Safari.app"])
        XCTAssertNotNil(resolved)
        XCTAssertTrue(resolved!.hasSuffix(".app"), "the rung hands back the BUNDLE, not an image")
    }

    func testFallsToPathsWhenNoBundleIdMatches() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: safariPath),
                          "Safari is the fixture for an app that is certainly installed")
        let resolved = ItemIconLadder.installedAppPath(
            bundleIds: ["com.example.definitely.not.installed"],
            paths: ["/nonexistent/One.app", safariPath])
        XCTAssertEqual(resolved, safariPath, "the FIRST path that exists wins, not the first path")
    }

    func testAbsentAppResolvesToNothing() {
        // No match returns nil, never an invented path.
        XCTAssertNil(ItemIconLadder.installedAppPath(
            bundleIds: ["com.example.definitely.not.installed"],
            paths: ["/nonexistent/One.app", "/nonexistent/Two.app"]))
    }

    func testNoBundleIdsAndNoPathsResolvesToNothing() {
        XCTAssertNil(ItemIconLadder.installedAppPath(bundleIds: [], paths: []))
    }

    func testEmptyStringsAreSkippedNotProbed() {
        // A blank bundle id or path is not a candidate ("" would resolve to the current directory).
        XCTAssertNil(ItemIconLadder.installedAppPath(bundleIds: [""], paths: [""]))
    }

    func testTildePathsAreExpanded() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        try XCTSkipUnless(FileManager.default.fileExists(atPath: home))
        XCTAssertEqual(ItemIconLadder.installedAppPath(bundleIds: [], paths: ["~"]), home)
    }
}

/// Item status text for diagnostics: the text in `item:<id>:<status>:<text>`, the `installing` and
/// `checking` states, and `failureMessage`.
@MainActor
final class ItemResultTextTests: XCTestCase {

    private func wiredState() throws -> (InspectState, CommandRouter, URL) {
        let state = InspectState()
        state.items = try ["network", "dns"].map { id in
            try JSONDecoder().decode(InspectConfig.ItemConfig.self, from: Data("""
            {"id":"\(id)","displayName":"\(id)","paths":[],
             "failureMessage":"Connect the VPN client, then run this again."}
            """.utf8))
        }
        let trigger = FileManager.default.temporaryDirectory
            .appendingPathComponent("item-result-\(UUID().uuidString).cmd")
        let router = CommandRouter()
        router.wireItemBase(state: state, presetLabel: "ItemResultTextTests", triggerFilePath: trigger.path)
        return (state, router, trigger)
    }

    /// The text sent with a status is kept and wins over generic labels.
    func testTheResultTextIsKeptAndShown() throws {
        let (state, router, trigger) = try wiredState()
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(at: trigger) }

        router.processCommand("item:dns:failed:Can't find the print server")
        XCTAssertTrue(state.failedItems.contains("dns"))
        XCTAssertEqual(state.itemStatusText["dns"], "Can't find the print server")
        XCTAssertEqual(ItemSetModel.displayStatusText(for: state.items[1], state: state),
                       "Can't find the print server", "the script's text, not \"Failed\"")

        router.processCommand("item:network:success:Connected")
        XCTAssertEqual(ItemSetModel.displayStatusText(for: state.items[0], state: state), "Connected",
                       "a completed row keeps its text — the log channel's \"Completed…\" guard does not apply")
    }

    /// A status without text clears the old text.
    func testAStatusWithoutTextClearsTheOldText() throws {
        let (state, router, trigger) = try wiredState()
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(at: trigger) }

        router.processCommand("item:network:checking:Checking…")
        XCTAssertEqual(state.itemStatusText["network"], "Checking…")
        router.processCommand("item:network:success")
        XCTAssertNil(state.itemStatusText["network"])
    }

    /// `checking`, `installing` and `running` are in-progress states, like `downloading`.
    func testCheckingAndInstallingAreInProgress() throws {
        let (state, router, trigger) = try wiredState()
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(at: trigger) }

        for status in ["checking", "installing", "running", "downloading"] {
            router.processCommand("item:network:pending")
            router.processCommand("item:network:\(status)")
            XCTAssertTrue(state.downloadingItems.contains("network"), "\(status) shows as in progress")
        }
    }

    /// With no live text a failed row shows its `failureMessage`, in Presets 1–3 alike.
    func testAFailedRowFallsBackToItsFailureMessage() throws {
        let (state, router, trigger) = try wiredState()
        defer { router.stopMonitoring(); try? FileManager.default.removeItem(at: trigger) }

        router.processCommand("item:dns:failed")
        XCTAssertEqual(ItemSetModel.displayStatusText(for: state.items[1], state: state),
                       "Connect the VPN client, then run this again.")
    }
}
