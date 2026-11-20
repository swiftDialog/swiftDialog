//
//  PlainSimpleMediaScreen.swift
//  dialog
//
//  The plain-simple movie step: a 16:9 movie (400 × 225) with an install strip below it, so the
//  install stays visible while the movie plays. A step, not a page: no chevron, hero or pager.

import SwiftUI

struct PlainSimpleMediaScreen: View {
    let title: String
    /// Two lines here (one on the list and confirm screens), since this screen has no hero.
    var subtitle: String = ""
    /// Image or video. nil draws the empty box rather than collapsing the layout.
    var mediaPath: String?
    /// Label in the chip over the movie's lower-left, e.g. a running time; nil draws no chip.
    var durationLabel: String?
    /// The item running now and the queue count, both from the live item model.
    var runningItemText: String?
    var progressText: String?
    /// Centres the media on the window axis, and the title and subtitle with it.
    var centred: Bool = false
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(title)
                .font(.system(size: PlainSimpleM.mediaTitleSize, weight: .bold))
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .multilineTextAlignment(centred ? .center : .leading)
                // Same 560 measure as the leading variant's text column, so both share one text block.
                .frame(width: centred ? PlainSimpleM.mediaColumn : PlainSimpleM.textColumn,
                       alignment: centred ? .center : .leading)
                .offset(x: centred ? PlainSimpleM.mediaRail : PlainSimpleM.textRail,
                        y: PlainSimpleM.heroTop)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: PlainSimpleM.subtitleSize))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(centred ? .center : .leading)
                    .frame(width: centred ? PlainSimpleM.mediaColumn : PlainSimpleM.textColumn,
                           alignment: centred ? .center : .leading)
                    .offset(x: centred ? PlainSimpleM.mediaRail : PlainSimpleM.textRail,
                            y: PlainSimpleM.mediaSubtitleTop)
            }

            mediaBox
                .offset(x: PlainSimpleM.mediaRail(centred: centred),
                        y: PlainSimpleM.contentBoxTopNoHero)

            installStrip
                .offset(x: PlainSimpleM.mediaRail(centred: centred),
                        y: PlainSimpleM.installStripTop(centred: centred))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Movie

    /// 400 × 225, on the list's card rail (or the centred 200 rail), same frame as the walkthrough's.
    private var mediaBox: some View {
        PlainSimpleMediaBox(mediaPath: mediaPath, durationLabel: durationLabel,
                            width: PlainSimpleM.mediaColumn(centred: centred),
                            height: PlainSimpleM.mediaBoxHeight(centred: centred))
    }

    // MARK: - Install strip

    /// The movie's width × 56: spinner, running item and count. Drawn only when something is running.
    @ViewBuilder
    private var installStrip: some View {
        if runningItemText != nil || progressText != nil {
            HStack(spacing: 0) {
                // The spinner shows only beside a named running item; otherwise the count stands alone.
                if let runningItemText {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: PlainSimpleM.installSpinnerSize, height: PlainSimpleM.installSpinnerSize)
                    Text(runningItemText)
                        .font(.system(size: 14))
                        .foregroundStyle(palette.text)
                        .lineLimit(1)
                        .padding(.leading, 12)
                }

                Spacer(minLength: 12)

                if let progressText {
                    Text(progressText)
                        .font(.system(size: 13))
                        .foregroundStyle(palette.textMuted)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, PlainSimpleM.installStripPadding)
            .frame(width: PlainSimpleM.installStripWidth(centred: centred), height: PlainSimpleM.installStripHeight)
            .background(
                RoundedRectangle(cornerRadius: PlainSimpleM.installStripRadius, style: .continuous)
                    .fill(palette.surfaceRaised)
            )
        }
    }
}
