//
//  StateLine.swift
//
//  The footer's per-screen note (how long, when due, who to ask), fed by `IntroStep.footerNote`.
//  Drawing only, shared by the card, rail and provisioning chromes.
//

import SwiftUI

/// A footer line that changes between screens. Markdown so a support address can be a link;
/// palette-derived ink so a branded text colour moves this line with it.
struct StateLine: View {
    let text: String

    @Environment(\.palette) private var palette

    var body: some View {
        Text(guidanceAttributedMarkdown(text))
            .font(.system(size: 13))
            .foregroundStyle(palette.text.opacity(0.44))
    }
}
