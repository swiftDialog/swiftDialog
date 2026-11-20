//
//  CardStepRows.swift
//  dialog
//
//  Left-column rows (promise, numbered, substep, warning) and the right-hand panels (stat text, panel, media section).
//

import SwiftUI

// MARK: - Left-column rows

struct CardPromiseRow: View {
    @Environment(\.palette) private var palette
    let text: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(.white, accent)
                .frame(width: InspectMetrics.unit.cardGlyphBox, height: InspectMetrics.unit.cardGlyphBox)
                .padding(.top, InspectMetrics.unit.cardGlyphNudge)   // optical baseline vs 14.5pt text
            Text(guidanceAttributedMarkdown(text))
                .font(.system(size: 14.5))
                .foregroundStyle(palette.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct CardNumberedRow: View {
    @Environment(\.palette) private var palette
    let index: Int
    let text: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                Circle().fill(accent.opacity(0.12))
                Text("\(index)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .frame(width: 21, height: 21)
            Text(guidanceAttributedMarkdown(text))                       // inline **bold** stays inline
                .font(.system(size: 14.5))
                .foregroundStyle(palette.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum CardSubstepState { case done, active, pending, failed }

struct CardSubstepRow: View {
    @Environment(\.palette) private var palette
    let state: CardSubstepState
    let label: String
    let accent: Color

    var body: some View {
        // A fixed glyph box keeps the label edge from shifting as states advance.
        HStack(alignment: .center, spacing: 11) {
            glyph.frame(width: InspectMetrics.unit.cardGlyphBox, height: InspectMetrics.unit.cardGlyphBox)
            Text(label)
                .font(.system(size: 14.5, weight: state == .active ? .medium : .regular))
                .foregroundStyle(labelColor)
        }
    }

    @ViewBuilder private var glyph: some View {
        switch state {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 17)).foregroundStyle(.white, accent)
        case .active:
            ProgressView().controlSize(.small).tint(accent)
        case .pending:
            Circle().strokeBorder(palette.text.opacity(0.153), lineWidth: 1.5)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 17)).foregroundStyle(.white, palette.warning)
        }
    }

    private var labelColor: Color {
        switch state {
        case .active: return palette.text.opacity(0.9)
        case .pending: return palette.text.opacity(0.32)
        case .done, .failed: return palette.text.opacity(0.55)
        }
    }
}

struct CardWarningBox: View {
    @Environment(\.palette) private var palette

    let text: String

    private var warnInk: Color { palette.warningInk }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(warnInk)
            Text(guidanceAttributedMarkdown(text))
                .font(.system(size: 13))
                .foregroundStyle(warnInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.warningBackground)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(warnInk.opacity(0.25), lineWidth: 0.5))
        )
    }
}

// MARK: - Right panels (shape inferred from which CardPanel fields are set)

/// The panel-stat figure, shared by the bookend stat strip and the card panel.
struct CardStatText: View {
    @Environment(\.palette) private var palette
    let value: String

    var body: some View {
        Text(value)
            .font(.system(size: 27, weight: .bold))
            .tracking(-0.54)
            .foregroundStyle(palette.text.opacity(0.9))
    }
}

struct CardPanelView: View {
    @Environment(\.palette) private var palette
    let panel: InspectConfig.CardPanel
    var accent: Color = .accentColor       // key color — media border, future accents

    var body: some View {
        if panel.video != nil {
            mediaPanel          // clean media section — no browser-chrome strip
        } else if panel.imageTitle != nil {
            // The window frame is for titled UI screenshots; a bare image is media.
            screenshotPanel
        } else if panel.image != nil {
            mediaPanel          // bare still image — clean media section
        } else if let paragraphs = panel.paragraphs, !paragraphs.isEmpty {
            reassurancePanel(paragraphs)
        } else {
            factsPanel
        }
    }

    /// A plain rounded section that loads the clip; see `CardMediaSection`.
    private var mediaPanel: some View {
        CardMediaSection(panel: panel, accent: accent)
    }

    private var factsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            if panel.caption != nil || panel.stat != nil {
                VStack(alignment: .leading, spacing: 4) {
                    caption
                    if let stat = panel.stat {
                        CardStatText(value: stat)
                    }
                }
            }
            if let pairs = panel.pairs, !pairs.isEmpty {
                panelDivider
                ForEach(pairs.indices, id: \.self) { i in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pairs[i].label)
                            .font(.system(size: 12.5))
                            .foregroundStyle(palette.text.opacity(0.5))
                        Text(pairs[i].value)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.text.opacity(0.9))
                    }
                }
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.text.opacity(0.035)))
    }

    private func reassurancePanel(_ paragraphs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            caption
            ForEach(paragraphs.indices, id: \.self) { i in
                if i > 0 { panelDivider }
                Text(guidanceAttributedMarkdown(paragraphs[i]))
                    .font(.system(size: i == 0 ? 14 : 13.5))
                    .foregroundStyle(i == 0 ? palette.text.opacity(0.85) : palette.text.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.text.opacity(0.035)))
    }

    private var screenshotPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(palette.text.opacity(0.18)).frame(width: 7, height: 7)
                }
                if let title = panel.imageTitle {
                    Text(title)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(palette.text.opacity(0.5))
                        .padding(.leading, 6)
                }
                Spacer()
            }
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(palette.surfaceRaised)

            Group {
                if let path = panel.image,
                   let nsImage = InspectImageCache.shared.image(atPath: path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    // Diagonal-stripe placeholder, never a fake screenshot.
                    CardStripePlaceholder()
                }
            }
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
    }

    @ViewBuilder private var caption: some View {
        if let caption = panel.caption {
            Text(caption.uppercased())
                .font(.system(size: 11.5, weight: .medium))
                .kerning(0.55)
                .foregroundStyle(palette.text.opacity(0.5))
        }
    }

    private var panelDivider: some View {
        Rectangle().fill(palette.text.opacity(0.09))
            .frame(height: 0.5).frame(maxWidth: .infinity)
    }
}

/// A plain rounded section for a clip (video or animated GIF) at its natural aspect, with a border that
/// hugs the media. `maxHeight` hands it exactly the room a fixed-height layout has left.
struct CardMediaSection: View {
    let panel: InspectConfig.CardPanel
    let accent: Color
    var maxHeight: CGFloat = 220
    /// Media never exceeds its column, or the fixed-width window layout shifts.
    var maxWidth: CGFloat = 344            // card panel column at the 820pt card

    var body: some View {
        Group {
            if let clip = panel.video, FileManager.default.fileExists(atPath: clip) {
                if clip.lowercased().hasSuffix(".gif") {
                    AsyncImageView(
                        iconPath: clip,
                        basePath: nil,
                        maxWidth: maxWidth,
                        maxHeight: maxHeight,
                        imageFit: .fit,
                        fallback: { CardStripePlaceholder().frame(height: min(170, maxHeight)) }
                    )
                } else {
                    AspectFitVideoView(videoPath: clip, autoPlay: true, caption: "",
                                       maxHeight: maxHeight, loop: true)
                }
            } else if let still = panel.image, FileManager.default.fileExists(atPath: still) {
                AsyncImageView(
                    iconPath: still,
                    basePath: nil,
                    maxWidth: maxWidth,
                    maxHeight: maxHeight,
                    imageFit: .fit,
                    fallback: { CardStripePlaceholder().frame(height: min(170, maxHeight)) }
                )
            } else {
                CardStripePlaceholder().frame(height: min(170, maxHeight))
            }
        }
        // Clip, border and shadow hug the media bounds.
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(accent.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        .frame(maxWidth: maxWidth, alignment: .leading)
    }
}
