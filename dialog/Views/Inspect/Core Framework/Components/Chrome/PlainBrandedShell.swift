//
//  PlainBrandedShell.swift
//  dialog
//
//  The `plain-branded` construction's frame, beside `plain-simple` and `plain-centered`. Whether
//  it draws a footer band is derived, not authored: any footer content (mark, step indicator,
//  claim) makes the band; none leaves the action pill floating over the void. Palette tokens only.
//

import SwiftUI

/// Geometry for the `plain-branded` shell and its screen. Sizes only, never theme. Measured from
/// the reference; the card is the one figure that grows (`cardHeight(forRowCount:)`).
enum PlainBrandedM {

    // MARK: - Window

    static let window = CGSize(width: 800, height: 600)

    // MARK: - Column: one left edge for every element

    /// 500 = 800 − 150 − 150, the same measure as `plain-centered`'s card. Every element inside
    /// starts on one left edge; the screen centres its own column, the shell hands it full bleed.
    static let columnWidth: CGFloat = 500
    static let columnMargin: CGFloat = 150

    // MARK: - Header pair: title and subtitle as one object

    /// To the first cap, with one card row.
    static let topOffset: CGFloat = 66
    /// To the first cap when the card would not fit under `topOffset`.
    static let tightTopOffset: CGFloat = 36
    /// `topOffset` while the whole card fits under it, `tightTopOffset` once it would not.
    static func topOffset(forRowCount rowCount: Int) -> CGFloat {
        let viewport = window.height - footerHeight
        let fits = topOffset + headerHeight + groupGap + cardHeight(forRowCount: rowCount) <= viewport
        return fits ? topOffset : tightTopOffset
    }
    /// Title plus subtitle, as a supporting measurement for the fit arithmetic; not enforced as a
    /// frame, so a long subtitle wraps instead of clipping.
    static let headerHeight: CGFloat = 80
    static let titleFontSize: CGFloat = 15
    static let subtitleFontSize: CGFloat = 14
    // Title and subtitle are one object: zero gap, hierarchy by weight and colour.

    // MARK: - Group gap

    /// The only vertical space between the composition's groups (header · card · payload).
    static let groupGap: CGFloat = 40

    /// The gap between guidance blocks inside the payload: half the group gap, so items within a
    /// group sit closer than the groups do.
    static let payloadBlockGap: CGFloat = groupGap / 2

    // MARK: - Card: hugs one row, grows with more

    static let cardRadius: CGFloat = 12
    static let cardPaddingVertical: CGFloat = 20
    static let cardPaddingHorizontal: CGFloat = 22
    static let cardIconSize: CGFloat = 22
    /// Icon-to-text gutter; also the gap between rows of a multi-item card.
    static let cardGutter: CGFloat = 14
    /// One row's content zone: the 72 hug minus 20 of padding top and bottom.
    static let cardRowContentHeight: CGFloat = 32
    /// The measured one-row card, 72; `cardHeight(forRowCount:)` reproduces it for one row.
    static let cardSingleRowHeight: CGFloat = cardPaddingVertical * 2 + cardRowContentHeight
    static let cardTitleFontSize: CGFloat = 13
    static let cardDetailFontSize: CGFloat = 12
    /// The trailing status mark's layout box (not a clip); its width is what the row's name
    /// truncation budget is measured against.
    static let cardMarkSize: CGFloat = cardGutter

    /// The height the card needs, uncapped: the one-row hug for one row, linear from there. The
    /// whole column scrolls, never the card. `rowCount` is clamped to at least 1 so an empty item
    /// set still draws the empty state at the one-row hug.
    static func cardHeight(forRowCount rowCount: Int) -> CGFloat {
        let n = max(rowCount, 1)
        return cardPaddingVertical * 2
            + CGFloat(n) * cardRowContentHeight
            + CGFloat(max(n - 1, 0)) * cardGutter
    }

    // The whole column scrolls as one surface; the card never scrolls inside it.

    // MARK: - Action pill: window-anchored, not column-anchored

    static let pillHeight: CGFloat = 28
    static let pillRadius: CGFloat = 14
    /// The band's rail and air, so the pill lands where every other primary does.
    static let pillTrailing: CGFloat = FooterBandM.rail
    static let pillBottom: CGFloat = (FooterBandM.band - FooterBandM.primaryHeight) / 2
    static let pillHorizontalPadding: CGFloat = 20

    // MARK: - Footer band, when footer content is authored

    /// The kit's one band height, shared with every construction.
    static let footerHeight: CGFloat = FooterBandM.band
    /// The hairline between the mark and what follows it; matches `StepCounter`'s divider.
    static let footerDividerHeight: CGFloat = 16

    // MARK: - Bottom-left seat: brand mark + step indicator, both optional

    /// The seat is window furniture, not column content: it mirrors the pill's rail rather than
    /// the column's margin, so the pair reads as placed together.
    static let bottomSeatLeading: CGFloat = pillTrailing
    /// Fallback when `logoConfig.maxHeight` is not authored; pairs with the 28pt pill.
    static let logoHeight: CGFloat = 24
    /// The gap between items in the footer cluster (mark · divider · step · claim).
    static let bottomSeatGap: CGFloat = 12
    static let stepIndicatorFontSize: CGFloat = 12
}

/// The `plain-branded` construction's frame. With footer content, a closing band; with none, the
/// pill floats over the void.
struct PlainBrandedShell<Content: View>: View {
    let buttonTitle: String
    /// A disabled primary stays visible and dimmed, as on the sibling shells.
    var buttonDisabled: Bool = false
    let onPrimaryAction: () -> Void
    /// The flow's resolved accent; tints the card icons and fills the action pill.
    let accent: Color
    /// Already resolved by the caller (nil draws nothing), never `imagePath` directly. Authoring
    /// a mark is what makes the footer band exist.
    var logoPath: String?
    /// `logoConfig.maxHeight` when authored, else `PlainBrandedM.logoHeight`.
    var logoHeight: CGFloat = PlainBrandedM.logoHeight
    /// `logoConfig.maxWidth` when authored; nil sizes the mark by height only.
    var logoMaxWidth: CGFloat?

    /// `logoConfig.logoClearSpace`, handed to `BrandMark`.
    var logoClearSpace: CGFloat = 0
    /// Already formatted, or nil to omit. The caller derives this and `stepDots` from one
    /// `(current, total)` pair so they cannot disagree.
    var stepIndicatorText: String?
    /// The raw step position for `StepDotIndicator`; nil draws no dots.
    var stepDots: (current: Int, total: Int)?
    /// The brand claim; nil shows nothing, there is no injected default.
    var claimText: String?
    @ViewBuilder let content: () -> Content

    @Environment(\.palette) private var palette

    /// True once any footer-cluster value is authored; never a config key of its own.
    private var hasFooterContent: Bool {
        logoPath != nil || stepIndicatorText != nil || stepDots != nil || claimText != nil
    }

    var body: some View {
        if hasFooterContent {
            // The band gets its own row, so a scrolling column can never extend behind it.
            VStack(spacing: 0) {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                footerBand
            }
        } else {
            // No band: the pill floats at the window margins; the content's scroll-edge fade is
            // what keeps a scrolled row from sliding under it sharply.
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .bottomTrailing) { floatingActionPill }
        }
    }

    /// The closing band on `FooterRow`: the whole leading cluster in the brand slot, the pill
    /// trailing, no top rule (the composition has no other hard edge, and the scroll fade already
    /// marks where content ends).
    private var footerBand: some View {
        FooterRow(rail: PlainBrandedM.bottomSeatLeading, rule: .none) {
            footerLeadingCluster
        } leading: {
            EmptyView()
        } trailing: {
            actionPillCapsule
        }
    }

    /// Mark · divider · step dots + counter · claim. The divider draws only between a mark and
    /// something after it.
    private var footerLeadingCluster: some View {
        HStack(spacing: PlainBrandedM.bottomSeatGap) {
            if let logoPath {
                BrandMark(path: logoPath, box: BrandMarkBox(height: logoHeight, maxWidth: logoMaxWidth),
                          clearSpace: logoClearSpace)
            }
            if logoPath != nil, stepDots != nil || claimText != nil {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 1, height: PlainBrandedM.footerDividerHeight)
            }
            if let stepDots {
                StepDotIndicator(current: stepDots.current, total: stepDots.total, accentColor: accent)
            }
            if let stepIndicatorText {
                Text(stepIndicatorText)
                    .font(.system(size: PlainBrandedM.stepIndicatorFontSize))
                    .foregroundStyle(palette.textMuted)
            }
            if let claimText {
                OwnershipLine(text: claimText, ink: palette.textMuted)
            }
        }
    }

    /// The no-footer mode's pill: `actionPillCapsule` at the band's own window margins.
    private var floatingActionPill: some View {
        actionPillCapsule
            .padding(.trailing, PlainBrandedM.pillTrailing)
            .padding(.bottom, PlainBrandedM.pillBottom)
    }

    /// The capsule button both modes share, so the pill is identical floating or in the band.
    /// Fixed 28pt capsule filled with the accent (not `PrimaryActionButton`, whose shape and
    /// height follow config); the label is white because it sits on the accent fill.
    private var actionPillCapsule: some View {
        Button(action: onPrimaryAction) {
            Text(buttonTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, PlainBrandedM.pillHorizontalPadding)
                .frame(height: PlainBrandedM.pillHeight)
        }
        .buttonStyle(.plain)
        .background(Capsule().fill(accent))
        .keyboardShortcut(.defaultAction)
        .disabled(buttonDisabled)
        .opacity(buttonDisabled ? 0.5 : 1)
    }
}
