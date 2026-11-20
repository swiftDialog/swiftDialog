//
//  RequirementEvaluator.swift
//  dialog
//
//  Rolls an item's requirements (paths, receipts, apps, plist values) up into one verdict. Pure;
//  the monitoring tick maps the verdict onto its status vocabulary.
//

import AppKit      // NSWorkspace resolves the "app" requirement via LaunchServices
import Foundation

struct RequirementEvaluation {
    let satisfied: Int
    let total: Int
    let done: Bool
}

enum RequirementEvaluator {

    /// The item's verdict, or nil when it declares no requirements (any-of paths detection applies).
    static func evaluate(_ item: any MonitoredItem,
                         receiptsBasePath: String) -> RequirementEvaluation? {
        guard let requirements = item.requirements, !requirements.isEmpty else { return nil }
        let satisfiedCount = requirements.filter {
            isSatisfied($0, receiptsBasePath: receiptsBasePath)
        }.count
        let anyMode = item.satisfy?.lowercased() == "any"
        let done = anyMode ? satisfiedCount >= 1 : satisfiedCount == requirements.count
        return RequirementEvaluation(satisfied: satisfiedCount,
                                     total: requirements.count,
                                     done: done)
    }

    static func isSatisfied(_ requirement: InspectConfig.ItemConfig.Requirement,
                            receiptsBasePath: String) -> Bool {
        let raw: Bool
        switch requirement.type.lowercased() {
        case "path":
            // Any listed path satisfies the one fact; `satisfy` applies across facts, not inside one.
            raw = (requirement.paths ?? []).contains { path in
                FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath)
            }
        case "app":
            // LaunchServices, not a path probe: an app in a non-standard location is still installed.
            if let bundleId = requirement.bundleId, !bundleId.isEmpty {
                raw = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
            } else {
                raw = false
            }

        case "receipt":
            // pkgutil writes <pkgId>.plist and .bom at install; either counts.
            if let pkgId = requirement.pkgId, !pkgId.isEmpty {
                let base = (receiptsBasePath as NSString).expandingTildeInPath
                raw = FileManager.default.fileExists(atPath: "\(base)/\(pkgId).plist")
                    || FileManager.default.fileExists(atPath: "\(base)/\(pkgId).bom")
            } else {
                raw = false
            }
        case "plist":
            raw = plistSatisfied(requirement)
        default:
            raw = false
        }
        return requirement.negate == true ? !raw : raw
    }

    private static func plistSatisfied(_ requirement: InspectConfig.ItemConfig.Requirement) -> Bool {
        guard let key = requirement.key, !key.isEmpty else { return false }

        let actualValue: String?
        if let domain = requirement.domain, !domain.isEmpty {
            // UserDefaults so managed preferences are included.
            let defaults = domain == ".GlobalPreferences"
                ? UserDefaults.standard : UserDefaults(suiteName: domain)
            actualValue = defaults?.object(forKey: key).map { String(describing: $0) }
        } else if let path = requirement.path, !path.isEmpty {
            let expandedPath = (path as NSString).expandingTildeInPath
            actualValue = PlistHelper.readPlist(at: expandedPath)?
                .value(forKeyPath: key).map { String(describing: $0) }
        } else {
            return false
        }

        // An unrecognised operator fails closed rather than becoming an equality test.
        guard let op = EvaluationOperator.resolve(evaluation: requirement.evaluation,
                                                  expectedValue: requirement.expectedValue) else {
            writeLog("RequirementEvaluator: unknown evaluation "
                     + "'\(requirement.evaluation ?? "")' on key '\(key)' — not satisfied",
                     logLevel: .error)
            return false
        }

        // Exhaustive on purpose: a new operator must be answered here.
        switch op {
        case .exists:
            return actualValue != nil
        case .boolean:
            return actualValue == "1" || actualValue?.lowercased() == "true"
        case .equals:
            return actualValue == requirement.expectedValue
        case .contains:
            // `actualValue` is already a string here, so an array-valued key can only substring-match.
            return EvaluationOperator.containsMatch(value: actualValue as Any,
                                                    expected: requirement.expectedValue)
        case .range:
            guard let actual = Int(actualValue ?? ""),
                  let parts = requirement.expectedValue?.split(separator: "-"), parts.count == 2,
                  let lower = Int(parts[0]), let upper = Int(parts[1]) else { return false }
            return actual >= lower && actual <= upper
        case .changed, .withinSeconds:
            // No baseline and no date parsing here; fail closed.
            return false
        }
    }
}
