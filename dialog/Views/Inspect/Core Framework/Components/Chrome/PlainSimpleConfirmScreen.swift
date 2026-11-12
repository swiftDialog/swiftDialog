//
//  PlainSimpleConfirmScreen.swift
//  dialog
//
//  The plain-simple confirmation screen: the walkthrough page's layout with a grey card in place of
//  the media box, so the window never appears to resize between them. A pager draws only for paged steps.

import SwiftUI

struct PlainSimpleConfirmScreen: View {
    /// Right-aligned to the mirror. nil draws nothing rather than an empty band.
    var eyebrow: String?
    let title: String
    /// The one-line instruction above the box, capped to one line as on the walkthrough page.
    var instruction: String = ""
    /// The card's own two lines: what happened, and what it means.
    let confirmationTitle: String
    var confirmationDetail: String = ""
    let accent: Color
    /// Drawn only when the step has pages.
    var pager: (current: Int, total: Int)?

    @Environment(\.palette) private var palette

    /// The hero SF Symbol in a tinted tile.
    var heroSymbol: String = "checkmark.seal"

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let eyebrow, !eyebrow.isEmpty {
                PlainSimpleEyebrow(text: eyebrow)
            }

            heroTile
                .offset(x: PlainSimpleM.textRail, y: PlainSimpleM.heroTop)

            Text(title)
                .font(.system(size: PlainSimpleM.titleSize, weight: .bold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .frame(width: PlainSimpleM.mirror - PlainSimpleM.titleRail, alignment: .leading)
                .offset(x: PlainSimpleM.titleRail, y: PlainSimpleM.titleTop)

            if !instruction.isEmpty {
                Text(instruction)
                    .font(.system(size: PlainSimpleM.subtitleSize))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
                    .frame(width: PlainSimpleM.textColumn, alignment: .leading)
                    .offset(x: PlainSimpleM.textRail, y: PlainSimpleM.subtitleTop)
            }

            confirmCard
                .offset(x: PlainSimpleM.mediaRail, y: PlainSimpleM.contentBoxTop)

            if let pager {
                PlainSimplePager(current: pager.current, total: pager.total, accent: accent)
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

    /// 560 × 116.5 on the media rail, opening where the walkthrough's movie box does.
    /// Horizontal padding is 26: there are no rows to align with the list card's 28 inset.
    private var confirmCard: some View {
        HStack(alignment: .top, spacing: PlainSimpleM.confirmTileGap) {
            RoundedRectangle(cornerRadius: PlainSimpleM.confirmTileRadius, style: .continuous)
                .fill(palette.success.opacity(0.15))
                .frame(width: PlainSimpleM.confirmTileSize, height: PlainSimpleM.confirmTileSize)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(palette.success)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(confirmationTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                if !confirmationDetail.isEmpty {
                    Text(confirmationDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, PlainSimpleM.confirmCardPaddingV)
        .padding(.horizontal, PlainSimpleM.confirmCardPaddingH)
        .frame(width: PlainSimpleM.mediaColumn, height: PlainSimpleM.confirmCardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: PlainSimpleM.cardRadius, style: .continuous)
                .fill(palette.surfaceRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: PlainSimpleM.cardRadius, style: .continuous)
                .strokeBorder(palette.text.opacity(0.08), lineWidth: 1)
        )
    }
}
