//
//  DateDisplayService.swift
//  dialog
//
//  Date formatting and plist-date parsing for inspect mode, in the style and locale the config selects.
//

import Foundation
import Synchronization

/// Shared date formatter, configured from `dateStyle` in the config. Called off the main actor too,
/// so all mutable state sits in one `State` behind a `Mutex`; no `DateFormatter` leaves the lock.
final class DateDisplayService: Sendable {
    static let shared = DateDisplayService()

    enum DateStyle: String, CaseIterable, Sendable {
        case relative   // "2 hours ago" / "vor 2 Stunden"
        case short      // "3/14/26, 3:45 PM" / "14.03.26, 15:45"
        case medium     // "Mar 14, 2026, 3:45 PM" / "14. März 2026, 15:45" (default)
        case long       // "March 14, 2026 at 3:45 PM" / "14. März 2026 um 15:45"
        case iso8601    // "2026-03-14T15:45:00Z" (locale-independent)
    }

    private struct State {
        var style: DateStyle = .medium

        /// Locale of the cached formatters; nil means the system's. Follows the UI language so a forced
        /// language does not render dates with the system locale's joiners.
        var displayLocale: Locale?

        // MARK: Cached formatters

        private var short: DateFormatter?
        private var medium: DateFormatter?
        private var long: DateFormatter?
        private var relative: RelativeDateTimeFormatter?
        private var iso: ISO8601DateFormatter?
        private var legacy: [DateFormatter]?

        private mutating func dateFormatter(_ slot: WritableKeyPath<State, DateFormatter?>,
                                            date: DateFormatter.Style) -> DateFormatter {
            if let f = self[keyPath: slot] { return f }
            let formatter = DateFormatter()
            formatter.dateStyle = date
            formatter.timeStyle = .short
            if let displayLocale { formatter.locale = displayLocale }
            self[keyPath: slot] = formatter
            return formatter
        }

        mutating func isoFormatter() -> ISO8601DateFormatter {
            if let iso { return iso }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            iso = formatter
            return formatter
        }

        private mutating func relativeFormatter() -> RelativeDateTimeFormatter {
            if let relative { return relative }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            if let displayLocale { formatter.locale = displayLocale }
            relative = formatter
            return formatter
        }

        /// Non-ISO formats accepted when parsing plist date strings.
        mutating func legacyParsers() -> [DateFormatter] {
            if let legacy { return legacy }
            let formats = [
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd",
                "MM/dd/yyyy HH:mm:ss",
                "dd.MM.yyyy HH:mm:ss"
            ]
            let parsers = formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }
            legacy = parsers
            return parsers
        }

        /// Drops the locale-bearing formatters; a `DateFormatter`'s locale is fixed at first use.
        mutating func resetFormatters() {
            short = nil
            medium = nil
            long = nil
            relative = nil
        }

        mutating func format(_ date: Date) -> String {
            switch style {
            case .relative: return relativeFormatter().localizedString(for: date, relativeTo: Date())
            case .short:    return dateFormatter(\.short, date: .short).string(from: date)
            case .medium:   return dateFormatter(\.medium, date: .medium).string(from: date)
            case .long:     return dateFormatter(\.long, date: .long).string(from: date)
            case .iso8601:  return isoFormatter().string(from: date)
            }
        }
    }

    private let state = Mutex(State())

    private init() {}

    // MARK: - Configuration

    /// Sets the style from the config's `dateStyle`; nil or unknown means medium.
    func configure(style styleString: String?) {
        let style = DateStyle(rawValue: styleString ?? "medium") ?? .medium
        state.withLock { $0.style = style }
        writeLog("DateDisplayService: Configured with style '\(style.rawValue)'", logLevel: .info)
    }

    /// Points the formatters at the resolved UI language; nil restores the system locale.
    func configure(languageCode: String?) {
        let newLocale = languageCode.map { Locale(identifier: $0) }
        let changed = state.withLock { s -> Bool in
            guard newLocale?.identifier != s.displayLocale?.identifier else { return false }
            s.displayLocale = newLocale
            s.resetFormatters()
            return true
        }
        guard changed else { return }
        writeLog("DateDisplayService: Display locale set to '\(newLocale?.identifier ?? "system")'",
                 logLevel: .info)
    }

    var currentStyle: DateStyle {
        state.withLock { $0.style }
    }

    // MARK: - Formatting

    /// Formats a date in the configured style and locale.
    func format(_ date: Date) -> String {
        state.withLock { $0.format(date) }
    }

    // MARK: - Parsing

    /// Parses a plist value into a Date: a `Date`, an ISO 8601 or legacy-format string, or a Unix
    /// timestamp in seconds.
    func parse(_ value: Any?) -> Date? {
        guard let value = value else { return nil }

        if let date = value as? Date {
            return date
        }

        if let stringValue = value as? String {
            return state.withLock { s -> Date? in
                if let date = s.isoFormatter().date(from: stringValue) { return date }
                for parser in s.legacyParsers() {
                    if let date = parser.date(from: stringValue) { return date }
                }
                return nil
            }
        }

        if let timestamp = value as? TimeInterval {
            return Date(timeIntervalSince1970: timestamp)
        }

        if let number = value as? NSNumber {
            return Date(timeIntervalSince1970: number.doubleValue)
        }

        return nil
    }

    /// `parse` then `format`; `fallback` when the value is not a date.
    func parseAndFormat(_ value: Any?, fallback: String = "Never") -> String {
        guard let date = parse(value) else {
            return fallback
        }
        return format(date)
    }
}
