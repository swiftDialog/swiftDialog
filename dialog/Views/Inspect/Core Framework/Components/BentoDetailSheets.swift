//
//  BentoDetailSheets.swift
//  dialog
//
//  The sheets a bento cell opens: the plist-bound detail sheet and the overlay detail view.
//

import SwiftUI

// MARK: - Sheet Context

/// Cell plus resolved payload, so `.sheet(item:)` gets its data in the content closure.
struct BentoSheetContext: Identifiable {
    enum Payload {
        case overlay(InspectConfig.DetailOverlayConfig)
        case plistBinding(PlistAggregator.ComplianceItem)
    }
    let id: String
    let cell: InspectConfig.GuidanceContent.BentoCellConfig
    let payload: Payload
}

// MARK: - Bento Plist Detail Sheet

/// Compact sheet for a plist-bound bento cell without a `detailOverlay`, populated from the live
/// `ComplianceItem`; the cell's `id` is the plist key.
struct BentoPlistDetailSheet: View {
    @Environment(\.inspectLocalization) private var l10n
    @Environment(\.palette) private var palette
    let cellConfig: InspectConfig.GuidanceContent.BentoCellConfig
    let item: PlistAggregator.ComplianceItem
    /// Pass/fail labels from the plist source config.
    let healthyLabel: String
    let attentionLabel: String
    let scaleFactor: CGFloat
    /// Logs remediation-button taps through the same channel as other button actions.
    let inspectState: any UserInputContext
    let onClose: () -> Void

    private var tint: Color {
        switch item.severity {
        case .healthy: return palette.success
        case .warning: return palette.warning
        case .failure: return item.finding ? palette.success : palette.warning
        }
    }
    private var statusLabel: String { item.finding ? healthyLabel : attentionLabel }
    private var actionURL: URL? {
        guard let raw = item.actionURL, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header ribbon
            HStack(alignment: .center, spacing: 14 * scaleFactor) {
                Image(systemName: cellConfig.sfSymbol ?? (item.finding ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"))
                    .font(.system(size: 28 * scaleFactor, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44 * scaleFactor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 17 * scaleFactor, weight: .semibold))
                    Text(item.category)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12 * scaleFactor)
                Text(statusLabel)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10 * scaleFactor)
                    .padding(.vertical, 5 * scaleFactor)
                    .background(Capsule().fill(tint.opacity(0.15)))
            }
            .padding(.horizontal, 20 * scaleFactor)
            .padding(.vertical, 16 * scaleFactor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.06))

            Divider()

            // Details list
            VStack(alignment: .leading, spacing: 10 * scaleFactor) {
                detailRow("Status", statusLabel, tint: tint)
                detailRow("Category", item.category)
                if item.isCritical {
                    detailRow("Criticality", "Critical", tint: palette.warning)
                }
                detailRow("Plist key", item.id, monospaced: true)
            }
            .padding(20 * scaleFactor)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Remediation content
            if item.explanation != nil || (item.severity != .healthy && (item.remediation != nil || actionURL != nil)) {
                Divider()
                VStack(alignment: .leading, spacing: 14 * scaleFactor) {
                    if let explanation = item.explanation {
                        markdownBlock(label: "Explanation", text: explanation)
                    }
                    if item.severity != .healthy, let remediation = item.remediation {
                        markdownBlock(label: "Remediation", text: remediation)
                    }
                    if item.severity != .healthy, let url = actionURL {
                        Button(item.actionButtonText ?? l10n("ui.bentoPlistOpen", "Open")) {
                            NSWorkspace.shared.open(url)
                            inspectState.writeToInteractionLog(
                                "button:\(item.id):remediation:url:\(url.absoluteString)"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(tint)
                    }
                }
                .padding(.horizontal, 20 * scaleFactor)
                .padding(.vertical, 16 * scaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Footer
            HStack {
                Spacer(minLength: 0)
                Button(l10n("ui.bentoPlistClose", "Close"), action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20 * scaleFactor)
            .padding(.bottom, 16 * scaleFactor)
            .padding(.top, 4 * scaleFactor)
        }
        .frame(width: InspectSizes.Bento.plistDetailWidth * scaleFactor)
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private func markdownBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            Text(label)
                .font(.system(size: 11 * scaleFactor, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(parseMarkdown(text))
                .font(.system(size: 13 * scaleFactor))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func parseMarkdown(_ markdown: String) -> AttributedString {
        guidanceAttributedMarkdown(markdown)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String, tint: Color? = nil, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12 * scaleFactor) {
            Text(label)
                .font(.system(size: 11 * scaleFactor, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(width: 88 * scaleFactor, alignment: .leading)
            if monospaced {
                // Only plist keys are selectable.
                Text(value)
                    .font(.system(size: 12 * scaleFactor, design: .monospaced))
                    .foregroundStyle(tint ?? .primary)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(tint ?? .primary)
            }
            Spacer()
        }
    }
}

// MARK: - Bento Detail View

/// The sheet a bento cell opens when inline expansion is off: the inline detail content
/// (`BentoInlineDetailView`) presented in a sheet sized by the overlay's `wide` flag.
struct BentoDetailView<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    let cellConfig: InspectConfig.GuidanceContent.BentoCellConfig
    let overlay: InspectConfig.DetailOverlayConfig
    let accentColor: Color
    let iconBasePath: String?
    /// Position among siblings for the "2 of 6" subject line; omitted when unknown.
    var subjectIndex: Int?
    var subjectTotal: Int?
    @ObservedObject var inspectState: Context
    let onClose: () -> Void

    /// The room the sheet may use; it fits into this rather than filling it.
    private var budget: CGSize {
        overlay.wide == true ? CGSize(width: 940, height: 560) : CGSize(width: 760, height: 540)
    }

    var body: some View {
        BentoInlineDetailView(
            cellConfig: cellConfig,
            overlay: overlay,
            gridSize: budget,
            accentColor: accentColor,
            iconBasePath: iconBasePath,
            subjectIndex: subjectIndex,
            subjectTotal: subjectTotal,
            inspectState: inspectState,
            onClose: onClose
        )
    }
}
