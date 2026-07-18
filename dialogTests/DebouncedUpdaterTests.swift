//
//  DebouncedUpdaterTests.swift
//  dialogTests
//
//  Unit tests for DebouncedUpdater (backlog M5, Tier 2). Uses the main queue
//  (the default) with a short delay; waitForExpectations spins the run loop so
//  the scheduled work items fire.
//

import XCTest
@testable import Dialog

final class DebouncedUpdaterTests: XCTestCase {

    func testRapidCallsCoalesceToLast() {
        let updater = DebouncedUpdater(delay: 0.05)
        var runCount = 0
        var lastValue = 0
        let ran = expectation(description: "debounced action runs")

        // Fire several times for the same key with no gap; only the last survives.
        for value in 1...5 {
            updater.debounce(key: "k") {
                runCount += 1
                lastValue = value
                if value == 5 { ran.fulfill() }
            }
        }

        wait(for: [ran], timeout: 1.0)
        XCTAssertEqual(runCount, 1, "Only the final debounced action should run")
        XCTAssertEqual(lastValue, 5)
    }

    func testCancelPreventsExecution() {
        let updater = DebouncedUpdater(delay: 0.05)
        var didRun = false
        updater.debounce(key: "k") { didRun = true }
        updater.cancel(key: "k")

        waitPastDelay()
        XCTAssertFalse(didRun, "A cancelled action must not run")
    }

    func testCancelAllPreventsExecution() {
        let updater = DebouncedUpdater(delay: 0.05)
        var aRan = false
        var bRan = false
        updater.debounce(key: "a") { aRan = true }
        updater.debounce(key: "b") { bRan = true }
        updater.cancelAll()

        waitPastDelay()
        XCTAssertFalse(aRan)
        XCTAssertFalse(bRan)
    }

    func testIndependentKeysBothRun() {
        let updater = DebouncedUpdater(delay: 0.05)
        let aRan = expectation(description: "a runs")
        let bRan = expectation(description: "b runs")
        updater.debounce(key: "a") { aRan.fulfill() }
        updater.debounce(key: "b") { bRan.fulfill() }
        wait(for: [aRan, bRan], timeout: 1.0)
    }

    /// Spin the run loop well past the debounce delay so any (uncancelled) work item
    /// would have fired.
    private func waitPastDelay() {
        let done = expectation(description: "waited")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { done.fulfill() }
        wait(for: [done], timeout: 1.0)
    }
}
