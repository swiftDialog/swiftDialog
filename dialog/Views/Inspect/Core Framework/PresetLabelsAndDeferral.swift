//
//  PresetLabelsAndDeferral.swift
//  dialog
//
//  Label lookup and user-initiated deferral, shared by all presets.
//

import SwiftUI

// MARK: - Unified Label Resolution

/// Resolves a label by key.
/// Order: labels.translations[lang], labels[key], uiLabels/complianceLabels/pickerLabels, then fallback.
func resolveLabel(_ key: String, config: InspectConfig?, language: String? = nil, fallback: String? = nil) -> String? {
    if let resolved = config?.labels?.resolve(key, language: language) {
        return resolved
    }

    // Older label structs, looked up by key name
    if let ui = config?.uiLabels {
        switch key {
        case "completedStatus": return ui.completedStatus
        case "downloadingStatus": return ui.downloadingStatus
        case "pendingStatus": return ui.pendingStatus
        case "failedStatus": return ui.failedStatus
        case "progressFormat": return ui.progressFormat
        case "stepCounterFormat": return ui.stepCounterFormat
        case "completionMessage": return ui.completionMessage
        case "completionSubtitle": return ui.completionSubtitle
        case "sectionHeaderCompleted": return ui.sectionHeaderCompleted
        case "sectionHeaderPending": return ui.sectionHeaderPending
        case "sectionHeaderFailed": return ui.sectionHeaderFailed
        case "statusConditionMet": return ui.statusConditionMet
        case "statusConditionNotMet": return ui.statusConditionNotMet
        case "statusChecking": return ui.statusChecking
        case "statusReadyToStart": return ui.statusReadyToStart
        case "statusInProgress": return ui.statusInProgress
        case "welcomeTitle": return ui.welcomeTitle
        case "welcomeBadge": return ui.welcomeBadge
        case "welcomeParagraph1": return ui.welcomeParagraph1
        case "welcomeParagraph2": return ui.welcomeParagraph2
        case "guideInformationLabel": return ui.guideInformationLabel
        case "sectionsLabel": return ui.sectionsLabel
        case "keyPointsLabel": return ui.keyPointsLabel
        case "getStartedTitle": return ui.getStartedTitle
        case "getStartedSubtitle": return ui.getStartedSubtitle
        case "imageNotAvailable": return ui.imageNotAvailable
        default: break
        }
    }

    if let comp = config?.complianceLabels {
        switch key {
        case "complianceStatus": return comp.complianceStatus
        case "recommendedActions": return comp.recommendedActions
        case "securityDetails": return comp.securityDetails
        case "lastCheck": return comp.lastCheck
        case "passed": return comp.passed
        case "failed": return comp.failed
        case "checksPassed": return comp.checksPassed
        default: break
        }
    }

    if let picker = config?.pickerLabels {
        switch key {
        case "selectButtonText": return picker.selectButtonText
        case "selectedButtonText": return picker.selectedButtonText
        case "deselectButtonText": return picker.deselectButtonText
        case "continueButton": return picker.continueButton
        case "finishButton": return picker.finishButton
        case "backButton": return picker.backButton
        case "pageCounterFormat": return picker.pageCounterFormat
        case "selectionPrompt": return picker.selectionPrompt
        case "selectionRequired": return picker.selectionRequired
        case "multiSelectHint": return picker.multiSelectHint
        default: break
        }
    }

    return fallback
}

// MARK: - Shared Deferral System

/// Performs a user-initiated deferral: writes the result file, prints to stdout, posts the event, exits.
/// Follows the deferral protocol scripts expect: exit code 10 and a duration string ("3m", "1h", "1d", "tomorrow").
func performDeferral(duration: String, config: InspectConfig?) {
    let seconds = parseDeferralDuration(duration)
    let exitCode = config?.deferralConfig?.exitCode ?? 10

    writeLog("Deferral: User deferred for \(duration) (\(seconds)s), exitCode=\(exitCode)", logLevel: .info)

    // Result path: config.resultFile, else the SD_RESULT_FILE environment variable.
    let resultPath = config?.resultFile
        ?? ProcessInfo.processInfo.environment["SD_RESULT_FILE"]
    if let resultPath, !resultPath.isEmpty {
        let result: [String: Any] = [
            "exitCode": exitCode,
            "deferDuration": duration,
            "deferSeconds": seconds,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "pid": ProcessInfo.processInfo.processIdentifier
        ]
        let expandedPath = (resultPath as NSString).expandingTildeInPath
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
            FileManager.default.createFile(atPath: expandedPath, contents: data)
            writeLog("Deferral: Result file written to \(expandedPath)", logLevel: .info)
        }
    } else {
        writeLog("Deferral: No resultFile configured, skipping result file write", logLevel: .debug)
    }

    // Scripts parse this stdout line.
    print("defer:\(seconds)")

    DialogNotifications.postEvent(.deferred, userInfo: [
        "duration": duration,
        "seconds": String(seconds),
        "exitCode": String(exitCode),
        "resultFile": resultPath ?? ""
    ])

    exit(Int32(exitCode))
}

/// Parses a duration string into seconds: "30s", "30m", "1h", "1d", "tomorrow" (next 9 AM local), or raw seconds.
func parseDeferralDuration(_ s: String) -> Int {
    let trimmed = s.trimmingCharacters(in: .whitespaces).lowercased()

    if trimmed == "tomorrow" {
        let cal = Calendar.current
        let now = Date()
        var components = cal.dateComponents([.year, .month, .day], from: now)
        components.hour = 9
        components.minute = 0
        components.second = 0
        if let target9AM = cal.date(from: components) {
            let candidate = target9AM > now ? target9AM : cal.date(byAdding: .day, value: 1, to: target9AM)!
            return max(60, Int(candidate.timeIntervalSince(now)))
        }
        return 86400  // 24 hours
    }

    let suffixes: [(String, Int)] = [("d", 86400), ("h", 3600), ("m", 60), ("s", 1)]
    for (suffix, multiplier) in suffixes {
        if let numStr = trimmed.hasSuffix(suffix) ? String(trimmed.dropLast(suffix.count)) : nil,
           let num = Int(numStr), num > 0 {
            return num * multiplier
        }
    }

    return Int(trimmed) ?? 3600
}

/// Human-readable label for a duration string, e.g. "1h" → "1 Hour", "tomorrow" → "Tomorrow".
func deferralLabel(for duration: String) -> String {
    let trimmed = duration.trimmingCharacters(in: .whitespaces).lowercased()

    if trimmed == "tomorrow" { return "Tomorrow" }

    let units: [(String, String, String)] = [
        ("d", "Day", "Days"),
        ("h", "Hour", "Hours"),
        ("m", "Minute", "Minutes"),
        ("s", "Second", "Seconds")
    ]

    for (suffix, singular, plural) in units {
        if let numStr = trimmed.hasSuffix(suffix) ? String(trimmed.dropLast(suffix.count)) : nil,
           let num = Int(numStr), num > 0 {
            return "\(num) \(num == 1 ? singular : plural)"
        }
    }

    return duration
}

/// Deferral options: config.deferralConfig.options, else IGNITECLI_DEFER_OPTIONS, else defaults.
func resolvedDeferralOptions(config: InspectConfig?) -> [InspectConfig.DeferOption] {
    if let options = config?.deferralConfig?.options, !options.isEmpty {
        return options
    }

    if let envOptions = ProcessInfo.processInfo.environment["IGNITECLI_DEFER_OPTIONS"],
       !envOptions.isEmpty {
        return envOptions.components(separatedBy: ",").map { duration in
            InspectConfig.DeferOption(duration: duration.trimmingCharacters(in: .whitespaces), label: nil)
        }
    }

    return [
        InspectConfig.DeferOption(duration: "1h", label: nil),
        InspectConfig.DeferOption(duration: "4h", label: nil),
        InspectConfig.DeferOption(duration: "tomorrow", label: nil)
    ]
}

/// Whether deferral is enabled by the config or the environment.
func isDeferralEnabled(config: InspectConfig?) -> Bool {
    if config?.deferralConfig?.enabled == true { return true }
    return ProcessInfo.processInfo.environment["IGNITECLI_DEFER_ENABLED"] == "true"
}

