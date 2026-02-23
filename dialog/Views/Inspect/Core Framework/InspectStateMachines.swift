//
//  InspectStateMachines.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 06/11/2025
//
//  Shared state machine enums for Inspect mode presets - this aims to avoid sprawl of custom logic per preset
//  Provides a kind of type-safe state management with associated values
//
//

import Foundation

// MARK: - Processing State Machine

/// Shared processing state machine for step execution across presets
///
/// Tracks the lifecycle of a processing step from countdown through completion.
/// Each state (except idle/completed) includes `waitElapsed` for progressive override UI:
/// - 0-10s: No override available
/// - 10-20s: Warning message shown (`.warning` level)
/// - 20-60s: Small override button available (`.small` level)
/// - 60s+: Large override button available (`.large` level)
///
/// ## Usage Example
/// ```swift
/// @State private var processingState: InspectProcessingState = .idle
///
/// // Start countdown
/// processingState = .countdown(stepId: "install_apps", remaining: 10)
///
/// // Transition to waiting
/// processingState = .waiting(stepId: "install_apps")
///
/// // Show progress
/// processingState = .progressing(stepId: "install_apps", percentage: 45)
///
/// // Complete
/// processingState = .completed(stepId: "install_apps", result: .success(message: "Done!"))
/// ```
///
/// ## State Transitions
/// ```
/// idle
///   ↓
/// countdown(stepId, remaining) → countdown(stepId, remaining-1) → ...
///   ↓
/// waiting(stepId)  OR  progressing(stepId, 0%)
///   ↓                       ↓
/// progressing(stepId, X%)   (continues)
///   ↓
/// completed(stepId, result)
///   ↓
/// idle
/// ```
///
/// - Note: This originaly derived from building pretty complex Preset6, extracted here for reuse across presets
/// - SeeAlso: `InspectCompletionResult`, `InspectOverrideLevel`
public enum InspectProcessingState: Equatable {
    /// No processing active
    case idle

    /// Countdown before processing starts
    /// - Parameters:
    ///   - stepId: Unique identifier for the step
    ///   - remaining: Countdown seconds remaining
    ///   - waitElapsed: Total seconds elapsed since processing started (default: 0)
    case countdown(stepId: String, remaining: Int, waitElapsed: Int = 0)

    /// Waiting for external process to complete
    /// - Parameters:
    ///   - stepId: Unique identifier for the step
    ///   - waitElapsed: Total seconds elapsed since processing started (default: 0)
    case waiting(stepId: String, waitElapsed: Int = 0)

    /// Processing with progress percentage
    /// - Parameters:
    ///   - stepId: Unique identifier for the step
    ///   - percentage: Progress percentage (0-100)
    ///   - waitElapsed: Total seconds elapsed since processing started (default: 0)
    case progressing(stepId: String, percentage: Int, waitElapsed: Int = 0)

    /// Processing completed with result
    /// - Parameters:
    ///   - stepId: Unique identifier for the step
    ///   - result: Completion result (success/failure/cancelled)
    case completed(stepId: String, result: InspectCompletionResult)

    // MARK: - Computed Properties

    /// Extract the step ID from any state that has one
    /// - Returns: Step ID or nil if state is `.idle`
    public var stepId: String? {
        switch self {
        case .idle: return nil
        case .countdown(let id, _, _): return id
        case .waiting(let id, _): return id
        case .progressing(let id, _, _): return id
        case .completed(let id, _): return id
        }
    }

    /// Check if processing is currently active manual UI tests required
    /// - Returns: `true` for countdown/waiting/progressing, `false` for idle/completed
    public var isActive: Bool {
        switch self {
        case .idle, .completed: return false
        default: return true
        }
    }

    /// Extract wait elapsed time (seconds) from current state
    ///
    /// Used to determine override level and show appropriate UI warnings/buttons.
    /// - Returns: Seconds elapsed, or 0 for idle/completed states
    public var waitElapsed: Int {
        switch self {
        case .countdown(_, _, let elapsed): return elapsed
        case .waiting(_, let elapsed): return elapsed
        case .progressing(_, _, let elapsed): return elapsed
        default: return 0
        }
    }

    // MARK: - State Transitions

    /// Create new state with incremented wait time
    ///
    /// Used by timers to update wait duration while preserving other state data.
    /// Idle and completed states remain unchanged.
    ///
    /// ## Example
    /// ```swift
    /// // In timer callback
    /// stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    ///     processingState = processingState.incrementingWait()
    /// }
    /// ```
    ///
    /// - Returns: New state with waitElapsed increased by 1, or self if idle/completed
    public func incrementingWait() -> InspectProcessingState {
        switch self {
        case .countdown(let id, let remaining, let elapsed):
            return .countdown(stepId: id, remaining: remaining, waitElapsed: elapsed + 1)
        case .waiting(let id, let elapsed):
            return .waiting(stepId: id, waitElapsed: elapsed + 1)
        case .progressing(let id, let percentage, let elapsed):
            return .progressing(stepId: id, percentage: percentage, waitElapsed: elapsed + 1)
        default:
            return self
        }
    }
}

// MARK: - Completion Result

/// Result of step completion
///
/// Represents the final outcome of a processing step. Used with
/// `InspectProcessingState.completed(stepId:result:)`.
///
/// ## Usage Example
/// ```swift
/// // Success
/// processingState = .completed(
///     stepId: "install_apps",
///     result: .success(message: "All apps installed successfully")
/// )
///
/// // Failure
/// processingState = .completed(
///     stepId: "install_apps",
///     result: .failure(message: "Installation failed: permission denied")
/// )
///
/// // User cancelled
/// processingState = .completed(
///     stepId: "install_apps",
///     result: .cancelled
/// )
/// ```
///
/// - Note: Messages are optional - presets may show default text if nil
public enum InspectCompletionResult: Equatable {
    /// Step completed successfully
    /// - Parameter message: Optional success message to display
    case success(message: String?)

    /// Step failed with error
    /// - Parameter message: Optional error message to display
    case failure(message: String?)
    
    /// Step completed with warning
    /// - Parameter message: Optional error message to display
    case warning(message: String?)

    /// Step was cancelled by user or system
    case cancelled
}

// MARK: - Progressive Override Level

/// Progressive override UI levels based on wait duration
///
/// Determines which override UI elements to show based on how long
/// a step has been processing. Provides progressive escalation from
/// warning message to override buttons.
///
/// ## Timeline
/// - **0-10s**: `.none` - No override UI shown
/// - **10-20s**: `.warning` - Show warning message about long wait
/// - **20-60s**: `.small` - Show small "Skip this step" link
/// - **60s+**: `.large` - Show prominent override button
///
/// ## Usage Example
/// ```swift
/// private var currentOverrideLevel: InspectOverrideLevel {
///     InspectOverrideLevel.level(for: processingState.waitElapsed)
/// }
///
/// // In view
/// if case .warning = currentOverrideLevel {
///     Text("This step is taking longer than expected...")
/// }
///
/// if case .large = currentOverrideLevel {
///     Button("Override") { ... }
/// }
/// ```
public enum InspectOverrideLevel: Equatable {
    /// No override available (0-10 seconds)
    case none

    /// Warning message shown (10-15 seconds) - shortened for better UX
    case warning

    /// Small override button available (15-60 seconds) - starts earlier now
    case small

    /// Large override button available (60+ seconds)
    case large

    /// Determine override level for given wait duration
    ///
    /// - Parameter duration: Wait time in seconds
    /// - Returns: Appropriate override level
    ///
    /// ## Updated Timing
    /// - Shortened warning period to 5s (was 10s)
    /// - Override button now available at 15s (was 20s)
    /// - Better UX: Users don't wait as long for manual override
    public static func level(for duration: Int) -> InspectOverrideLevel {
        switch duration {
        case 0..<10: return .none
        case 10..<15: return .warning      // Shortened: was 10..<20
        case 15..<60: return .small        // Starts earlier: was 20..<60
        default: return .large
        }
    }
}

// MARK: - Documentation References

/// # Related Documentation
///
/// - **STATE_MACHINE_PATTERN.md**: Complete pattern documentation
/// - **InspectConfig.swift**: Item status enums (InspectItemStatus)
/// - **InspectState.swift**: Configuration loading enums (LoadingState, ConfigurationSource)
/// - **Preset6.swift**: Original implementation and usage examples
///
/// # Adoption Guide
///
/// To adopt these state machines in your preset:
///
/// 1. Import and use directly:
/// ```swift
/// @State private var processingState: InspectProcessingState = .idle
/// @State private var stateTimer: Timer?
/// ```
///
/// 2. Or create typealiases for shorter names:
/// ```swift
/// typealias ProcessingState = InspectProcessingState
/// typealias CompletionResult = InspectCompletionResult
/// typealias OverrideLevel = InspectOverrideLevel
/// ```
///
/// 3. Implement timer management:
/// ```swift
/// private func startStateTimer() {
///     stateTimer?.invalidate()
///     stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
///         processingState = processingState.incrementingWait()
///     }
/// }
/// ```
///
/// 4. Use computed properties for UI decisions:
/// ```swift
/// private var currentOverrideLevel: InspectOverrideLevel {
///     InspectOverrideLevel.level(for: processingState.waitElapsed)
/// }
/// ```

