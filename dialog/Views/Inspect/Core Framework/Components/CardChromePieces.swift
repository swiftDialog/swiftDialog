//
//  CardChromePieces.swift
//  dialog
//
//  The card's chrome pieces: brand mark, footer bar, hero band, chrome ground and the small brand mark.
//

import SwiftUI

/// One brand-mark rendering for every placement: same height source (authored maxHeight, capped) and
/// trim treatment. `BrandMarkBox.fit` lowers the height only when a wide mark would overflow its slot's box.
struct CardBrandMark: View {
    let path: String
    /// The authored mark height (`logoConfig.maxHeight`), capped at 28.
    let logoHeight: CGFloat
    let clearSpace: CGFloat

    /// The box for every seat. `.header` has no box of its own in `BrandSlotMetrics`, so it shares
    /// `.actionSlot` (220×22).
    private var brandSlotBox: CGSize { BrandSlotMetrics.actionSlot }

    var body: some View {
        let aspectRatio = LogoTrimCache.image(for: path).map { image in
            image.size.height > 0 ? image.size.width / image.size.height : 0
        }
        let box = BrandMarkBox.fit(authored: Double(min(logoHeight, 28)), default: 28,
                                   cap: brandSlotBox.height, maxWidth: brandSlotBox.width,
                                   clearSpace: clearSpace, aspectRatio: aspectRatio)
        // No maxWidth in the drawn box: the width bound lowers the height and the image hugs its ratio.
        return BrandMark(path: path, box: BrandMarkBox(height: box.height, maxWidth: nil),
                         clearSpace: clearSpace)
            .accessibilityHidden(true)
            // Tells the preset the card already shows the brand, so its window-corner mark stands down.
            .preference(key: CardBrandSeatedKey.self, value: true)
    }
}

/// The card footer in `FooterRow`'s slots: the mark (`.actionLeading`), wayfinding with the claim, and the
/// action cluster. A `.actionCentered` mark overlays the band's centre. Shared by `CardStepShell` and the showcase.
struct CardFooterBar: View {
    let footer: CardFooterModel
    let accent: Color
    /// "Step n of N", drawn here only when the counter is placed in the footer.
    let stepLabel: String?

    @Environment(\.palette) private var palette
    /// Where the brand mark sits (header · leading footer · centred footer).
    @Environment(\.cardBrandSlot) private var brandSlot
    /// Which end of the card states the step count (root key `stepCounterPlacement`).
    @Environment(\.cardStepCounterPlacement) private var counterPlacement
    /// Countdown-to-quit from the environment; `footer.autoClose` wins when set.
    @Environment(\.cardAutoClose) private var envAutoClose
    /// The flow-level brand claim; see `CardFooterClaimKey`.
    @Environment(\.cardFooterClaim) private var footerClaim

    var body: some View {
        FooterRow(rail: InspectMetrics.unit.cardEdge, rule: .none, gap: 0) {
            if let logo = footer.logoPath, brandSlot == .actionLeading {
                brandMark(logo)
                    .padding(.trailing, 16)
            }
        } leading: {
            HStack(spacing: 16) {
                // The divider needs both sides: a mark before it and a pager, measure bar or dots after it.
                let hasMarkBefore = footer.logoPath != nil && brandSlot == .actionLeading
                let separates = hasMarkBefore && (footer.subStepper != nil
                    || (footer.dots.map { StepDotIndicator.form(total: $0.total) == .measure
                                          || StepDotIndicator.drawsDots(total: $0.total) } ?? false))
                if separates {
                    Rectangle()
                        .fill(palette.text.opacity(0.14))
                        .frame(width: 0.5, height: 18)
                }
                if let pager = footer.subStepper {
                    HStack(spacing: 10) {
                        subStepperArrow("chevron.left", action: pager.onPrev)
                        Text("\(pager.current + 1) of \(pager.total)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(palette.text.opacity(0.45))
                        subStepperArrow("chevron.right", action: pager.onNext)
                    }
                } else if let dots = footer.dots, StepDotIndicator.form(total: dots.total) == .measure {
                    // Past the cap, position is one measure bar. `dots.current` is 0-based; the bar is 1-based.
                    StepMeasureBar(current: dots.current + 1, total: dots.total, accentColor: accent)
                } else if let dots = footer.dots, StepDotIndicator.drawsDots(total: dots.total) {
                    // Dots up to the cap (too many would crowd the bar). `dots` is 0-based; the module is 1-based.
                    StepDotIndicator(current: dots.current + 1, total: dots.total, accentColor: accent)
                } else if let note = footer.footnote {
                    StateLine(text: note)
                }
                // The counter words after the dots, the same `cardStepLabel` string the header would show,
                // so one translation covers both. `footer.narration` replaces this slot when set; both
                // narration lines are always present so the bar never moves.
                if let narration = footer.narration {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(narration.line1)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(palette.text.opacity(0.55))
                            .lineLimit(1)
                        Text(narration.line2)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(palette.text.opacity(0.35))
                            .lineLimit(1)
                    }
                } else if let stepLabel, counterPlacement == .footer {
                    Text(stepLabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(palette.text.opacity(0.45))
                }
                if let autoClose = footer.autoClose ?? envAutoClose {
                    CardAutoCloseCountdown(model: autoClose)
                }
                Spacer()
                // The claim, centred in the free span; 11.5pt muted from `BrandSlotMetrics`, wrapping to two lines.
                if let line = footer.stateLine, !line.isEmpty {
                    // The step's own line takes the claim's seat.
                    Text(line)
                        .font(.system(size: BrandSlotMetrics.claimFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 16)
                } else if let claim = CardFooterClaim.resolve(authored: footerClaim), !claim.isEmpty {
                    Text(claim)
                        .font(.system(size: BrandSlotMetrics.claimFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(BrandSlotMetrics.claimLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                }
            }
        } trailing: {
            FooterActionCluster(
                actions: FooterActionsModel(backText: footer.backText,
                                            onBack: footer.onBack,
                                            secondaryText: footer.secondaryText,
                                            onSecondary: footer.onSecondary,
                                            continueText: footer.continueText,
                                            continueDisabled: footer.continueDisabled,
                                            primaryHidden: footer.primaryHidden,
                                            onContinue: footer.onContinue,
                                            inspectConfig: footer.inspectConfig,
                                            deferralText: footer.deferralText),
                accent: accent)
        }
        // A centred brand mark sits on the band's centre, which is the window's centre line.
        .overlay {
            if brandSlot == .actionCentered, let logo = footer.logoPath {
                brandMark(logo)
            }
        }
    }

    private func brandMark(_ path: String) -> some View {
        CardBrandMark(path: path, logoHeight: footer.logoHeight, clearSpace: footer.logoClearSpace)
    }

    /// One pager arrow, disabled (not hidden) at the ends so the cluster never changes width.
    @ViewBuilder private func subStepperArrow(_ symbol: String, action: (() -> Void)?) -> some View {
        Button(action: { action?() }) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(palette.text.opacity(action == nil ? 0.18 : 0.55))
                .frame(width: 22, height: 22)
                .background(Circle().fill(palette.text.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

/// The hero band: a 44pt accent-tinted rounded square with a 20pt glyph, the rail step-icon vocabulary.
struct CardHeroBand: View {
    let hero: CardHeroModel
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(0.12))
            if IconRef.isComputer(hero.icon) {
                Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            } else if FileManager.default.fileExists(atPath: hero.icon),
               let nsImage = InspectImageCache.shared.image(atPath: hero.icon) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: IconRef.symbolOrBareName(hero.icon) ?? hero.icon)
                    .font(.system(size: InspectMetrics.unit.cardHeroGlyph, weight: hero.sfWeight))
                    .foregroundStyle(hero.sfColor ?? accent)
            }
        }
        .frame(width: InspectMetrics.unit.cardHeroBox, height: InspectMetrics.unit.cardHeroBox)
        .accessibilityHidden(true)
    }
}

/// The card chrome's ground: `cardSurface` plus the managed backdrop wash when in force, so every card
/// surface matches on a managed Mac.
struct CardChromeGround: View {
    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            palette.cardSurface
            if let tint = palette.backdropTint(for: scheme) {
                tint.opacity(0.12)
            }
        }
    }
}

/// 20pt brand mark for the card's eyebrow row and the rail's brand row: "SF=symbol" or an image path.
struct SmallBrandMark: View {
    let icon: String?
    let accent: Color

    var body: some View {
        if let icon {
            Group {
                if let symbolName = IconRef.symbol(icon) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous).fill(accent)
                        Image(systemName: symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                } else if let nsImage = InspectImageCache.shared.image(atPath: icon) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
            }
            .frame(width: 20, height: 20)
        }
    }
}
