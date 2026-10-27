//
//  InstallationDetectionTests.swift
//  dialogTests
//
//  Installation detection on the state: expired notices and the removal dwell, script-reported
//  status and who owns a monitored item.
//

import XCTest
import SwiftUI
import AppKit
@testable import Dialog

// MARK: - Notice pruning

/// `AppInspector.expiredNotices`, the prune rule, as pure arithmetic. The call site is covered by
/// `ExpiredNoticesWiringTests`.
final class ExpiredNoticesTests: XCTestCase {

    private let fixedNow = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func minutesAgo(_ seconds: TimeInterval) -> Date {
        fixedNow.addingTimeInterval(-seconds)
    }

    func testAnEmptyDictionaryExpiresNothing() {
        XCTAssertEqual(AppInspector.expiredNotices([:], now: fixedNow), [])
    }

    func testNothingExpiredWhenEveryEntryIsFresh() {
        let removed = ["a": minutesAgo(1), "b": minutesAgo(5)]
        XCTAssertEqual(AppInspector.expiredNotices(removed, now: fixedNow), [])
    }

    /// The filter is per entry: one of three expires.
    func testOneOfThreeExpires() {
        let removed = [
            "fresh1": minutesAgo(1),
            "stale": minutesAgo(AppInspector.removalNoticeDwell + 10),
            "fresh2": minutesAgo(5)
        ]
        XCTAssertEqual(AppInspector.expiredNotices(removed, now: fixedNow), ["stale"])
    }

    func testAllExpireWhenAllArePastTheDwell() {
        let removed = [
            "a": minutesAgo(AppInspector.removalNoticeDwell + 1),
            "b": minutesAgo(AppInspector.removalNoticeDwell + 100)
        ]
        XCTAssertEqual(Set(AppInspector.expiredNotices(removed, now: fixedNow)), ["a", "b"])
    }

    /// An entry exactly at the dwell is expired (`>=`).
    func testAnEntryExactlyAtTheDwellIsExpired() {
        let removed = ["boundary": minutesAgo(AppInspector.removalNoticeDwell)]
        XCTAssertEqual(AppInspector.expiredNotices(removed, now: fixedNow), ["boundary"])
    }

    /// One second short of the dwell is not expired.
    func testAnEntryOneSecondShortOfTheDwellIsNotExpired() {
        let removed = ["almost": minutesAgo(AppInspector.removalNoticeDwell - 1)]
        XCTAssertEqual(AppInspector.expiredNotices(removed, now: fixedNow), [])
    }
}

/// `checkDirectInstallationStatus` calls the prune: driven through the real `InspectState` and its
/// real debounce, so removing the call fails here.
@MainActor
final class ExpiredNoticesWiringTests: XCTestCase {

    func testCheckDirectInstallationStatusPrunesAnExpiredNotice() {
        let state = InspectState()
        // A never-installed item to pass `guard !items.isEmpty`; its path cannot exist, so it takes no branch.
        state.items = [InspectConfig.ItemConfig(
            id: "placeholder", displayName: "Placeholder",
            paths: ["/nonexistent/path/ExpiredNoticesWiringTests-\(UUID().uuidString)"])]
        state.removedItems = ["gone": Date(timeIntervalSinceNow: -(AppInspector.removalNoticeDwell + 5))]

        state.checkDirectInstallationStatus()

        let settled = XCTestExpectation(description: "the debounced prune has run")
        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay + 0.3) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 3)

        XCTAssertNil(state.removedItems["gone"],
                     "checkDirectInstallationStatus must still CALL the prune — deleting that "
                     + "call (not just changing expiredNotices' arithmetic) must fail this test")
    }

    /// A notice not yet past the dwell survives the same call.
    func testCheckDirectInstallationStatusLeavesAFreshNoticeAlone() {
        let state = InspectState()
        state.items = [InspectConfig.ItemConfig(
            id: "placeholder", displayName: "Placeholder",
            paths: ["/nonexistent/path/ExpiredNoticesWiringTests-\(UUID().uuidString)"])]
        state.removedItems = ["fresh": Date()]

        state.checkDirectInstallationStatus()

        let settled = XCTestExpectation(description: "the poller pass has run")
        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay + 0.3) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 3)

        XCTAssertNotNil(state.removedItems["fresh"],
                        "a fresh notice must survive the same poller pass that prunes a stale one")
    }
}

/// A status a script reported is evidence the path check lacks: the check undoes only a path or
/// cache file it saw itself. A path it never saw is "not there yet", not "removed".
@MainActor
final class ScriptReportedStatusTests: XCTestCase {

    private func settle() {
        let settled = XCTestExpectation(description: "the debounced poller pass has run")
        DispatchQueue.main.asyncAfter(deadline: .now() + InspectConstants.debounceDelay + 0.3) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 3)
    }

    private func missingPathItem() -> InspectConfig.ItemConfig {
        InspectConfig.ItemConfig(id: "a", displayName: "A",
                                 paths: ["/nonexistent/ScriptReportedStatusTests-\(UUID().uuidString).app"])
    }

    func testAReportedSuccessHoldsWhileThePathIsMissing() {
        let state = InspectState()
        state.items = [missingPathItem()]
        state.completedItems.insert("a")          // what `item:a:success` does

        state.checkDirectInstallationStatus(); settle()
        state.checkDirectInstallationStatus(); settle()

        XCTAssertTrue(state.completedItems.contains("a"),
                      "a path the check never saw present is not a removal")
        XCTAssertNil(state.removedItems["a"], "and it must not raise a 'Removed' notice")
    }

    func testAReportedInstallingHoldsWithoutACacheFile() {
        let state = InspectState()
        state.items = [missingPathItem()]
        state.downloadingItems.insert("a")        // what `item:a:installing` does

        state.checkDirectInstallationStatus(); settle()

        XCTAssertTrue(state.downloadingItems.contains("a"),
                      "no cache file is not evidence against a reported install in progress")
    }

    /// A path the check saw present and then gone is still a removal.
    func testARemovalTheCheckSawStillResetsTheItem() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScriptReportedStatusTests-\(UUID().uuidString)")
        let app = dir.appendingPathComponent("A.app")
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let state = InspectState()
        state.items = [InspectConfig.ItemConfig(id: "a", displayName: "A", paths: [app.path])]

        state.checkDirectInstallationStatus(); settle()
        XCTAssertTrue(state.completedItems.contains("a"), "the check sees the install")

        try FileManager.default.removeItem(at: app)
        state.checkDirectInstallationStatus(); settle()

        XCTAssertFalse(state.completedItems.contains("a"), "and then sees it go")
        XCTAssertNotNil(state.removedItems["a"], "with the removal notice")
    }
}

// MARK: - A stale stop cannot kill the arriving screen

/// `monitoringService` is one `@StateObject` per preset, and SwiftUI runs the incoming step's
/// `onAppear` before the outgoing one's `onDisappear`: start(3) · start(4) · stop(3). The late stop
/// must not tear down step 4's session.
@MainActor
final class MonitoringOwnershipTests: XCTestCase {

    private var tempDir: URL!
    private var service: UnifiedMonitoringService!

    private struct Item: MonitoredItem {
        let id: String
        let displayName: String
        let itemPaths: [String]
        var icon: String? { nil }
        var paths: [String] { itemPaths }
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

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("monitoring-ownership-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        service = UnifiedMonitoringService()
    }

    override func tearDownWithError() throws {
        service.stopMonitoring()
        LogMonitorService.shared.setItems([])
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func drainMain() {
        let exp = expectation(description: "main queue drained")
        DispatchQueue.main.async { exp.fulfill() }
        wait(for: [exp], timeout: 2)
    }

    private func install(_ name: String) throws -> String {
        let url = tempDir.appendingPathComponent(name)
        try Data("installed".utf8).write(to: url)
        return url.path
    }

    /// Waits one real timer tick (2.6s). `forceStatusCheck()` would still detect changes after a stop,
    /// so only the timer shows whether the session survived.
    private func waitForATick() {
        let ticked = expectation(description: "the service's own status timer ran")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { ticked.fulfill() }
        wait(for: [ticked], timeout: 5)
    }

    /// start(a) · start(b) · stop(a): b keeps running, shown by the timer noticing b's deleted file.
    func testAStopFromASupersededScreenLeavesTheNewSessionRunning() throws {
        let bPath = try install("Obsidian.app")

        service.startMonitoring(items: [Item(id: "a", displayName: "A", itemPaths: [try install("Figma.app")])],
                                owner: "step-a")
        service.startMonitoring(items: [Item(id: "b", displayName: "Obsidian", itemPaths: [bPath])],
                                owner: "step-b")
        drainMain()
        XCTAssertEqual(service.itemStatuses["b"], .completed)

        // The departing screen's onDisappear, arriving late.
        XCTAssertFalse(service.stopMonitoring(owner: "step-a"),
                       "a superseded screen must be told its stop was not honoured — the caller " +
                       "gates the shared log monitor's teardown on this very answer")
        XCTAssertEqual(service.monitoringOwner, "step-b", "the session never left step b")

        try FileManager.default.removeItem(atPath: bPath)
        waitForATick()
        drainMain()

        XCTAssertEqual(service.itemStatuses["b"], .pending,
                       "the arriving screen's monitoring must still be TICKING after the departing " +
                       "screen's stop — this is the frozen-screen bug")
        XCTAssertNotNil(service.removedItems["b"],
                        "and the removal it exists to notice must still be recorded")
    }

    /// The owner's own stop still stops the session.
    func testTheOwnersOwnStopIsHonoured() throws {
        let path = try install("Obsidian.app")
        service.startMonitoring(items: [Item(id: "b", displayName: "Obsidian", itemPaths: [path])],
                                owner: "step-b")
        drainMain()
        XCTAssertEqual(service.itemStatuses["b"], .completed)

        XCTAssertTrue(service.stopMonitoring(owner: "step-b"))
        XCTAssertNil(service.monitoringOwner, "a torn-down session belongs to no one")

        try FileManager.default.removeItem(atPath: path)
        waitForATick()
        drainMain()

        XCTAssertEqual(service.itemStatuses["b"], .completed,
                       "no timer remains, so the deletion goes unnoticed — that is what stopping means")
        XCTAssertTrue(service.removedItems.isEmpty)
    }

    /// An unowned session (`owner: nil`) is stopped only by the unconditional stop, the shutdown path.
    func testAnUnownedSessionIsOnlyStoppedUnconditionally() throws {
        service.startMonitoring(items: [Item(id: "a", displayName: "A", itemPaths: [try install("Figma.app")])])
        drainMain()
        XCTAssertNil(service.monitoringOwner)
        XCTAssertFalse(service.stopMonitoring(owner: "step-a"), "nobody owns it, so no one may claim it")

        service.stopMonitoring()
        XCTAssertNil(service.monitoringOwner)
    }

    /// Step 4 owns the session; stale stops from steps 2 and 3 arrive after.
    func testTwoStaleStopsInARowCannotKillTheCurrentScreen() throws {
        let path = try install("Obsidian.app")
        service.startMonitoring(items: [Item(id: "s2", displayName: "S2", itemPaths: [])], owner: "step-2")
        service.startMonitoring(items: [Item(id: "s3", displayName: "S3", itemPaths: [])], owner: "step-3")
        service.startMonitoring(items: [Item(id: "s4", displayName: "Obsidian", itemPaths: [path])], owner: "step-4")
        drainMain()

        XCTAssertFalse(service.stopMonitoring(owner: "step-2"))
        XCTAssertFalse(service.stopMonitoring(owner: "step-3"))
        XCTAssertEqual(service.monitoringOwner, "step-4")

        try FileManager.default.removeItem(atPath: path)
        // Poked rather than timed: this test is about the ordering of stops, not the timer.
        service.forceStatusCheck()
        drainMain()
        XCTAssertNotNil(service.removedItems["s4"], "step 4 is still the owner and still watching")
    }
}
