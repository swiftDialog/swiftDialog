//
//  CardStepComponents.swift
//  dialog
//
//  The shared card chrome's models and rules (config "chrome": "card"): the per-preset contract
//  `CardStepModel` that `CardStepScreen` renders, the footer vocabulary and the action cluster.

import SwiftUI

// MARK: - Per-preset contract

/// The optional per-step hero: a band in the card language, not the legacy floating circle.
struct CardHeroModel {
    let icon: String                       // "SF=symbol", bare SF name, or image path
    var sfColor: Color?              // heroImageSFSymbolColor; nil → accent
    var sfWeight: Font.Weight = .medium    // heroImageSFSymbolWeight; see CardHeroAdvice
}

/// How the card treats the legacy `heroImage*` keys. `CardHeroBand` is a fixed 44pt box with a 20pt glyph:
/// `heroImageSFSymbolWeight` is honoured; size, shape and padding describe the old circle and are ignored
/// with an advisory.
enum CardHeroAdvice {

    /// Unknown spellings fall back to `.medium`, the band's default.
    static func weight(from raw: String?) -> Font.Weight {
        switch raw {
        case "bold": return .bold
        case "regular": return .regular
        default: return .medium
        }
    }

    /// The authored keys this chrome ignores, in a stable order for the advisory. `heroBadge` overlays the
    /// old circle and is ignored too; the outro's title badge says "done" instead. `badge` defaults to nil.
    static func ignoredKeys(shape: String?, size: Double?, padding: Double?,
                            badge: String? = nil) -> [String] {
        var keys: [String] = []
        if shape != nil { keys.append("heroImageShape") }
        if size != nil { keys.append("heroImageSize") }
        if padding != nil { keys.append("heroImagePadding") }
        if badge != nil { keys.append("heroBadge") }
        return keys
    }
}

/// Whether a card footer draws its position dots. On by default; `showProgressDots: false` turns them off.
/// The legacy standard intro draws dots only when the key is `true`.
enum CardFooterDots {
    static func shown(authored: Bool?) -> Bool {
        authored != false
    }
}

/// The completed-cadence recap (`showCadenceRecap`) as data. It shows live monitor state, so the arm
/// derives it and hands the shell a value, like `CardStepModel.substeps`.
struct CardRecapModel {
    let tiles: [CadenceRecapTile]
    /// Entries proven satisfied, never the cursor; see `satisfiedCount`.
    let satisfiedCount: Int
    /// Cadence position; equals the entry count on a finished run, so the active ring is off.
    let position: Int
    let timedOut: Set<Int>
    let accent: Color
    let basePath: String?
    /// Pre-localized and filtered; the strip joins them with " · ".
    let summary: [String]
    /// A clean run earns the green tick; a run with timeouts gets the clock.
    let clean: Bool

    /// Entries minus those forced past their timeout, clamped at zero. The cursor also advances on
    /// timeouts (`IntroStepMonitorService.performAdvance`), so it overstates what was proven.
    static func satisfiedCount(total: Int, timedOut: Set<Int>) -> Int {
        max(total - timedOut.count, 0)
    }

    /// The summary segments in order, empties dropped. No measured duration drops that segment; the
    /// closing claim survives only a clean run.
    static func segments(passed: String, duration: String?, closing: String?,
                         clean: Bool) -> [String] {
        [passed, duration, clean ? closing : nil]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
    }
}

struct CardStepModel {
    var eyebrow: String?
    var eyebrowIcon: String?               // path or "SF=symbol"
    var stepLabel: String?                 // "Step 2 of 4"
    var hero: CardHeroModel?         // optional hero band above the title
    var title: String
    /// The `stepOverlay` info button's action; the preset view presents the sheet. nil → no button.
    var onTitleInfo: (() -> Void)?
    var titleBadge: Bool = false           // outro: 30pt badge beside the title
    var titleBadgeFailed: Bool = false     // red badge — flow finished with failures
    var subtitle: String?
    var progress: Double?            // processing: 5pt capsule bar in the header
    var blocks: [InspectConfig.GuidanceContent] = []            // left column content
    var substeps: [(state: CardSubstepState, label: String)]?   // processing rows (wins over blocks)
    var escape: RailEscapeModel?                          // stall escape hatch (override entry)
    var failures: [(label: String, detail: String?)] = []       // outro: failed steps in the listing
    /// Outro: the decisions receipt. Each row's Change navigates to an existing step id.
    var receipt: [ChoiceReceiptRow] = []
    var receiptChangeLabel: String = "Change"
    var onReceiptChange: ((String) -> Void)?
    /// The completed-cadence recap, when `showCadenceRecap` is authored and the cadence completed this session.
    var recap: CardRecapModel?
    var panel: InspectConfig.CardPanel?
    /// Media arm: `mediaSide: "left"` mirrors the split (panel leading, copy trailing).
    var panelLeading: Bool = false
    var footer: CardFooterModel
}

/// The action-bar sub-stepper (‹ n of m ›), anchored left. Replaces the dots on steps with sub-screens.
struct CardSubStepperModel {
    let current: Int                       // 0-based
    let total: Int
    let onPrev: (() -> Void)?              // nil on the first sub-step
    let onNext: (() -> Void)?              // nil on the last sub-step
}

/// A two-line mono narration in the step-counter slot. Both lines are always present so the footer height
/// never changes between running and complete. Currently unused by any caller.
struct CardFooterNarrationModel {
    /// "{satisfied} of {total} installed[ · now: {label}]", pre-localized by the caller.
    let line1: String
    /// The checking-detail line, or a single space (not empty, which would change the line height).
    let line2: String
}

struct CardFooterModel {
    var dots: (current: Int, total: Int)?  // nil → no dots (outro)
    var subStepper: CardSubStepperModel?   // wins over dots when present
    /// A two-line narration replacing the step-counter slot (never the dots); wins over `stepLabel`.
    var narration: CardFooterNarrationModel?
    var footnote: String?                  // Markdown; outro support line
    /// The state line ("how long, and who do I ask"); when set it takes the claim's seat. nil keeps the
    /// brand claim. Set by `softwareFooter` for the `bundles` layout's note.
    var stateLine: String?
    var backText: String?                  // nil → no Back button
    var onBack: (() -> Void)?
    /// Optional plain-styled secondary beside the primary (e.g. "Reveal in Finder").
    var secondaryText: String?
    var onSecondary: (() -> Void)?
    /// nil or empty draws no primary action (`continueButtonText: ""`); a reference screen has nowhere to
    /// continue to. The rule lives on `FooterActionsModel.resolvedPrimary`.
    var continueText: String?
    var continueDisabled: Bool = false
    /// Draws no primary but holds its seat; see `FooterActionsModel.primaryHidden`.
    var primaryHidden: Bool = false
    var onContinue: () -> Void
    var logoPath: String?                  // footer logo
    var logoHeight: CGFloat = 27           // logoConfig.maxHeight (band incl. clear space)
    var logoClearSpace: CGFloat = 0        // logoConfig.logoClearSpace
    var inspectConfig: InspectConfig?      // deferral ("Later") menu source — nil hides it
    var deferralText: String?              // localized "Later" label (nil → config/default)
    var autoClose: CardAutoCloseModel?     // visible countdown-to-quit in the footer
}

/// The bounded final-screen hold: classic `--timer`'s tick pattern as a quiet footer line, with a clean
/// exit (the caller's onFire writes the result file and exit event first).
struct CardAutoCloseModel {
    let seconds: Double
    /// Label format with a `{time}` placeholder, pre-localized (`ui.closesIn`).
    var labelFormat: String = "Closes in {time}"
    let onFire: () -> Void
}

/// A held door yields no auto-close model, so the countdown starts only when the door opens.
enum CardAutoCloseGate {
    static func model(_ model: CardAutoCloseModel?, doorHeld: Bool) -> CardAutoCloseModel? {
        doorHeld ? nil : model
    }
}

struct CardAutoCloseCountdown: View {
    @Environment(\.palette) private var palette
    let model: CardAutoCloseModel
    /// Line colour for seats off the window's ground; nil keeps the palette ink.
    var ink: Color?
    /// The `Countdown` clock, armed on appear and cancelled on disappear, so leaving never quits the window.
    @State private var clock: Countdown?

    /// At least one tick: a hold that rounds to zero still waits a second.
    private var seconds: Int { max(1, Int(model.seconds.rounded())) }
    private var time: String { clock?.label ?? Countdown.mmss(seconds) }

    var body: some View {
        Text(model.labelFormat.replacingOccurrences(of: "{time}", with: time))
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(ink ?? palette.text.opacity(0.45))
            .monospacedDigit()
            .onAppear {
                let countdown = Countdown(seconds: seconds)
                clock = countdown
                countdown.start(onFire: { [onFire = model.onFire] in
                    // Show 0 briefly before quitting, as classic does.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(200))
                        onFire()
                    }
                })
            }
            .onDisappear {
                clock?.cancel()
                clock = nil
            }
            .accessibilityLabel("This window closes in \(time)")
    }
}

// MARK: - Footer vocabulary

/// The disabled-primary ink pair: a disabled action dims its label with its fill.
enum FooterPrimaryInk {
    static func tint(disabled: Bool, accent: Color, text: Color) -> Color {
        disabled ? text.opacity(0.059) : accent
    }
    static func label(disabled: Bool, text: Color) -> Color {
        disabled ? text.opacity(0.31) : .white
    }
}

// MARK: - Bar stability

// A bar's geometry derives only from values fixed at step construction, never from which children
// draw at render time. Remedies by child kind:
// - async decorative content: a fixed box on a fixed-height band (`BrandMark` in `FooterRow`)
// - a participant that is sometimes empty: a zero-width slice in the row (the claim in `CardFooterBar`)
// - a control that is briefly absent: keep its seat (`subStepperArrow`, `primaryHidden`)
// - varying text: a constant-size slot (`CardFooterNarrationModel.line2`)

/// The trailing action run every step footer offers: Later ⌄ · Back · secondary · primary, drawn by
/// `FooterActionCluster`.
struct FooterActionsModel {
    var backText: String?            // nil → no Back
    var onBack: (() -> Void)?
    var secondaryText: String?       // plain-styled secondary beside the primary
    var onSecondary: (() -> Void)?
    /// nil or empty draws no primary (`continueButtonText: ""`).
    var continueText: String?
    var continueDisabled: Bool = false
    /// The primary keeps its seat but is not drawn, clickable or in the accessibility tree. Unlike
    /// `continueText == nil`, the button is coming back, so the footer must not change height.
    var primaryHidden: Bool = false
    var onContinue: () -> Void
    var inspectConfig: InspectConfig?    // deferral "Later ⌄" source — nil hides it
    var deferralText: String?

    var resolvedPrimary: String? {
        guard let text = continueText, !text.isEmpty else { return nil }
        return text
    }
}

/// The 30pt done/failed badge beside an outro title, shared by card and rail; palette-derived.
struct StatusTitleBadge: View {
    @Environment(\.palette) private var palette
    let failed: Bool

    var body: some View {
        ZStack {
            Circle().fill(failed ? palette.errorBackground : palette.successBackground)
            Image(systemName: failed ? "xmark" : "checkmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(failed ? palette.error : palette.success)
        }
        .frame(width: 30, height: 30)
    }
}

struct FooterActionCluster: View {
    @Environment(\.palette) private var palette
    @Environment(\.footerControlSize) private var footerControlSize
    @Environment(\.inspectButtonShape) private var buttonShape
    let actions: FooterActionsModel
    let accent: Color

    var body: some View {
        HStack(spacing: 18) {
            if isDeferralEnabled(config: actions.inspectConfig) {
                DeferralMenuView(config: actions.inspectConfig,
                                 accentColor: accent,
                                 buttonText: actions.deferralText)
            }
            // Back and the secondary share one drawing.
            if let backText = actions.backText, let onBack = actions.onBack {
                Door.word(ink: palette.text.opacity(0.55), label: backText, action: onBack)
            }
            if let secondaryText = actions.secondaryText, let onSecondary = actions.onSecondary {
                Door.word(ink: palette.text.opacity(0.55), label: secondaryText, action: onSecondary)
            }
            if let primary = actions.resolvedPrimary {
                Button(primary, action: actions.onContinue)
                    .buttonStyle(.borderedProminent)
                    .controlSize(footerControlSize)
                    .inspectButtonShape(buttonShape)
                    .tint(FooterPrimaryInk.tint(disabled: actions.continueDisabled,
                                                accent: accent, text: palette.text))
                    .foregroundStyle(FooterPrimaryInk.label(disabled: actions.continueDisabled,
                                                            text: palette.text))
                    .disabled(actions.continueDisabled || actions.primaryHidden)
                    // Return presses it, except while the seat is held.
                    .keyboardShortcut(actions.primaryHidden ? nil : .defaultAction)
                    // Held seat: `opacity(0)` alone would still take clicks and appear to accessibility.
                    .opacity(actions.primaryHidden ? 0 : 1)
                    .allowsHitTesting(!actions.primaryHidden)
                    .accessibilityHidden(actions.primaryHidden)
            }
        }
        // Pin the cluster to the primary's height so taller siblings overhang instead of shifting the primary.
        .frame(height: FooterBandM.clusterHeight(tallestSibling: FooterBandM.primaryHeight))
    }
}

/// Opens a URL-shaped continueAction (x-apple.systempreferences:, https://) without a shell; engine
/// keywords pass through. Shared by both adapters.
func openCardContinueActionURL(_ action: String?) {
    guard let action,
          !["next", "skip", "portal", "minimize"].contains(action),
          let url = URL(string: action), url.scheme != nil else { return }
    NSWorkspace.shared.open(url)
}
