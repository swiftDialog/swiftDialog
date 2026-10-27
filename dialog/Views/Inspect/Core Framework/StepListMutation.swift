//
//  StepListMutation.swift
//  dialog
//
//  `step_add:` / `step_remove:` for every step preset: decode, desugar, duplicate replay, anchor
//  or index, and a cursor fix-up that keeps the mounted step mounted. Presets store the result.
//

import Foundation

enum StepListMutation {
    enum Outcome {
        /// The new list, where the step went (or came from), and the cursor fixed up so the step
        /// on screen stays on screen.
        case applied(steps: [InspectConfig.IntroStep], index: Int, cursor: Int, id: String)
        /// The same step sent again (multi-dispatch replay): nothing changes, and the ack says so.
        case duplicate(id: String)
        case rejected(StepCommandResult)

        /// The ack for an outcome that needs no more than the router's reply.
        var result: StepCommandResult {
            switch self {
            case .applied(_, _, _, let id): return .ok(id: id)
            case .duplicate(let id): return .ok(id: id, note: "duplicate")
            case .rejected(let result): return result
            }
        }
    }

    /// Adds the step in `payload` (a `StepAddEnvelope`). The step is desugared exactly as the file
    /// decoder does, so a step that arrives over IPC is indistinguishable from one in the config.
    static func add(payload: String, to steps: [InspectConfig.IntroStep], cursor: Int,
                    label: String) -> Outcome {
        let envelope: StepAddEnvelope<InspectConfig.IntroStep>
        do { envelope = try decodeStepEnvelope(payload) } catch {
            return .rejected(.rejected(id: nil, message: "decode failed: \(stepDecodeFailureSummary(error))"))
        }
        var advisories: [String] = []
        let step = InspectConfig.canonicalizeStep(envelope.step, advisories: &advisories)
        for line in advisories { writeLog("\(label): step_add \(line)", logLevel: .info) }
        guard !step.id.isEmpty else { return .rejected(.rejected(id: nil, message: "step id required")) }
        guard envelope.after == nil || envelope.at == nil else {
            return .rejected(.rejected(id: step.id, message: "'after' and 'at' are mutually exclusive"))
        }
        var list = steps
        if let existing = list.first(where: { $0.id == step.id }) {
            if canonicalStepJSON(existing) == canonicalStepJSON(step) { return .duplicate(id: step.id) }
            return .rejected(.rejected(id: step.id, message: "duplicate id '\(step.id)'"))
        }
        let insertIndex: Int
        if let after = envelope.after {
            guard let anchor = list.firstIndex(where: { $0.id == after }) else {
                return .rejected(.rejected(id: step.id, message: "unknown anchor id '\(after)'"))
            }
            insertIndex = anchor + 1
        } else if let at = envelope.at {
            guard (0...list.count).contains(at) else {
                return .rejected(.rejected(id: step.id, message: "index \(at) out of range 0...\(list.count)"))
            }
            insertIndex = at
        } else {
            insertIndex = list.count
        }
        let hadMountedStep = !list.isEmpty
        list.insert(step, at: insertIndex)
        let newCursor = (hadMountedStep && insertIndex <= cursor) ? cursor + 1 : cursor
        return .applied(steps: list, index: insertIndex, cursor: newCursor, id: step.id)
    }

    /// Removes a step that is not the one on screen.
    static func remove(id stepId: String, from steps: [InspectConfig.IntroStep], cursor: Int) -> Outcome {
        var list = steps
        guard let index = list.firstIndex(where: { $0.id == stepId }) else {
            return .rejected(.rejected(id: stepId, message: "unknown id '\(stepId)'"))
        }
        guard index != cursor else {
            return .rejected(.rejected(id: stepId, message: "cannot remove current step"))
        }
        list.remove(at: index)
        let newCursor = index < cursor ? cursor - 1 : cursor
        return .applied(steps: list, index: index, cursor: newCursor, id: stepId)
    }

    /// The event and log line for an applied change. Call it after storing the new list, so
    /// anything the event wakes sees the list it describes.
    static func announce(_ outcome: Outcome, added: Bool, label: String) {
        guard case .applied(let list, let index, _, let id) = outcome else { return }
        DialogNotifications.postEvent(added ? .stepAdded : .stepRemoved, userInfo: [
            "id": id, "index": String(index), "count": String(list.count)
        ])
        if added {
            writeLog("\(label): step_add '\(id)' at \(index) — \(list.count) steps", logLevel: .info)
        } else {
            writeLog("\(label): step_remove '\(id)' — \(list.count) steps", logLevel: .info)
        }
    }
}

/// Resolves `batch_update:{"step":…, "updates":{blockKey: {property: value}}}` to a step and its
/// block indices. `"_"` means the step holding the first named block, else the first step; a
/// block key is a numeric index or a block id. Applying the result stays with the preset.
enum GuidanceBatchUpdate {
    struct Resolved {
        let stepId: String
        let blocks: [Int: [String: String]]
        /// Block keys that matched no block in the step.
        let unresolvedKeys: [String]
    }

    enum Failure: Error, Equatable {
        case invalidJSON
        case unknownStep(String)
    }

    private struct Payload: Codable {
        let step: String
        let updates: [String: [String: String]]
    }

    static func resolve(_ jsonString: String, in steps: [InspectConfig.IntroStep]) -> Result<Resolved, Failure> {
        guard let data = jsonString.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return .failure(.invalidJSON)
        }
        let target: InspectConfig.IntroStep?
        if payload.step == "_" {
            target = payload.updates.keys.compactMap { key -> InspectConfig.IntroStep? in
                guard Int(key) == nil else { return nil }
                return steps.first { step in step.content?.contains { $0.id == key } == true }
            }.first ?? steps.first
        } else {
            target = steps.first { $0.id == payload.step }
        }
        guard let step = target, let content = step.content else { return .failure(.unknownStep(payload.step)) }
        var blocks: [Int: [String: String]] = [:]
        var unresolved: [String] = []
        for (blockKey, properties) in payload.updates {
            if let index = InspectConfig.GuidanceContent.resolveBlockIndex(blockKey, in: content) {
                blocks[index] = properties
            } else {
                unresolved.append(blockKey)
            }
        }
        return .success(Resolved(stepId: step.id, blocks: blocks, unresolvedKeys: unresolved))
    }
}
