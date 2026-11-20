//
//  SpecimenFrame.swift
//  dialog
//
//  A labelled frame naming the block it wraps, applied by `GuidanceContentView` around any routed arm.
//  On card steps, `bullets`, `warning`, `prose` and `text` render outside it, so `specimen` is ignored there.

import SwiftUI

extension InspectConfig.GuidanceContent {
    /// Whether this block asks to be framed; an empty name draws no frame.
    var wantsSpecimenFrame: Bool {
        guard let name = specimen else { return false }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct SpecimenFrame<Content: View>: View {
    @Environment(\.palette) private var palette

    let name: String
    let note: String?
    let scaleFactor: CGFloat
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12 * scaleFactor)
                .padding(.top, 16 * scaleFactor)
                .padding(.bottom, 12 * scaleFactor)
                // Border in an overlay so an opaque block cannot hide it; the chip, applied last, masks it.
                .overlay(
                    RoundedRectangle(cornerRadius: 7 * scaleFactor, style: .continuous)
                        .stroke(palette.text.opacity(0.14), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) { chip }
            if let note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 11.5 * scaleFactor))
                    .foregroundStyle(palette.text.opacity(0.45))
                    .padding(.leading, 4 * scaleFactor)
            }
        }
        // The chip overshoots the border by 7pt; reserving it here keeps any ancestor from clipping it.
        .padding(.top, 7 * scaleFactor)
    }

    /// Monospaced because the chip is a value you type into JSON; it sits on the border as the frame's label.
    private var chip: some View {
        Text(name)
            .font(.system(size: 10.5 * scaleFactor, design: .monospaced))
            .foregroundStyle(palette.text.opacity(0.55))
            .padding(.horizontal, 5 * scaleFactor)
            .padding(.vertical, 1 * scaleFactor)
            .background(palette.cardSurface)
            .padding(.leading, 10 * scaleFactor)
            .offset(y: -7 * scaleFactor)
    }
}
