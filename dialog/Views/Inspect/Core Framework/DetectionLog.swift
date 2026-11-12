//
//  DetectionLog.swift
//
//  Diagnostics channel recording which detection engine (FSEvents, poller, log monitor, IPC,
//  requirements, census) moved an item. Off unless `DIALOG_DETECTION_LOG` names a path.
//

import Foundation

/// Which engine caused an item's state to change.
enum DetectionEngine: String {
    case fsevents, poller, logmonitor, command
    /// The requirement group evaluated on the monitoring tick (`RequirementEvaluator`).
    case requirements
    /// `ReceiptCensus`: a new receipt completed the next pending row, by count rather than by name.
    case census
}

enum DetectionLog {

    /// The environment variable that turns the channel on.
    static let variable = "DIALOG_DETECTION_LOG"

    /// Where lines go, or nil when the channel is off; an empty value counts as unset.
    static func destination(in environment: [String: String]) -> String? {
        guard let path = environment[variable], !path.isEmpty else { return nil }
        return path
    }

    /// One requirement as the evidence that satisfied it, e.g. `receipt com.example.pkg`.
    static func evidence(_ requirement: InspectConfig.ItemConfig.Requirement) -> String {
        let kind = requirement.type.lowercased()
        let what: String
        switch kind {
        case "receipt": what = requirement.pkgId ?? "(no pkgId)"
        case "path": what = (requirement.paths ?? []).joined(separator: "|")
        case "app": what = requirement.bundleId ?? "(no bundleId)"
        case "plist":
            what = (requirement.domain ?? requirement.path ?? "(no domain)") + ":" + (requirement.key ?? "(no key)")
        default: what = "(unknown type)"
        }
        return (requirement.negate == true ? "not " : "") + kind + " " + what
    }

    /// One transition as a line: `<iso8601> <itemId> <from> -> <to> by=<engine>`.
    static func line(itemId: String, from: String, to: String,
                     by engine: DetectionEngine, at: Date = Date()) -> String {
        let stamp = ISO8601DateFormatter().string(from: at)
        return "\(stamp) \(itemId) \(from) -> \(to) by=\(engine.rawValue)"
    }

    /// The from/to words for a poller transition; arms follow the priority order of
    /// `checkDirectInstallationStatus`.
    static func pollerWords(wasCompleted: Bool, wasDownloading: Bool,
                            isInstalled: Bool, isDownloading: Bool) -> (from: String, to: String) {
        if isInstalled && !wasCompleted {
            return (wasDownloading ? "downloading" : "pending", "completed")
        }
        if !isInstalled && wasCompleted {
            return ("completed", isDownloading ? "downloading" : "pending")
        }
        if isDownloading && !wasDownloading {
            return ("pending", "downloading")
        }
        // Reset to pending, and any combination not named above.
        return (wasDownloading ? "downloading" : (wasCompleted ? "completed" : "pending"), "pending")
    }

    /// A free-form line on the same channel as `note`, for config loads and commands, successful
    /// ones included.
    static func trace(_ text: String, at: Date = Date()) {
        append(ISO8601DateFormatter().string(from: at) + " " + text + "\n")
    }

    /// No-op when the channel is off; silent on write failure.
    private static func append(_ text: String) {
        guard let path = destination(in: ProcessInfo.processInfo.environment),
              let data = text.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Append one transition.
    static func note(itemId: String, from: String, to: String, by engine: DetectionEngine) {
        append(line(itemId: itemId, from: from, to: to, by: engine) + "\n")
        // The debug meter counts engine sources from the same transitions.
        InspectDebugMeter.shared.record(source: engine.rawValue, itemId: itemId, detail: "\(from) -> \(to)")
    }
}
