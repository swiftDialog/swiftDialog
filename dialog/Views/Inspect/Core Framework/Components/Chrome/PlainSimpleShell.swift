//
//  PlainSimpleShell.swift
//  dialog
//
//  The `plain-simple` construction's frame: back chevron, body, footer. The shell hands the body
//  a full-bleed region; the body decides its own alignment.
//

import SwiftUI

/// Geometry for the plain-simple shell. Sizes only, never theme. Every figure is authored at
/// 800 × 600; what sits below the content box derives from the window and the footer band.
enum PlainSimpleM {

    // MARK: - The shared shell, identical on every screen

    /// The rail the card and the media box sit on.
    static let mediaRail: CGFloat = 120
    /// The hero and subtitle share the card's left edge.
    static let textRail: CGFloat = mediaRail
    /// Every band ends here.
    static let mirror: CGFloat = 680
    /// The card, the confirm card and the gate line; the movie uses `movieColumn`.
    static let mediaColumn: CGFloat = 560
    /// The header runs the card's full width, not the inset row width.
    static let textColumn: CGFloat = mirror - textRail
    /// The pager dots and the centred movie centre on it.
    static let windowAxis: CGFloat = 400

    /// Where the content box opens on the list, walkthrough and confirm screens. Pinned, never
    /// centred, so the box top holds still whatever the content height.
    static let contentBoxTop: CGFloat = 202
    /// The movie step carries no hero, so it opens 2 higher.
    static let contentBoxTopNoHero: CGFloat = 200

    /// The window this construction is authored at.
    static let designHeight: CGFloat = 600
    /// The kit's one footer band, on the window's bottom edge.
    static let footerHeight: CGFloat = FooterBandM.band
    /// Everything the body stacks from the top must end above this.
    static let footerBandTop: CGFloat = designHeight - footerHeight

    // MARK: - The header
    //
    // The hero pairs beside the title rather than stacking above it; the card gets the height.

    static let chevronTop: CGFloat = 24
    static let chevronRail: CGFloat = 24
    static let chevronSize: CGFloat = 32

    static let heroTop: CGFloat = 76
    static let heroSize: CGFloat = 48
    static let heroRadius: CGFloat = 12
    /// Centres the title optically on the hero.
    static let titleTop: CGFloat = 85
    /// The hero's trailing edge plus the gap.
    static let titleRail: CGFloat = textRail + heroSize + 16
    static let titleSize: CGFloat = 24
    /// One line, ellipsised: a wrapped subtitle would push the content box down.
    static let subtitleTop: CGFloat = 144
    static let subtitleSize: CGFloat = 16

    // MARK: - The install card (list screen)

    /// The line every row icon lands on is `mediaRail + cardInset`.
    static let cardInset: CGFloat = 28
    static let cardWidth: CGFloat = mediaColumn
    /// A ceiling, not a fixed height: the card hugs its rows below it. It lands on a row
    /// boundary (four rows plus the queued line) so the last row is never sliced.
    static let cardMaxHeight: CGFloat = 4 * cardRowHeight + queuedLineHeight
    /// Derived: whatever the band leaves below the card ceiling.
    static var tailGap: CGFloat { footerBandTop - contentBoxTop - cardMaxHeight }

    static let cardRowHeight: CGFloat = 56
    /// The raised live row. At most one row is active; that is a model invariant, and this
    /// treatment renders only where the data says `.active`.
    static let activeRowHeight: CGFloat = 64
    static let activeRowInset: CGFloat = 8
    static let activeRowMargin: CGFloat = 3
    static let rowIconSize: CGFloat = 32
    /// Icon to text.
    static let rowGutter: CGFloat = 20
    /// Text to status glyph.
    static let rowTrail: CGFloat = 22
    /// The "more items queued" line for a list the card cannot show whole.
    static let queuedLineHeight: CGFloat = 44

    /// Hug the content, stop at the ceiling.
    static func cardHeight(forRowCount count: Int, hasActiveRow: Bool = false, showsQueuedLine: Bool = false) -> CGFloat {
        guard count > 0 else { return cardRowHeight }
        let plain = CGFloat(hasActiveRow ? count - 1 : count) * cardRowHeight
        let active = hasActiveRow ? activeRowHeight + activeRowMargin * 2 : 0
        let queued = showsQueuedLine ? queuedLineHeight : 0
        return min(plain + active + queued, cardMaxHeight)
    }

    static let cardRadius: CGFloat = 10

    // MARK: - The movie step
    //
    // A step, not a page: no chevron, hero or pager. Only things that consume the user's time
    // become steps.

    /// Larger than the list's title because nothing is paired beside it.
    static let mediaTitleSize: CGFloat = 30
    static let mediaSubtitleTop: CGFloat = 128
    /// 16:9, and short enough that the strip and the pager both fit above the band. The chain
    /// below it (strip, pager, gate line) derives from this height.
    static let movieColumn: CGFloat = 400
    static let movieBoxHeight: CGFloat = 225
    /// The same number under the name the screens and tests read it by.
    static var mediaBoxHeight: CGFloat { movieBoxHeight }
    static let mediaBoxRadius: CGFloat = 12

    /// Every media box carries a poster, a play control and a duration chip, so a still image and
    /// a movie present identically.
    static let durationChipInset: CGFloat = 16
    static let durationChipHeight: CGFloat = 24
    static let durationChipBaseGap: CGFloat = 24

    /// The install strip under the movie: install never disappears while a tour plays.
    static var installStripTop: CGFloat { installStripTop(centred: false) }
    static let installStripHeight: CGFloat = 56
    static let installStripRadius: CGFloat = 12
    static let installStripPadding: CGFloat = 20
    static let installSpinnerSize: CGFloat = 20

    // MARK: - The centred movie step and walkthrough page
    //
    // Centred is the flow-wide default; `contentAlign: "leading"` opts into the leading rail.
    // One axis per flow, never per step, or the window appears to shift as the user advances.
    // The two variants differ by rail and text alignment alone.

    /// The movie centred on the window axis.
    static let centredMovieRail: CGFloat = 200

    /// The flow's axis from the root `contentAlign`: centred unless it says "leading".
    static func isCentred(authored: String?) -> Bool {
        authored?.lowercased() != "leading"
    }

    static func mediaRail(centred: Bool) -> CGFloat { centred ? centredMovieRail : mediaRail }
    static func mediaColumn(centred: Bool) -> CGFloat { movieColumn }
    static func mediaBoxHeight(centred: Bool) -> CGFloat { movieBoxHeight }

    /// The strip follows the movie by this gap in both variants; the box top never moves.
    static let installStripGap: CGFloat = 28
    static func installStripTop(centred: Bool) -> CGFloat {
        contentBoxTopNoHero + mediaBoxHeight(centred: centred) + installStripGap
    }

    /// The strip shares the movie's column so it never reads as the subject.
    static func installStripWidth(centred: Bool) -> CGFloat { mediaColumn(centred: centred) }

    // MARK: - The walkthrough and confirm page chrome
    //
    // A page is not a step. When an inner pager is on screen the outer step is words (the
    // eyebrow), never a second dot row.

    /// Right-aligned to the mirror.
    static let eyebrowTop: CGFloat = 30
    static let eyebrowSize: CGFloat = 12

    /// Same top as the walkthrough's movie, the card's width.
    static let confirmCardHeight: CGFloat = 116.5
    /// The horizontal padding is its own, not the row inset: this card has no rows to line up with.
    static let confirmCardPaddingV: CGFloat = 22
    static let confirmCardPaddingH: CGFloat = 26
    static let confirmTileSize: CGFloat = 44
    static let confirmTileRadius: CGFloat = 11
    /// Tile to text.
    static let confirmTileGap: CGFloat = 20

    /// The pager is pinned: arrows at fixed x whatever the page count, dots centred between
    /// them, so the arrows never slide between a two-dot and a four-dot page.
    static var pagerTop: CGFloat { contentBoxTop + movieBoxHeight + installStripGap }
    static let pagerArrowSize: CGFloat = 34
    static let pagerArrowLeadingX: CGFloat = 318
    static let pagerArrowTrailingX: CGFloat = 448
    static let pagerDotSize: CGFloat = 7
    static let pagerDotPitch: CGFloat = 16
    /// The gate explanation sits under the pager, where the gate is, not beside the disabled pill.
    static var gateLineTop: CGFloat { pagerTop + 43 }

    // MARK: - Footer furniture

    static let wordmarkHeight: CGFloat = 24
    /// Logo trailing edge to the step dots.
    static let footerDotsGap: CGFloat = 21
}

struct PlainSimpleShell<Content: View>: View {
    var showsBack: Bool = false
    /// The authored, localized back label for VoiceOver. nil falls back to "Back".
    var backLabel: String?
    var onBack: (() -> Void)?
    let buttonTitle: String
    /// A disabled primary stays visible and greyed, one look across presets.
    var buttonDisabled: Bool = false
    let onPrimaryAction: () -> Void
    /// The flow's resolved brand colour. Required so a call site cannot fall silently back to
    /// the system accent.
    let accent: Color
    /// Resolved by the caller; nil draws no mark rather than a placeholder.
    var wordmarkPath: String?
    /// `logoConfig.maxHeight`, falling back to this construction's constant when unauthored.
    var logoHeight: CGFloat = PlainSimpleM.wordmarkHeight
    /// `logoConfig.maxWidth`: marks size by their trimmed content, so this is the only knob that
    /// bounds a wide wordmark. nil is height-only sizing.
    var logoMaxWidth: CGFloat?

    /// `logoConfig.logoClearSpace`, handed to `BrandMark`.
    var logoClearSpace: CGFloat = 0
    /// The secondary action as plain text beside the pill: skip as text, continue as pill, never
    /// two pills. nil draws nothing.
    var secondaryTitle: String?
    var onSecondaryAction: (() -> Void)?
    /// Already-formatted step label, or nil to omit. The words and `stepDots` derive from one
    /// `(current, total)` pair so they cannot disagree.
    var stepIndicatorText: String?
    /// Feeds `StepDotIndicator`. nil withholds the whole cluster.
    var stepDots: (current: Int, total: Int)?
    /// The band's top hairline. A shell-level switch, not an authored key.
    var showsFooterRule: Bool = true
    @ViewBuilder let content: () -> Content

    @Environment(\.palette) private var palette

    /// Absolute bands, not a `VStack`: the body is handed the whole window so content height can
    /// never move a line the design fixes. The footer is anchored to the window's bottom edge
    /// rather than a y, so it holds in a taller window.
    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsBack, let onBack {
                backChevron(onBack)
                    .offset(x: PlainSimpleM.chevronRail, y: PlainSimpleM.chevronTop)
            }
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) { footerBand }
    }

    /// The only step-level back. A pager's own left arrow turns a page and is never drawn as a
    /// second chevron.
    private func backChevron(_ onBack: @escaping () -> Void) -> some View {
        Door.back(plate: palette.surfaceRaised, ink: palette.text,
                  label: backLabel ?? "Back", action: onBack)
            .accessibilityLabel(backLabel ?? "Back")
    }

    /// `FooterRow`'s three slots: wordmark, step indicator, then secondary and primary. The
    /// footer takes the band's rail, not the body's.
    private var footerBand: some View {
        FooterRow(rail: FooterBandM.rail, rule: showsFooterRule ? .over : .none) {
            if let wordmarkPath {
                BrandMark(path: wordmarkPath, box: BrandMarkBox(height: logoHeight, maxWidth: logoMaxWidth),
                          clearSpace: logoClearSpace)
            }
        } leading: {
            // Both halves are withheld together on a one-phase flow, and on a paged screen,
            // where the outer step moves to `PlainSimpleEyebrow`.
            if let stepDots {
                HStack(spacing: 0) {
                    // The gap is the constant: a wider authored mark moves the dots.
                    Spacer().frame(width: PlainSimpleM.footerDotsGap)
                    StepDotIndicator(current: stepDots.current, total: stepDots.total, accentColor: accent)
                    if let stepIndicatorText {
                        Text(stepIndicatorText)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textMuted)
                            .lineLimit(1)
                            .padding(.leading, 10)
                    }
                }
            }
        } trailing: {
            HStack(spacing: 0) {
                if let secondaryTitle, let onSecondaryAction {
                    Button(action: onSecondaryAction) {
                        Text(secondaryTitle)
                            .font(.system(size: 13))
                            .foregroundStyle(palette.textMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 18)
                }
                PrimaryActionButton(tint: accent, action: onPrimaryAction) {
                    Text(buttonTitle)
                }
                .disabled(buttonDisabled)
            }
        }
    }
}
