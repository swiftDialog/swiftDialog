//
//  PlainSimpleWalkthroughScreen.swift
//  dialog
//
//  The plain-simple media walkthrough page: an inner pager walks the pages of one task, the outer step
//  sits in the eyebrow, and Continue stays disabled until the last page. The instruction is one line so
//  a 16:9 movie (400 × 225, the movie step's frame) and the pager fit.

import SwiftUI

struct PlainSimpleWalkthroughScreen: View {
    /// The outer step, in words, on the mirror.
    var eyebrow: String?
    let title: String
    /// One line, ellipsised beyond it.
    var instruction: String = ""
    var mediaPath: String?
    var durationLabel: String?
    /// 1-based. The pager's arrows do not move with it.
    let current: Int
    let total: Int
    /// Shown under the pager while the gate is closed, so the disabled button is explained.
    var gateText: String?
    /// Centred variant. Every anchor matches the leading variant; only the media rail and text
    /// alignment change, so the variants swap without the window appearing to move.
    var centred: Bool = false
    let accent: Color
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var heroSymbol: String = "questionmark.circle"

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let eyebrow, !eyebrow.isEmpty {
                PlainSimpleEyebrow(text: eyebrow)
            }

            // Centred hero and title at the leading variant's y, sharing the movie's axis.
            if centred {
                HStack(spacing: 16) {
                    heroTile
                    Text(title)
                        .font(.system(size: PlainSimpleM.titleSize, weight: .bold))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                }
                .frame(width: PlainSimpleM.mediaColumn, alignment: .center)
                .offset(x: PlainSimpleM.mediaRail, y: PlainSimpleM.heroTop)
            } else {
                heroTile
                    .offset(x: PlainSimpleM.textRail, y: PlainSimpleM.heroTop)

                Text(title)
                    .font(.system(size: PlainSimpleM.titleSize, weight: .bold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                    .frame(width: PlainSimpleM.mirror - PlainSimpleM.titleRail, alignment: .leading)
                    .offset(x: PlainSimpleM.titleRail, y: PlainSimpleM.titleTop)
            }

            if !instruction.isEmpty {
                Text(instruction)
                    .font(.system(size: PlainSimpleM.subtitleSize))
                    .foregroundStyle(palette.textMuted)
                    // One line in both variants; a wrapped centred paragraph would be ragged on both sides.
                    .lineLimit(1)
                    .multilineTextAlignment(centred ? .center : .leading)
                    .frame(width: centred ? PlainSimpleM.mediaColumn : PlainSimpleM.textColumn,
                           alignment: centred ? .center : .leading)
                    .offset(x: centred ? PlainSimpleM.mediaRail : PlainSimpleM.textRail,
                            y: PlainSimpleM.subtitleTop)
            }

            mediaBox
                .offset(x: PlainSimpleM.mediaRail(centred: centred),
                        y: PlainSimpleM.contentBoxTop)

            PlainSimplePager(current: current, total: total, accent: accent,
                             onBack: onBack, onForward: onForward)

            if let gateText, !gateText.isEmpty, current < total {
                PlainSimpleGateLine(text: gateText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var heroTile: some View {
        RoundedRectangle(cornerRadius: PlainSimpleM.heroRadius, style: .continuous)
            .fill(accent.opacity(0.12))
            .frame(width: PlainSimpleM.heroSize, height: PlainSimpleM.heroSize)
            .overlay(
                Image(systemName: heroSymbol)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(accent)
            )
    }

    /// The movie step's 400 × 225 box at 202 rather than 200 (this page has a hero), with poster and duration.
    private var mediaBox: some View {
        PlainSimpleMediaBox(mediaPath: mediaPath, durationLabel: durationLabel,
                            width: PlainSimpleM.mediaColumn(centred: centred),
                            height: PlainSimpleM.mediaBoxHeight(centred: centred))
    }
}
