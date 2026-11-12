//
//  InspectStateMachines.swift
//  dialog
//
//  Processing-step state machine shared by the presets: countdown, waiting, progress,
//  completion, and the override level a long wait unlocks.
//

import Foundation

// MARK: - Processing State Machine

/// Lifecycle of one processing step: idle → countdown → waiting or progressing → completed → idle.
/// Active states carry `waitElapsed` (seconds), which `InspectOverrideLevel.level(for:)` reads.
public enum InspectProcessingState: Equatable {
    case idle

    /// `total` is the duration the countdown started from; ring views divide by it.
    case countdown(stepId: String, remaining: Int, total: Int, waitElapsed: Int = 0)

    /// Waiting for an external process.
    case waiting(stepId: String, waitElapsed: Int = 0)

    /// `percentage` is 0-100.
    case progressing(stepId: String, percentage: Int, waitElapsed: Int = 0)

    case completed(stepId: String, result: InspectCompletionResult)

    // MARK: - Computed Properties

    /// Nil for `.idle`.
    public var stepId: String? {
        switch self {
        case .idle: return nil
        case .countdown(let id, _, _, _): return id
        case .waiting(let id, _): return id
        case .progressing(let id, _, _): return id
        case .completed(let id, _): return id
        }
    }

    /// True for countdown, waiting and progressing.
    public var isActive: Bool {
        switch self {
        case .idle, .completed: return false
        default: return true
        }
    }

    /// Seconds elapsed; 0 for idle and completed.
    public var waitElapsed: Int {
        switch self {
        case .countdown(_, _, _, let elapsed): return elapsed
        case .waiting(_, let elapsed): return elapsed
        case .progressing(_, _, let elapsed): return elapsed
        default: return 0
        }
    }
}

// MARK: - Completion Result

/// Outcome of a processing step. A nil message lets the preset show its default text.
public enum InspectCompletionResult: Equatable {
    case success(message: String?)
    case failure(message: String?)
    case warning(message: String?)
    case cancelled
}

// MARK: - Progressive Override Level

/// Which override UI a long wait has unlocked: none (0-10 s), a warning (10-15 s), a small
/// skip link (15-60 s), a large override button (60 s+).
public enum InspectOverrideLevel: Equatable {
    case none
    case warning
    case small
    case large

    /// `duration` in seconds.
    public static func level(for duration: Int) -> InspectOverrideLevel {
        switch duration {
        case 0..<10: return .none
        case 10..<15: return .warning
        case 15..<60: return .small
        default: return .large
        }
    }
}

