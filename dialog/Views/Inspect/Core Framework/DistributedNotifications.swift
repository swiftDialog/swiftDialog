//
//  DistributedNotifications.swift
//  dialog
//
//  DistributedNotificationCenter IPC: external tools observe the events the dialog posts and post
//  commands it runs. Channels are per session (pid-suffixed), with the un-suffixed names kept
//  for older scripts:
//    com.swiftdialog.event.<pid>    events the dialog emits
//    com.swiftdialog.command.<pid>  commands the dialog observes
//    com.swiftdialog.ack.<pid>      acknowledgments
//  Every event carries `event` (an `EventType` raw value) and `pid`; the per-event extras are
//  listed on `EventType`. A tool may send a command on both this channel and the trigger file
//  with the same `nonce`; `CommandRouter` runs each nonce once.

import AppKit
import Foundation

@MainActor
enum DialogNotifications {

    // MARK: - Notification Names

    /// This session's pid, the channel suffix that isolates sessions from each other.
    nonisolated static let sessionPid = ProcessInfo.processInfo.processIdentifier

    /// Events the dialog posts.
    nonisolated static let eventName =
        NSNotification.Name("com.swiftdialog.event.\(DialogNotifications.sessionPid)")

    /// Commands the dialog observes.
    nonisolated static let commandName =
        NSNotification.Name("com.swiftdialog.command.\(DialogNotifications.sessionPid)")

    /// Acknowledgments of commands.
    nonisolated static let ackName =
        NSNotification.Name("com.swiftdialog.ack.\(DialogNotifications.sessionPid)")

    /// The names without the pid, still posted to and observed for older scripts. A command on
    /// them that names another `pid` is ignored.
    nonisolated static let legacyEventName = NSNotification.Name("com.swiftdialog.event")
    nonisolated static let legacyAckName = NSNotification.Name("com.swiftdialog.ack")
    nonisolated static let legacyCommandNames = [NSNotification.Name("com.swiftdialog.command"),
                                                 NSNotification.Name("com.ignitecli.command")]

    // MARK: - Event Vocabulary

    /// The event vocabulary; raw values are what consumers read from `userInfo["event"]`, so adding
    /// or renaming a case is a breaking change. All extra values are strings.
    nonisolated enum EventType: String {
        /// Ready for commands. Extras: triggerFile, finalTriggerFile, stepListFile, readinessFile,
        /// preset?, itemCount?, items? (comma-joined, at most 50), ackChannel, commandChannel, eventChannel.
        case ready
        /// About to terminate. Extras: triggerFile, exitCode?, completedCount?, failedCount?,
        /// totalSteps?, resultFile?.
        case exit
        /// A deferral was chosen. Extras: duration ("30m", "1h", "tomorrow"), seconds, exitCode, resultFile.
        case deferred = "defer"
        /// Extras: stepId, button, action.
        case button
        /// A step transition. Extras: stepId, action (e.g. "completed", "all_complete").
        case step
        /// A picker, grid or wallpaper selection. Extras: key, values (comma-joined), flavorId?.
        case selection
        /// A step was inserted. Extras: id, index, count. The key is `id`, never `stepId`: a
        /// consumer waiting on a step matches any event carrying that `stepId`.
        case stepAdded = "step_added"
        /// A step was removed. Extras: id, index, count.
        case stepRemoved = "step_removed"
        /// The step_list response file was written. Extras: path, count.
        case stepList = "step_list"
    }

    // MARK: - Post Events

    /// JSONL mirror of the event stream: every posted event also appends `{event, pid, timestamp,
    /// …userInfo}` here. Set once at inspect launch, before `ready` posts; classic mode never sets it.
    nonisolated(unsafe) private static var eventFilePath: String?
    /// Serial, so lines keep their order and file I/O stays off the posting path.
    nonisolated private static let eventFileQueue = DispatchQueue(label: "swiftdialog.eventfile", qos: .utility)

    nonisolated static func configureEventFile(_ path: String?) {
        eventFilePath = path
    }

    /// Posts an event on the session and legacy channels. `mirrorToFile: false` is for callers
    /// that write their own richer line to the event file.
    nonisolated static func postEvent(_ event: EventType, userInfo: [String: String] = [:],
                                      mirrorToFile: Bool = true) {
        var info = userInfo
        info["event"] = event.rawValue
        info["pid"] = String(ProcessInfo.processInfo.processIdentifier)

        for name in [eventName, legacyEventName] {
            DistributedNotificationCenter.default().postNotificationName(
                name, object: nil, userInfo: info, deliverImmediately: true
            )
        }

        if mirrorToFile, let path = eventFilePath {
            var entry = info
            entry["timestamp"] = ISO8601DateFormatter().string(from: Date())
            eventFileQueue.async { [entry] in
                guard let data = try? JSONSerialization.data(withJSONObject: entry),
                      let line = String(data: data, encoding: .utf8) else { return }
                let expandedPath = (path as NSString).expandingTildeInPath
                let lineData = (line + "\n").data(using: .utf8)!
                if let handle = FileHandle(forWritingAtPath: expandedPath) {
                    handle.seekToEndOfFile()
                    handle.write(lineData)
                    handle.closeFile()
                } else {
                    FileManager.default.createFile(atPath: expandedPath, contents: lineData)
                }
            }
        }
    }

    nonisolated static func postButtonClick(stepId: String, label: String, action: String) {
        postEvent(.button, userInfo: [
            "stepId": stepId,
            "button": label,
            "action": action
        ])
    }

    /// `mirrorToFile: false` is for callers that write their own step line to the event file.
    nonisolated static func postStepChange(stepId: String, action: String, mirrorToFile: Bool = true) {
        postEvent(.step, userInfo: [
            "stepId": stepId,
            "action": action
        ], mirrorToFile: mirrorToFile)
    }

    /// - Parameter flavorId: the identity behind `values` (a dock flavour or its decline value),
    ///   sent as an extra key so `key` and `values` keep their contract.
    nonisolated static func postSelection(key: String, values: [String], flavorId: String? = nil) {
        var userInfo = [
            "key": key,
            "values": values.joined(separator: ",")
        ]
        if let flavorId { userInfo["flavorId"] = flavorId }
        postEvent(.selection, userInfo: userInfo)
    }

    // MARK: - Acknowledgments

    /// Posts a command acknowledgment. `nonce` echoes the inbound command's nonce so same-verb
    /// acks can be told apart.
    nonisolated static func postAck(command: String, stepId: String, status: String = "OK",
                                    property: String? = nil, value: String? = nil, message: String? = nil,
                                    nonce: String? = nil) {
        var info: [String: String] = [
            "command": command, "stepId": stepId, "status": status,
            "pid": String(ProcessInfo.processInfo.processIdentifier)
        ]
        if let property { info["property"] = property }
        if let value { info["value"] = value }
        if let message { info["message"] = message }
        if let nonce { info["nonce"] = nonce }

        for name in [ackName, legacyAckName] {
            DistributedNotificationCenter.default().postNotificationName(
                name, object: nil, userInfo: info, deliverImmediately: true
            )
        }
    }

    // MARK: - Command Observer

    /// Receives a raw command line (the trigger-file format) and the sender's `nonce`.
    typealias CommandHandler = (String, String?) -> Void

    private static var observers: [NSObjectProtocol] = []
    /// Held here, not captured by the observer's `@Sendable` block, which reads it on `.main`.
    private static var commandHandler: CommandHandler?

    /// Observes this session's command channel and the legacy names.
    static func startObserving(handler: @escaping CommandHandler) {
        stopObserving()
        commandHandler = handler

        let ours = String(sessionPid)
        for name in [commandName] + legacyCommandNames {
            let legacy = name != commandName
            observers.append(DistributedNotificationCenter.default().addObserver(
                forName: name, object: nil, queue: .main
            ) { notification in
                // Reduced to `[String: String]` so nothing non-Sendable crosses into the actor.
                // Non-string values are kept as their text: `{"next": 1}` still means next.
                var info: [String: String] = [:]
                for (key, value) in notification.userInfo ?? [:] {
                    if let key = key as? String { info[key] = (value as? String) ?? "\(value)" }
                }
                if legacy, let pid = info["pid"], pid != ours { return }
                MainActor.assumeIsolated {
                    guard let handler = commandHandler else { return }
                    processCommandNotification(info, handler: handler)
                }
            })
        }
    }

    /// Hands a command line to the active router from inside the process. Dropped when no router
    /// is observing.
    static func dispatchLocally(_ command: String) {
        commandHandler?(command, nil)
    }

    static func stopObserving() {
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers.removeAll()
        commandHandler = nil
    }

    nonisolated private static func processCommandNotification(
        _ userInfo: [String: String], handler: CommandHandler
    ) {
        guard !userInfo.isEmpty else { return }

        // Every expansion carries the send's nonce; one key can expand to two commands (`badge`).
        let nonce = (userInfo["nonce"]).flatMap { $0.isEmpty ? nil : $0 }
        func emit(_ command: String) { handler(command, nonce) }

        if let command = userInfo["command"] {
            emit(command)
        }

        // `badge`: "blockId:state[:actual value]" → update_guidance with the wildcard stepId.
        if let badge = userInfo["badge"] {
            let parts = badge.split(separator: ":", maxSplits: 2)
            if parts.count >= 2 {
                emit("update_guidance:_:\(parts[0]):state=\(parts[1])")
                if parts.count >= 3 {
                    emit("update_guidance:_:\(parts[0]):actual=\(parts[2])")
                }
            }
        }

        if let update = userInfo["update_guidance"] {
            emit("update_guidance:\(update)")
        }

        if let navigate = userInfo["navigate"] {
            emit("navigate:\(navigate)")
        }

        if let batchJSON = userInfo["batch"] {
            emit("batch_update:\(batchJSON)")
        }

        // Verb-keyed shorthands: {"success": "edge:Done"} is "success:edge:Done".
        if let success = userInfo["success"] { emit("success:\(success)") }
        if let failure = userInfo["failure"] { emit("failure:\(failure)") }
        if let warning = userInfo["warning"] { emit("warning:\(warning)") }
        if let complete = userInfo["complete"] { emit("complete:\(complete)") }
        if let progress = userInfo["progress"] { emit("progress:\(progress)") }
        if let item = userInfo["item"] { emit("item:\(item)") }

        if let select = userInfo["select"] { emit("select:\(select)") }

        // Presence-triggered; the value is ignored.
        if userInfo["next"] != nil { emit("next") }
        if userInfo["prev"] != nil { emit("prev") }
        if userInfo["reset"] != nil { emit("reset") }
    }
}
