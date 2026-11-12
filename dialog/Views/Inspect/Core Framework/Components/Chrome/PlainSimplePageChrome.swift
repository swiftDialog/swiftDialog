//
//  PlainSimplePageChrome.swift
//  dialog
//
//  Chrome the walkthrough and confirm screens share around their content box: the outer step as
//  an eyebrow in words (never two dot rows on one screen), the inner pager with pinned arrows,
//  the gate line and the media box.
//

import SwiftUI

/// Past this many pages the dots stop being countable and the pager reads "n of N" instead.
private let maxCountableDots = 5

/// "Step 2 of 4 · E-mail encryption", right-aligned to the media column.
struct PlainSimpleEyebrow: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: PlainSimpleM.eyebrowSize, weight: .semibold))
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
        }
        .frame(width: PlainSimpleM.mediaColumn, alignment: .trailing)
        .offset(x: PlainSimpleM.mediaRail, y: PlainSimpleM.eyebrowTop)
    }
}

/// The inner pager: two arrows pinned regardless of page count, with a dot row centred between
/// them. `current` is 1-based; the leading arrow is absent on page one so it does not read as a
/// second Back beside the shell's chevron.
struct PlainSimplePager: View {
    let current: Int
    let total: Int
    let accent: Color
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?

    @Environment(\.palette) private var palette

    private var showsDots: Bool { total <= maxCountableDots }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if current > 1, let onBack {
                arrow("chevron.left", action: onBack)
                    .offset(x: PlainSimpleM.pagerArrowLeadingX, y: PlainSimpleM.pagerTop)
            }

            Group {
                if showsDots {
                    HStack(spacing: PlainSimpleM.pagerDotPitch - PlainSimpleM.pagerDotSize) {
                        ForEach(0..<max(total, 1), id: \.self) { index in
                            Circle()
                                .fill(index + 1 == current ? accent : palette.text.opacity(0.22))
                                .frame(width: PlainSimpleM.pagerDotSize, height: PlainSimpleM.pagerDotSize)
                        }
                    }
                } else {
                    Text("\(current) of \(total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textMuted)
                }
            }
            // Fixed width between the arrows, so the dot count never pushes them.
            .frame(width: PlainSimpleM.pagerArrowTrailingX - (PlainSimpleM.pagerArrowLeadingX + PlainSimpleM.pagerArrowSize))
            .frame(height: PlainSimpleM.pagerArrowSize)
            .offset(x: PlainSimpleM.pagerArrowLeadingX + PlainSimpleM.pagerArrowSize,
                    y: PlainSimpleM.pagerTop)

            if current < total, let onForward {
                arrow("chevron.right", action: onForward)
                    .offset(x: PlainSimpleM.pagerArrowTrailingX, y: PlainSimpleM.pagerTop)
            }
        }
    }

    private func arrow(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.text)
                .frame(width: PlainSimpleM.pagerArrowSize, height: PlainSimpleM.pagerArrowSize)
                .background(Circle().fill(palette.surfaceRaised))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "chevron.left" ? "Previous page" : "Next page")
    }
}

/// "Finish all 4 pages to continue", centred beneath the pager: a disabled Continue must say why.
struct PlainSimpleGateLine: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(palette.textMuted)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(width: PlainSimpleM.mediaColumn)
        .offset(x: PlainSimpleM.mediaRail, y: PlainSimpleM.gateLineTop)
    }
}


/// Which outer step a phase is, for the footer stepper and the confirm screen's eyebrow. Pure so
/// a wrong total on the wrong screen is testable without a capture.
enum PlainStepPosition {
    /// In flow order. Only screens that consume the user's time are steps.
    enum Phase { case intro, main, tour, summary }

    /// nil withholds the indicator: a stepper that always reads "step 1 of 1" is furniture.
    static func position(phase: Phase,
                         hasIntro: Bool,
                         hasTour: Bool = false,
                         hasSummary: Bool) -> (current: Int, total: Int)? {
        let total = 1 + (hasIntro ? 1 : 0) + (hasTour ? 1 : 0) + (hasSummary ? 1 : 0)
        guard total >= 2 else { return nil }
        let mainStep = hasIntro ? 2 : 1
        switch phase {
        case .intro:   return (current: 1, total: total)
        case .main:    return (current: mainStep, total: total)
        case .tour:    return (current: mainStep + 1, total: total)
        case .summary: return (current: total, total: total)
        }
    }
}


/// The one media box the movie step and the walkthrough pages share, so width and left edge never
/// drift between pages; height is the one dimension allowed to vary.
struct PlainSimpleMediaBox: View {
    var mediaPath: String?
    /// Chip over the lower-left, typically a running time. nil draws no chip.
    var durationLabel: String?
    var width: CGFloat = PlainSimpleM.mediaColumn
    var height: CGFloat = PlainSimpleM.mediaBoxHeight

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: PlainSimpleM.mediaBoxRadius, style: .continuous)
                .fill(palette.surfaceRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: PlainSimpleM.mediaBoxRadius, style: .continuous)
                        .strokeBorder(palette.text.opacity(0.08), lineWidth: 1)
                )

            if let mediaPath, !mediaPath.isEmpty {
                // `.fit`, never `.fill`: a recording of any aspect must keep its edges, and the
                // animated renderer keeps a GIF playing.
                IntroAnimatedImageView(url: URL(fileURLWithPath: (mediaPath as NSString).expandingTildeInPath),
                                       maxWidth: Double(width),
                                       maxHeight: Double(height),
                                       fit: .fit)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: PlainSimpleM.mediaBoxRadius, style: .continuous))
            } else {
                // Never a black rectangle: an empty page still gets the box and an affordance.
                Image(systemName: "play.rectangle")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(palette.textMuted.opacity(0.5))
                    .frame(width: width, height: height)
            }

            if let durationLabel, !durationLabel.isEmpty {
                Text(durationLabel)
                    .font(.system(size: 12, weight: .medium))
                    // Fixed ink on a fixed scrim: the chip's ground is the movie, which does not
                    // adapt to the appearance, so neither may the chip.
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: PlainSimpleM.durationChipHeight)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(.leading, PlainSimpleM.durationChipInset)
                    .padding(.bottom, PlainSimpleM.durationChipBaseGap)
            }
        }
        .frame(width: width, height: height)
    }
}
