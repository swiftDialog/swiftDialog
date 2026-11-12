//
//  SelectionEmission.swift
//  Dialog
//
//  Pure decisions for when a selecting block emits a `select:` line and which `userValues` key it writes,
//  kept free of clock, file system and state so the suite can test them.

import Foundation

enum SelectionEmission {

    /// What produced the value. A drag frame and the drag ending look the same on screen but differ on the wire.
    enum Trigger {
        /// A pointer sample mid-drag. Moves the handle; never an answer.
        case dragFrame
        /// An answer: drag end, chip or card tap, confirm press, or a value resolved on appear.
        case committed
    }

    /// Whether `newValue` should be written to `userValues`, logged and broadcast, given what was last recorded.
    /// Emits when nothing was recorded (so an accepted pre-selection still produces a `select:` line) or the
    /// wire string changed; suppresses identical values and every `.dragFrame`.
    static func shouldEmit(newValue: String, recorded: String?, trigger: Trigger) -> Bool {
        guard trigger != .dragFrame else { return false }
        guard let recorded else { return true }
        return newValue != recorded
    }

    /// The key a selecting block writes to, and whether it fell back to the shared literal
    /// ("option", "wallpaper", "dock", "slot"). Two blocks on one fallback overwrite each other, so callers
    /// log when `usedFallback` is true. An empty string counts as absent.
    static func resolveKey(_ explicit: String?, fallback: String) -> (key: String, usedFallback: Bool) {
        guard let explicit, !explicit.isEmpty else { return (fallback, true) }
        return (explicit, false)
    }
}

// MARK: - Selection-key fallbacks

/// Selecting blocks fall back to a shared literal key when none is authored (`option-picker` → "option",
/// `wallpaper-picker` → "wallpaper", `dock-picker` → "dock"), so two id-less blocks of one type
/// overwrite each other in `userValues`. Key derivation is `SelectionEmission.resolveKey`; this type
/// maps block types to key fields and reports fallbacks and collisions per step. `slot-picker` logs its own.
enum GuidanceSelectionKeys {

    /// One per block that will take its type's shared fallback key.
    struct FallbackWarning: Equatable {
        let blockType: String
        /// The literal the block will end up writing to.
        let key: String
        /// How many other blocks on the step take this key: 0 warns about a missing key, 1+ is a collision.
        let sharedWith: Int
    }

    /// Block type → (key field, fallback literal). The one place the mapping lives; arms call `resolvedKey(for:)`.
    private static func authoredKey(for block: InspectConfig.GuidanceContent) -> (key: String?, fallback: String)? {
        switch block.type {
        case "option-picker":    return (block.optionKey, "option")
        case "wallpaper-picker": return (block.wallpaperSelectionKey, "wallpaper")
        case "dock-picker":      return (block.dockSelectionKey, "dock")
        case "grid-picker":      return (block.gridSelectionKey, "grid")
        default:                 return nil
        }
    }

    /// The key a block writes to; nil for non-selecting types.
    static func resolvedKey(for block: InspectConfig.GuidanceContent) -> String? {
        guard let (authored, fallback) = authoredKey(for: block) else { return nil }
        return SelectionEmission.resolveKey(authored, fallback: fallback).key
    }

    /// The warnings this step's blocks earn, in authored order.
    static func fallbackWarnings(in blocks: [InspectConfig.GuidanceContent]) -> [FallbackWarning] {
        var takers: [String: Int] = [:]
        var offenders: [(type: String, key: String)] = []
        for block in blocks {
            guard let (authored, fallback) = authoredKey(for: block) else { continue }
            let resolved = SelectionEmission.resolveKey(authored, fallback: fallback)
            guard resolved.usedFallback else { continue }
            takers[resolved.key, default: 0] += 1
            offenders.append((block.type, resolved.key))
        }
        return offenders.map {
            FallbackWarning(blockType: $0.type, key: $0.key,
                            sharedWith: (takers[$0.key] ?? 1) - 1)
        }
    }

    /// The log line for a warning; pinned by a test so a collision reads as data loss.
    static func message(for warning: FallbackWarning) -> String {
        let head = "GuidanceContentView: a '\(warning.blockType)' block has no selection key "
            + "authored — defaulting to '\(warning.key)'."
        guard warning.sharedWith > 0 else {
            return head + " Author a distinct key before adding a second one to this step, or "
                + "they will silently share (and overwrite) one answer."
        }
        return head + " \(warning.sharedWith + 1) blocks on this step now share '\(warning.key)' "
            + "— they overwrite each other's answers and all but one is lost. Author distinct keys."
    }

    /// Called once per `GuidanceContentView.onAppear`.
    static func logFallbacks(in blocks: [InspectConfig.GuidanceContent]) {
        for warning in fallbackWarnings(in: blocks) {
            writeLog(message(for: warning), logLevel: .error)
        }
    }
}
