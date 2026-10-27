//
//  SetupAssistantPiecesTests.swift
//  dialogTests
//
//  Pieces the Setup Assistant flows seat: the cadence window, the software sort rule, the footer
//  band and the Preset 5 icon ladder.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - Window model

final class CadenceWindowTests: XCTestCase {
    func testTheWindowSlidesOnlyWhenTheActiveCardWouldFallOutside() {
        let w = { (active: Int) in CadenceM.visibleWindow(count: 12, active: active, viewport: 732, minCard: 144) }
        XCTAssertEqual(w(0), [0, 1, 2, 3], "early stages sit at the leading edge")
        XCTAssertEqual(w(3), [0, 1, 2, 3], "still inside — the row does not move")
        XCTAssertEqual(w(4), [1, 2, 3, 4], "now it slides, by one")
        XCTAssertEqual(w(11), [8, 9, 10, 11], "late stages sit at the trailing edge")
    }

    /// A run that fits draws every entry and never windows.
    func testARunThatFitsIsNotWindowed() {
        XCTAssertEqual(CadenceM.visibleWindow(count: 4, active: 3, viewport: 732, minCard: 144),
                       [0, 1, 2, 3])
    }
}

// MARK: - Software sort

final class SoftwareSortRuleTests: XCTestCase {
    private func bundle(_ id: String, installed: Int, total: Int) -> InspectConfig.GuidanceContent.BundleRowPayload {
        InspectConfig.GuidanceContent.BundleRowPayload(
            bundleId: id, title: id, summary: nil, size: nil, icons: nil,
            installedCount: installed, totalCount: total, hasDetail: false,
            actionLabel: nil, action: nil, actionURL: nil, requestId: nil)
    }
    private func detail(_ name: String, status: StepStatus) -> InspectConfig.GuidanceContent.DetailRowPayload {
        InspectConfig.GuidanceContent.DetailRowPayload(
            itemId: name.lowercased(), displayName: name, icon: nil, appBundleId: nil, paths: [],
            status: status.rawValue, detail: nil, actionLabel: nil, action: nil, actionURL: nil, requestId: nil)
    }

    /// Bundles needing action come first and settled ones last, stable within each group.
    func testBundlesActionNeededFirstSettledLast() {
        let rows = [bundle("Essentials", installed: 4, total: 4), bundle("Design", installed: 1, total: 4),
                    bundle("Engineering", installed: 4, total: 4), bundle("Data", installed: 0, total: 4)]
        XCTAssertEqual(SoftwareSortRule.bundleOrder(rows).map(\.bundleId),
                       ["Design", "Data", "Essentials", "Engineering"])
        XCTAssertEqual(SoftwareSortRule.bundleOrder(rows).firstIndex(where: SoftwareSortRule.isSettled), 2)
    }

    /// Detail rows sort alphabetically once settled; a row needing a hand goes first.
    func testDetailRowsAlphabeticalWhenSettled() {
        let all = [detail("Safari", status: .completed), detail("Slack", status: .completed),
                   detail("1Password", status: .completed), detail("Google Chrome", status: .completed)]
        XCTAssertEqual(SoftwareSortRule.detailOrder(all).map(\.displayName),
                       ["1Password", "Google Chrome", "Safari", "Slack"])
        let mixed = all + [detail("Zed", status: .pending)]
        XCTAssertEqual(SoftwareSortRule.detailOrder(mixed).first?.displayName, "Zed")
    }

    /// Rows fit the band between a 60 floor and a 78 ceiling: four rows plus the divider in 316pt land at 67.
    func testBundleRowsFitTheBand() {
        XCTAssertEqual(SoftwareRowM.fittedRowHeight(available: 316, rows: 4, hasDivider: true), 67)
        XCTAssertEqual(SoftwareRowM.fittedRowHeight(available: 800, rows: 4, hasDivider: true), 78)
        XCTAssertEqual(SoftwareRowM.fittedRowHeight(available: 200, rows: 4, hasDivider: true), 60)
        XCTAssertEqual(SoftwareRowM.fittedRowHeight(available: nil, rows: 4, hasDivider: false), 78)
    }

    /// The launch note spells out the state, without doubling an authored note that already says it.
    func testLaunchNoteSpellsTheState() {
        XCTAssertEqual(SoftwareSortRule.launchNote(authored: "available when the install finishes", status: .pending),
                       "not installed yet · available when the install finishes")
        XCTAssertEqual(SoftwareSortRule.launchNote(authored: "your editor", status: .completed), "your editor")
        XCTAssertEqual(SoftwareSortRule.launchNote(authored: nil, status: .active), "installing")
        XCTAssertEqual(SoftwareSortRule.launchNote(authored: "installing now", status: .active), "installing now")
        XCTAssertTrue(SoftwareSortRule.isUnavailable(.pending))
        XCTAssertFalse(SoftwareSortRule.isUnavailable(nil))
    }
}

// MARK: - One footer band, centred on the primary

// air = (band − hairline − primary) / 2: 28pt, or 27.5 with a half-point hairline. The band centres
// the primary, never the row, so a taller secondary or Back cannot lift it.

final class FooterBandTests: XCTestCase {

    /// One band height and one primary height across every construction.
    func testTheBandAndThePrimaryAreOneNumberEach() {
        XCTAssertEqual(FooterBandM.band, 84,
                       "the band provisioning, plain-centered, portal and the setup-assistant "
                       + "already reserved — the census made it the one number")
        XCTAssertEqual(FooterBandM.primaryHeight, 28,
                       "every construction's primary; the setup-assistant's 34pt doors came down "
                       + "to it for the same reason, because a 34pt control in an 84 band centres "
                       + "at 24.75 and no band height puts 34 and 28 on the same air")
    }

    /// The air is 28; the hairline's 27.5 follows from the same arithmetic.
    func testTheAirIsTwentyEightAndTheHairlineTakesAQuarter() {
        XCTAssertEqual(FooterBandM.air(), 28)
        XCTAssertEqual(FooterBandM.air(hairline: 0.5), 27.75,
                       "renders 27.5 — measured on card:portal and the setup-assistant, both of "
                       + "which draw a 0.5pt rule that CONSUMES band height. plain-centered draws "
                       + "its hairline as an overlay instead and reads a clean 28.")
    }

    /// Preset 2's card fits a two-line 12pt name seat inside its 168, so the pager keeps its frame.
    func testThePresetTwoCardHoldsItsTwoLineNameSeat() {
        XCTAssertEqual(Preset2CardM.height, 168, "the card did not grow")
        XCTAssertEqual(Preset2CardM.nameSize, 12)
        XCTAssertEqual(Preset2CardM.nameLines, 2)
        XCTAssertEqual(Preset2CardM.nameSeat, 30)
        XCTAssertLessThanOrEqual(Preset2CardM.fixedContent, Preset2CardM.height,
                                 "12 + 76 + 8 + 30 + 8 + 15 + 12 = 161 must fit in 168")
    }

    /// The setup-assistant footer's rule is inside the band and its content on the band's 40 rail.
    func testTheSetupAssistantFooterIsOnTheBandsRail() {
        XCTAssertEqual(SetupAssistantM.rail, FooterBandM.rail)
        XCTAssertEqual(SetupAssistantM.footerHeight, FooterBandM.band)
        XCTAssertEqual(SetupAssistantM.footerDoorHeight, FooterBandM.primaryHeight)
        _ = SetupAssistantFooter(surface: .beta, accent: .blue)
    }

    /// The footer row is three slots on the band; its defaults are the band's rail and no rule.
    func testTheFooterRowIsThreeSlotsOnTheBand() {
        let row = FooterRow { EmptyView() } leading: { EmptyView() } trailing: { EmptyView() }
        XCTAssertEqual(row.rail, FooterBandM.rail)
        XCTAssertEqual(row.rule, .none)
        XCTAssertNil(row.fill)
    }

    /// `air` takes only the hairline, so no sibling's height can reach it.
    func testAirIsBlindToTheRestOfTheRow() {
        for tallestSibling in [CGFloat(16), 28, 32, 34, 52] {
            XCTAssertEqual(FooterBandM.clusterHeight(tallestSibling: tallestSibling),
                           FooterBandM.primaryHeight,
                           "a \(tallestSibling)pt sibling must overhang the primary, not lift it")
        }
    }
}

// MARK: - The ladder reaches Preset 5

/// Preset 5's carousel, journey grid and bookend all read `MonitoredItem.resolvedArt`; the grid loads
/// a `.app` path as a bundle, not an image.
final class ItemIconLadderPreset5Tests: XCTestCase {

    /// Only the first four members matter to the ladder.
    private struct Row: MonitoredItem {
        var id: String
        var displayName: String
        var icon: String?
        var paths: [String]
        var plistKey: String? { nil }
        var expectedValue: String? { nil }
        var evaluation: String? { nil }
        var plistRecheckInterval: Int? { nil }
        var useUserDefaults: Bool? { nil }
        var jsonMonitors: [InspectConfig.JsonMonitor]? { nil }
        var requirements: [InspectConfig.ItemConfig.Requirement]? { nil }
        var satisfy: String? { nil }
        var showBundleInfo: String? { nil }
        var logAliases: [String]? { nil }
    }

    private let safari = "/Applications/Safari.app"

    func testAuthoredIconOutranksTheInstalledApp() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: safari))
        let row = Row(id: "a", displayName: "A", icon: "/x/mine.png", paths: [safari])
        XCTAssertEqual(row.resolvedArt, "/x/mine.png", "an admin who names an icon means it")
    }

    func testNoIconResolvesToTheInstalledApp() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: safari))
        let row = Row(id: "b", displayName: "B", icon: nil, paths: [safari])
        XCTAssertEqual(row.resolvedArt, safari)
    }

    func testNoIconAndNoAppResolvesToNothing() {
        let row = Row(id: "c", displayName: "C", icon: nil, paths: ["/nonexistent/C.app"])
        XCTAssertNil(row.resolvedArt, "the seat's own fallback takes over, never an invented path")
    }

    func testAMissIsNotProbedAgainInsideTheFloor() throws {
        // An injected clock exercises the miss floor; the directory created between asks must not be probed.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ladder-\(UUID().uuidString)").path
        let clock = Mutex(Date(timeIntervalSince1970: 1_000))
        let ladder = ItemIconLadder(missRetryInterval: 2, now: { clock.withLock { $0 } })

        XCTAssertNil(ladder.installedAppPath(itemId: "x", bundleIds: [], paths: [dir]), "a real miss")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: dir) }

        clock.withLock { $0 = Date(timeIntervalSince1970: 1_001) }
        XCTAssertNil(ladder.installedAppPath(itemId: "x", bundleIds: [], paths: [dir]),
                     "inside the floor: answered from the miss, not probed — the directory exists now")

        clock.withLock { $0 = Date(timeIntervalSince1970: 1_002) }
        XCTAssertEqual(ladder.installedAppPath(itemId: "x", bundleIds: [], paths: [dir]), dir,
                       "at the floor: probed again, found")
    }

    func testTheFloorIsPerRow() {
        let ladder = ItemIconLadder(missRetryInterval: 60, now: { Date(timeIntervalSince1970: 0) })
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertNil(ladder.installedAppPath(itemId: "a", bundleIds: [], paths: ["/nonexistent"]))
        // Row "a" missed; row "b" was never asked and probes.
        XCTAssertEqual(ladder.installedAppPath(itemId: "b", bundleIds: [], paths: [home]), home)
    }

    func testTheGridLoadsAnAppBundleAsItsIcon() throws {
        try XCTSkipUnless(FileManager.default.fileExists(atPath: safari))
        // `NSImage(contentsOfFile:)` is nil for a `.app` directory, so the grid loads it as a bundle.
        XCTAssertNotNil(JourneyGridM.artwork(at: safari))
        // The toast uses the same loader.
        XCTAssertNotNil(ItemArt.image(at: safari))
        XCTAssertNil(JourneyGridM.artwork(at: "/nonexistent/App.app"))
        XCTAssertNil(JourneyGridM.artwork(at: "relative.png"), "art must be an absolute path")
        XCTAssertNil(JourneyGridM.artwork(at: nil))
    }
}
