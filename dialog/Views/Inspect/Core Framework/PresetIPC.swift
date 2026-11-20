//
//  PresetIPC.swift
//  dialog
//
//  Session file IPC for every preset: the trigger, readiness, step_list and result files and the
//  key names external tools read from them.
//

import SwiftUI

// MARK: - IPC Helpers

/// `config.readinessFile`, else `<trigger>.ready`.
func resolveReadinessFilePath(config: InspectConfig?, triggerFilePath: String) -> String {
    config?.readinessFile ?? "\(triggerFilePath).ready"
}

/// The directory for per-pid session discovery JSON, or nil when publishing is off ("" or "none").
func resolvePublishedSessionsDir() -> String? {
    let raw = appArguments.publishedSessionsDir.value.trimmingCharacters(in: .whitespaces)
    guard !raw.isEmpty, raw.lowercased() != "none" else { return nil }
    return (raw as NSString).expandingTildeInPath
}

/// This process's published session file, `<dir>/<pid>.json`, or nil when publishing is off.
func resolvePublishedSessionPath() -> String? {
    guard let dir = resolvePublishedSessionsDir() else { return nil }
    let pid = ProcessInfo.processInfo.processIdentifier
    return (dir as NSString).appendingPathComponent("\(pid).json")
}

/// The trigger-file path: `config.triggerFile`, else a per-pid path. One session = one pid = one
/// trigger file, as with the notification channels. This process publishes the path in the
/// readiness JSON, the session file and the `ready` event; consumers read it there, never
/// re-derive it.
func presetTriggerFilePath(config: InspectConfig?) -> String {
    if let customPath = config?.triggerFile { return customPath }
    return "/tmp/swiftdialog_\(ProcessInfo.processInfo.processIdentifier).trigger"
}

// The derived paths take the trigger path, not the config, so callers cannot drift from them.

/// The completion-trigger path: `_final` spliced before the extension when there is one.
func finalTriggerPath(for triggerPath: String) -> String {
    let url = URL(fileURLWithPath: triggerPath)
    let ext = url.pathExtension
    let base = url.deletingPathExtension().path
    return ext.isEmpty ? "\(triggerPath)_final" : "\(base)_final.\(ext)"
}

/// The `step_list` response path; must match `CommandRouter`'s default.
func stepListPath(for triggerPath: String) -> String { "\(triggerPath).steps.json" }

/// The completion-trigger path for a config.
func presetFinalTriggerFilePath(config: InspectConfig?) -> String {
    finalTriggerPath(for: presetTriggerFilePath(config: config))
}

/// The fixed per-preset trigger path 3.1.1 used; v6 keeps it as a symlink so scripts keep working.
func legacyTriggerSymlinkPath(preset: Character) -> String { "/tmp/swiftdialog_dev_preset\(preset).trigger" }

/// Links the stable names to this session's files, once the config is loaded and before any
/// preset starts monitoring, so a script can rely on them from launch:
///   /tmp/swiftdialog_dev_presetN.trigger         → trigger           (3.1.1 path)
///   /tmp/swiftdialog_dev_presetN_final.trigger   → completion file   (3.1.1 path, presets 5/6)
///   /tmp/swiftdialog_dev_presetN.trigger.ready   → readiness file    (3.1.1 path)
/// The 3.1.1 names only apply when the config sets no `triggerFile` (3.1.1 then used the
/// configured path), and `.ready` only when it sets no `readinessFile`. A link to a file not
/// written yet dangles until it is, so `test -f` on `.ready` still means "ready". Best effort: a
/// failure is logged and never affects the session.
func installTriggerLinks(config: InspectConfig) {
    let trigger = presetTriggerFilePath(config: config)
    var links: [(String, String)] = []
    if config.triggerFile == nil, let n = config.preset.first(where: \.isNumber) {
        let legacy = legacyTriggerSymlinkPath(preset: n)
        links.append((legacy, trigger))
        // Presets 5 and 6 write a completion file; 3.1.1 offered `_final` for those two only.
        if n == "5" || n == "6" {
            links.append((finalTriggerPath(for: legacy), finalTriggerPath(for: trigger)))
        }
        if config.readinessFile == nil {
            links.append(("\(legacy).ready", resolveReadinessFilePath(config: config, triggerFilePath: trigger)))
        }
    }
    let fm = FileManager.default
    for (link, target) in links {
        // A stale link from an earlier session, or a plain file left by 3.1.1.
        if (try? fm.destinationOfSymbolicLink(atPath: link)) != nil || fm.fileExists(atPath: link) {
            do { try fm.removeItem(atPath: link) } catch {
                writeLog("IPC: cannot replace \(link) (owned by another user?): \(error.localizedDescription)",
                         logLevel: .error)
                continue
            }
        }
        do {
            try fm.createSymbolicLink(atPath: link, withDestinationPath: target)
            writeLog("IPC: link \(link) → \(target)", logLevel: .debug)
        } catch {
            writeLog("IPC: could not create link \(link): \(error.localizedDescription)", logLevel: .error)
        }
    }
}

/// Writes the readiness JSON, the published session file and the `ready` event once monitoring
/// and the command file are set up. Each carries every session path and the resolved
/// (pid-suffixed) channel names, so no consumer has to derive one.
func writeReadinessFile(config: InspectConfig?, triggerFilePath: String,
                        preset: String? = nil, itemCount: Int? = nil,
                        itemIDs: [String]? = nil) {
    let path = resolveReadinessFilePath(config: config, triggerFilePath: triggerFilePath)
    var json: [String: Any] = [
        "pid": ProcessInfo.processInfo.processIdentifier,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "triggerFile": triggerFilePath,
        "finalTriggerFile": finalTriggerPath(for: triggerFilePath),
        "stepListFile": stepListPath(for: triggerFilePath),
        "readinessFile": path,
        "ackChannel": DialogNotifications.ackName.rawValue,
        "eventChannel": DialogNotifications.eventName.rawValue,
        "commandChannel": DialogNotifications.commandName.rawValue
    ]
    if let preset { json["preset"] = preset }
    if let itemCount { json["itemCount"] = itemCount }
    if let itemIDs { json["items"] = Array(itemIDs.prefix(50)) }

    if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
        FileManager.default.createFile(atPath: (path as NSString).expandingTildeInPath, contents: data)
        print("[SWIFTDIALOG] readiness_file: \(path)")
        writeLog("IPC: Readiness file written to \(path)", logLevel: .info)

        // The session file lets external tools discover active sessions by directory listing.
        if let publishedPath = resolvePublishedSessionPath() {
            var published = json
            if let resultFile = config?.resultFile { published["resultFile"] = resultFile }
            if let eventFile = config?.eventFile { published["eventFile"] = eventFile }
            published["schemaVersion"] = 2
            let dir = (publishedPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            if let pubData = try? JSONSerialization.data(withJSONObject: published, options: .prettyPrinted) {
                FileManager.default.createFile(atPath: publishedPath, contents: pubData)
                print("[SWIFTDIALOG] published_session: \(publishedPath)")
                writeLog("IPC: Published session file at \(publishedPath)", logLevel: .info)
            }
        }

        // The `ready` event carries the same path set as the readiness JSON.
        var eventInfo: [String: String] = [
            "triggerFile": triggerFilePath,
            "finalTriggerFile": finalTriggerPath(for: triggerFilePath),
            "stepListFile": stepListPath(for: triggerFilePath),
            "readinessFile": path
        ]
        if let preset { eventInfo["preset"] = preset }
        if let itemCount { eventInfo["itemCount"] = String(itemCount) }
        if let itemIDs { eventInfo["items"] = itemIDs.prefix(50).joined(separator: ",") }
        eventInfo["ackChannel"] = DialogNotifications.ackName.rawValue
        eventInfo["commandChannel"] = DialogNotifications.commandName.rawValue
        eventInfo["eventChannel"] = DialogNotifications.eventName.rawValue
        DialogNotifications.postEvent(.ready, userInfo: eventInfo)
    }
}

/// Logs, cleans up the readiness file with the result counts, and terminates.
@MainActor
func presetCleanExit(state: InspectState, triggerFilePath: String,
                     label: String, message: String, exitCode: Int32 = 0) -> Never {
    writeLog("\(label): \(message)", logLevel: .info)
    cleanupReadinessFile(state: state, triggerFilePath: triggerFilePath, exitCode: Int(exitCode))
    exit(exitCode)
}

/// The item-preset exit: the readiness cleanup with completed / failed / total counts.
@MainActor
func cleanupReadinessFile(state: InspectState, triggerFilePath: String, exitCode: Int) {
    cleanupReadinessFile(config: state.config, triggerFilePath: triggerFilePath,
                         exitCode: exitCode,
                         completedCount: state.completedItems.count,
                         failedCount: state.failedItems.count,
                         totalSteps: state.items.count)
}

/// Posts the `exit` event with the result summary, then deletes the readiness and session files.
func cleanupReadinessFile(config: InspectConfig?, triggerFilePath: String,
                          exitCode: Int? = nil, completedCount: Int? = nil,
                          failedCount: Int? = nil, totalSteps: Int? = nil) {
    let path = resolveReadinessFilePath(config: config, triggerFilePath: triggerFilePath)

    var eventInfo: [String: String] = ["triggerFile": triggerFilePath]
    if let exitCode { eventInfo["exitCode"] = String(exitCode) }
    if let completedCount { eventInfo["completedCount"] = String(completedCount) }
    if let failedCount { eventInfo["failedCount"] = String(failedCount) }
    if let totalSteps { eventInfo["totalSteps"] = String(totalSteps) }
    if let resultFile = config?.resultFile { eventInfo["resultFile"] = resultFile }
    DialogNotifications.postEvent(.exit, userInfo: eventInfo)

    try? FileManager.default.removeItem(atPath: (path as NSString).expandingTildeInPath)
    writeLog("IPC: Readiness file cleaned up at \(path)", logLevel: .debug)

    if let publishedPath = resolvePublishedSessionPath() {
        try? FileManager.default.removeItem(atPath: publishedPath)
        writeLog("IPC: Published session file cleaned up at \(publishedPath)", logLevel: .debug)
    }
}

/// A step's identity for the result file.
struct ResultStepInfo {
    let id: String
    let stepType: String

    /// The entry type of an item preset's item; untyped steps report `resolvedStepType` instead.
    static let itemEntryType = "item"
}

/// Writes the `step_list` response: live order, status per step and the input snapshot, in the
/// result file's shape. Returns an error message (the rejection ack) or nil; posts the
/// `step_list` event after the atomic write.
@MainActor
func writeStepListResponse(path: String,
                           preset: String,
                           steps: [(id: String, stepType: String)],
                           state: InspectState,
                           currentIndex: Int,
                           progress: [String: Int] = [:],
                           formValues: [String: String] = [:],
                           selections: [String: [String]] = [:]) -> String? {
    var stepArray: [[String: Any]] = []
    for step in steps {
        var entry: [String: Any] = [
            "id": step.id,
            "stepType": step.stepType,
            "status": state.status(for: step.id).rawValue
        ]
        if let pct = progress[step.id] ?? state.itemProgress[step.id] {
            entry["progress"] = pct
        }
        stepArray.append(entry)
    }

    var result: [String: Any] = [
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "pid": ProcessInfo.processInfo.processIdentifier,
        "preset": preset,
        "count": steps.count,
        "currentIndex": currentIndex,
        "steps": stepArray
    ]
    if steps.indices.contains(currentIndex) {
        result["currentId"] = steps[currentIndex].id
    }
    if !formValues.isEmpty { result["formValues"] = formValues }
    if !selections.isEmpty { result["selections"] = selections }

    let expandedPath = (path as NSString).expandingTildeInPath
    guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) else {
        return "failed to serialize step list"
    }
    do {
        try data.write(to: URL(fileURLWithPath: expandedPath), options: .atomic)
    } catch {
        return "failed to write \(path): \(error.localizedDescription)"
    }
    DialogNotifications.postEvent(.stepList, userInfo: ["path": path, "count": String(steps.count)])
    writeLog("IPC: step_list response written to \(path)", logLevel: .info)
    return nil
}

/// The result file for an item-set exit: each step or item with its live state, plus user inputs
/// and dock picks. Dock order matters and `selections` sets are unordered, so each dock pick is
/// also written to `formValues` as `dock.<key>` with the ordered comma-joined paths. No-op
/// without `config.resultFile`.
@MainActor
func writeItemPresetResultFile(state: InspectState, exitCode: Int) {
    guard state.config?.resultFile != nil else { return }
    // Item presets author `items`, not steps; each item becomes an entry of its own type.
    let stepInfos = state.steps.isEmpty
        ? state.items.map { ResultStepInfo(id: $0.id, stepType: ResultStepInfo.itemEntryType) }
        : state.steps.map { ResultStepInfo(id: $0.id, stepType: $0.resolvedStepType) }
    var formValues = state.userValues
    var selections: [String: Set<String>] = [:]
    for (key, joined) in state.dockSelection {
        formValues["dock.\(key)"] = joined
        selections[key] = Set(joined.split(separator: ",").map(String.init))
    }
    // Form blocks write `guidanceFormInputs`, not `userValues`; flatten them in without
    // overwriting a picker's answer. A `secure: true` textfield's value must never reach a file
    // on disk.
    var secureIds = secureFieldIds(in: state.config?.guidanceContent)
    for item in state.config?.items ?? [] {
        secureIds.formUnion(secureFieldIds(in: item.guidanceContent))
    }
    for (key, value) in flattenedGuidanceFormValues(state.guidanceFormInputs,
                                                    excludingFieldIds: secureIds)
    where formValues[key] == nil {
        formValues[key] = value
    }
    let failed = Dictionary(uniqueKeysWithValues: state.failedItems.map {
        ($0, state.logMonitorStatuses[$0] ?? "failed")
    })
    // A failed item reports `completed` with result `failure`, never `pending`.
    writeResultFile(
        config: state.config, exitCode: exitCode, steps: stepInfos,
        completedSteps: state.completedItems.union(state.failedItems), failedSteps: failed,
        formValues: formValues, selections: selections
    )
}

/// Writes the JSON result file on exit: step statuses, selections and form values. A completed step
/// carries `result` = success | failure; the step keys are read by scripts, so do not rename them.
func writeResultFile(
    config: InspectConfig?,
    exitCode: Int,
    steps: [ResultStepInfo] = [],
    completedSteps: Set<String> = [],
    failedSteps: [String: String] = [:],
    skippedSteps: Set<String> = [],
    currentStepIndex: Int = 0,
    formValues: [String: String] = [:],
    selections: [String: Set<String>] = [:],
    selectedBrand: String? = nil
) {
    guard let resultPath = config?.resultFile else { return }

    var result: [String: Any] = [
        "exitCode": exitCode,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "pid": ProcessInfo.processInfo.processIdentifier,
        "lastStepIndex": currentStepIndex,
        "totalSteps": steps.count
    ]

    if !steps.isEmpty {
        let stepArray: [[String: Any]] = steps.map { step in
            var entry: [String: Any] = [
                "id": step.id,
                "stepType": step.stepType
            ]
            if completedSteps.contains(step.id) {
                entry["status"] = "completed"
                entry["result"] = failedSteps[step.id] != nil ? "failure" : "success"
            } else if skippedSteps.contains(step.id) {
                entry["status"] = "skipped"
            } else {
                entry["status"] = "pending"
            }
            if let reason = failedSteps[step.id] {
                entry["failureReason"] = reason
            }
            return entry
        }
        result["steps"] = stepArray
    }

    if !selections.isEmpty {
        result["selections"] = selections.mapValues { Array($0) }
    }

    if !formValues.isEmpty {
        result["formValues"] = formValues
    }

    if let brand = selectedBrand {
        result["selectedBrand"] = brand
    }

    let expandedPath = (resultPath as NSString).expandingTildeInPath
    if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]) {
        FileManager.default.createFile(atPath: expandedPath, contents: data)
        print("[SWIFTDIALOG] result_file: \(resultPath)")
        writeLog("IPC: Result file written to \(resultPath) (exitCode: \(exitCode))", logLevel: .info)
    }
}

/// Deminiaturizes the minimized window and brings the blur back, confined to the dialog's display.
func restoreDialogWindow() {
    DispatchQueue.main.async {
        if appArguments.blurScreen.present {
            blurredScreen.show()
            InspectBlurScope.confineToDialogScreen()
        }
        NSApp.windows.filter { $0.isMiniaturized }.first?.deminiaturize(nil)
    }
}

// MARK: - Window Minimize/Restore

/// Miniaturizes the dialog window without closing it. With `--blurscreen` the blur hides too, or
/// the user would face a blurred, empty screen.
func minimizeDialogWindow() {
    DispatchQueue.main.async {
        if appArguments.blurScreen.present { blurredScreen.hide() }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            (NSApp.keyWindow ?? NSApp.windows.first { $0.isVisible })?.miniaturize(nil)
        }
    }
}

/// `button1Action` / `button2Action` = "minimize": the button minimizes instead of exiting. Only
/// an exit is replaced; a button that navigates keeps navigating, and closes the app makes on its
/// own (`autoClose`, `quit:`) still exit.
enum ButtonExit {
    static func minimizes(_ action: String?) -> Bool {
        guard let action = action?.lowercased() else { return false }
        return action == "minimize" || action == "minimise"
    }

    /// Minimises and returns true when `action` asks for it; the caller exits otherwise.
    @discardableResult
    static func minimizeInsteadOfExiting(_ action: String?, label: String) -> Bool {
        guard minimizes(action) else { return false }
        writeLog("\(label): button action minimize — window sent to the Dock instead of exiting", logLevel: .info)
        minimizeDialogWindow()
        return true
    }
}
