//
//  SetupAssistantFramedShell.swift
//  dialog
//
//  The framed Setup Assistant shell (state β): the picture is a specimen in a card on the
//  window's ground, with title and lede above it and two footer buttons.
//

import SwiftUI

/// State β, framed: the media sits in a card on the window's ground with title and lede above, and the
/// footer holds a quiet door and the primary. For screens with real instructions. Paints from the palette.
struct SetupAssistantFramedShell<Media: View>: View {
    let title: String
    var lede: String?
    /// Numbered steps in one row under the media, inside the card.
    var steps: [MigrationActionStep] = []
    /// The line under the steps, e.g. "Leave System Settings open until this screen says it is done."
    var specimenNote: String?
    /// Phase, count and bar, inside the card at its width, so the phase name prints once.
    var progress: SetupAssistantCapsule = .none
    /// The customer mark on the footer's left.
    var logoPath: String?
    /// The footer's state line: estimate and do-not-sleep warning.
    var footerLine: String?
    var primaryTitle: String?
    /// Continue stays disabled until the process has started.
    var primaryDisabled: Bool = false
    var onPrimary: (() -> Void)?
    /// The quiet door, a pill in the footer row.
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?
    /// The back door; nil omits it.
    var backLabel: String?
    var onBack: (() -> Void)?
    let accent: Color
    /// The height the specimen budgets against (default `recommended`); shorter values shrink the specimen.
    var frameHeight: CGFloat = SetupAssistantM.recommended.height
    @ViewBuilder var media: () -> Media

    @Environment(\.palette) private var palette

    /// The specimen's height after the card's furniture and the footer. Arithmetic, so the first frame is right.
    private var mediaHeight: CGFloat {
        let hasStrip = !steps.isEmpty || specimenNote != nil || progress != .none
        let strip = !hasStrip ? 0
            : SetupAssistantM.betaStripPadTop + SetupAssistantM.betaStripPadBottom
                + (steps.isEmpty ? 0 : SetupAssistantM.betaStepRow)
                + (progress == .none ? 0 : SetupAssistantM.betaProgressBlock)
                + (specimenNote == nil ? 0 : SetupAssistantM.captionLine + 10)
        // The doors sit in the footer band and the card clears it by `footerClearance`.
        let below = SetupAssistantM.footerHeight + SetupAssistantM.footerClearance
        let available = frameHeight - SetupAssistantM.betaCardTop - strip - below
        return max(min(SetupAssistantM.betaMediaHeight, available), SetupAssistantM.betaMediaFloor)
    }

    var body: some View {
        // Frames to `hostHeight`, like α; `frameHeight` only feeds the specimen arithmetic.
        ZStack(alignment: .topLeading) {
            palette.windowBackground
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: SetupAssistantM.betaTitleSize, weight: .bold))
                    .foregroundStyle(palette.text)
                if let lede {
                    Text(lede)
                        .font(.system(size: SetupAssistantM.ledeSize))
                        .foregroundStyle(palette.textMuted)
                        // At most two lines.
                        .lineLimit(2)
                        .padding(.top, 6)
                }
            }
            .frame(width: SetupAssistantM.betaCardWidth, alignment: .leading)
            .offset(x: SetupAssistantM.betaMargin, y: SetupAssistantM.betaTitleY)

            card
                .frame(width: SetupAssistantM.betaCardWidth)
                .offset(x: SetupAssistantM.betaMargin, y: SetupAssistantM.betaCardTop)

            SetupAssistantFooter(
                surface: .beta,
                logoPath: logoPath,
                line: footerLine,
                primaryTitle: primaryTitle,
                primaryDisabled: primaryDisabled,
                onPrimary: onPrimary,
                secondaryTitle: secondaryTitle,
                onSecondary: onSecondary,
                backLabel: backLabel,
                onBack: onBack,
                accent: accent)
                // Bottom-aligned, not offset from `frameHeight`, since the window comes back taller.
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: SetupAssistantM.recommended.width, height: SetupAssistantM.hostHeight)
        .clipShape(RoundedRectangle(cornerRadius: SetupAssistantM.frameRadius, style: .continuous))
        .ignoresSafeArea()
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            media()
                .frame(width: SetupAssistantM.betaCardWidth, height: mediaHeight)
                .clipped()
            if !steps.isEmpty || specimenNote != nil || progress != .none {
                VStack(alignment: .leading, spacing: 10) {
                    cardProgress
                    if !steps.isEmpty {
                        // One row: the actions read as a sequence across.
                        HStack(alignment: .top, spacing: SetupAssistantM.betaStepGap) {
                            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                                HStack(alignment: .top, spacing: 8) {
                                    chip(index + 1)
                                    Text(step.text)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(palette.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    if let specimenNote {
                        Text(specimenNote)
                            .font(.system(size: SetupAssistantM.captionSize))
                            .foregroundStyle(palette.textFaint)
                    }
                }
                .padding(.top, SetupAssistantM.betaStripPadTop)
                .padding(.horizontal, SetupAssistantM.betaStripPadH)
                .padding(.bottom, SetupAssistantM.betaStripPadBottom)
                .frame(width: SetupAssistantM.betaCardWidth, alignment: .leading)
            }
        }
        .background(RoundedRectangle(cornerRadius: SetupAssistantM.betaCardRadius,
                                     style: .continuous)
            .fill(palette.surfaceRaised))
        .clipShape(RoundedRectangle(cornerRadius: SetupAssistantM.betaCardRadius,
                                    style: .continuous))
    }

    /// The numbered chip, in the accent.
    private func chip(_ n: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(accent)
            Text("\(n)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: SetupAssistantM.betaStepChip, height: SetupAssistantM.betaStepChip)
    }

    /// Phase, count and bar inside the card at its width. The fill is the accent, on the raised card.
    @ViewBuilder private var cardProgress: some View {
        if case .progress(let text, let count, let fraction) = progress {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                    if let count {
                        Spacer(minLength: 12)
                        Text(count)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                    }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: SetupAssistantM.barRadius)
                            .fill(palette.text.opacity(0.12))
                        RoundedRectangle(cornerRadius: SetupAssistantM.barRadius)
                            .fill(accent)
                            .frame(width: geo.size.width * min(max(fraction, 0), 1))
                    }
                }
                .frame(height: SetupAssistantM.barHeight)
            }
        }
    }
}
