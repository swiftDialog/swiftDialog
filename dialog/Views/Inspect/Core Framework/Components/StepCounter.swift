//
//  StepCounter.swift
//  dialog
//
//  The flow-position counter footers and rails place: `StepDotIndicator` plus `StepCounterLabel`
//  words. Knows nothing about a band or preset.
//

import SwiftUI

/// `dots ·  Step 4 of 6` — the flow position, as one assembled unit.
struct StepCounter: View {
    /// Whether a long flow draws a bar instead of dots is `StepDotIndicator.form(total:)`'s
    /// decision; callers cannot override it here.
    enum Form {
        /// The words alone.
        case words
        /// A rule, the indicator, then the words.
        case dots
    }

    /// 1-based position in the flow.
    let current: Int
    /// Total steps in the flow.
    let total: Int
    var form: Form = .dots
    var accentColor: Color = .accentColor
    /// An already-resolved template for callers whose lookup chain is richer than the environment's.
    var template: String?
    /// Tap on dot n (1-based); only the dot form wires it.
    var onSelect: ((Int) -> Void)?
    /// Tap on the words; the caller owns any gesture meaning.
    var onTap: (() -> Void)?

    @Environment(\.palette) private var palette
    @Environment(\.inspectLocalization) private var l10n

    /// Drawn whatever the indicator decides: a one-step flow has no dots but still reads "Step 1 of 1".
    private var words: String {
        StepCounterLabel.text(current: current, total: total, template: template, localizer: l10n)
    }

    private var drawsIndicator: Bool {
        form == .dots && StepDotIndicator.form(total: total) != .none
    }

    var body: some View {
        // 12 matches the footer's leading cluster spacing.
        HStack(spacing: 12) {
            if drawsIndicator {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 1, height: 16)
                StepDotIndicator(current: current, total: total,
                                 accentColor: accentColor, onSelect: onSelect)
            }
            Text(words)
                .font(.caption2)
                .foregroundStyle(palette.textFaint)
                .lineLimit(1)
                .onTapGesture { onTap?() }
        }
    }
}

extension StepCounter {
    /// A copy carrying the host's accent.
    func tinted(_ color: Color) -> StepCounter {
        var copy = self
        copy.accentColor = color
        return copy
    }
}
