//
//  Clocks.swift
//  dialog
//
//  The two clocks inspect presets and services use: a visible `Countdown` that fires once and a
//  repeating `Poll`. Both are main-actor `Task`s with an injectable tick, so tests own their time.
//

import Foundation
import Observation

/// A running clock of either kind, so one `@State` seat and one `cancel()` cover both.
@MainActor
protocol ClockJob: AnyObject {
    func cancel()
}

// MARK: - Countdown

/// A visible clock: `seconds` down to zero, then it fires once. `onTick` runs after every decrement
/// with the new `remaining` (0 on the last); `onFire` runs once after that, both on the main actor.
@MainActor
@Observable
final class Countdown: ClockJob {
    /// Waits until an absolute deadline (start plus n seconds), so lateness never accumulates.
    typealias Tick = @Sendable (_ deadline: ContinuousClock.Instant) async throws -> Void

    let total: Int
    private(set) var remaining: Int
    private(set) var fired = false
    private var task: Task<Void, Never>?
    private let tick: Tick

    /// `tick` waits for each second's deadline; tests inject their own.
    init(seconds: Int, tick: @escaping Tick = { try await Task.sleep(until: $0, clock: .continuous) }) {
        self.total = max(0, seconds)
        self.remaining = self.total
        self.tick = tick
    }

    /// `m:ss`, or `h:mm:ss` past an hour.
    var label: String { Self.mmss(remaining) }

    @discardableResult
    func start(onTick: @escaping @MainActor (Int) -> Void = { _ in },
               onFire: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        task?.cancel()
        let tick = self.tick
        // `self` is weak and never held across the wait, so a released clock stops at its next tick
        // instead of firing into a view that has gone.
        let t = Task { @MainActor [weak self] in
            // Deadlines are absolute from here, so a late wake does not accumulate.
            let origin = ContinuousClock.now
            var n = 0
            while (self?.remaining ?? 0) > 0 {
                n += 1
                do { try await tick(origin + .seconds(n)) } catch { return }   // cancelled between ticks
                guard !Task.isCancelled, let self else { return }
                self.remaining -= 1
                onTick(self.remaining)
            }
            guard !Task.isCancelled, let self else { return }
            self.fired = true
            onFire()
        }
        task = t
        return t
    }

    /// Idempotent. A cancelled countdown never fires.
    func cancel() {
        task?.cancel()
        task = nil
    }

    /// Pure, so callable off the main actor.
    nonisolated static func mmss(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return s >= 3600
            ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
            : String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Poll

/// A repeating main-actor job. `body` runs after every interval until `cancel()`, the first run
/// after the first interval. The interval is measured from the end of the last run, so a poll
/// never bursts to catch up.
@MainActor
final class Poll: ClockJob {
    typealias Tick = @Sendable () async throws -> Void

    let interval: TimeInterval
    private var task: Task<Void, Never>?
    private let tick: Tick

    /// The shortest interval a poll accepts; a zero sleep would spin the main actor.
    static let floor: TimeInterval = 0.1

    init(every interval: TimeInterval,
         tick: Tick? = nil) {
        let interval = max(Self.floor, interval)
        self.interval = interval
        self.tick = tick ?? { try await Task.sleep(for: .seconds(interval)) }
    }

    @discardableResult
    func start(_ body: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        task?.cancel()
        let tick = self.tick
        let t = Task { @MainActor [weak self] in    // a released poll stops, as Countdown does
            while true {
                do { try await tick() } catch { return }
                guard !Task.isCancelled, self != nil else { return }
                body()
            }
        }
        task = t
        return t
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
