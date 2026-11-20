//
//  ChoiceReceipt.swift
//  dialog
//
//  The outro receipt of per-choice answers, each with a way back to its step. Per-item install
//  outcomes are `PresetOutroReceiptView`'s job.
//

import SwiftUI

/// One decision the user made, and the way back to it.
struct ChoiceReceiptRow: Identifiable {
    var id: String { stepId }
    /// Must be an existing step id: Change navigates here and resume is index-based.
    let stepId: String
    /// What was decided, e.g. "Dock".
    let label: String
    /// The answer in the user's terms, e.g. "Essentials — 4 apps added to your Dock".
    let value: String
}

/// A receipt of decisions, each with a Change action. The caller resolves values from live
/// selections and omits choices never made; this view invents nothing.
struct ChoiceReceipt: View {
    let rows: [ChoiceReceiptRow]
    let accent: Color
    var scaleFactor: CGFloat = 1.0
    var changeLabel: String = "Change"
    /// Nil hides the Change action.
    var onChange: ((String) -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8 * scaleFactor) {
            ForEach(rows) { row in
                HStack(spacing: 12 * scaleFactor) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15 * scaleFactor))
                        .foregroundStyle(palette.success)

                    VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                        Text(row.label)
                            .font(.system(size: 13 * scaleFactor, weight: .medium))
                        Text(row.value)
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8 * scaleFactor)

                    if let onChange {
                        Button(changeLabel) { onChange(row.stepId) }
                            .buttonStyle(.plain)
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(accent)
                    }
                }
                .padding(.horizontal, 14 * scaleFactor)
                .padding(.vertical, 10 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 10 * scaleFactor, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }
}

// MARK: - The receipt on the card contract

/// Which authored receipt rows survive into a rendered receipt; the card arms read `receipt`
/// through this. `label` and `value` are injected for localization and live selection lookup.
enum CardReceipt {

    /// Keeps authored order; a row whose step was never answered (`value` nil) is omitted.
    static func rows(_ authored: [InspectConfig.IntroStep.ReceiptRow],
                     label: (InspectConfig.IntroStep.ReceiptRow) -> String,
                     value: (InspectConfig.IntroStep.ReceiptRow) -> String?) -> [ChoiceReceiptRow] {
        authored.compactMap { row in
            guard let answer = value(row) else { return nil }
            return ChoiceReceiptRow(stepId: row.stepId, label: label(row), value: answer)
        }
    }
}
