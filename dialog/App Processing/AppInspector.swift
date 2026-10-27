//
//  AppInspector.swift
//  dialog
//
//  Two helpers for installation detection, and no monitor: `InspectState+InstallationDetection`
//  detects installations and `MonitoringModule` owns live monitoring.
//    · `PathGlob` — glob matching for configured item paths, read by
//      `InspectState+InstallationDetection` and covered by its own assertions.
//    · The row-signal helpers — pure, static, and the subject of their own tests.
//

import Foundation

/// Glob matching for configured item paths.
///
/// Exists because jamf drops a stub named after the PACKAGE into
/// `/Library/Application Support/JAMF/Receipts/`, so the name carries a version —
/// "Obsidian-1.12.7.pkg". An author matching that with an exact path writes a check that breaks on
/// the next release, so `.../Receipts/Obsidian*` has to be expressible.
///
/// Lives here, beside the detection it serves: `App Processing/` is not a synchronized folder, so a new
/// file there needs its project entries (the `Views/Inspect` folders pick files up on their own).
enum PathGlob {

    /// Whether a pattern contains glob magic. A plain path keeps exact-match semantics, so an
    /// author writing a literal path never silently gains prefix behaviour.
    static func needsGlob(_ pattern: String) -> Bool {
        pattern.contains(where: { $0 == "*" || $0 == "?" || $0 == "[" })
    }

    /// fnmatch, NOT regex. Package names are full of characters that are literal in a glob and
    /// magic in a regex — "SelfService+2.16.0.pkg" is the real example — and `.` must stay a
    /// literal dot rather than "any character".
    static func matches(name: String, pattern: String) -> Bool {
        name.withCString { n in pattern.withCString { p in fnmatch(p, n, 0) == 0 } }
    }

    /// Whether any file at `path` exists, honouring a glob in the LAST component only; the
    /// directory itself is always taken literally. The literal path is tried first: `[`, `?` and
    /// `*` are legal in file names ("Foo [Beta].app"), and 3.1.1 matched paths literally.
    static func exists(atPath path: String) -> Bool {
        if FileManager.default.fileExists(atPath: path) { return true }
        guard needsGlob(path) else { return false }
        let url = URL(fileURLWithPath: path)
        let directory = url.deletingLastPathComponent().path
        let pattern = url.lastPathComponent
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            return false
        }
        return entries.contains { matches(name: $0, pattern: pattern) }
    }
}

// MARK: - AppInspector: row-signal decisions

/// The pure part of what the retired monitor decided: given where a row is now and where it
/// was, what it should SAY. An `enum` rather than a `class` since the monitor went — there is
/// nothing to instantiate, and saying so structurally stops the shell being rebuilt by accident.
enum AppInspector {

    /// What a row should SAY, given where it is now and where it was.
    ///
    /// `.removed` exists because a removal and a cleared download present the SAME current state —
    /// `isInstalled:false, isCached:false` — and were both rendered as "Pending", so an app the
    /// user had just uninstalled read as "waiting to be installed". Only the history separates
    /// them, which is why `wasInstalled` is a parameter and not derivable here.
    ///
    /// Pure and static so the decision is testable without a filesystem.
    enum RowSignal { case installed, downloading, removed, pending }

    /// How long a removal stays worth announcing. After this the row settles back to plain
    /// "Pending": being uninstalled is a condition, not news.
    static let removalNoticeDwell: TimeInterval = 30

    static func removalNoticeExpired(removedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(removedAt) >= removalNoticeDwell
    }

    /// The prune's actual rule: which ids in a `removedItems`-shaped dictionary are past the
    /// dwell. Extracted so `checkDirectInstallationStatus`'s prune is testable without a real
    /// filesystem, a real item list, or a real debouncer — the same "pure decision, tested
    /// separately, called from the messy place" split as `signal(isInstalled:wasInstalled:isCached:)`
    /// above. `checkDirectInstallationStatus` is expected to be the ONLY caller that decides
    /// which ids to drop; a test that only exercises this function proves the arithmetic, not the
    /// wiring — `ExpiredNoticesWiringTests` in `DoorTests.swift` covers the wiring separately.
    static func expiredNotices(_ removed: [String: Date], now: Date = Date()) -> [String] {
        removed.filter { removalNoticeExpired(removedAt: $0.value, now: now) }.map(\.key)
    }

    /// The listitem STATE a signal maps to. `.removed` and `.pending` deliberately agree — a
    /// removed app is not installed, so its state is pending; only its statustext differs.
    static func rowState(for signal: RowSignal) -> String {
        switch signal {
        case .installed:   return "success"
        case .downloading: return "wait"
        case .removed, .pending: return "pending"
        }
    }

    static func signal(isInstalled: Bool, wasInstalled: Bool, isCached: Bool) -> RowSignal {
        if isInstalled { return .installed }            // a cached copy left over from the
        if wasInstalled { return .removed }             // install must not demote the row
        return isCached ? .downloading : .pending
    }
}
