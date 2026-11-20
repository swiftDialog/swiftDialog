//
//  CardStepShell.swift
//  dialog
//
//  CardStepShell: the fixed card chrome (header band, left column, right panel, footer) any preset loads with a model.
//

import SwiftUI

// MARK: - Shell

struct CardStepShell<Content: View>: View {
    @Environment(\.cardHeaderHelp) private var headerHelp
    @Environment(\.palette) private var palette
    /// Resolved first name for `{userName}` in card titles, injected at the preset root.
    @Environment(\.cardGreetingName) private var greetingName
    /// For `backdropTint(for:)`, which depends on the active appearance.
    @Environment(\.colorScheme) private var scheme
    /// Set once by `InspectMetrics.buttonControlSize` at the preset root.
    @Environment(\.footerControlSize) private var footerControlSize
    /// Where the brand mark sits (header · leading footer · centred footer).
    @Environment(\.cardBrandSlot) private var brandSlot
    /// Which end of the card states the step count (root key `stepCounterPlacement`).
    @Environment(\.cardStepCounterPlacement) private var counterPlacement
    /// The flow-level top band; nil when unauthored or suppressed for this arm.
    @Environment(\.cardTopBand) private var topBand
    /// The flow's button flavour (root `buttonShape`).
    @Environment(\.inspectButtonShape) private var buttonShape
    /// Overrides the payload's top inset; nil uses the computed value. For variants that draw their own
    /// title inside the payload (the bento grid, `BentoFillM.headerToGrid`).
    var bodyTopInset: CGFloat?
    /// Title (21pt bold) and lede (13.5pt) on one baseline row, the lede truncating before the step counter.
    /// No hero band. Opt-in.
    var compactHeader: Bool = false
    /// The 28pt fade where a payload reaches the footer; off for payloads that fill their band by design.
    var fadesOverflow: Bool = true
    var bandGradientPalette: [String]?
    var bandIconBasePath: String?
    let eyebrow: String?
    let eyebrowIcon: String?               // path or "SF=symbol"
    let stepLabel: String?                 // "Step 1 of 4"
    /// The hero tile overlays the trailing end of the title row, so the title's y never depends on a hero.
    var hero: CardHeroModel?
    private var isCompact: Bool { compactHeader }
    /// nil skips the whole title/subtitle band, including its gap; an empty string would still take height.
    let title: String?
    /// Optional info-button action beside the title (`stepOverlay`).
    var onTitleInfo: (() -> Void)?
    var titleBadge: Bool = false           // outro: 30pt badge beside the title
    var titleBadgeFailed: Bool = false     // red badge — finished with failures
    let subtitle: String?
    /// A step-specific statement at the trailing end of the title band (e.g. an "installed" roll-up).
    /// nil draws nothing. `AnyView` keeps call sites that pass none type-inferred.
    var titleAccessory: AnyView?
    var progress: Double?            // processing: 5pt capsule bar in the header
    /// `cadenceAlign: "center"`: the step counter moves above the title and both centre. Currently unused.
    var centeredHeader: Bool = false
    let accent: Color
    let footer: CardFooterModel
    @ViewBuilder let content: () -> Content

    /// The claim flavour absorbs the header.
    private var claimAbsorbs: Bool { topBand?.flavor.lowercased() == "claim" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let topBand {
                CardTopBand(band: topBand,
                            title: claimAbsorbs ? title.map(branded) : nil,
                            subtitle: claimAbsorbs ? subtitle.map(branded) : nil,
                            accent: accent,
                            gradientPalette: bandGradientPalette,
                            logoPath: footer.logoPath,
                            iconBasePath: bandIconBasePath)
            }
            if !claimAbsorbs {
                header
            }
            // The payload band is top-anchored, so slack pools at the bottom. Its measured size is handed
            // down (`inspectBodyBand`) so a payload with an authored height fits it.
            GeometryReader { band in
                content()
                    .environment(\.inspectBodyBand, band.size)
                    .frame(width: band.size.width, height: band.size.height, alignment: .topLeading)
            }
                .padding(.bottom, FooterBandM.bodyAir)
                .padding(.horizontal, InspectMetrics.unit.cardEdge)
                // Tracks `cardBodyTop`; under a top band the cardBand* verticals apply.
                .padding(.top, bodyTopInset ?? (topBand != nil
                    ? (progress != nil ? 24 : InspectMetrics.unit.cardBandBodyTop)
                    : (fixedHeaderBand ? 0 : (progress != nil ? 44 : InspectMetrics.unit.cardBodyTop))))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                // A mask, not a reserve: an overflowing payload fades where it meets the footer, and nothing moves.
                .mask(bodyMask)
            CardFooterBar(footer: footer, accent: accent, stepLabel: stepLabel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ground)
    }

    /// The card's surface: `palette.cardSurface`, plus a 12% wash of the backdrop palette's first colour when
    /// one resolves (config or managed preference via `resolvePhaseBackdrop`), as `DecisionRowList.tint` does.
    /// `CardChromeGround` uses a `ZStack` so the wash sits on the base.
    private var ground: some View {
        CardChromeGround()
    }

    /// The overflow fade, or a plain mask when `fadesOverflow` is false. One opaque rectangle either way,
    /// so the palette-literal sanction for this file stays at one line.
    private var bodyMask: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Color.black)
            if fadesOverflow {
                LinearGradient(colors: [Color.black, Color.black.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: CardStepShellM.bodyFadeHeight)
            }
        }
    }

    private var header: some View {
        VStack(alignment: centeredHeader ? .center : .leading, spacing: InspectMetrics.unit.cardHeaderGap) {
            // Compact header with an empty eyebrow row: the row is skipped and the counter joins the title row.
            if !(isCompact && eyebrow == nil && eyebrowIcon == nil && brandSlot != .header) {
            HStack(spacing: 8) {
                SmallBrandMark(icon: eyebrowIcon, accent: accent)
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.system(size: 11.5, weight: .medium))
                        .kerning(0.55)
                        .foregroundStyle(palette.text.opacity(0.55))
                }
                Spacer()
                // The counter cluster carries the brand: logo · hairline · counter. Hidden with `centeredHeader`.
                if brandSlot == .header, let logo = footer.logoPath {
                    brandMark(logo)
                    // The hairline separates mark from counter, so it goes when the counter does.
                    if stepLabel != nil, counterPlacement == .header, !centeredHeader {
                        Rectangle()
                            .fill(palette.text.opacity(0.14))
                            .frame(width: 0.5, height: 14)
                    }
                }
                // Hidden when the footer states the count, or with `centeredHeader` (drawn above the title).
                if let stepLabel, counterPlacement == .header, !centeredHeader {
                    Text(stepLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.text.opacity(0.45))
                }
                if let headerHelp {
                    if stepLabel != nil, counterPlacement == .header, !centeredHeader {
                        Rectangle()
                            .fill(palette.text.opacity(0.14))
                            .frame(width: 0.5, height: 14)
                    }
                    headerHelpButton(headerHelp)
                }
            }
            // Fixed row height: a 20pt eyebrow icon overhangs instead of growing the row, so the title's y is stable.
            .frame(height: 15)
            }
            // `cadenceAlign: "center"`: the counter sits above the title, centred across the full width.
            if centeredHeader, let stepLabel, counterPlacement == .header {
                Text(stepLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.text.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            // nil title: the caller draws its own header and this band takes no height at all.
            if title != nil {
                if isCompact {
                    compactTitleRow
                } else if titleBadge {
                    HStack(spacing: 13) {
                        StatusTitleBadge(failed: titleBadgeFailed)
                        titleBlock
                    }
                } else if let onTitleInfo {
                    // Seated on the title's baseline; muted with the card's own token rather than `.secondary`.
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        titleText
                        Button(action: onTitleInfo) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(palette.text.opacity(0.55))
                        }
                        .buttonStyle(.plain)
                        .help("More information")
                    }
                    .padding(.bottom, InspectMetrics.unit.cardTitleLedeGap - InspectMetrics.unit.cardHeaderGap)
                    subtitleText
                } else if let titleAccessory {
                    // One-line accessory on the title's baseline, so the header never grows.
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        titleText
                        Spacer(minLength: 12)
                        titleAccessory
                    }
                    .padding(.bottom, InspectMetrics.unit.cardTitleLedeGap - InspectMetrics.unit.cardHeaderGap)
                    subtitleText
                } else {
                    titleBlock
                }
            }
            if let progress {
                AccentProgressCapsule(progress: progress, accent: accent)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let hero, !isCompact {
                // Centred on the title's first line, drawn over the header so it takes no height.
                CardHeroBand(hero: hero, accent: accent)
                    .padding(.top, 15 + InspectMetrics.unit.cardHeaderGap
                        + (34 - InspectMetrics.unit.cardHeroBox) / 2)
            }
        }
        .padding(.top, topBand != nil ? InspectMetrics.unit.cardBandHeaderTop
                                      : InspectMetrics.unit.cardHeaderTop)
        .padding(.horizontal, InspectMetrics.unit.cardEdge)
        // A fixed band on the plain card, so the body starts at the same y whether the lede runs one line or two.
        .frame(height: fixedHeaderBand ? InspectMetrics.unit.cardHeaderBand : nil, alignment: .top)
    }

    /// The plain card header is a band of one height while it has a lede, so a one- or two-line lede never
    /// moves the body. Without a lede the band closes and the body follows the title; a top band or the
    /// compact header is never fixed.
    private var fixedHeaderBand: Bool {
        topBand == nil && !isCompact && !(subtitle ?? "").isEmpty
    }

    /// Title and lede as one block, 8 apart (the header's rows are 13 apart).
    @ViewBuilder private var titleBlock: some View {
        VStack(alignment: centeredHeader ? .center : .leading, spacing: InspectMetrics.unit.cardTitleLedeGap) {
            titleText
            subtitleText
        }
    }

    /// Compact header row: title and lede on one baseline, plus the step counter at the row's top when
    /// the eyebrow row is not drawn. The lede truncates first.
    private var compactTitleRow: some View {
        HStack(alignment: .top, spacing: 14) {
            HStack(alignment: .lastTextBaseline, spacing: 14) {
                Text(branded(title ?? ""))
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(palette.text.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize()
                if let subtitle, !subtitle.isEmpty {
                    Text(branded(subtitle))
                        .font(.system(size: 13.5))
                        .foregroundStyle(palette.text.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 16)
            if let stepLabel, counterPlacement == .header, eyebrow == nil, eyebrowIcon == nil,
               brandSlot != .header {
                Text(stepLabel)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(palette.text.opacity(0.45))
                    .fixedSize()
            }
            // With no eyebrow row the counter lives here, so the help control does too.
            if let headerHelp, eyebrow == nil, eyebrowIcon == nil, brandSlot != .header {
                headerHelpButton(headerHelp)
            }
        }
    }

    /// The header help control (`CardHeaderHelp`): an accent glyph sized to the counter beside it.
    /// Reports itself seated so the preset hides its floating disc.
    private func headerHelpButton(_ help: CardHeaderHelp) -> some View {
        // `HelpGlyphButton` at the counter's 14pt line height, so the eyebrow row does not grow.
        HelpGlyphButton(icon: help.icon, tooltip: help.tooltip, tint: accent, action: help.action)
        .accessibilityIdentifier("helpButton.cardHeader")
        .preference(key: CardHeaderHelpSeatedKey.self, value: true)
    }

    /// The brand mark at its authored size, via `CardBrandMark` (shared with `CardFooterBar`).
    private func brandMark(_ path: String) -> some View {
        CardBrandMark(path: path, logoHeight: footer.logoHeight, clearSpace: footer.logoClearSpace)
    }

    private func branded(_ text: String) -> String {
        guard let greetingName else { return text }
        return substituteGreeting(text, userName: greetingName)
    }

    private var titleText: some View {
        // Unreachable with nil: every caller sits behind `if title != nil`.
        Text(branded(title ?? ""))
            .font(.system(size: 28, weight: .bold))
            .tracking(-0.56)
            .lineLimit(2)
            .foregroundStyle(palette.text.opacity(0.9))
            .multilineTextAlignment(centeredHeader ? .center : .leading)
            .padding(.trailing, hero != nil && !isCompact ? InspectMetrics.unit.cardHeroBox + 16 : 0)
    }

    @ViewBuilder private var subtitleText: some View {
        if let subtitle {
            Text(branded(subtitle))
                .font(.system(size: 15))
                .foregroundStyle(palette.text.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: InspectMetrics.unit.cardCopyMax, alignment: .leading)
        }
    }
}
