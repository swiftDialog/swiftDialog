//
//  CardShowcaseView.swift
//  dialog
//
//  The showcase step in the card design language: a full-window stage with the mark and title
//  centred on it, a caption band and the card's action bar. One layout at every window size.
//

import SwiftUI

/// How the stage is filled, resolved once so the view never re-decides it.
enum ShowcaseFill: Equatable {
    case flat(Color)
    case gradient([Color])
}

/// The stage's geometry and fill. Pure so the floor can be tested rather than eyeballed.
enum ShowcaseStage {

    /// The default when `showcaseImageHeight` is unauthored.
    static let defaultFraction: CGFloat = 0.6

    /// The least height that holds the mark, the gap, one title line, the optical nudge and
    /// breathing room on both edges.
    static let minimumHeight: CGFloat = 220

    /// What the other bands are owed before the stage may take anything: the strip, the action
    /// bar and one subtitle line of caption.
    static let reservedChrome: CGFloat = 44 + FooterBandM.band + 96

    static func fraction(_ authored: Double?) -> CGFloat {
        guard let authored, authored > 0 else { return defaultFraction }
        return min(max(CGFloat(authored), 0.2), 0.9)
    }

    /// Floor first, then the chrome's claim; the chrome wins so a short window still shows the
    /// buttons that get the user out.
    static func height(windowHeight: CGFloat, fraction: CGFloat) -> CGFloat {
        let wanted = max(minimumHeight, windowHeight * fraction)
        return max(0, min(wanted, windowHeight - reservedChrome))
    }

    /// Precedence: an authored flat `heroBackgroundColor`, then the gradient chain
    /// step → config → brand.
    static func fill(heroBackground: String?,
                     stepGradient: [String]?,
                     configGradient: [String]?,
                     brand: Color) -> ShowcaseFill {
        // `Color(hex:)` cannot fail, so a tier is chosen by whether the author wrote something,
        // never by whether it parses.
        if let heroBackground { return .flat(Color(hex: heroBackground)) }
        for authored in [stepGradient, configGradient] {
            let colors = (authored ?? []).map { Color(hex: $0) }
            if !colors.isEmpty { return .gradient(colors) }
        }
        return .gradient([brand.opacity(0.8), brand.opacity(0.6), brand.opacity(0.8)])
    }

    /// Splits a hero into a symbol mark or a file path, never both. A degenerate "SF=" is a
    /// symbol reference with no name and falls back to the default mark rather than becoming
    /// a file path.
    static func mark(hero: String?) -> (mark: String?, artwork: String?) {
        guard let hero else { return ("sparkles", nil) }
        if IconRef.isSymbolReference(hero) {
            return (IconRef.symbol(hero) ?? "sparkles", nil)
        }
        return (nil, hero)
    }
}

/// The authored keys this chrome does not honour. Same posture as `CardHeroAdvice`.
enum CardShowcaseAdvice {

    /// Every retired key this route can see, reported whenever authored (`false` included).
    /// The stage sizes by `showcaseImageHeight`, fixes the mark's weight, and paints its own
    /// ground, so the hero sizing, symbol weight and colour, and overlay text colour keys have
    /// nothing to act on.
    static func ignoredKeys(assistantImageHeight: Double?,
                            heroImageShape: String? = nil,
                            heroImageSize: Double? = nil,
                            heroImagePadding: Double? = nil,
                            heroBadge: String? = nil,
                            showProgressDots: Bool? = nil,
                            heroImageSFSymbolWeight: String? = nil,
                            heroImageSFSymbolColor: String? = nil,
                            contentAnchor: String? = nil,
                            showcaseTextColor: String? = nil) -> [String] {
        var keys = assistantImageHeight == nil ? [] : ["assistantImageHeight"]
        keys += CardHeroAdvice.ignoredKeys(shape: heroImageShape, size: heroImageSize,
                                           padding: heroImagePadding, badge: heroBadge)
        if showProgressDots != nil { keys.append("showProgressDots") }
        if heroImageSFSymbolWeight != nil { keys.append("heroImageSFSymbolWeight") }
        if heroImageSFSymbolColor != nil { keys.append("heroImageSFSymbolColor") }
        if contentAnchor != nil { keys.append("contentAnchor") }
        if showcaseTextColor != nil { keys.append("showcaseTextColor") }
        return keys
    }
}


/// Everything the bands need, already resolved: data and closures only, so the view stays
/// previewable and the arm keeps ownership of navigation.
struct CardShowcaseModel {
    let title: String?
    let subtitle: String?
    /// A bare SF symbol name, never a file path; `ShowcaseStage.mark(hero:)` routes files to
    /// `artworkPath`. nil draws no mark.
    let mark: String?
    /// A file image drawn full-bleed behind the mark and title. nil draws the fill alone.
    let artworkPath: String?
    let fill: ShowcaseFill
    let stageFraction: CGFloat
    let accent: Color
    /// 0-based; the dots are 1-based and convert once, in the strip.
    let stepIndex: Int
    let totalSteps: Int
    /// The card footer's model with its dots off: this screen states position in its strip.
    let footer: CardFooterModel
}

/// Four bands: strip · stage · caption · action bar. The caption band is the card's payload
/// column and draws the same blocks every other card step draws.
struct CardShowcaseView: View {
    let model: CardShowcaseModel
    let blocks: [InspectConfig.GuidanceContent]
    /// Live state for interactive blocks in the caption; kept off the model, which stays
    /// resolved data plus closures.
    @ObservedObject var inspectState: InspectState
    /// Resolves both the stage artwork and any image block in the caption.
    let iconBasePath: String?
    /// The block renderer's `itemId`, one per step.
    let stepId: String

    @Environment(\.palette) private var palette
    /// The strip draws no visible counter, so its accessibility label is the only localized
    /// statement of position.
    @Environment(\.inspectLocalization) private var l10n
    /// A plain property because the bands need it at construction time.
    var scaleFactor: CGFloat = 1.0

    /// The strip and the bar are what `ShowcaseStage.reservedChrome` withholds from the stage,
    /// so they are drawn unscaled or the floor stops being a floor.
    private let stripHeight: CGFloat = 44
    /// The one card band, so the primary sits where every other card screen puts it.
    private let actionBarHeight: CGFloat = FooterBandM.band

    var body: some View {
        GeometryReader { geo in
            let stageHeight = ShowcaseStage.height(windowHeight: geo.size.height,
                                                   fraction: model.stageFraction)
            VStack(spacing: 0) {
                strip
                stage(height: stageHeight, width: geo.size.width)
                caption
                actionBar
            }
        }
        .background(palette.cardSurface)
    }

    // MARK: - Band 1: the strip

    /// Wayfinding only: the dots at the trailing edge, nothing invented for the leading edge, and
    /// no counter pill restating what the dots say.
    private var strip: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            StepDotIndicator(current: model.stepIndex + 1,
                             total: model.totalSteps,
                             accentColor: model.accent)
        }
        .padding(.horizontal, InspectMetrics.unit.cardEdge)
        .frame(height: stripHeight)
        // `StepDotIndicator` hides itself from accessibility, expecting a counter beside it;
        // with no counter here, this label is what assistive tech gets.
        .accessibilityElement()
        .accessibilityLabel(StepCounterLabel.text(current: model.stepIndex + 1,
                                                  total: model.totalSteps,
                                                  localizer: l10n))
    }

    // MARK: - Band 2: the stage

    /// The fill, the artwork over it, then the mark and title as one centred group. The mark
    /// belongs to the title group, so exactly one is ever drawn.
    private func stage(height: CGFloat, width: CGFloat) -> some View {
        ZStack {
            fill
            if let artworkPath = model.artworkPath {
                // The fill is already painted underneath; a gradient fallback would double its
                // alpha where an image fails to load.
                AsyncImageView(iconPath: artworkPath,
                               basePath: iconBasePath,
                               maxWidth: width,
                               maxHeight: height,
                               fallback: { Color.clear })
                    .frame(width: width, height: height)
                    .clipped()
            }
            // The gap makes mark and title read as one object; the group sits above true centre
            // because an arithmetically centred group reads low. Both scale with the type.
            VStack(spacing: 28 * scaleFactor) {
                markView
                if let title = model.title {
                    Text(title)
                        .font(.system(size: 34 * scaleFactor, weight: .bold))
                        .foregroundStyle(stageInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40 * scaleFactor)
                }
            }
            .offset(y: -12 * scaleFactor)
        }
        .frame(width: width, height: height)
        .clipped()
    }

    @ViewBuilder private var fill: some View {
        switch model.fill {
        case .flat(let color):
            color
        case .gradient(let colors):
            LinearGradient(gradient: Gradient(colors: colors),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Large and thin: a small hairline icon in that much colour reads as a loading state.
    /// `model.mark` is already a bare symbol name, so no file-path guard is needed.
    @ViewBuilder private var markView: some View {
        if let mark = model.mark {
            Image(systemName: mark)
                .font(.system(size: 88 * scaleFactor, weight: .thin))
                .foregroundStyle(stageInk.opacity(0.9))
        }
    }

    /// The one non-palette colour here: the stage paints its own ground, so what reads on it is
    /// decided by the fill, not the window's appearance. An authored ink is ignored for the same
    /// reason.
    private var stageInk: Color { .white }

    // MARK: - Band 3: the caption

    /// The card's payload column: subtitle, then the blocks through the shared
    /// `GuidanceContentView`. Scrolls, because the stage has first claim on the height.
    private var caption: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let subtitle = model.subtitle {
                    Text(subtitle)
                        .font(.system(size: 15 * scaleFactor))
                        .foregroundStyle(palette.text.opacity(0.75))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        // Capped like every card's body copy; the blocks below stay full-bleed.
                        .frame(maxWidth: InspectMetrics.unit.cardCopyMax, alignment: .leading)
                }
                if !blocks.isEmpty {
                    GuidanceContentView(
                        contentBlocks: blocks,
                        scaleFactor: scaleFactor,
                        iconBasePath: iconBasePath,
                        inspectState: inspectState,
                        itemId: stepId,
                        onOverlayTap: nil,
                        accentColor: model.accent,
                        // Body copy under a fold line; the stage already owns the centred axis.
                        contentAlignment: .leading
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, InspectMetrics.unit.cardEdge)
            .padding(.top, 26)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Band 4: the action bar

    /// The card footer every other card arm draws. Back is absent, never disabled, when the arm
    /// resolved no label. No counter: the strip states position.
    private var actionBar: some View {
        CardFooterBar(footer: model.footer, accent: model.accent, stepLabel: nil)
            .frame(height: actionBarHeight)
        // Tinted off the card's own ink so the hairline tracks it in both appearances.
        .overlay(alignment: .top) { Divider().overlay(palette.text.opacity(0.07)) }
    }
}
