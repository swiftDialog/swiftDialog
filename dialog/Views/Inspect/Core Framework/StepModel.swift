//
//  StepModel.swift
//  dialog
//
//  The live step vocabulary for IPC step composition (`step_add:`, `step_list`), shared by
//  every preset.
//

import Foundation

/// Live status of a step or item. Raw values are the `step_list` wire format; do not rename cases.
/// Precedence when several stores claim an id: failed → completed → skipped → active → pending.
enum StepStatus: String, Codable {
    case pending
    case active
    case completed
    case failed
    case skipped

    /// The row has an outcome — completed, failed or skipped — and waits on nothing more.
    var isFinished: Bool { self == .completed || self == .failed || self == .skipped }

    /// The one parser for every authored spelling of a lifecycle state, so no two files disagree
    /// about a word. `wait` is `active`, as classic swiftDialog draws it. Unknown words return nil.
    init?(lenient authored: String) {
        switch authored.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "active", "downloading", "installing", "wait":
            self = .active
        case "complete", "completed", "installed", "success":
            self = .completed
        case "error", "fail", "failed", "failure":
            self = .failed
        case "pending":
            self = .pending
        case "skipped":
            self = .skipped
        default:
            return nil
        }
    }

    /// Every spelling the lenient parse accepts, grouped by meaning. Must match `init?(lenient:)`.
    static let synonyms: [StepStatus: Set<String>] = [
        .active: ["active", "downloading", "installing", "wait"],
        .completed: ["complete", "completed", "installed", "success"],
        .failed: ["error", "fail", "failed", "failure"],
        .pending: ["pending"],
        .skipped: ["skipped"]
    ]
}

/// Outcome of a step-composition handler, carried back to the router's ack. `note` rides as the
/// ack `message` on OK acks (e.g. "duplicate" for a replayed no-op).
enum StepCommandResult {
    case ok(id: String, note: String? = nil)
    case rejected(id: String?, message: String)
}

/// Wire envelope for `step_add:`. `after` and `at` are mutually exclusive; neither means append.
struct StepAddEnvelope<Step: Decodable>: Decodable {
    let step: Step
    let after: String?
    let at: Int?
}

func decodeStepEnvelope<Step: Decodable>(_ payload: String) throws -> StepAddEnvelope<Step> {
    guard var data = payload.data(using: .utf8) else {
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "payload is not UTF-8"))
    }
    // 3.1.1 step keys, as for a loaded config (InspectLegacyRemap).
    if var envelope = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
       let step = envelope["step"] as? [String: Any] {
        let remap = InspectLegacyRemap.apply(step: step)
        if !remap.notes.isEmpty {
            InspectLegacyRemap.log(remap.notes)
            envelope["step"] = remap.object
            data = (try? JSONSerialization.data(withJSONObject: envelope)) ?? data
        }
    }
    return try JSONDecoder().decode(StepAddEnvelope<Step>.self, from: data)
}

/// A rejection message that names the offending key of a `DecodingError`.
func stepDecodeFailureSummary(_ error: Error) -> String {
    guard let decodingError = error as? DecodingError else { return error.localizedDescription }
    func path(_ context: DecodingError.Context) -> String {
        context.codingPath.map(\.stringValue).joined(separator: ".")
    }
    switch decodingError {
    case .keyNotFound(let key, let context):
        let prefix = path(context)
        return "missing key '\(prefix.isEmpty ? key.stringValue : "\(prefix).\(key.stringValue)")'"
    case .typeMismatch(_, let context):
        return "type mismatch at '\(path(context))'"
    case .valueNotFound(_, let context):
        return "missing value at '\(path(context))'"
    case .dataCorrupted(let context):
        return "invalid JSON\(context.debugDescription.isEmpty ? "" : ": \(context.debugDescription)")"
    @unknown default:
        return "\(decodingError)"
    }
}

/// Sorted-key encoding for payload identity: a replayed `step_add` whose step encodes identically
/// is a no-op, not a duplicate-id error.
func canonicalStepJSON<S: Encodable>(_ step: S) -> Data? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try? encoder.encode(step)
}

/// Block ids of secure textfields. The live `step_list` snapshot must exclude them.
func secureFieldIds(in blocks: [InspectConfig.GuidanceContent]?) -> Set<String> {
    guard let blocks else { return [] }
    return Set(blocks.compactMap { block -> String? in
        guard block.type == "textfield", block.secure == true else { return nil }
        return block.id
    })
}

/// Flattens the guidance form store to `"itemId.fieldId"` → value, the result-file shape.
/// `confirmations` is not included.
func flattenedGuidanceFormValues(_ inputs: [String: GuidanceFormInputState],
                                 excludingFieldIds: Set<String> = []) -> [String: String] {
    var result: [String: String] = [:]
    for (itemId, formState) in inputs {
        for (fieldId, value) in formState.dropdowns where !excludingFieldIds.contains(fieldId) {
            result["\(itemId).\(fieldId)"] = value
        }
        for (fieldId, value) in formState.radios where !excludingFieldIds.contains(fieldId) {
            result["\(itemId).\(fieldId)"] = value
        }
        for (fieldId, value) in formState.textfields where !excludingFieldIds.contains(fieldId) {
            result["\(itemId).\(fieldId)"] = value
        }
        for (fieldId, value) in formState.toggles where !excludingFieldIds.contains(fieldId) {
            result["\(itemId).\(fieldId)"] = String(value)
        }
        for (fieldId, value) in formState.sliders where !excludingFieldIds.contains(fieldId) {
            result["\(itemId).\(fieldId)"] = String(value)
        }
        for (fieldId, value) in formState.checkboxes where !excludingFieldIds.contains(fieldId) {
            result["\(itemId).\(fieldId)"] = String(value)
        }
    }
    return result
}

extension InspectState {

    /// One status read for every preset: `stepStatusProvider` when a preset registers one, else
    /// the shared item sets (which have no skip state).
    func status(for id: String) -> StepStatus {
        if let status = stepStatusProvider?(id) { return status }
        if failedItems.contains(id) { return .failed }
        if completedItems.contains(id) { return .completed }
        if downloadingItems.contains(id) { return .active }
        return .pending
    }

    /// Ordered (id, stepType) list from `stepSnapshotProvider`, else the shared `steps`.
    func stepSnapshot() -> [(id: String, stepType: String)] {
        if let snapshot = stepSnapshotProvider?() { return snapshot }
        return steps.map { (id: $0.id, stepType: $0.resolvedStepType) }
    }
}
