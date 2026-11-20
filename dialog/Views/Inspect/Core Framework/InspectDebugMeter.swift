//
//  InspectDebugMeter.swift
//
//  Live metering for the opt-in debug panel: which row-moving source is alive on this host, a
//  running tail, and read-only probes of managed plists.
//

import Foundation
import Synchronization

/// One line of the running tail, tagged with its source so the panel can show one source at a time.
struct RecentLine: Equatable, Sendable {
    let at: Date
    let source: String?      // nil for lines that are not attributable to one source
    let text: String
}

/// One source's live account.
struct InspectSourceMeter: Equatable, Sendable {
    /// Rows actually moved.
    var count: Int = 0
    /// Lines that arrived for this source, matched or not; a source whose lines all miss is not silent.
    var attempts: Int = 0
    var lastItem: String = ""
    var lastDetail: String = ""
    var lastAt: Date?
}

/// A `Mutex`-guarded store the panel reads on a timer. Events arrive from the FSEvents queue,
/// the debouncer queue and main, and a debug instrument must not impose actor plumbing on the
/// code it measures.
final class InspectDebugMeter: Sendable {
    static let shared = InspectDebugMeter()

    /// The environment variable that shows the panel. The meter records regardless, so a panel
    /// opened mid-run shows history.
    static let variable = "DIALOG_INSPECT_DEBUG"

    static func panelEnabled(in environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let value = environment[variable]?.lowercased() else { return false }
        return !["", "0", "false", "no"].contains(value)
    }

    /// Everything this store holds, in one value behind one lock.
    private struct State: Sendable {
        var sources: [String: InspectSourceMeter] = [:]
        var facts: [(key: String, value: String)] = []
        var recent: [RecentLine] = []

        /// Caller is inside the lock.
        mutating func append(source: String?, _ text: String) {
            recent.append(RecentLine(at: Date(), source: source, text: text))
            if recent.count > 400 { recent.removeFirst(recent.count - 400) }
        }
    }

    private let state = Mutex(State())

    /// Every source that can move a row, listed whether or not it has: a zero is the finding.
    static let knownSources = ["fsevents", "poller", "logmonitor", "requirements", "census", "listitem", "cadence:message"]

    private init() {
        state.withLock { state in
            for name in Self.knownSources { state.sources[name] = InspectSourceMeter() }
        }
    }

    // MARK: - Recording

    func record(source: String, itemId: String, detail: String) {
        state.withLock { state in
            var meter = state.sources[source] ?? InspectSourceMeter()
            meter.count += 1
            meter.attempts += 1
            meter.lastItem = itemId
            meter.lastDetail = detail
            meter.lastAt = Date()
            state.sources[source] = meter
            state.append(source: source, "\(itemId)  \(detail)")
        }
    }

    /// A standing fact about this session (config path, chrome, step, row count). Last write per
    /// key wins.
    func note(fact key: String, _ value: String) {
        state.withLock { state in
            if let index = state.facts.firstIndex(where: { $0.key == key }) {
                state.facts[index].value = value
            } else {
                state.facts.append((key, value))
            }
        }
    }

    /// A tail line for something that is not a row transition: a command, a subject that matched
    /// nothing.
    func trace(_ text: String, source: String? = nil) {
        state.withLock { state in
            if let source {
                var meter = state.sources[source] ?? InspectSourceMeter()
                meter.attempts += 1
                meter.lastAt = Date()
                state.sources[source] = meter
            }
            state.append(source: source, text)
        }
    }

    // MARK: - Reading

    struct Snapshot: Equatable {
        var sources: [(name: String, meter: InspectSourceMeter)]
        var facts: [(String, String)]
        var recent: [RecentLine]

        static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
            lhs.recent == rhs.recent
                && lhs.facts.map(\.0) == rhs.facts.map(\.0)
                && lhs.facts.map(\.1) == rhs.facts.map(\.1)
                && lhs.sources.map(\.name) == rhs.sources.map(\.name)
                && lhs.sources.map(\.meter) == rhs.sources.map(\.meter)
        }
    }

    /// Writes everything collected so far to a file in `directory` and returns the path.
    func dump(to directory: String = "/private/tmp") -> String? {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let path = "\(directory)/dialog-debug-\(stamp).txt"
        let snap = snapshot()
        var out = ["swiftDialog inspect — debug dump \(stamp)", ""]
        out.append("SOURCES")
        for entry in snap.sources {
            let seen = entry.meter.lastAt.map { ISO8601DateFormatter().string(from: $0) } ?? "never"
            out.append("  \(entry.name.padding(toLength: 16, withPad: " ", startingAt: 0)) "
                       + "matched=\(entry.meter.count) arrived=\(entry.meter.attempts) last=\(seen) "
                       + "item=\(entry.meter.lastItem) \(entry.meter.lastDetail)")
        }
        out.append("")
        out.append("FACTS")
        for (key, value) in snap.facts { out.append("  \(key): \(value)") }
        out.append("")
        out.append("RECENT (oldest first, \(snap.recent.count) lines)")
        let formatter = ISO8601DateFormatter()
        for line in snap.recent {
            out.append("  \(formatter.string(from: line.at)) [\(line.source ?? "-")] \(line.text)")
        }
        let text = out.joined(separator: "\n") + "\n"
        guard let data = text.data(using: .utf8),
              (try? data.write(to: URL(fileURLWithPath: path))) != nil else { return nil }
        return path
    }

    func snapshot() -> Snapshot {
        state.withLock { state in
            // Known sources first in a fixed order so the panel does not reshuffle; extras follow, sorted.
            let extra = state.sources.keys.filter { !Self.knownSources.contains($0) }.sorted()
            let names = Self.knownSources + extra
            return Snapshot(sources: names.map { ($0, state.sources[$0] ?? InspectSourceMeter()) },
                            facts: state.facts.map { ($0.key, $0.value) },
                            recent: state.recent)
        }
    }
}

/// Reads out the keys of the preference domains the flow depends on, to answer whether a profile
/// has arrived. Reads the plist directly, not CFPreferences, whose cache can lag.
enum InspectPlistInspector {

    struct Domain: Identifiable {
        var id: String { name }
        let name: String
        let path: String
        let note: String
    }

    /// The known domains plus `extra`, each read from `/Library/Managed Preferences` when present,
    /// else `/Library/Preferences`.
    static func domains(extra: [String] = []) -> [Domain] {
        let known: [(String, String)] = [
            ("com.ignitecli", "the flow's own managed policy — the one that has gone missing"),
            ("com.fleetdm.fleetd.config", "Fleet's URL and enroll secret, read by orbit itself"),
            ("au.csiro.dialog", "swiftDialog's own defaults"),
            ("com.example.branding", "brand palette and logos from MDM")
        ]
        let names = known.map(\.0) + extra.filter { candidate in !known.contains { $0.0 == candidate } }
        return names.map { name in
            let managed = "/Library/Managed Preferences/\(name).plist"
            let local = "/Library/Preferences/\(name).plist"
            let path = FileManager.default.fileExists(atPath: managed) ? managed : local
            let note = known.first { $0.0 == name }?.1 ?? "requested for this run"
            return Domain(name: name, path: path, note: note)
        }
    }

    /// Every key in a domain, sorted, with values flattened to one line. nil when the file is
    /// absent, which differs from "arrived but empty".
    static func read(_ domain: Domain) -> [(String, String)]? {
        guard let data = FileManager.default.contents(atPath: domain.path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil)
                as? [String: Any] else { return nil }
        return plist.keys.sorted().map { key in
            (key, flatten(plist[key]))
        }
    }

    private static func flatten(_ value: Any?) -> String {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        case let array as [Any]: return "[" + array.map { flatten($0) }.joined(separator: ", ") + "]"
        case let dict as [String: Any]:
            return "{" + dict.keys.sorted().map { "\($0): \(flatten(dict[$0]))" }.joined(separator: ", ") + "}"
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        case let data as Data: return "<\(data.count) bytes>"
        default: return value.map { "\($0)" } ?? "—"
        }
    }
}
