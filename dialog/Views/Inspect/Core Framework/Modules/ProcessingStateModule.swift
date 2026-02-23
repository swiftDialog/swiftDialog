//
//  ProcessingStateModule.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 22/01/2026
//
//  Modular processing state UI components for Inspect presets
//
//  This module provides reusable views for displaying processing states:
//  - Countdown timers with circular progress
//  - Progress percentage displays
//  - Waiting spinners
//  - Warning banners for long waits
//  - Success/failure result banners
//  - Full-screen overlay variants for frameless presets
//
//  Used by: Preset6, Preset5 (and future presets)
//

import SwiftUI

// MARK: - Processing Display Style

/// Display style for processing state views
enum ProcessingDisplayStyle {
    /// Inline display within content flow (default for Preset6)
    case inline
    /// Full-screen overlay with blur background (for frameless presets like Preset5)
    case overlay
    /// Compact card style
    case card
}

// MARK: - Processing State Configuration

/// Configuration for processing state display
struct ProcessingStateConfiguration {
    let highlightColor: Color
    let scaleFactor: CGFloat
    let displayStyle: ProcessingDisplayStyle
    let showOverrideUI: Bool
    let allowOverride: Bool

    init(
        highlightColor: Color = .accentColor,
        scaleFactor: CGFloat = 1.0,
        displayStyle: ProcessingDisplayStyle = .inline,
        showOverrideUI: Bool = true,
        allowOverride: Bool = true
    ) {
        self.highlightColor = highlightColor
        self.scaleFactor = scaleFactor
        self.displayStyle = displayStyle
        self.showOverrideUI = showOverrideUI
        self.allowOverride = allowOverride
    }
}

// MARK: - Processing State View

/// Main view for displaying processing state with countdown, progress, or waiting indicator
///
/// This is the primary reusable component for showing processing state across presets.
/// It handles all states from the InspectProcessingState enum and displays appropriate UI.
///
/// ## Usage Example
/// ```swift
/// ProcessingStateView(
///     state: processingState,
///     message: "Installing software...",
///     progressPercentage: dynamicProgress,
///     configuration: .init(highlightColor: .blue, scaleFactor: 1.0)
/// )
/// ```
struct ProcessingStateView: View {
    let state: InspectProcessingState
    let message: String?
    let progressPercentage: Int?
    let totalDuration: Int?
    let configuration: ProcessingStateConfiguration

    init(
        state: InspectProcessingState,
        message: String? = nil,
        progressPercentage: Int? = nil,
        totalDuration: Int? = nil,
        configuration: ProcessingStateConfiguration = ProcessingStateConfiguration()
    ) {
        self.state = state
        self.message = message
        self.progressPercentage = progressPercentage
        self.totalDuration = totalDuration
        self.configuration = configuration
    }

    private var scaleFactor: CGFloat { configuration.scaleFactor }
    private var highlightColor: Color { configuration.highlightColor }

    var body: some View {
        VStack(spacing: 16 * scaleFactor) {
            // Visual indicator based on state
            processingIndicator

            // Message text
            if let displayMessage = computedMessage {
                Text(displayMessage)
                    .font(.system(size: 14 * scaleFactor, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16 * scaleFactor)
    }

    @ViewBuilder
    private var processingIndicator: some View {
        if let percentage = progressPercentage {
            // External progress percentage
            progressCircle(percentage: percentage)
        } else {
            switch state {
            case .countdown(_, let remaining, _):
                countdownCircle(remaining: remaining)
            case .waiting:
                waitingSpinner
            case .progressing(_, let percentage, _):
                progressCircle(percentage: percentage)
            default:
                // Fallback: static ellipsis
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 48 * scaleFactor, weight: .medium))
                    .foregroundStyle(highlightColor)
                    .padding(.vertical, 24 * scaleFactor)
            }
        }
    }

    private func countdownCircle(remaining: Int) -> some View {
        let duration = totalDuration ?? 5
        return ZStack {
            Circle()
                .stroke(highlightColor.opacity(0.3), lineWidth: 4)
                .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)

            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(duration))
                .stroke(highlightColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0), value: remaining)

            Text("\(max(0, remaining))")
                .font(.system(size: 48 * scaleFactor, weight: .bold, design: .rounded))
                .foregroundStyle(highlightColor)
        }
        .padding(.vertical, 8 * scaleFactor)
    }

    private func progressCircle(percentage: Int) -> some View {
        ZStack {
            Circle()
                .stroke(highlightColor.opacity(0.3), lineWidth: 4)
                .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)

            Circle()
                .trim(from: 0, to: CGFloat(percentage) / 100.0)
                .stroke(highlightColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 100 * scaleFactor, height: 100 * scaleFactor)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: percentage)

            Text("\(percentage)%")
                .font(.system(size: 36 * scaleFactor, weight: .bold, design: .rounded))
                .foregroundStyle(highlightColor)
        }
        .padding(.vertical, 8 * scaleFactor)
    }

    private var waitingSpinner: some View {
        ProgressView()
            .controlSize(.large)
            .tint(highlightColor)
            .scaleEffect(1.5 * scaleFactor)
            .frame(height: 100 * scaleFactor)
    }

    private var computedMessage: String? {
        guard let message = message else { return nil }

        switch state {
        case .countdown(_, let remaining, _) where remaining > 0:
            return message.replacingOccurrences(of: "{countdown}", with: "\(remaining)")
        case .waiting:
            return "Waiting for result..."
        default:
            return message.contains("{countdown}") ? "Processing..." : message
        }
    }
}

// MARK: - Processing Warning Banner

/// Warning banner shown during long waits in processing state
///
/// Displays a warning message with elapsed time and optional override guidance.
/// Only shown when override level is `.warning` and processing is in waiting state.
struct ProcessingWarningBanner: View {
    let waitElapsed: Int
    let message: String?
    let scaleFactor: CGFloat

    init(
        waitElapsed: Int,
        message: String? = nil,
        scaleFactor: CGFloat = 1.0
    ) {
        self.waitElapsed = waitElapsed
        self.message = message
        self.scaleFactor = scaleFactor
    }

    var body: some View {
        HStack(spacing: 8 * scaleFactor) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14 * scaleFactor))
                .foregroundStyle(.orange)

            Text(message ?? "This step has been waiting for over \(waitElapsed) seconds. If you're experiencing issues, you can use the override option below.")
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12 * scaleFactor)
        .background(Color.orange.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 8 * scaleFactor)
    }
}

// MARK: - Processing Result Banner

/// Banner displaying success or failure result after processing completes
///
/// Shows a colored banner with icon and message indicating the result.
struct ProcessingResultBanner: View {
    let result: ProcessingResultType
    let message: String?
    let scaleFactor: CGFloat

    enum ProcessingResultType {
        case success
        case failure(reason: String?)
        case warning
        case cancelled

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .failure: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .cancelled: return "xmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .failure: return .red
            case .warning: return .orange
            case .cancelled: return .secondary
            }
        }
    }

    init(
        result: ProcessingResultType,
        message: String? = nil,
        scaleFactor: CGFloat = 1.0
    ) {
        self.result = result
        self.message = message
        self.scaleFactor = scaleFactor
    }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            Image(systemName: result.icon)
                .font(.system(size: 20 * scaleFactor))
                .foregroundStyle(result.color)

            VStack(alignment: .leading, spacing: 4 * scaleFactor) {
                if let message = message {
                    Text(message)
                        .font(.system(size: 14 * scaleFactor, weight: .semibold))
                        .foregroundStyle(.primary)
                }

                if case .failure(let reason) = result, let failureReason = reason, !failureReason.isEmpty {
                    Text(failureReason)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12 * scaleFactor)
        .background(result.color.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(result.color.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 8 * scaleFactor)
    }
}

// MARK: - Processing Overlay View

/// Full-screen processing overlay for frameless presets
///
/// Displays processing state as an overlay with blurred background.
/// Used by frameless presets like Preset5 that need processing feedback
/// without a traditional windowed interface.
struct ProcessingOverlayView: View {
    let state: InspectProcessingState
    let message: String?
    let progressPercentage: Int?
    let totalDuration: Int?
    let configuration: ProcessingStateConfiguration
    let onCancel: (() -> Void)?
    let onOverride: (() -> Void)?

    @State private var showCancelButton = false

    init(
        state: InspectProcessingState,
        message: String? = nil,
        progressPercentage: Int? = nil,
        totalDuration: Int? = nil,
        configuration: ProcessingStateConfiguration = ProcessingStateConfiguration(displayStyle: .overlay),
        onCancel: (() -> Void)? = nil,
        onOverride: (() -> Void)? = nil
    ) {
        self.state = state
        self.message = message
        self.progressPercentage = progressPercentage
        self.totalDuration = totalDuration
        self.configuration = configuration
        self.onCancel = onCancel
        self.onOverride = onOverride
    }

    private var scaleFactor: CGFloat { configuration.scaleFactor }
    private var currentOverrideLevel: InspectOverrideLevel {
        InspectOverrideLevel.level(for: state.waitElapsed)
    }

    var body: some View {
        ZStack {
            // Blurred background
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            // Content card
            VStack(spacing: 24 * scaleFactor) {
                // Processing indicator
                ProcessingStateView(
                    state: state,
                    message: message,
                    progressPercentage: progressPercentage,
                    totalDuration: totalDuration,
                    configuration: configuration
                )

                // Warning banner if waiting too long
                if case .warning = currentOverrideLevel,
                   case .waiting = state,
                   configuration.showOverrideUI {
                    ProcessingWarningBanner(
                        waitElapsed: state.waitElapsed,
                        scaleFactor: scaleFactor
                    )
                }

                // Override/Cancel buttons
                if configuration.allowOverride && showCancelButton {
                    HStack(spacing: 16 * scaleFactor) {
                        if let onCancel = onCancel {
                            Button("Cancel") {
                                onCancel()
                            }
                            .buttonStyle(.bordered)
                        }

                        if let onOverride = onOverride,
                           currentOverrideLevel != .none {
                            Button("Skip Step") {
                                onOverride()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
            }
            .padding(32 * scaleFactor)
            .background(.ultraThinMaterial)
            .clipShape(.rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            .padding(40)
        }
        .onAppear {
            // Show cancel button after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showCancelButton = true
                }
            }
        }
    }
}

// MARK: - Progressive Override Button

/// Button for overriding stuck processing steps
///
/// Displays differently based on the current override level:
/// - `.small`: Subtle link-style button
/// - `.large`: Prominent button with warning styling
struct ProgressiveOverrideButton: View {
    let overrideLevel: InspectOverrideLevel
    let buttonText: String
    let scaleFactor: CGFloat
    let action: () -> Void

    init(
        overrideLevel: InspectOverrideLevel,
        buttonText: String = "Override",
        scaleFactor: CGFloat = 1.0,
        action: @escaping () -> Void
    ) {
        self.overrideLevel = overrideLevel
        self.buttonText = buttonText
        self.scaleFactor = scaleFactor
        self.action = action
    }

    var body: some View {
        switch overrideLevel {
        case .small:
            Button(action: action) {
                Text(buttonText)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(.orange)
            }
            .buttonStyle(.plain)

        case .large:
            Button(action: action) {
                HStack(spacing: 8 * scaleFactor) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.system(size: 14 * scaleFactor))
                    Text(buttonText)
                        .font(.system(size: 14 * scaleFactor, weight: .semibold))
                }
                .padding(.horizontal, 16 * scaleFactor)
                .padding(.vertical, 10 * scaleFactor)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)

        default:
            EmptyView()
        }
    }
}

// MARK: - Processing State Container

/// Container view that wraps processing content with appropriate styling
///
/// Applies the correct container styling based on the display style configuration.
/// This is useful for wrapping ProcessingStateView with consistent styling.
struct ProcessingStateContainer<Content: View>: View {
    let displayStyle: ProcessingDisplayStyle
    let scaleFactor: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        displayStyle: ProcessingDisplayStyle = .inline,
        scaleFactor: CGFloat = 1.0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.displayStyle = displayStyle
        self.scaleFactor = scaleFactor
        self.content = content
    }

    var body: some View {
        switch displayStyle {
        case .inline:
            content()

        case .card:
            content()
                .padding(16 * scaleFactor)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

        case .overlay:
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                content()
                    .padding(32 * scaleFactor)
                    .background(.ultraThinMaterial)
                    .clipShape(.rect(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .padding(40)
            }
        }
    }
}

// MARK: - Helper Extensions

extension InspectCompletionResult {
    /// Convert to ProcessingResultBanner.ProcessingResultType for display
    var displayType: ProcessingResultBanner.ProcessingResultType {
        switch self {
        case .success:
            return .success
        case .failure(let message):
            return .failure(reason: message)
        case .warning:
            return .warning
        case .cancelled:
            return .cancelled
        }
    }

    /// Extract message from result
    var message: String? {
        switch self {
        case .success(let msg), .failure(let msg), .warning(let msg):
            return msg
        case .cancelled:
            return "Cancelled"
        }
    }
}
