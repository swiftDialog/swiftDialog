//
//  DistributedNotifications.swift
//  dialog
//
//  DistributedNotificationCenter bridge for cross-process IPC.
//  External tools (ignitecli, Fleet Desktop, custom scripts) can:
//    - Observe events posted by Dialog (button clicks, step changes, selections)
//    - Post commands that Dialog executes (update_guidance, navigate, etc.)
//
//  Channels:
//    Dialog → External:  com.swiftdialog.event     — UI events Dialog emits
//    External → Dialog:  com.swiftdialog.command    — commands Dialog observes
//    Dialog → External:  com.swiftdialog.ack       — acknowledgments for commands
//
//  Event vocabulary on `com.swiftdialog.event` is locked to the `EventType` enum
//  below. Every posted event always includes:
//    event : String  — EventType rawValue (ready | exit | defer | button | step | selection)
//    pid   : String  — Dialog process id (stringified Int32)
//
//  Per-event userInfo extras (all values stringified by callers):
//    ready      — { triggerFile, preset?, itemCount?, items?, ackChannel }
//                 items: comma-joined, capped at 50 ids; ackChannel: always "com.swiftdialog.ack"
//    exit       — { triggerFile, exitCode?, completedCount?, failedCount?, totalSteps?, resultFile? }
//    defer      — { duration, seconds, exitCode, resultFile }
//                 duration: human string ("30m", "1h", "tomorrow"); seconds: parsed Int
//    button     — { stepId, button, action }
//    step       — { stepId, action }
//                 action examples: "completed", "all_complete"
//    selection  — { key, values }
//                 values: comma-joined String
//
//  Adding a new EventType case is a breaking change for consumers — coordinate first.

import Foundation

@MainActor
enum DialogNotifications {

    // MARK: - Notification Names (nonisolated — these are constants, safe from any context)

    /// Posted by Dialog when UI events occur.
    nonisolated static let eventName = NSNotification.Name("com.swiftdialog.event")

    /// Observed by Dialog — external tools post commands here.
    nonisolated static let commandName = NSNotification.Name("com.swiftdialog.command")

    /// Also observe ignitecli's command channel for interoperability.
    nonisolated static let ignitecliCommandName = NSNotification.Name("com.ignitecli.command")

    /// Posted by Dialog when a command is acknowledged.
    nonisolated static let ackName = NSNotification.Name("com.swiftdialog.ack")

    // MARK: - Event Vocabulary

    /// Wire-format event types posted on `com.swiftdialog.event`. The raw value
    /// is what external consumers read from `userInfo["event"]`.
    nonisolated enum EventType: String {
        /// Dialog started; UI is ready to receive commands.
        case ready
        /// Dialog is about to terminate (normal close path).
        case exit
        /// User chose a deferral option from DeferralMenuView.
        case deferred = "defer"
        /// Button click in any preset.
        case button
        /// Step transition in flow-based presets (4 / 5 / 6).
        case step
        /// Picker / grid / wallpaper selection committed.
        case selection
    }

    // MARK: - Post Events

    /// Post a UI event notification that external tools can observe.
    nonisolated static func postEvent(_ event: EventType, userInfo: [String: String] = [:]) {
        var info = userInfo
        info["event"] = event.rawValue
        info["pid"] = String(ProcessInfo.processInfo.processIdentifier)

        DistributedNotificationCenter.default().postNotificationName(
            eventName, object: nil, userInfo: info, deliverImmediately: true
        )
    }

    /// Button click event.
    nonisolated static func postButtonClick(stepId: String, label: String, action: String) {
        postEvent(.button, userInfo: [
            "stepId": stepId,
            "button": label,
            "action": action,
        ])
    }

    /// Step transition event.
    nonisolated static func postStepChange(stepId: String, action: String) {
        postEvent(.step, userInfo: [
            "stepId": stepId,
            "action": action,
        ])
    }

    /// Selection event (grid picker, wallpaper, etc.).
    nonisolated static func postSelection(key: String, values: [String]) {
        postEvent(.selection, userInfo: [
            "key": key,
            "values": values.joined(separator: ","),
        ])
    }

    // MARK: - Acknowledgments

    /// Post a command acknowledgment notification that external tools can observe.
    nonisolated static func postAck(command: String, stepId: String, status: String = "OK",
                                    property: String? = nil, value: String? = nil, message: String? = nil) {
        var info: [String: String] = [
            "command": command, "stepId": stepId, "status": status,
            "pid": String(ProcessInfo.processInfo.processIdentifier)
        ]
        if let property { info["property"] = property }
        if let value { info["value"] = value }
        if let message { info["message"] = message }

        DistributedNotificationCenter.default().postNotificationName(
            ackName, object: nil, userInfo: info, deliverImmediately: true
        )
    }

    // MARK: - Command Observer

    /// Handler called when an external command notification is received.
    typealias CommandHandler = (String) -> Void

    private static var observer: NSObjectProtocol?
    private static var ignitecliObserver: NSObjectProtocol?

    /// Start observing command notifications. The handler receives the raw
    /// command string (same format as trigger file commands).
    static func startObserving(handler: @escaping CommandHandler) {
        stopObserving()  // Clean up previous registration to prevent observer leaks
        let center = DistributedNotificationCenter.default()

        observer = center.addObserver(
            forName: commandName, object: nil, queue: .main
        ) { notification in
            processCommandNotification(notification, handler: handler)
        }

        ignitecliObserver = center.addObserver(
            forName: ignitecliCommandName, object: nil, queue: .main
        ) { notification in
            processCommandNotification(notification, handler: handler)
        }
    }

    /// Stop observing command notifications.
    static func stopObserving() {
        if let obs = observer {
            DistributedNotificationCenter.default().removeObserver(obs)
            observer = nil
        }
        if let obs = ignitecliObserver {
            DistributedNotificationCenter.default().removeObserver(obs)
            ignitecliObserver = nil
        }
    }

    private static func processCommandNotification(
        _ notification: Notification, handler: CommandHandler
    ) {
        guard let userInfo = notification.userInfo else { return }

        // Direct command string (e.g. "update_guidance:confirm:0:state=success")
        if let command = userInfo["command"] as? String {
            handler(command)
        }

        // Badge shorthand — routes through update_guidance with wildcard stepId
        // Format: "blockId:state" or "blockId:state:actual value"
        if let badge = userInfo["badge"] as? String {
            let parts = badge.split(separator: ":", maxSplits: 2)
            if parts.count >= 2 {
                handler("update_guidance:_:\(parts[0]):state=\(parts[1])")
                if parts.count >= 3 {
                    handler("update_guidance:_:\(parts[0]):actual=\(parts[2])")
                }
            }
        }

        // Update guidance shorthand
        if let update = userInfo["update_guidance"] as? String {
            handler("update_guidance:\(update)")
        }

        // Navigate shorthand
        if let navigate = userInfo["navigate"] as? String {
            handler("navigate:\(navigate)")
        }

        // Batch update: JSON payload for atomic multi-block updates
        // Avoids per-property flicker by delivering all updates in a single command
        if let batchJSON = userInfo["batch"] as? String {
            handler("batch_update:\(batchJSON)")
        }

        // Status shorthands — lets external tools post e.g. {"success": "edge:Done"}
        // instead of {"command": "success:edge:Done"}
        if let success = userInfo["success"] as? String { handler("success:\(success)") }
        if let failure = userInfo["failure"] as? String { handler("failure:\(failure)") }
        if let warning = userInfo["warning"] as? String { handler("warning:\(warning)") }
        if let complete = userInfo["complete"] as? String { handler("complete:\(complete)") }
        if let progress = userInfo["progress"] as? String { handler("progress:\(progress)") }
        if let item = userInfo["item"] as? String { handler("item:\(item)") }

        // Selection shorthand — e.g. {"select": "preferredLanguage:Deutsch"}
        if let select = userInfo["select"] as? String { handler("select:\(select)") }

        // Navigation shorthands — presence-triggered, value is ignored
        if userInfo["next"] != nil { handler("next") }
        if userInfo["prev"] != nil { handler("prev") }
        if userInfo["reset"] != nil { handler("reset") }
    }
}
