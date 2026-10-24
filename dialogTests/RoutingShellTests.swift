//
//  RoutingShellTests.swift
//  dialogTests
//
//  What the routing shell reads: the clocks and the blur scope.
//

import XCTest
import SwiftUI
import Synchronization
@testable import Dialog

// MARK: - Clocks

/// `Countdown` and `Poll`: the tick sequence, firing once at zero, cancel never firing, and an injected tick.
@MainActor
final class ClocksTests: XCTestCase {

    /// A tick that returns at once, so a whole countdown runs in one `await`.
    private let instant: Countdown.Tick = { _ in }

    func testCountdownTicksDownAndFiresOnceAtZero() async {
        let clock = Countdown(seconds: 3, tick: instant)
        var ticks: [Int] = []
        var fires = 0
        await clock.start(onTick: { ticks.append($0) }, onFire: { fires += 1 }).value
        XCTAssertEqual(ticks, [2, 1, 0], "every decrement is reported, the last with zero")
        XCTAssertEqual(fires, 1)
        XCTAssertTrue(clock.fired)
        XCTAssertEqual(clock.remaining, 0)
        XCTAssertEqual(clock.label, "0:00")
    }

    func testCancelledCountdownNeverFires() async {
        // A tick that throws on the second call: the loop treats it as cancellation.
        let calls = Mutex(0)
        let clock = Countdown(seconds: 5, tick: { _ in
            let n = calls.withLock { $0 += 1; return $0 }
            if n == 2 { throw CancellationError() }
        })
        var fired = false
        await clock.start(onFire: { fired = true }).value
        XCTAssertFalse(fired)
        XCTAssertFalse(clock.fired)
        XCTAssertEqual(clock.remaining, 4, "one tick landed before the cancel")
    }

    func testCancelIsIdempotentAndZeroSecondsFiresImmediately() async {
        let clock = Countdown(seconds: 0, tick: instant)
        var fires = 0
        await clock.start(onFire: { fires += 1 }).value
        XCTAssertEqual(fires, 1, "a zero-length countdown fires without ticking")
        clock.cancel(); clock.cancel()
        XCTAssertEqual(fires, 1)
    }

    /// Ticks are fixed deadlines from the start (start + 1 s, + 2 s…), so a late wake-up does not drift.
    func testTicksAreDeadlinesFromTheStartNotRelativeSleeps() async {
        let asked = Mutex<[ContinuousClock.Instant]>([])
        let clock = Countdown(seconds: 3, tick: { deadline in asked.withLock { $0.append(deadline) } })
        await clock.start(onFire: {}).value
        let d = asked.withLock { $0 }
        XCTAssertEqual(d.count, 3, "one deadline per second")
        XCTAssertEqual(d[1] - d[0], .seconds(1))
        XCTAssertEqual(d[2] - d[0], .seconds(2), "measured from the start, not from the last tick")
    }

    func testLabelIsTheOneFormatter() {
        XCTAssertEqual(Countdown.mmss(0), "0:00")
        XCTAssertEqual(Countdown.mmss(59), "0:59")
        XCTAssertEqual(Countdown.mmss(61), "1:01")
        XCTAssertEqual(Countdown.mmss(3600), "1:00:00")
        XCTAssertEqual(Countdown.mmss(-5), "0:00", "never negative")
    }

    func testPollRunsItsBodyEveryTickUntilCancelled() async {
        let calls = Mutex(0)
        let poll = Poll(every: 5, tick: {
            let n = calls.withLock { $0 += 1; return $0 }
            if n > 3 { throw CancellationError() }
        })
        var runs = 0
        await poll.start { runs += 1 }.value
        XCTAssertEqual(runs, 3, "three ticks landed, the fourth was the cancel")
    }

    /// A poll never goes below its floor, so `autoAdvanceDelay: 0` cannot spin the main actor.
    func testPollIntervalHasAFloor() {
        XCTAssertEqual(Poll(every: 0).interval, Poll.floor)
        XCTAssertEqual(Poll(every: -3).interval, Poll.floor)
        XCTAssertEqual(Poll(every: 2).interval, 2)
    }
}

/// The real `Task.sleep` tick once: a two-second countdown fires in well under ten.
@MainActor
final class ClocksRealTickTests: XCTestCase {
    func testRealTickFiresATwoSecondCountdown() async {
        let clock = Countdown(seconds: 2)
        let start = Date()
        var fired = false
        await clock.start(onFire: { fired = true }).value
        XCTAssertTrue(fired)
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 1.5, "it actually waited")
        XCTAssertLessThan(Date().timeIntervalSince(start), 10)
    }

    /// A released countdown stops at its next tick, so a clock in view `@State` does not outlive its view.
    func testReleasedCountdownStopsAtItsNextTick() async {
        var clock: Countdown? = Countdown(seconds: 20, tick: { _ in try await Task.sleep(for: .milliseconds(50)) })
        var fired = false
        var ticks = 0
        let run = clock!.start(onTick: { _ in ticks += 1 }, onFire: { fired = true })
        try? await Task.sleep(for: .milliseconds(130))
        clock = nil
        await run.value
        XCTAssertFalse(fired, "a released clock never fires")
        XCTAssertGreaterThan(ticks, 0, "it was running before it was released")
        XCTAssertLessThan(ticks, 20, "and it stopped short of zero")
    }
}

// MARK: - Inspect blur scope

/// `--blurscreen` in inspect keeps only the blur on the dialog's display, whatever the screen order.
final class InspectBlurScopeTests: XCTestCase {
    private let main = CGRect(x: 0, y: 0, width: 2560, height: 1440)
    private let side = CGRect(x: 2560, y: 0, width: 1920, height: 1080)

    func testTheOtherDisplaysBlurIsHidden() {
        XCTAssertEqual(InspectBlurScope.framesToHide(blurFrames: [main, side], dialogScreenFrame: main), [1])
        XCTAssertEqual(InspectBlurScope.framesToHide(blurFrames: [side, main], dialogScreenFrame: main), [0])
    }

    func testOneDisplayHidesNothing() {
        XCTAssertEqual(InspectBlurScope.framesToHide(blurFrames: [main], dialogScreenFrame: main), [])
    }
}
