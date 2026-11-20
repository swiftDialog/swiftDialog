//
//  DetectionExplain.swift
//
//  The `--inspect-lint --explain` report for a row that never completes. It calls the runtime matchers
//  (`FilenameMatching`, `PathGlob`), so it agrees with real detection, and it only suggests
//  filenames the matcher accepts.
//

import Foundation

enum DetectionExplain {

    /// The report text plus the fault count the CLI turns into its exit code.
    struct Result {
        let text: String
        let faults: Int
    }

    /// Fixed line shape tests read: one line per item, the filename last and containing no spaces.
    private static let acceptsPrefix = "  matcher   accepts "

    static func report(for config: InspectConfig) -> String { evaluate(for: config).text }

    static func evaluate(for config: InspectConfig) -> Result {
        var out: [String] = []
        var faults = 0

        let items = monitoredItems(in: config)
        let receiptsBasePath = config.receiptsBasePath ?? "/var/db/receipts"
        out.append("swiftDialog — detection report")
        out.append("items: \(items.count)")
        if items.isEmpty {
            // Not a fault; stated so a clean verdict is not read as "detection works".
            out.append("note: this config monitors nothing — it has no detection behaviour to "
                       + "report on, and a clean verdict below says only that.")
        }

        // An unreadable cache is indistinguishable from "nothing is downloading" at runtime.
        let caches = config.cachePaths ?? []
        if caches.isEmpty {
            out.append("cachePaths: none authored — no item can ever report as downloading")
        } else {
            for cache in caches {
                let readable = FileManager.default.isReadableFile(atPath: cache)
                    || (try? FileManager.default.contentsOfDirectory(atPath: cache)) != nil
                out.append("cachePaths: \(cache) \(readable ? "readable" : "UNREADABLE")")
                if !readable { faults += 1 }
            }
        }

        for monitor in logMonitors(in: config) {
            let known = LogPatternPreset.presets[monitor.preset ?? ""] != nil
            out.append("logMonitor: \(monitor.path) preset=\(monitor.preset ?? "<custom pattern>")"
                       + (monitor.preset == nil ? "" : (known ? " (known)" : " UNKNOWN PRESET")))
            if monitor.preset != nil, !known { faults += 1 } else if let preset = monitor.preset,
                    let mechanic = DetectionMechanic(rawValue: preset) {
                out.append("            caveat: \(mechanic.caveat)")
            }
        }

        for item in items {
            out.append("")
            out.append("item \(item.id) — \"\(item.displayName)\"")

            if item.paths.isEmpty && (item.requirements?.isEmpty ?? true) {
                // The poller skips rows without paths, so this row only moves over IPC.
                out.append("  paths     none, and no requirements — this row can only be driven "
                           + "over IPC and will never change by itself")
                faults += 1
            }

            // Declared requirements decide the row on every preset (the runtime's RequirementEvaluator), and
            // its paths are then not checked, so an absent path is not a fault there.
            let verdict = RequirementEvaluator.evaluate(item, receiptsBasePath: receiptsBasePath)
            for path in item.paths {
                let expanded = (path as NSString).expandingTildeInPath
                let present = PathGlob.exists(atPath: expanded)
                if verdict != nil {
                    out.append("  path      \(path) \(present ? "present" : "absent")"
                               + " (not used: requirements decide)")
                } else {
                    out.append("  path      \(path) \(present ? "present" : "ABSENT")")
                    if !present { faults += 1 }
                }
            }

            for requirement in item.requirements ?? [] {
                let met = RequirementEvaluator.isSatisfied(requirement, receiptsBasePath: receiptsBasePath)
                out.append("  require   type=\(requirement.type) \(requirementDetail(requirement)) "
                           + (met ? "met" : "NOT MET"))
            }
            if let verdict {
                let rule = item.satisfy?.lowercased() == "any" ? "any one must pass" : "all must pass"
                out.append("  decides   requirements, \(rule): \(verdict.satisfied) of \(verdict.total) met, "
                           + (verdict.done ? "the row completes" : "the row WAITS"))
                if !verdict.done { faults += 1 }
            }

            if caches.isEmpty {
                out.append("  matcher   no cachePaths authored, so no filename can be matched")
            } else if let accepted = acceptedFilename(for: item) {
                out.append("\(acceptsPrefix)\(accepted)")
            } else {
                out.append("  matcher   NO CANDIDATE ACCEPTED — nothing this tool can suggest "
                           + "would match; give the item an id that appears in the filename")
                faults += 1
            }
        }

        out.append("")
        out.append(faults == 0 ? "verdict: no faults found"
                               : "verdict: \(faults) fault\(faults == 1 ? "" : "s")")
        return Result(text: out.joined(separator: "\n"), faults: faults)
    }

    // MARK: - The suggestion

    /// The first candidate filename the real matcher accepts; candidates are space-free because the
    /// report puts the filename last on its line.
    private static func acceptedFilename(for item: any MonitoredItem) -> String? {
        let squashed = item.displayName.replacingOccurrences(of: " ", with: "")
        let underscored = item.displayName.replacingOccurrences(of: " ", with: "_")
        let candidates = [
            "\(squashed).pkg",
            "\(item.id).pkg",
            "\(underscored).pkg",
            "\(item.id)-1.0.pkg"
        ]
        return candidates.first { candidate in
            !candidate.contains(" ")
                && FilenameMatching.matches(itemId: item.id, displayName: item.displayName,
                                            filename: candidate, brandFuzzy: true, log: nil)
        }
    }

    // MARK: - Gathering

    /// Items from both authoring shapes: the flat `config.items` and the stepped `introSteps[].items`.
    private static func monitoredItems(in config: InspectConfig) -> [any MonitoredItem] {
        var all: [any MonitoredItem] = config.items
        for step in config.introSteps ?? [] {
            all.append(contentsOf: (step.items ?? []) as [any MonitoredItem])
        }
        return all
    }

    private static func logMonitors(in config: InspectConfig) -> [InspectConfig.LogMonitorConfig] {
        var all: [InspectConfig.LogMonitorConfig] = []
        if let single = config.logMonitor { all.append(single) }
        all.append(contentsOf: config.logMonitors ?? [])
        return all
    }

    private static func requirementDetail(_ requirement: InspectConfig.ItemConfig.Requirement) -> String {
        var parts: [String] = []
        if let values = requirement.paths, !values.isEmpty {
            parts.append("paths=\(values.joined(separator: ","))")
        }
        if let value = requirement.bundleId { parts.append("bundleId=\(value)") }
        if let value = requirement.pkgId { parts.append("pkgId=\(value)") }
        if let value = requirement.domain ?? requirement.path { parts.append("plist=\(value)") }
        if let value = requirement.key { parts.append("key=\(value)") }
        if let value = requirement.expectedValue { parts.append("expected=\(value)") }
        if requirement.negate == true { parts.append("negated") }
        return parts.isEmpty ? "(no target)" : parts.joined(separator: " ")
    }
}
