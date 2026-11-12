//
//  CommandRouter.swift
//  dialog
//
//  Command parsing and dispatch for every inspect preset. Presets register closures; the router
//  owns the trigger file, the notification channel, nonce dedupe and acks.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Trigger-file read position

/// Incremental read position in the trigger file. The offset is trusted only while the bytes just
/// before it are still there unchanged (`anchor`, the last `anchorLength` consumed bytes); a file
/// whose bytes there no longer match was rewritten, not appended to, and is read from the start.
/// Comparing a bounded anchor instead of the whole consumed prefix keeps each check the same cost
/// however long the deployment's command history grows.
struct TriggerCursor {
    private var offset: Int = 0
    private var anchor = Data()
    /// The unfinished last line: the file length it ends at, and the uptime first seen there.
    private var tail: (length: Int, since: TimeInterval)?
    static let tailGrace: TimeInterval = 0.5
    static let anchorLength = 256

    /// True while a last line without a newline waits out `tailGrace`: the file must be read again
    /// even though it has not changed.
    var isHoldingTail: Bool { tail != nil }

    private mutating func consume(through end: Int, of data: Data) {
        offset = end
        anchor = data.subdata(in: max(0, end - Self.anchorLength)..<end)
    }

    /// Adopts the file's current contents without yielding them, so a file left by a previous run
    /// does not replay on launch.
    mutating func seekToEnd(of data: Data) {
        consume(through: data.count, of: data)
    }

    /// The bytes to process now, or nil when nothing is new. Runs on every poll tick, so an
    /// unchanged file (including an identical rewrite) must yield nil. Only whole lines are
    /// handed over; a last line without a newline is held until it has stood for `tailGrace`,
    /// so a half-written line is never dispatched but `printf next` still runs.
    mutating func advance(over data: Data,
                          now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Data? {
        guard data.count >= offset, data.subdata(in: (offset - anchor.count)..<offset) == anchor else {
            // The file was replaced: read all of it.
            offset = 0
            anchor = Data()
            tail = nil
            return advance(over: data, now: now)
        }
        guard data.count > offset else { return nil }
        let end: Int
        if let newline = data[offset...].lastIndex(of: UInt8(ascii: "\n")) {
            end = newline + 1
        } else if let held = tail, held.length == data.count, now - held.since >= Self.tailGrace {
            end = data.count
        } else {
            if tail?.length != data.count { tail = (data.count, now) }
            return nil
        }
        let slice = data.subdata(in: offset..<end)
        consume(through: end, of: data)
        tail = end < data.count ? (data.count, now) : nil
        return slice
    }
}

// MARK: - CommandRouter

@MainActor
final class CommandRouter: ObservableObject {

    // MARK: - Closure Registry

    // Navigation
    var onNavigateByID: ((String) -> Void)?
    var onNavigateByIndex: ((Int) -> Void)?
    var onNext: (() -> Void)?
    var onPrev: (() -> Void)?
    /// `continue`: what clicking the primary button does. Falls back to `onNext`.
    var onContinue: (() -> Void)?
    /// `override:<stepId>:success|failure|skip`: the step completes with that result at once.
    var onOverride: ((String, InspectCompletionResult) -> Void)?
    var onReset: (() -> Void)?
    /// `close`: always closes. `quit:` closes only when `isFlowHeld` is not true.
    var onClose: (() -> Void)?
    /// Asked before `quit:` is honoured: true while the current step still holds its door. nil
    /// means never held.
    var isFlowHeld: (() -> Bool)?

    // Completion
    var onComplete: ((String) -> Void)?
    var onSuccess: ((String, String?) -> Void)?
    var onFailure: ((String, String?) -> Void)?
    var onWarning: ((String, String?) -> Void)?

    // Content updates
    var onUpdateGuidance: ((String) -> Void)?    // raw command line (preset-specific parsing)
    var onUpdateMessage: ((String, String) -> Void)?
    var onProgress: ((String, Int) -> Void)?      // always 0-100
    var onBatchUpdate: ((String) -> Void)?         // raw JSON string
    var onDisplayData: ((String, String, String, String?) -> Void)?

    // Validation
    var onRecheck: ((String?) -> Void)?

    // Selections
    var onSelect: ((String, [String]) -> Void)?    // (selectionKey, values)

    // Overrides
    var onSetCommand: ((String, String, String?) -> Void)?
    var onItemStatus: ((String, String, String?) -> Void)?
    /// `itemicon:<id>:<path or URL>` — a row's icon, set while running; empty clears it.
    var onItemIcon: ((String, String) -> Void)?
    var onListItem: ((String) -> Void)?            // raw remainder after "listitem:"
    var onCadence: ((String) -> Void)?             // raw remainder after "cadence:"

    // Step composition. Handlers return the ack verdict; a nil closure acks "not supported".
    var onAddStep: ((String) -> StepCommandResult)?      // raw envelope JSON after "step_add:"
    var onRemoveStep: ((String) -> StepCommandResult)?   // step id
    var onStepList: ((String) -> StepCommandResult)?     // resolved response path

    // MARK: - Configuration

    /// Acknowledgment log path; nil disables ack writing.
    var acknowledgmentLogPath: String?

    /// Preset identifier for log messages.
    var presetLabel: String = "CommandRouter"

    /// The nonce of the command being dispatched, echoed by `writeAck`. Dispatch is synchronous,
    /// so instance storage is safe.
    private var currentNonce: String?

    // MARK: - Nonce Dedupe

    /// A tool may send a command on both transports (notification and trigger file) with the same
    /// nonce; each tagged command runs once. The key is nonce + command because one notification
    /// can expand to several commands. An untagged line always runs.
    private static let nonceCapacity = 256
    private var seenNonces: Set<String> = []
    private var nonceOrder: [String] = []

    /// Returns false when this nonce + command has already run. Bounded at `nonceCapacity`.
    private func claimNonce(_ nonce: String, command: String) -> Bool {
        let key = "\(nonce)\u{1F}\(command)"
        guard !seenNonces.contains(key) else {
            writeLog("\(presetLabel): duplicate nonce \(nonce) — skipping '\(command)'", logLevel: .debug)
            return false
        }
        seenNonces.insert(key)
        nonceOrder.append(key)
        if nonceOrder.count > Self.nonceCapacity {
            seenNonces.remove(nonceOrder.removeFirst())
        }
        return true
    }

    /// Splits a raw line into command and nonce. The only wire form is a final tab-separated
    /// `nonce=<token>` field: message text such as `update_message:x:ping @helpdesk` is content,
    /// never a nonce.
    private static func splitNonce(_ line: String) -> (command: String, nonce: String?) {
        if line.contains("\t") {
            var fields = line.components(separatedBy: "\t")
            if let last = fields.last, last.hasPrefix("nonce=") {
                fields.removeLast()
                let nonce = String(last.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                return (fields.joined(separator: "\t"), nonce.isEmpty ? nil : nonce)
            }
        }
        return (line, nil)
    }

    /// Number of navigable items, for bounds-checking navigate-by-index.
    var itemCount: Int = 0


    // MARK: - File Monitoring

    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fallbackPoll: Poll?
    private var cursor = TriggerCursor()
    private var monitoredPath: String = ""

    /// Starts watching the trigger file and the notification channel.
    func startMonitoring(triggerFilePath: String, notificationHandler: ((String) -> Void)? = nil) {
        // A second start replaces the watchers: the old source must be cancelled or its descriptor stays open.
        stopMonitoring()
        monitoredPath = triggerFilePath
        lastSeen = nil

        writeLog("\(presetLabel): startMonitoring path='\(triggerFilePath)' exists=\(FileManager.default.fileExists(atPath: triggerFilePath))", logLevel: .debug)

        if let data = FileManager.default.contents(atPath: triggerFilePath) {
            cursor.seekToEnd(of: data)
        }

        // The cancel handler closes this descriptor: a restart opens a new one before the old cancel runs.
        let fd = open(triggerFilePath, O_EVTONLY)
        if fd >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd, eventMask: [.write, .delete, .rename], queue: .main
            )
            source.setEventHandler { [weak self] in
                DispatchQueue.main.async { self?.checkForNewLines() }
            }
            source.setCancelHandler { close(fd) }
            source.resume()
            dispatchSource = source
        }

        // The poll catches what DispatchSource misses, including a file that did not exist yet.
        let fallback = Poll(every: 0.2)
        fallback.start { [weak self] in self?.checkForNewLines() }
        fallbackPoll = fallback

        DialogNotifications.startObserving { [weak self] (command: String, nonce: String?) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                notificationHandler?(command)
                self.processCommand(command, nonce: nonce)
            }
        }

        writeLog("\(presetLabel): File monitoring started at \(triggerFilePath) (DispatchSource + Timer)", logLevel: .info)
    }

    func stopMonitoring() {
        fallbackPoll?.cancel()
        fallbackPoll = nil
        dispatchSource?.cancel()
        dispatchSource = nil
        DialogNotifications.stopObserving()
    }

    /// Size and modification date at the last read: the 0.2 s poll reads the file only when it changed.
    private var lastSeen: (size: Int, modified: Date)?

    private func checkForNewLines() {
        guard !monitoredPath.isEmpty else { return }
        let attributes = try? FileManager.default.attributesOfItem(atPath: monitoredPath)
        if let size = attributes?[.size] as? Int, let modified = attributes?[.modificationDate] as? Date {
            if let seen = lastSeen, seen.size == size, seen.modified == modified, !cursor.isHoldingTail { return }
            lastSeen = (size, modified)
        }
        guard let data = FileManager.default.contents(atPath: monitoredPath) else { return }
        guard let newData = cursor.advance(over: data) else { return }
        guard let newContent = String(bytes: newData, encoding: .utf8) else { return }

        let lines = newContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            processCommand(trimmed)
        }
    }

    // MARK: - Single Entry Point

    /// Parses raw command lines and dispatches each. Every delivery path funnels through here, so
    /// this is where dedupe lives. `nonce` is the notification path's tag; file lines carry their
    /// own `\tnonce=` trailer. Tagged commands run once; untagged ones always run.
    func processCommand(_ rawLine: String, nonce: String? = nil) {
        let lines = rawLine.components(separatedBy: .newlines)
        for line in lines {
            let (raw, lineNonce) = Self.splitNonce(line)
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let effectiveNonce = lineNonce ?? nonce
            if let effectiveNonce, !claimNonce(effectiveNonce, command: trimmed) { continue }
            dispatchSingleCommand(trimmed, nonce: effectiveNonce)
        }
    }

    // MARK: - Command Dispatch

    /// Wall-clock time for the debug panel.
    private func shortTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }

    /// Dispatches one parsed, deduped command. `nonce` is kept for `writeAck` to echo.
    private func dispatchSingleCommand(_ trimmed: String, nonce: String? = nil) {
        currentNonce = nonce
        // Every command is traced before dispatch, matched or not.
        DetectionLog.trace("IN  \(trimmed.prefix(240))")
        InspectDebugMeter.shared.trace("IN  \(trimmed.prefix(200))")
        // `quit:` is the supervisor's release: a supervised close (exit 5), unless the current
        // step still holds its door; then it is deferred and the step's own release ends the
        // flow. The bare verb `quit` stays unknown.
        if trimmed == "quit:" || trimmed.hasPrefix("quit:") {
            if isFlowHeld?() == true {
                InspectDebugMeter.shared.note(fact: "quit: received",
                                              "yes, at \(shortTime()) — deferred, the step holds its door")
                writeLog("\(presetLabel): quit: (orbit's release) deferred — the step holds its door", logLevel: .info)
                writeAck("quit", stepId: "_", message: "deferred")
                return
            }
            InspectDebugMeter.shared.note(fact: "quit: received",
                                          "yes, at \(shortTime()) — honoured: close")
            writeLog("\(presetLabel): quit: (orbit's release) → close", logLevel: .info)
            writeAck("quit", stepId: "_")   // ack before the process exits
            onClose?()
            return
        }

        if trimmed.hasPrefix("success:") {
            let parts = trimmed.dropFirst(8).split(separator: ":", maxSplits: 1)
            guard !parts.isEmpty else { return }
            let stepId = String(parts[0])
            let message = parts.count > 1 ? String(parts[1]) : nil
            writeLog("\(presetLabel): success:\(stepId)", logLevel: .info)
            onSuccess?(stepId, message)
            writeAck("success", stepId: stepId, message: message)

        } else if trimmed.hasPrefix("failure:") {
            let parts = trimmed.dropFirst(8).split(separator: ":", maxSplits: 1)
            guard !parts.isEmpty else { return }
            let stepId = String(parts[0])
            let reason = parts.count > 1 ? String(parts[1]) : "Step failed"
            writeLog("\(presetLabel): failure:\(stepId)", logLevel: .info)
            onFailure?(stepId, reason)
            writeAck("failure", stepId: stepId, message: reason)

        } else if trimmed.hasPrefix("warning:") {
            let parts = trimmed.dropFirst(8).split(separator: ":", maxSplits: 1)
            guard !parts.isEmpty else { return }
            let stepId = String(parts[0])
            let message = parts.count > 1 ? String(parts[1]) : "Step warning"
            writeLog("\(presetLabel): warning:\(stepId)", logLevel: .info)
            onWarning?(stepId, message)
            writeAck("warning", stepId: stepId, message: message)

        } else if trimmed.hasPrefix("complete:") {
            let stepId = String(trimmed.dropFirst(9))
            writeLog("\(presetLabel): complete:\(stepId)", logLevel: .info)
            onComplete?(stepId)
            writeAck("complete", stepId: stepId)

        } else if trimmed.hasPrefix("navigate:") || trimmed.hasPrefix("goto:") {
            let prefixLen = trimmed.hasPrefix("goto:") ? 5 : 9
            let argument = String(trimmed.dropFirst(prefixLen)).trimmingCharacters(in: .whitespaces)

            // A numeric argument in range is an index; anything else is a step id.
            if let index = Int(argument), index >= 0, index < itemCount {
                writeLog("\(presetLabel): navigate by index \(index)", logLevel: .info)
                onNavigateByIndex?(index)
            } else {
                writeLog("\(presetLabel): navigate by ID '\(argument)'", logLevel: .info)
                onNavigateByID?(argument)
            }
            writeAck("navigate", stepId: argument)

        } else if trimmed == "next" {
            writeLog("\(presetLabel): next", logLevel: .info)
            onNext?()
            writeAck("next", stepId: "_")

        } else if trimmed == "continue" {
            writeLog("\(presetLabel): continue", logLevel: .info)
            if let onContinue { onContinue() } else { onNext?() }
            writeAck("continue", stepId: "_")

        } else if trimmed.hasPrefix("override:") {
            let parts = trimmed.dropFirst(9).split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2, let result = Self.overrideResult(parts[1]) else {
                writeLog("\(presetLabel): override needs <stepId>:success|failure|skip — got '\(trimmed)'", logLevel: .error)
                writeAck("override", stepId: parts.first ?? "_", status: "ERROR", message: "invalid")
                return
            }
            writeLog("\(presetLabel): override \(parts[0]) → \(parts[1])", logLevel: .info)
            onOverride?(parts[0], result)
            writeAck("override", stepId: parts[0])

        } else if trimmed == "prev" || trimmed == "back" {
            writeLog("\(presetLabel): prev", logLevel: .info)
            onPrev?()
            writeAck("prev", stepId: "_")

        } else if trimmed == "reset" {
            writeLog("\(presetLabel): reset", logLevel: .info)
            onReset?()
            writeAck("reset", stepId: "_")

        } else if trimmed == "close" {
            writeLog("\(presetLabel): close (supervised)", logLevel: .info)
            writeAck("close", stepId: "_")   // ack before the process exits
            onClose?()

        } else if trimmed.hasPrefix("cadence:") {
            // cadence:satisfy:<id> | cadence:advance | cadence:goto:<index> | cadence:message:<index>:<text>
            let remainder = String(trimmed.dropFirst(8))
            writeLog("\(presetLabel): cadence:\(remainder)", logLevel: .info)
            onCadence?(remainder)
            writeAck("cadence", stepId: remainder)

        } else if trimmed.hasPrefix("progress:") {
            // progress:stepId:value — a value of 1.0 or less is a fraction, else a percent.
            let parts = trimmed.dropFirst(9).split(separator: ":")
            if parts.count == 2 {
                let stepId = String(parts[0])
                if let raw = Double(String(parts[1])) {
                    let pct = raw > 1.0 ? min(100, max(0, Int(raw))) : min(100, max(0, Int(raw * 100)))
                    writeLog("\(presetLabel): progress:\(stepId):\(pct)%", logLevel: .info)
                    onProgress?(stepId, pct)
                    writeAck("progress", stepId: stepId, property: "percentage", value: "\(pct)")
                }
            }

        } else if trimmed.hasPrefix("update_guidance:") {
            writeLog("\(presetLabel): update_guidance command", logLevel: .info)
            onUpdateGuidance?(trimmed)
            let ackParts = trimmed.dropFirst(16).split(separator: ":", maxSplits: 2)
            writeAck("update_guidance",
                     stepId: ackParts.first.map(String.init) ?? "_",
                     property: ackParts.count > 1 ? String(ackParts[1]) : nil)

        } else if trimmed.hasPrefix("update_message:") {
            let parts = trimmed.dropFirst(15).split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let stepId = String(parts[0])
                let message = String(parts[1])
                writeLog("\(presetLabel): update_message:\(stepId)", logLevel: .info)
                onUpdateMessage?(stepId, message)
                writeAck("update_message", stepId: stepId, message: message)
            }

        } else if trimmed.hasPrefix("batch_update:") {
            let jsonString = String(trimmed.dropFirst("batch_update:".count))
            writeLog("\(presetLabel): batch_update", logLevel: .info)
            onBatchUpdate?(jsonString)
            writeAck("batch_update", stepId: "_")

        } else if trimmed.hasPrefix("display_data:") {
            let parts = trimmed.dropFirst(13).split(separator: ":", maxSplits: 2)
            if parts.count >= 3 {
                let stepId = String(parts[0])
                let key = String(parts[1])
                let valueAndColor = String(parts[2])

                var value = valueAndColor
                var color: String?
                if let lastColonIndex = valueAndColor.lastIndex(of: ":") {
                    let potentialColor = String(valueAndColor[valueAndColor.index(after: lastColonIndex)...])
                    if potentialColor.hasPrefix("#") {
                        color = potentialColor
                        value = String(valueAndColor[..<lastColonIndex])
                    }
                }

                writeLog("\(presetLabel): display_data:\(stepId):\(key)", logLevel: .info)
                onDisplayData?(stepId, key, value, color)
                writeAck("display_data", stepId: stepId, property: key, value: value)
            }

        } else if trimmed == "recheck:" || trimmed.hasPrefix("recheck:") {
            let targetItemId = trimmed == "recheck:" ? nil : String(trimmed.dropFirst(8))
            writeLog("\(presetLabel): recheck\(targetItemId.map { ":\($0)" } ?? "")", logLevel: .info)
            onRecheck?(targetItemId)
            writeAck("recheck", stepId: targetItemId ?? "_")

        } else if trimmed.hasPrefix("set:") {
            let parts = trimmed.dropFirst(4).split(separator: ":", maxSplits: 2)
            if parts.count >= 2 {
                let targetType = String(parts[0])
                let value = String(parts[1])
                let extra = parts.count > 2 ? String(parts[2]) : nil
                writeLog("\(presetLabel): set:\(targetType):\(value)", logLevel: .info)
                onSetCommand?(targetType, value, extra)
                writeAck("set", stepId: targetType, property: value, value: extra ?? "")
            }

        } else if trimmed.hasPrefix("item:") {
            let parts = trimmed.dropFirst(5).split(separator: ":", maxSplits: 2)
            guard parts.count >= 2 else {
                writeLog("\(presetLabel): Invalid item command: \(trimmed)", logLevel: .error)
                return
            }
            let itemId = String(parts[0])
            let status = String(parts[1])
            let message = parts.count > 2 ? String(parts[2]) : nil
            writeLog("\(presetLabel): item:\(itemId):\(status)", logLevel: .info)
            onItemStatus?(itemId, status, message)
            writeAck("item", stepId: itemId, message: message)

        } else if trimmed.hasPrefix("itemicon:") {
            // itemicon:<id>:<path or URL> — the value keeps its own colons.
            let parts = trimmed.dropFirst(9).split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty else {
                writeLog("\(presetLabel): Invalid itemicon command: \(trimmed)", logLevel: .error)
                return
            }
            onItemIcon?(String(parts[0]), String(parts[1]))
            writeAck("itemicon", stepId: String(parts[0]))

        } else if trimmed.hasPrefix("listitem:") {
            let remainder = String(trimmed.dropFirst(9))
            writeLog("\(presetLabel): listitem command", logLevel: .info)
            onListItem?(remainder)
            writeAck("listitem", stepId: "_")

        } else if trimmed.hasPrefix("select:") {
            // select:key:value1,value2
            let parts = trimmed.dropFirst(7).split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let values = String(parts[1]).split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                writeLog("\(presetLabel): select:\(key):\(values.joined(separator: ","))", logLevel: .info)
                onSelect?(key, values)
                writeAck("select", stepId: key, value: values.joined(separator: ","))
            }

        } else if trimmed.hasPrefix("step_add:") {
            // step_add:{"step":{…},"after":"<id>"|"at":<n>}
            let payload = String(trimmed.dropFirst(9))
            writeLog("\(presetLabel): step_add", logLevel: .info)
            ackStepCommand("step_add", result: onAddStep?(payload))

        } else if trimmed.hasPrefix("step_remove:") {
            let stepId = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
            writeLog("\(presetLabel): step_remove:\(stepId)", logLevel: .info)
            ackStepCommand("step_remove", result: onRemoveStep?(stepId))

        } else if trimmed == "step_list" || trimmed.hasPrefix("step_list:") {
            // step_list[:<path>]; the default path must match `stepListPath(for:)`.
            let arg = trimmed.hasPrefix("step_list:")
                ? String(trimmed.dropFirst(10)).trimmingCharacters(in: .whitespaces) : ""
            let path = arg.isEmpty ? "\(monitoredPath).steps.json" : arg
            writeLog("\(presetLabel): step_list -> \(path)", logLevel: .info)
            ackStepCommand("step_list", result: onStepList?(path), value: path)

        } else if ["minimize:", "minimise:", "window:minimize", "window:minimise"].contains(trimmed) {
            minimizeDialogWindow()
            writeLog("\(presetLabel): minimize", logLevel: .info)
            writeAck("minimize", stepId: "window")

        } else if ["restore:", "window:restore", "maximize:", "maximise:"].contains(trimmed) {
            // `maximize:` / `maximise:` are classic's spelling of the same restore.
            restoreDialogWindow()
            writeLog("\(presetLabel): restore", logLevel: .info)
            writeAck("restore", stepId: "window")

        } else if trimmed.hasPrefix("window:") {
            // window:<position>[:offset] — position names match --position. Side positions
            // centre vertically and default to a 48pt edge margin, as a step's windowPosition does.
            let parts = trimmed.dropFirst(7).split(separator: ":", maxSplits: 1).map { String($0.trimmingCharacters(in: .whitespaces)) }
            let positionName = parts.first?.lowercased() ?? "center"
            var (vertical, horozontal) = windowPosition(positionName)
            let isSidePosition = !["center", "deadcenter"].contains(positionName)
            if case .center = vertical { vertical = .deadcenter }
            let offset: CGFloat = parts.count > 1 ? CGFloat(Double(parts[1]) ?? 0) : (isSidePosition ? 48 : 0)
            DispatchQueue.main.async {
                if let window = NSApp.windows.first {
                    placeWindow(window, size: nil, vertical: vertical, horozontal: horozontal, offset: offset, animated: true)
                }
            }
            writeLog("\(presetLabel): window:\(positionName) offset=\(offset)", logLevel: .info)
            writeAck("window", stepId: positionName, value: "\(offset)")

        } else if trimmed.hasPrefix("appearance:") {
            // appearance:dark|light|auto
            let mode = String(trimmed.dropFirst(11)).trimmingCharacters(in: .whitespaces).lowercased()
            DispatchQueue.main.async {
                InspectAppearance.apply(mode)
            }
            writeLog("\(presetLabel): appearance:\(mode)", logLevel: .info)
            writeAck("appearance", stepId: mode)

        } else {
            writeLog("\(presetLabel): Unknown command: \(trimmed)", logLevel: .debug)
        }
    }

    /// Acks a step-composition verdict; a nil result (no handler registered) is an error ack.
    private func ackStepCommand(_ verb: String, result: StepCommandResult?, value: String? = nil) {
        switch result {
        case .ok(let id, let note):
            writeAck(verb, stepId: id, value: value, message: note)
        case .rejected(let id, let message):
            writeAck(verb, stepId: id ?? "_", status: "error", message: message)
        case nil:
            writeAck(verb, stepId: "_", status: "error",
                     message: "step composition not supported for \(presetLabel)")
        }
    }

    // MARK: - Acknowledgment

    private func writeAck(_ command: String, stepId: String, index: Int = -1,
                          status: String = "OK", property: String? = nil,
                          value: String? = nil, message: String? = nil) {
        guard let path = acknowledgmentLogPath else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        var entry = "\(timestamp) command=\(command) stepId=\(stepId) index=\(index) status=\(status)"
        if let property = property { entry += " property=\(property)" }
        if let value = value { entry += " value=\(value)" }
        if let message = message { entry += " message=\(message)" }
        if let nonce = currentNonce { entry += " nonce=\(nonce)" }
        entry += "\n"

        DialogNotifications.postAck(
            command: command, stepId: stepId, status: status,
            property: property, value: value, message: message,
            nonce: currentNonce
        )

        guard let data = entry.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: path) {
            if let fileHandle = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                _ = try? fileHandle.seekToEnd()
                _ = try? fileHandle.write(contentsOf: data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

extension CommandRouter {
    /// The override's three choices and their accepted spellings.
    nonisolated static func overrideResult(_ word: String) -> InspectCompletionResult? {
        switch word.lowercased() {
        case "success", "done", "pass", "passed": return .success(message: nil)
        case "failure", "failed", "fail": return .failure(message: "Marked as failed by user")
        case "skip", "skipped": return .cancelled
        default: return nil
        }
    }
}
