//
//  CommandRouter.swift
//  dialog
//
//  Unified command parsing and dispatch for all Inspect presets.
//  Replaces duplicated inline command handlers in Preset5/Preset6 with a
//  single entry point that normalizes, parses, and dispatches commands
//  via closure-based registration.
//
//  Presets register handler closures on setup — the router owns parsing
//  and normalization, presets own the actual state mutations.
//

import Foundation
import SwiftUI

// MARK: - CommandRouter

@MainActor
final class CommandRouter: ObservableObject {

    // MARK: - Closure Registry

    // Navigation
    var onNavigateByID: ((String) -> Void)?
    var onNavigateByIndex: ((Int) -> Void)?
    var onNext: (() -> Void)?
    var onPrev: (() -> Void)?
    var onReset: (() -> Void)?

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
    var onListItem: ((String) -> Void)?            // raw remainder after "listitem:"

    // MARK: - Configuration

    /// Acknowledgment log path (nil disables ack writing)
    var acknowledgmentLogPath: String?

    /// Preset identifier for log messages
    var presetLabel: String = "CommandRouter"

    /// Total number of navigable items (for bounds-checking navigate-by-index)
    var itemCount: Int = 0

    // MARK: - File Monitoring (hosted on this class for stable lifecycle)

    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fallbackTimer: Timer?
    private var lastProcessedByteOffset: Int = 0
    private var monitoredPath: String = ""

    /// Start monitoring a trigger file. Timer and DispatchSource callbacks are stable
    /// because this is a class (not a SwiftUI struct copy).
    func startMonitoring(triggerFilePath: String, notificationHandler: ((String) -> Void)? = nil) {
        monitoredPath = triggerFilePath

        writeLog("\(presetLabel): [DIAG] startMonitoring path='\(triggerFilePath)' exists=\(FileManager.default.fileExists(atPath: triggerFilePath))", logLevel: .error)

        // Skip stale content by recording current file size
        if let data = FileManager.default.contents(atPath: triggerFilePath) {
            lastProcessedByteOffset = data.count
        }

        // DispatchSource for zero-latency detection
        fileDescriptor = open(triggerFilePath, O_EVTONLY)
        if fileDescriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor, eventMask: [.write, .delete, .rename], queue: .main
            )
            source.setEventHandler { [weak self] in
                DispatchQueue.main.async { self?.checkForNewLines() }
            }
            source.setCancelHandler { [weak self] in
                guard let fd = self?.fileDescriptor, fd >= 0 else { return }
                close(fd)
            }
            source.resume()
            dispatchSource = source
        }

        // Timer fallback (200ms) — catches anything DispatchSource misses
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkForNewLines() }
        }

        // DistributedNotification → processCommand
        DialogNotifications.startObserving { [weak self] (command: String) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                notificationHandler?(command)
                self.processCommand(command)
            }
        }

        writeLog("\(presetLabel): File monitoring started at \(triggerFilePath) (DispatchSource + Timer)", logLevel: .info)
    }

    /// Stop file monitoring and cleanup.
    func stopMonitoring() {
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        dispatchSource?.cancel()
        dispatchSource = nil
        DialogNotifications.stopObserving()
    }

    /// Check for new bytes in the monitored trigger file (byte-offset tracking).
    /// Byte offset avoids the trailing-newline off-by-one that line-count tracking has.
    private func checkForNewLines() {
        guard !monitoredPath.isEmpty,
              let data = FileManager.default.contents(atPath: monitoredPath) else { return }
        guard data.count > lastProcessedByteOffset else {
            return
        }

        let newData = data.subdata(in: lastProcessedByteOffset..<data.count)
        guard let newContent = String(data: newData, encoding: .utf8) else { return }

        writeLog("\(presetLabel): [DIAG] checkForNewLines \(newData.count) bytes, mainThread=\(Thread.isMainThread)", logLevel: .error)

        let lines = newContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            processCommand(trimmed)
        }
        lastProcessedByteOffset = data.count
    }

    // MARK: - Single Entry Point

    /// Parse a raw command line and dispatch to the appropriate handler.
    /// Handles multi-line input (splits on newlines).
    func processCommand(_ rawLine: String) {
        let lines = rawLine.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            dispatchSingleCommand(trimmed)
        }
    }

    // MARK: - Command Dispatch

    private func dispatchSingleCommand(_ trimmed: String) {
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

            // Auto-detect: numeric index OR step ID
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

        } else if trimmed == "prev" || trimmed == "back" {
            writeLog("\(presetLabel): prev", logLevel: .info)
            onPrev?()
            writeAck("prev", stepId: "_")

        } else if trimmed == "reset" {
            writeLog("\(presetLabel): reset", logLevel: .info)
            onReset?()
            writeAck("reset", stepId: "_")

        } else if trimmed.hasPrefix("progress:") {
            // progress:stepId:value — auto-detect 0-1 or 0-100
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

        } else if trimmed.hasPrefix("listitem:") {
            let remainder = String(trimmed.dropFirst(9))
            writeLog("\(presetLabel): listitem command", logLevel: .info)
            onListItem?(remainder)
            writeAck("listitem", stepId: "_")

        } else if trimmed.hasPrefix("select:") {
            // select:key:value1,value2 — set a grid/form selection externally
            let parts = trimmed.dropFirst(7).split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let values = String(parts[1]).split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                writeLog("\(presetLabel): select:\(key):\(values.joined(separator: ","))", logLevel: .info)
                onSelect?(key, values)
                writeAck("select", stepId: key, value: values.joined(separator: ","))
            }

        } else {
            writeLog("\(presetLabel): Unknown command: \(trimmed)", logLevel: .debug)
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
        entry += "\n"

        // Post ack via DistributedNotification for instant delivery
        DialogNotifications.postAck(
            command: command, stepId: stepId, status: status,
            property: property, value: value, message: message
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
