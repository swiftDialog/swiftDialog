//
//  ProgressBar.swift
//  dialog
//
//  The linear progress bar and its count caption, placed by Preset 1's sidebar and Preset 4.
//  `config.progressBarConfig` status colours drive the tint when present; otherwise the caller's.
//

import SwiftUI

struct ProgressBar: View {
    @ObservedObject var state: InspectState
    /// nil lets the bar fill its container.
    var width: CGFloat? = 250
    /// nil skips the height frame and takes the system height.
    var height: CGFloat? = 4
    var spacing: CGFloat = 8
    var showLabel: Bool = true
    /// The caption's point size.
    var labelSize: CGFloat = 11
    var tint: Color?
    var localizedFormat: String?
    /// Caller-supplied fraction (0–1) replacing the derived completed/items ratio.
    var progressOverride: Double?

    private var progress: Double {
        if let progressOverride { return min(1.0, max(0, progressOverride)) }
        return state.trackedItems.isEmpty ? 0.0 : Double(state.trackedCompletedCount) / Double(state.trackedItems.count)
    }

    /// Completion beats failure beats normal; `enableStatusColors` gates the normal/error arms.
    private var resolvedTint: Color? {
        guard let pbc = state.config?.progressBarConfig else { return tint }
        let allComplete = !state.trackedItems.isEmpty && state.trackedCompletedCount == state.trackedItems.count
        if allComplete, pbc.showCompletionState == true { return pbc.completeColor }
        if state.trackedFailedCount > 0 {
            if pbc.showBlockingState == true { return pbc.blockingColor }
            if pbc.enableStatusColors == true { return pbc.errorColor }
        }
        if pbc.enableStatusColors == true { return pbc.normalColor }
        return tint
    }

    /// Geometry is fixed at construction, never derived from the caption's current text.
    var body: some View {
        VStack(spacing: spacing) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: width)
                .frame(height: height)
                .tint(resolvedTint)

            if showLabel {
                Text(PresetCommonViews.getProgressText(state: state, localizedFormat: localizedFormat))
                    .font(.system(size: labelSize))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The accent progress capsule for card and rail headers, on a 0.08 track.
struct AccentProgressCapsule: View {
    @Environment(\.palette) private var palette
    let progress: Double
    let accent: Color
    var height: CGFloat = 5
    /// The track behind the fill; nil is the shared 0.08 text track.
    var track: Color?
    /// How a change of `progress` moves; nil jumps.
    var animation: Animation? = .easeInOut(duration: 0.3)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track ?? palette.text.opacity(0.08))
                Capsule().fill(accent)
                    .frame(width: max(0, geo.size.width * min(1, progress)))
            }
        }
        .frame(height: height)
        .animation(animation, value: progress)
    }
}
