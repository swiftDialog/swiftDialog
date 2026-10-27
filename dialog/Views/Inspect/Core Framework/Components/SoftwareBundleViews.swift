//
//  SoftwareBundleViews.swift
//  dialog
//
//  The software step's member type and the `handoff-list` block with its rows. Every state shown
//  is detected by monitoring, never authored; the bundle rows live in `GuidanceCatalogueBlocks.swift`.
//

import SwiftUI

/// One member of a bundle, resolved from the step's items plus live monitoring.
struct SoftwareMember: Identifiable {
    let id: String
    let name: String
    let icon: String?
    let bundleId: String?
    let paths: [String]
    let status: StepStatus
    /// Version/build read off the installed bundle; shown only when installed.
    var detail: String?
    var actionLabel: String?
    var action: String?
    var actionURL: String?
    var requestId: String?
}

// MARK: - Handoff row

/// A place to go or something to launch, naming its target so a dead button is diagnosable.
struct HandoffRow: View {
    let handoff: InspectConfig.SoftwareHandoff
    let accent: Color
    let status: StepStatus?
    var scaleFactor: CGFloat = 1.0
    var iconBasePath: String?
    var onAction: (() -> Void)?

    private var unavailable: Bool { SoftwareSortRule.isUnavailable(status) }

    /// The grey line under the title: `targetNote` or `subtitle`, never the authored `detail`.
    private var line: String? {
        let authored = handoff.targetNote ?? handoff.subtitle
        return SoftwareSortRule.launchNote(authored: authored, status: status)
    }

    var body: some View {
        HStack(spacing: 12 * scaleFactor) {
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                Text(handoff.title)
                    .font(.system(size: 13 * scaleFactor, weight: .medium))
                HStack(spacing: 6 * scaleFactor) {
                    if let target = handoff.target {
                        Text(target)
                            .font(.system(size: 11 * scaleFactor, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if let line {
                        Text(line)
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 8 * scaleFactor)
            Button(handoff.buttonLabel ?? "Launch") { onAction?() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(unavailable)
        }
        // The disabled button is the one visual cue; the row itself is never dimmed.
        .padding(.vertical, 9 * scaleFactor)
    }
}

// MARK: - Hand-off list as a content block

/// `type: "handoff-list"`: one `handoffs` array drawn as shortcuts (rows with a `detail`) above
/// launches, split by `SoftwareSortRule.handoffOrder`. Status comes from the `ProgressContext`
/// sets; a handoff with no `itemId` gets nil, meaning "not gated", not "pending".
struct GuidanceHandoffListBlock<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let handoffs: [InspectConfig.SoftwareHandoff]
    let accent: Color
    let scaleFactor: CGFloat
    var iconBasePath: String?
    @ObservedObject var inspectState: Context
    var onAction: (InspectConfig.SoftwareHandoff) -> Void = { _ in }
    @Environment(\.palette) private var palette

    private func status(for handoff: InspectConfig.SoftwareHandoff) -> StepStatus? {
        guard let itemId = handoff.itemId else { return nil }
        if inspectState.completedItems.contains(itemId) { return .completed }
        if inspectState.downloadingItems.contains(itemId) { return .active }
        if inspectState.failedItems.contains(itemId) { return .failed }
        return .pending
    }

    var body: some View {
        let split = SoftwareSortRule.handoffOrder(handoffs) {
            SoftwareSortRule.isUnavailable(status(for: $0))
        }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(split.shortcuts) { row in
                HandoffRow(handoff: row, accent: accent, status: nil,
                           scaleFactor: scaleFactor, iconBasePath: iconBasePath,
                           onAction: { onAction(row) })
            }
            if !split.shortcuts.isEmpty, !split.launches.isEmpty {
                Rectangle()
                    .fill(palette.text.opacity(SoftwareRowM.ruleAlpha))
                    .frame(height: 1)
                    .padding(.vertical, 8 * scaleFactor)
            }
            ForEach(split.launches) { row in
                HandoffRow(handoff: row, accent: accent, status: status(for: row),
                           scaleFactor: scaleFactor, iconBasePath: iconBasePath,
                           onAction: { onAction(row) })
            }
        }
    }
}
