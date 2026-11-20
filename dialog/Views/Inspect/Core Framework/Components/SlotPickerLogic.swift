//
//  SlotPickerLogic.swift
//  Dialog
//
//  The slot picker's arithmetic: clamping, snapping, track position and label choice. Pure
//  functions; every instant is a parameter and nothing reads the clock or time zone.
//

import Synchronization
import Foundation

enum SlotPicker {

    // MARK: - The wire format

    /// Shared formatter; `ISO8601DateFormatter` is not `Sendable`, so it lives behind a `Mutex`.
    private static let iso: Mutex<ISO8601DateFormatter> = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return Mutex(formatter)
    }()

    /// The wire representation of an instant: ISO-8601 with an offset, never the readout text.
    static func isoString(_ date: Date) -> String { iso.withLock { $0.string(from: date) } }

    /// The inverse; nil for anything unparseable so a corrupt restored value is dropped.
    static func isoDate(_ raw: String) -> Date? { iso.withLock { $0.date(from: raw) } }

    /// Clamp to [start, deadline], snap to the nearest granularity boundary, then clamp again
    /// since snapping can round past the deadline. Ties round to the later boundary.
    static func snap(_ instant: Date, start: Date, deadline: Date, granularityMinutes: Int) -> Date {
        let clamped = min(max(instant, start), deadline)
        guard granularityMinutes > 0 else { return clamped }

        let granularity = TimeInterval(granularityMinutes * 60)
        let elapsed = clamped.timeIntervalSince(start)
        let snappedElapsed = (elapsed / granularity).rounded() * granularity
        let snapped = start.addingTimeInterval(snappedElapsed)

        return min(max(snapped, start), deadline)
    }

    /// 0…1 position on the track; clamped, and 0 for a non-positive window.
    static func position(of instant: Date, start: Date, windowHours: Int) -> Double {
        guard windowHours > 0 else { return 0 }

        let windowSeconds = TimeInterval(windowHours * 3600)
        let elapsed = instant.timeIntervalSince(start)
        return min(max(elapsed / windowSeconds, 0), 1)
    }

    /// Whole hours between start and chosen, floored, never negative.
    static func exposureHours(from start: Date, to chosen: Date) -> Int {
        let elapsed = chosen.timeIntervalSince(start)
        guard elapsed > 0 else { return 0 }
        return Int(elapsed / 3600)
    }

    /// Resolve a quickPick/defaultAt value: an ISO-8601 instant, or "now" / "deadline"
    /// (case-insensitive). nil for anything unparseable.
    static func resolve(_ at: String, now: Date, deadline: Date) -> Date? {
        switch at.lowercased() {
        case "now":
            return now
        case "deadline":
            return deadline
        default:
            return isoDate(at)
        }
    }

    /// The primary button's label. `format` carries "{time}"; when chosen equals now, `atNow` wins.
    static func primaryLabel(chosen: Date, now: Date, format: String, atNow: String,
                             timeText: String) -> String {
        guard chosen != now else { return atNow }
        return format.replacingOccurrences(of: "{time}", with: timeText)
    }

    /// Floor `date` to a granularity boundary relative to the Unix epoch. A view floors its `start`
    /// through this so `snap` is a no-op on an already clock-aligned authored instant.
    static func floorToGranularity(_ date: Date, granularityMinutes: Int) -> Date {
        guard granularityMinutes > 0 else { return date }
        let granularitySeconds = Double(granularityMinutes * 60)
        let interval = date.timeIntervalSince1970
        let floored = (interval / granularitySeconds).rounded(.down) * granularitySeconds
        return Date(timeIntervalSince1970: floored)
    }

    /// The inverse of `position`; `fraction` is clamped to 0…1 and a non-positive window
    /// returns `start`.
    static func instant(atPosition fraction: Double, start: Date, windowHours: Int) -> Date {
        guard windowHours > 0 else { return start }
        let clampedFraction = min(max(fraction, 0), 1)
        let windowSeconds = TimeInterval(windowHours * 3600)
        return start.addingTimeInterval(clampedFraction * windowSeconds)
    }

    /// The instant halfway across the track; `start` for a non-positive window.
    static func midpoint(start: Date, windowHours: Int) -> Date {
        guard windowHours > 0 else { return start }
        return start.addingTimeInterval(Double(windowHours) * 3600 / 2)
    }
}
