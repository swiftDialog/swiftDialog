//
//  InspectDynamicState.swift
//  dialog
//
//  Live content overrides for the step presets (messages, progress, guidance block properties,
//  `set:` overrides) and the `update_guidance:` / `set:` command parsers that feed them.
//

import SwiftUI
import Observation

/// Per-property observable store of live content changes; shared by every step preset.
@MainActor
@Observable
class InspectDynamicState {

    // MARK: - Tracked State

    /// stepId -> processing message
    var dynamicMessages: [String: String] = [:]

    /// stepId -> 0-100
    var progressPercentages: [String: Int] = [:]

    /// stepId -> [(key, value, color)]
    var customDataDisplay: [String: [(String, String, String?)]] = [:]

    /// stepId -> blockIndex -> [property -> value]; a block's text is its `content` property.
    /// Read through `applied(to:blockIndex:stepId:)`.
    var dynamicGuidanceProperties: [String: [Int: [String: String]]] = [:]

    /// `set:` overrides (`DynamicSetCommand`): stepId -> hero image path or SF reference.
    var heroImageOverrides: [String: String] = [:]
    /// Replaces the config's base path for relative icon paths.
    var iconBasePathOverride: String?
    /// `set:icon`, recorded; nothing draws it yet.
    var iconOverride: String?

    /// list index -> "iconName-color"
    var itemStatusIcons: [Int: String] = [:]

    // MARK: - Update Methods

    func updateMessage(stepId: String, message: String) {
        dynamicMessages[stepId] = message
        writeLog("InspectDynamicState: Updated message for '\(stepId)'", logLevel: .info)
    }

    /// Clamps to 0-100.
    func updateProgress(stepId: String, percentage: Int) {
        progressPercentages[stepId] = min(100, max(0, percentage))
        writeLog("InspectDynamicState: Updated progress for '\(stepId)': \(percentage)%", logLevel: .info)
    }

    /// Replaces an existing key's entry or appends a new one.
    func updateDisplayData(stepId: String, key: String, value: String, color: String? = nil) {
        var stepData = customDataDisplay[stepId] ?? []

        if let existingIndex = stepData.firstIndex(where: { $0.0 == key }) {
            stepData[existingIndex] = (key, value, color)
        } else {
            stepData.append((key, value, color))
        }

        customDataDisplay[stepId] = stepData
        writeLog("InspectDynamicState: Updated display data '\(key)' = '\(value)' for '\(stepId)'", logLevel: .info)
    }

    /// The block with its live properties and live `content` applied; the one reader for every preset.
    func applied(to block: InspectConfig.GuidanceContent, blockIndex: Int, stepId: String) -> InspectConfig.GuidanceContent {
        let props = dynamicGuidanceProperties[stepId]?[blockIndex] ?? [:]
        guard !props.isEmpty else { return block }
        var b = block.applyingDynamicProperties(props)
        if let content = props["content"] { b.content = content }
        return b
    }

    func updateGuidanceProperty(stepId: String, blockIndex: Int, property: String, value: String) {
        var stepDict = dynamicGuidanceProperties[stepId] ?? [:]
        var blockDict = stepDict[blockIndex] ?? [:]

        blockDict[property] = value
        stepDict[blockIndex] = blockDict

        dynamicGuidanceProperties[stepId] = stepDict

        writeLog("InspectDynamicState: updateGuidanceProperty('\(stepId)'[\(blockIndex)].\(property) = '\(value)')", logLevel: .info)
    }

    /// `append=`: adds to a block's live content (not the authored text) and marks the stream open.
    func appendGuidanceContent(stepId: String, blockIndex: Int, text: String) {
        let current = dynamicGuidanceProperties[stepId]?[blockIndex]?["content"] ?? ""
        // Runs of three or more newlines collapse to one paragraph break; the only edit made to a writer's text.
        let next = (current + text).replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        updateGuidancePropertiesBatch(stepId: stepId, blocks: [blockIndex: ["content": next, "stream": "open"]])
    }

    /// The stream verbs: `append=` adds the text as written, `line=` adds it plus a newline.
    /// Nil for any other property.
    nonisolated static func streamedText(property: String, value: String) -> String? {
        switch property {
        case "append": return unescapeIPCText(value)
        case "line": return unescapeIPCText(value) + "\n"
        default: return nil
        }
    }

    /// The trigger file is line-based, so `\n` carries a newline and `\\` a backslash. Any other
    /// escape is kept as typed.
    nonisolated static func unescapeIPCText(_ s: String) -> String {
        guard s.contains("\\") else { return s }
        var out = ""
        var pendingBackslash = false
        for ch in s {
            if pendingBackslash {
                switch ch {
                case "n": out.append("\n")
                case "\\": out.append("\\")
                default: out.append("\\"); out.append(ch)
                }
                pendingBackslash = false
            } else if ch == "\\" {
                pendingBackslash = true
            } else {
                out.append(ch)
            }
        }
        if pendingBackslash { out.append("\\") }
        return out
    }

    /// Updates several blocks in one observation fire, so they land in one render frame.
    func updateGuidancePropertiesBatch(stepId: String, blocks: [Int: [String: String]]) {
        var stepDict = dynamicGuidanceProperties[stepId] ?? [:]

        for (blockIndex, properties) in blocks {
            var blockDict = stepDict[blockIndex] ?? [:]
            blockDict.merge(properties) { _, new in new }
            stepDict[blockIndex] = blockDict
        }

        dynamicGuidanceProperties[stepId] = stepDict

        let totalProps = blocks.values.reduce(0) { $0 + $1.count }
        writeLog("InspectDynamicState: Batch updated \(blocks.count) blocks (\(totalProps) properties) for '\(stepId)'", logLevel: .info)
    }

    /// Nil or empty removes the icon.
    func updateItemStatusIcon(index: Int, icon: String?) {
        if let icon = icon, !icon.isEmpty {
            itemStatusIcons[index] = icon
        } else {
            itemStatusIcons.removeValue(forKey: index)
        }
        writeLog("InspectDynamicState: Updated status icon for item \(index)", logLevel: .info)
    }

    func clearAllState() {
        dynamicMessages.removeAll()
        progressPercentages.removeAll()
        customDataDisplay.removeAll()
        dynamicGuidanceProperties.removeAll()
        itemStatusIcons.removeAll()
        heroImageOverrides.removeAll()
        iconBasePathOverride = nil
        iconOverride = nil

        writeLog("InspectDynamicState: Cleared all dynamic state", logLevel: .info)
    }
}

/// `update_guidance:<step>:<block>:<value>` for every step preset — which step and block it means
/// and what it does. `<step>` is a step id, or `_` for the step holding block `<block>`; an id that
/// matches no step means the current one. `<block>` is an index or a block id. `<value>` is
/// `property=value` (`append=` / `line=` stream, `content=` replaces the text with `\n`
/// unescaped, any other property is set as sent), or plain text that replaces the content.
enum GuidanceUpdateCommand {
    enum Operation: Equatable {
        case append(String)
        case setProperty(String, String)
    }

    struct Resolved: Equatable {
        let stepId: String
        let blockIndex: Int
        let operation: Operation
    }

    enum Failure: Error, Equatable {
        case malformed
        case unknownBlock(String)
    }

    static func resolve(_ command: String, steps: [InspectConfig.IntroStep],
                        currentStep: InspectConfig.IntroStep?) -> Result<Resolved, Failure> {
        let payload = command.hasPrefix("update_guidance:") ? String(command.dropFirst(16)) : command
        let parts = payload.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3 else { return .failure(.malformed) }
        let stepId = parts[0], blockKey = parts[1], value = parts[2]

        let holder = steps.first { $0.content?.contains { $0.id == blockKey } == true }
        let step: InspectConfig.IntroStep? = (stepId == "_" || stepId.isEmpty)
            ? (holder ?? currentStep)
            : (steps.first { $0.id == stepId } ?? currentStep)
        guard let step, let content = step.content,
              let blockIndex = InspectConfig.GuidanceContent.resolveBlockIndex(blockKey, in: content) else {
            return .failure(.unknownBlock(blockKey))
        }

        let operation: Operation
        if let eq = value.firstIndex(of: "=") {
            let property = String(value[..<eq])
            let raw = String(value[value.index(after: eq)...])
            if let streamed = InspectDynamicState.streamedText(property: property, value: raw) {
                operation = .append(streamed)
            } else if property == "content" {
                operation = .setProperty("content", InspectDynamicState.unescapeIPCText(raw))
            } else {
                operation = .setProperty(property, raw)
            }
        } else {
            operation = .setProperty("content", value)
        }
        return .success(Resolved(stepId: step.id, blockIndex: blockIndex, operation: operation))
    }
}

extension InspectDynamicState {
    func apply(_ update: GuidanceUpdateCommand.Resolved) {
        switch update.operation {
        case .append(let text):
            appendGuidanceContent(stepId: update.stepId, blockIndex: update.blockIndex, text: text)
        case .setProperty(let property, let value):
            updateGuidanceProperty(stepId: update.stepId, blockIndex: update.blockIndex, property: property, value: value)
        }
    }
}

/// `set:<type>:<value>[:<extra>]` for every step preset. Returns the log line, or nil for an
/// unknown type.
/// - `status-badge:<id|label>:<state>` — the first matching block, on the current step first
/// - `phase-tracker:<phase>` — every phase tracker's `currentPhase`
/// - `heroImage:<stepId>:<path>` — that step's hero (an empty path removes it)
/// - `iconBasePath:<path>` — the base for relative icon paths (empty removes it)
/// - `icon:<path>` — recorded
/// - `clear:<status-badge|phase-tracker|heroImage|iconBasePath|icon|all>`
enum DynamicSetCommand {
    @MainActor
    static func apply(type: String, value: String, extra: String? = nil, steps: [InspectConfig.IntroStep],
                      currentStepId: String?, state: InspectDynamicState) -> String? {
        switch type {
        case "status-badge":
            let newState = extra ?? "enabled"
            let ordered = steps.filter { $0.id == currentStepId } + steps.filter { $0.id != currentStepId }
            for step in ordered {
                for (index, block) in (step.content ?? []).enumerated()
                where (block.id ?? block.content ?? block.label ?? "") == value || block.label == value {
                    state.updateGuidanceProperty(stepId: step.id, blockIndex: index, property: "state", value: newState)
                    return "status badge '\(value)' on '\(step.id)' → '\(newState)'"
                }
            }
            return "status badge '\(value)' matched no block"
        case "phase-tracker":
            guard let phase = Int(value) else { return "invalid phase-tracker index '\(value)'" }
            for step in steps {
                for (index, block) in (step.content ?? []).enumerated() where block.type == "phase-tracker" {
                    state.updateGuidanceProperty(stepId: step.id, blockIndex: index, property: "currentPhase", value: "\(phase)")
                }
            }
            return "phase tracker → phase \(phase)"
        case "heroImage":
            let path = extra ?? ""
            if path.isEmpty { state.heroImageOverrides.removeValue(forKey: value) } else { state.heroImageOverrides[value] = path }
            return path.isEmpty ? "hero image for '\(value)' cleared" : "hero image for '\(value)' → '\(path)'"
        case "iconBasePath":
            state.iconBasePathOverride = value.isEmpty ? nil : value
            return "icon base path → '\(value)'"
        case "icon":
            state.iconOverride = value.isEmpty ? nil : value
            return "icon → '\(value)'"
        case "clear":
            switch value {
            case "status-badge", "status-badges":
                state.dynamicGuidanceProperties.removeAll()
            case "phase-tracker":
                for (stepId, blocks) in state.dynamicGuidanceProperties {
                    state.dynamicGuidanceProperties[stepId] = blocks.mapValues { $0.filter { $0.key != "currentPhase" } }
                }
            case "heroImage", "heroImages":
                state.heroImageOverrides.removeAll()
            case "iconBasePath":
                state.iconBasePathOverride = nil
            case "icon":
                state.iconOverride = nil
            case "all":
                state.dynamicGuidanceProperties.removeAll()
                state.heroImageOverrides.removeAll()
                state.iconBasePathOverride = nil
                state.iconOverride = nil
            default:
                return "unknown clear type '\(value)'"
            }
            return "cleared '\(value)'"
        default:
            return nil
        }
    }
}

