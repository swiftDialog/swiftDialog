//
//  GuidanceFormSectionBlock.swift
//  dialog
//
//  The "form-section" guidance block: a heading that groups the fields under it, and the
//  section-label treatment shared with the advisory block.
//

import SwiftUI

/// The one section-label style: uppercased, small, monospaced, faint.
struct GuidanceSectionLabel: View {
    let text: String
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10 * scaleFactor, weight: .semibold, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(palette.textFaint)
    }
}

// MARK: - Form section (type: "form-section")

/// A group heading for the blocks that follow it, with an optional right-hand note and a rule.
/// It groups by adjacency only; it does not own the fields structurally.
struct GuidanceFormSectionBlock: View {
    let block: InspectConfig.GuidanceContent
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    /// Accepts `sectionLabel`, `label` or `content` as the heading, in that order.
    private var heading: String? {
        let candidate = block.sectionLabel ?? block.label ?? block.content
        guard let candidate, !candidate.isEmpty else { return nil }
        return candidate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            HStack(alignment: .firstTextBaseline) {
                if let heading {
                    GuidanceSectionLabel(text: heading, scaleFactor: scaleFactor)
                }

                Spacer(minLength: 12 * scaleFactor)

                // Not uppercased: the note is a phrase, not a second heading.
                if let note = block.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 10 * scaleFactor, weight: .regular, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                        .multilineTextAlignment(.trailing)
                }
            }

            Rectangle()
                .fill(palette.textMuted.opacity(0.15))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12 * scaleFactor)
    }
}
