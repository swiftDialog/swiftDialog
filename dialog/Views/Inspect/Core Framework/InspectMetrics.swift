//
//  InspectMetrics.swift
//  dialog
//
//  Scale-resolved design tokens for every inspect screen; values are post-scale, so never scale them again.
//  `typeScale` moves fonts and icon sizes (density); `measureScale` moves columns, padding and insets.
//

import SwiftUI

struct InspectMetrics: Equatable {
    /// Fonts and icon point sizes. Moves with `density`.
    let typeScale: CGFloat
    /// Columns, padding, spacing, insets. Pinned per chrome.
    let measureScale: CGFloat

    /// The one-knob form: both axes at one value.
    init(scale: CGFloat) {
        self.typeScale = scale
        self.measureScale = scale
    }

    /// The two-axis form; the seam the density tier writes through (`InspectLayoutProtocol`).
    init(typeScale: CGFloat, measureScale: CGFloat) {
        self.typeScale = typeScale
        self.measureScale = measureScale
    }

    /// The fixed-window chromes (card, rail, showcase) do not scale; every `card*` and `rail*`
    /// token they read comes through here.
    static let unit = InspectMetrics(scale: 1.0)

    // MARK: Typography tiers

    /// Step-screen title, 26pt bold.
    var stepTitle: Font { .system(size: 26 * typeScale, weight: .bold) }
    /// Step-screen subtitle, the 13pt pair of `stepTitle`.
    var stepSubtitle: Font { .system(size: 13 * typeScale) }
    /// Phase-screen (intro/outro) title, one tier up from steps.
    var phaseTitle: Font { .system(size: 28 * typeScale, weight: .bold) }
    /// Phase-screen subtitle.
    var phaseSubtitle: Font { .system(size: 15 * typeScale) }
    /// Hero-display title (showcase/guide panels, banner overlays).
    var displayTitle: Font { .system(size: 34 * typeScale, weight: .bold) }
    /// Standard body/content text.
    var body: Font { .system(size: 14 * typeScale) }
    /// Caption/secondary-detail text.
    var caption: Font { .system(size: 12 * typeScale) }

    // MARK: Spacing rhythm (scaled)

    /// Horizontal padding on a step's main content area.
    var contentPadH: CGFloat { 40 * measureScale }
    /// Max width for text-heavy content columns.
    var contentMaxW: CGFloat { 480 * measureScale }
    /// Readable cap for prose in the leading stance. Grids go full-bleed; a paragraph must not,
    /// and stays flush left rather than centring in the leftover space.
    var proseMaxW: CGFloat { 520 * measureScale }
    /// Max width for multi-column layouts (bento grids, compliance summaries).
    var wideContentMaxW: CGFloat { 820 * measureScale }
    /// Ceiling of the header band (title/subtitle block). A constant, not a result: a two-line
    /// subtitle wraps inside the band rather than growing it, so the payload starts at one height
    /// across a flow. Applied as `maxHeight`, so it is the most a heading may reserve.
    var headerBandH: CGFloat { 96 * measureScale }
    /// Gap between title and subtitle.
    var titleSubtitle: CGFloat { 8 * measureScale }
    /// Gap between content blocks.
    var blockGap: CGFloat { 16 * measureScale }
    /// Gap between major sections.
    var sectionGap: CGFloat { 20 * measureScale }
    /// Top inset from container edge to first element.
    var topInset: CGFloat { 16 * measureScale }

    // MARK: Anchoring

    /// The one distance every `contentAnchor: "top"` path produces between window top and the
    /// first content element.
    var anchorTopInset: CGFloat { 40 * measureScale }

    // MARK: Phase-footer chrome (FooterRow surface)

    /// Horizontal inset of the phase-screen footer.
    var phaseFooterHorizontal: CGFloat { 40 * measureScale }
    /// Bottom inset of the phase-screen footer.
    var phaseFooterBottom: CGFloat { 24 * measureScale }

    // MARK: Rail chrome (RailStepComponents surface)

    /// Fixed width of the left rail (step chooser column).
    var railWidth: CGFloat { 232 * measureScale }
    /// Outer inset of the rail; children add `railChildPad` so the active row's pill bleeds past its text.
    var railPad: CGFloat { 20 * measureScale }
    /// Horizontal inset on the rail's children (rows, brand mark, progress, logo).
    var railChildPad: CGFloat { 12 * measureScale }
    /// Top inset of the rail step's content column.
    var railContentTop: CGFloat { 34 * measureScale }
    /// Leading inset of the content column.
    var railContentLeading: CGFloat { 36 * measureScale }
    /// Bottom inset of the content column, so the rail's primary button lands 28 up like every other footer's.
    var railContentBottom: CGFloat { (FooterBandM.band - FooterBandM.primaryHeight) / 2 * measureScale }
    /// Trailing inset of the content column.
    var railContentTrailing: CGFloat { FooterBandM.rail * measureScale }
    /// Vertical gap between the content column's major regions (header, body, media, footer).
    var railContentGap: CGFloat { 22 * measureScale }
    /// Readable cap on the rail step subtitle.
    var railSubtitleMax: CGFloat { 460 * measureScale }
    /// Rail step title point size; the site applies its tracking (−0.022em) itself.
    var railTitleSize: CGFloat { 27 * typeScale }
    /// Rail body copy point size.
    var railBodySize: CGFloat { 14 * typeScale }

    // MARK: Card chrome (CardStepComponents surface)

    /// Box of the card's optional hero tile; the rail step-icon box, so both chromes share one mark size.
    var cardHeroBox: CGFloat { 44 * measureScale }
    /// Point size of an SF-symbol hero glyph inside `cardHeroBox`.
    var cardHeroGlyph: CGFloat { 20 * typeScale }
    /// The card's one text edge: header block, copy column and action bar align here. 44 makes
    /// the card column 732; recap rows depend on that width.
    var cardEdge: CGFloat { 44 * measureScale }
    /// Top inset of the card header band: eyebrow row at y 68, title 96, body 208 in the spec.
    var cardHeaderTop: CGFloat { 36 * measureScale }
    /// Eyebrow row → title: 68 + the 15 row + 13 puts the title's top at y 96.
    var cardHeaderGap: CGFloat { 13 * measureScale }
    /// Title → lede; the two are one block.
    var cardTitleLedeGap: CGFloat { 8 * measureScale }
    /// Header band height on a bandless card screen, so the body starts at one y (176 here, 184 in
    /// window coordinates) whether the lede runs one line or two.
    var cardHeaderBand: CGFloat { 176 * measureScale }
    /// Minimum room between the header and the payload band. The progress-bearing branch of
    /// CardStepShell moves with it so the payload edge holds across a flow.
    var cardBodyTop: CGFloat { 46 * measureScale }
    /// Compressed verticals used only under a top band, which already separates the header from
    /// the window edge. Band is flow-level, so every step compresses together and the payload
    /// edge still holds. Bandless cards never read these.
    var cardBandHeaderTop: CGFloat { 20 * measureScale }
    var cardBandBodyTop: CGFloat { 26 * measureScale }
    /// Gap between the card's copy column and its panel.
    var cardColGap: CGFloat { 36 * measureScale }
    /// Fixed width of the card's copy/list column, not a max; the panel takes the rest.
    var cardListWidth: CGFloat { 352 * measureScale }
    /// Wrap cap on the card subtitle.
    var cardCopyMax: CGFloat { 560 * measureScale }
    /// Bottom inset of the card action bar.
    var cardFooterBottom: CGFloat { 30 * measureScale }
    /// Fixed box for every status glyph, so the label edge holds as states change.
    var cardGlyphBox: CGFloat { 17 * measureScale }
    /// Optical baseline nudge for glyphs beside top-aligned 14.5pt text.
    var cardGlyphNudge: CGFloat { 2 * measureScale }

    // MARK: Controls

    /// Button control size flips to `.regular` below 0.9 on `typeScale`; a threshold, not a mode name.
    var buttonControlSize: ControlSize { typeScale < 0.9 ? .regular : .large }
}

// MARK: - Footer control size

/// `buttonControlSize` is the only place that decides a footer primary button's size; it reaches
/// footers without a `scaleFactor` through the environment. The shape (pill vs rounded rectangle)
/// follows the size tier; there is no separate shape key and no hand-drawn capsule.
private struct FooterControlSizeKey: EnvironmentKey {
    /// The standard tier's size, so an uninjected preview draws the usual button.
    static let defaultValue: ControlSize = .large
}

extension EnvironmentValues {
    /// Injected once at the preset root from `InspectMetrics.buttonControlSize`.
    var footerControlSize: ControlSize {
        get { self[FooterControlSizeKey.self] }
        set { self[FooterControlSizeKey.self] = newValue }
    }
}

/// The setup-assistant shell's metrics, at 1×. Separate from the provisioning shell's table; the
/// two share only the frame and the rails.
enum SetupAssistantM {
    /// The same frame as the provisioning shell, so a flow can mix the two without resizing.
    static let recommended = CGSize(width: 820, height: 600)
    static let frameRadius: CGFloat = 14

    static let rail: CGFloat = 40
    static var column: CGFloat { recommended.width - 2 * rail }

    /// Scrim heights by capsule: marks, progress bar, and the taller journey list or grid.
    static let scrimTall: CGFloat = 380
    static let scrimShort: CGFloat = 360
    static let scrimJourney: CGFloat = 420
    static let scrimMidStop: CGFloat = 0.32
    static let scrimMidOpacity: CGFloat = 0.55
    static let scrimEndOpacity: CGFloat = 0.95

    static let stackGap: CGFloat = 18

    static let titleSize: CGFloat = 24
    static let titleTracking: CGFloat = -0.48   // −.02em at 24pt
    static let ledeSize: CGFloat = 15.5
    static let ledeOpacity: CGFloat = 0.66
    static let ledeMaxWidth: CGFloat = 560

    static let capsuleRadius: CGFloat = 12
    static let capsuleFill: CGFloat = 0.10
    static let capsuleStroke: CGFloat = 0.18
    static let capsulePadH: CGFloat = 20
    static let capsulePadVBar: CGFloat = 16
    static let capsulePadBottomBar: CGFloat = 18

    /// The unmet mark is a ring, not a filled disc: a filled grey disc reads as a disabled control.
    static let markSize: CGFloat = 16
    static let markUnmet: CGFloat = 0.18
    static let markRingWidth: CGFloat = 1.5
    /// A fixed row box, so three marks are always 84 tall whatever the type metrics do.
    static let markRowHeight: CGFloat = 28
    /// List capsules take this tighter padding; their rows carry their own height.
    static let marksPadV: CGFloat = 12

    /// Journey rows drawn before the list scrolls inside itself. The capsule grows upward, so
    /// past this count the title is pushed off the top edge; under it the list is a plain stack.
    static let journeyRowsVisible: Int = 5

    /// The height the rows region is given, never what its content asks for. Uses the
    /// provisioning row height because the capsule draws `ProvisioningRowView` itself.
    static var journeyRowsHeight: CGFloat {
        CGFloat(journeyRowsVisible) * ProvisioningM.rowHeight
    }

    static let barHeight: CGFloat = 4
    static let barRadius: CGFloat = 2
    static let barTrack: CGFloat = 0.20

    // MARK: - The standard footer

    /// The footer row never changes height, so nothing reflows between screens.
    static let footerHeight: CGFloat = FooterBandM.band
    /// Edge to edge; the one element that does not take the rail.
    static let footerRuleWidth: CGFloat = FooterBandM.ruleWidth
    /// α's rule is light on the scrim, β's is dark on the window.
    static let footerRuleAlpha: CGFloat = 0.16
    static let footerRuleBeta: CGFloat = 0.08
    /// The mark is dimmed by opacity, never recoloured.
    static let footerLogoHeight: CGFloat = 18
    /// The most `logoConfig.maxHeight` can ask of the footer: the mark must clear the rule and the doors.
    static let footerLogoCap: CGFloat = 28
    static let footerLogoOpacity: Double = 0.9
    /// One line, truncating: a wrap would grow the row.
    static let footerLineSize: CGFloat = 12.5
    static let footerLineAlpha: Double = 0.5
    /// The kit's one primary height, so the band stays one number.
    static let footerDoorHeight: CGFloat = FooterBandM.primaryHeight
    static let footerDoorRadius: CGFloat = 10
    static let footerDoorPadH: CGFloat = 18
    static let doorSize: CGFloat = 14.5
    /// The quiet door's plate: light on α, a raised surface on β.
    static let footerGhostAlpha: Double = 0.14
    /// A disabled primary greys by opacity, so enabling it changes nothing but the alpha.
    static let footerDisabledOpacity: Double = 0.4
    static let footerGap: CGFloat = 18
    static let footerDoorGap: CGFloat = 10
    static let footerClearance: CGFloat = 24

    // MARK: banded ground (`SetupAssistantGroundStyle.banded`)
    /// The lede clears the band's foot by this.
    static let bandPadBottom: CGFloat = 26
    /// 1pt, not the footer hairline: this rule separates two surfaces.
    static let bandRuleWidth: CGFloat = 1
    static let bandRuleAlpha: CGFloat = 0.24
    /// From the rule down to the capsule's top edge.
    static let bandGap: CGFloat = 28

    /// The window adds this much chrome to the height it is asked for, so the shell frames to
    /// `hostHeight` or its footer floats 32pt above the bottom edge. A constant, because a
    /// `GeometryReader` inside this hierarchy reports the safe box, not the window.
    static let windowChrome: CGFloat = 32
    static var hostHeight: CGFloat { recommended.height + windowChrome }


    // MARK: - State β · the framed card

    /// β centres a 640 card in a 90 margin; the title aligns to the card, the doors keep the rail.
    static let betaMargin: CGFloat = 90
    static let betaCardTop: CGFloat = 170
    static let betaCardWidth: CGFloat = 640
    static let betaCardRadius: CGFloat = 14
    static let betaTitleY: CGFloat = 78
    static let betaTitleSize: CGFloat = 21
    static let betaMediaHeight: CGFloat = 252
    /// The caption strip beneath the specimen, inside the card.
    static let betaStripPadTop: CGFloat = 18
    static let betaStripPadH: CGFloat = 22
    static let betaStripPadBottom: CGFloat = 20
    /// β clips rather than scrolls, so a short host shrinks the specimen down to this floor.
    static let betaMediaFloor: CGFloat = 120
    /// Phase line + gap + bar, for the height budget.
    static let betaProgressBlock: CGFloat = 30
    static let captionSize: CGFloat = 12.5
    static let captionLine: CGFloat = 20
    /// The strip's row of numbered actions.
    static let betaStepChip: CGFloat = 18
    static let betaStepGap: CGFloat = 16
    static let betaStepRow: CGFloat = 34

    // The accent and success colours are not constants here: they come from the palette at the
    // call site so a tenant's brand applies. Only white and black are fixed, on the photograph.
}


enum CardM {
    /// The reference window `measureScale` is pinned to; a plain constant, since scaling it would be circular.
    static let card = CGSize(width: 820, height: 600)
}

/// Geometry for the provisioning shell. Sizes only, never theme; figures are expressed against
/// the viewport so they hold at any window from the minimum up.
struct ProvisioningM {

    /// The size this shell and the migration renderers aim at.
    static let recommended = CGSize(width: 820, height: 600)
    static let minimum = CGSize(width: 800, height: 600)

    let width: CGFloat
    let height: CGFloat

    init(size: CGSize) {
        // A window below the minimum clips visibly rather than producing negative regions.
        self.width = max(size.width, Self.minimum.width)
        self.height = max(size.height, Self.minimum.height)
    }

    init(width: CGFloat, height: CGFloat) { self.init(size: CGSize(width: width, height: height)) }

    // MARK: - Horizontal

    /// The one edge every family shares.
    static let rail: CGFloat = 44
    /// The rows, the track and the header copy all span it.
    var column: CGFloat { width - 2 * Self.rail }
    /// Where every band ends; the state word and the identity mark right-align to it.
    var mirror: CGFloat { width - Self.rail }

    // MARK: - Header
    //
    // Header figures are absolute: the header is pinned so a two-line title cannot move the
    // list top, which every screen in the flow shares.

    /// Everything below derives from or moves with it.
    static let topInset: CGFloat = 36
    /// Eyebrow: 12 semibold, tracked +1.2.
    static let eyebrowY: CGFloat = topInset
    static let eyebrowSize: CGFloat = 12
    static let eyebrowTracking: CGFloat = 1.2
    /// The counter is 12 / 500 mono, right-aligned to the mirror on the eyebrow's line, and is
    /// the only step counter on the screen.
    static let counterIsMonospaced = true
    static let counterSize: CGFloat = 12
    /// 28 bold, tracking −0.7.
    static let titleY: CGFloat = 64
    static let titleSize: CGFloat = 28
    static let titleTracking: CGFloat = -0.7
    /// 15 / 20, eight under the title's line.
    static let ledeY: CGFloat = 106
    static let ledeSize: CGFloat = 15
    static let ledeLineSpacing: CGFloat = 5
    /// Narrower than the column so the lede reads as a sentence, not a paragraph.
    static let ledeMaxWidth: CGFloat = 520
    /// Hard ceiling: a third line would run into the list's top rule.
    static let ledeMaxLines = 2

    // MARK: - The list

    /// Where the first bound rule lands, on every screen in the flow.
    static let listTop: CGFloat = 176
    /// Rows are a fixed height so the item count never changes the screen's geometry.
    static let rowHeight: CGFloat = 52
    static let boundRuleOpacity: CGFloat = 0.13
    static let separatorOpacity: CGFloat = 0.06

    /// A fixed-width mark slot so every glyph shares a centre line regardless of size.
    static let markSlot: CGFloat = 18
    static let markGap: CGFloat = 16
    /// The row's left edge for text.
    static var nameX: CGFloat { rail + markSlot + markGap }
    static let nameSize: CGFloat = 15.5
    /// State and detail share one size; only the family and the colour differ.
    static let detailSize: CGFloat = 13

    // MARK: - Preview-led body: one preview reflecting the current pick, hairline rows beside it

    static let previewWidth: CGFloat = 392
    static let previewHeight: CGFloat = 245
    static let previewRadius: CGFloat = 12
    static let previewGap: CGFloat = 40
    /// The rows start here and run to the mirror.
    static var previewRowsX: CGFloat { rail + previewWidth + previewGap }
    static let previewRowsWidth: CGFloat = 308
    /// One caption line below the preview.
    static let previewCaptionSize: CGFloat = 12.5

    // MARK: - Tile grid, the other body idiom; `optionLayout` picks "cards" or "rows"

    static let tileWidth: CGFloat = 234
    static let tileHeight: CGFloat = 224
    static let tileRadius: CGFloat = 12
    static let tileGap: CGFloat = 15
    static let tilePad: CGFloat = 14
    static let tileInnerGap: CGFloat = 12
    /// The per-option preview the row list cannot carry.
    static let tilePreviewWidth: CGFloat = 206
    static let tilePreviewHeight: CGFloat = 130
    static let tilePreviewRadius: CGFloat = 8
    static let tileRadio: CGFloat = 18
    static let tileLabelSize: CGFloat = 14.5
    /// Three tiles close on the column by construction.
    static func tileGridWidth(_ columns: Int) -> CGFloat {
        CGFloat(columns) * tileWidth + CGFloat(max(columns - 1, 0)) * tileGap
    }

    /// A fourth tile overruns the column; more than three draws the row list instead.
    static let maxTiles = 3

    /// A column that cannot carry three tiles draws rows, so a narrow construction cannot author
    /// a layout it has no room for.
    var fitsTileGrid: Bool { column >= Self.tileGridWidth(3) }

    // MARK: - The status band

    /// Measured up from the footer rule, so these follow the window bottom.
    static let footerBandHeight: CGFloat = FooterBandM.band
    var footerRuleY: CGFloat { height - Self.footerBandHeight }
    /// Where a body that fills stops: `FooterBandM.bodyAir` above the rule.
    var bodyBottom: CGFloat { footerRuleY - FooterBandM.bodyAir }
    static let trackAboveRule: CGFloat = 40
    var trackY: CGFloat { footerRuleY - Self.trackAboveRule }
    static let countAboveTrack: CGFloat = 20
    var countY: CGFloat { trackY - Self.countAboveTrack }

    static let trackHeight: CGFloat = 3
    static let trackRadius: CGFloat = 2

    /// The chrome strip: hairline top and bottom, no fill, under the list region and above the
    /// quiet band.
    static let stripHeight: CGFloat = 44
    var stripTop: CGFloat { footerRuleY - Self.quietBandHeight - Self.stripHeight }
    /// Always empty.
    static let quietBandHeight: CGFloat = FooterBandM.bodyAir

    // MARK: - The list region

    /// The only variable gap in the design; extra height collects here.
    var listRegionHeight: CGFloat { stripTop - Self.listTop }

    /// Slack kept between the last bound rule and the count.
    static let minimumBandSlack: CGFloat = 8

    /// Rows that draw before the list scrolls inside its region. The slack is reserved so the
    /// band never creeps up on the list as the window grows.
    var maxVisibleRows: Int {
        let usable = listRegionHeight - Self.minimumBandSlack
        return max(1, Int((usable / Self.rowHeight).rounded(.down)))
    }

    /// The height the list is given, never what its content asks for, so a list cannot push
    /// the band.
    func listHeight(rowCount: Int) -> CGFloat {
        CGFloat(min(rowCount, maxVisibleRows)) * Self.rowHeight
    }

    /// A scrolling list ends on a half row as the cue that more follows (macOS hides the
    /// scroller until someone scrolls). A list that fits uses `listHeight(rowCount:)`.
    func scrollingListHeight() -> CGFloat {
        let half = Self.rowHeight / 2
        let whole = max(1, Int(((listRegionHeight - Self.minimumBandSlack - half) / Self.rowHeight).rounded(.down)))
        return CGFloat(whole) * Self.rowHeight + half
    }

    // MARK: - The footer

    /// The rule ink, painted over the band's top edge by `FooterRow` so it costs the band nothing.
    static let footerRuleOpacity: CGFloat = 0.1
    /// The lockup's box; the band centres it.
    static let footerRowHeight: CGFloat = 32
    static let wordmarkHeight: CGFloat = 24
    /// A mark fits to the cap height inside the box, width free.
    static let logoMaxWidth: CGFloat = 120
    static let logoCapHeight: CGFloat = 20
    /// The footer's own cap, separate from the identity rail's so one cannot move the other.
    static let footerLogoMaxWidth: CGFloat = 120

    // MARK: - Two-brand lockup, opt-in via logoConfig.lockup: "both"
    //
    // The vendor yields by position and wording, never by being faded or shrunk.
    static let lockupMarkSize: CGFloat = 24
    static let lockupMarkRadius: CGFloat = 6
    static let lockupNameSize: CGFloat = 14
    static let lockupAttributionSize: CGFloat = 12.5
    static let lockupDividerHeight: CGFloat = 16
    static let lockupGap: CGFloat = 11
    /// Both marks share the box height and are held under 4 : 1 so a wide wordmark cannot crowd
    /// the line.
    static let lockupRatioCeiling: CGFloat = 4

    /// box ÷ cap height, derived so the two figures cannot drift apart.
    static var identityRatioCeiling: CGFloat { logoMaxWidth / logoCapHeight }
}
