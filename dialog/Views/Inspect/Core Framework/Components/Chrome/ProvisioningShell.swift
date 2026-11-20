//
//  ProvisioningShell.swift
//  dialog
//
//  One frame for every screen in a provisioning flow: pinned header, pinned footer, the list
//  between, and a status band above the footer rule. `ProvisioningM` measures against the
//  viewport so the same arithmetic holds from the 800 × 600 minimum up.
//

import SwiftUI

/// The frame, drawn as absolute bands rather than a `VStack` so content height can never move
/// the footer.
struct ProvisioningShell<Content: View>: View {
    /// Passed in rather than read from a `GeometryReader` so the geometry is testable without
    /// mounting SwiftUI.
    let metrics: ProvisioningM

    /// Drawn as authored; the shell applies no case transform.
    var eyebrow: String?
    /// The flow position, drawn once, here.
    var stepCounter: String?
    let title: String
    var lede: String?

    /// One label across the whole flow; "Done" appears only on the last screen.
    let primaryTitle: String
    var primaryDisabled: Bool = false
    /// `holdPrimary: "hidden"`: the primary keeps its seat invisibly so the band does not reflow.
    var primaryHidden: Bool = false
    let onPrimary: () -> Void
    /// A popover anchored on the primary. nil draws none.
    var primaryPopoverShown: Binding<Bool>?
    var primaryPopover: AnyView?
    /// The step's `autoCloseAfter`.
    @Environment(\.cardAutoClose) private var autoClose
    /// Plain text beside the pill, never a second pill.
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?
    /// Text by default; `.chevron` is for the closer, where a worded Back beside Finish would
    /// read as a second verb. A step's `backButtonKind` overrides either way.
    var secondaryStyle: SecondaryStyle = .text

    enum SecondaryStyle {
        case text, chevron

        /// The step key `backButtonKind`: "text" or "chevron"; nil for anything else.
        init?(authored: String?) {
            switch authored?.lowercased() {
            case "text": self = .text
            case "chevron": self = .chevron
            default: return nil
            }
        }
    }

    let accent: Color
    var wordmarkPath: String?
    /// The customer half of the two-brand lockup; non-nil opts the footer into it.
    var customerName: String?
    var customerMark: ProvisioningIdentity?
    /// Authored so it localizes; the shell never invents copy.
    var attribution: String?
    var logoHeight: CGFloat = ProvisioningM.wordmarkHeight
    var logoMaxWidth: CGFloat? = ProvisioningM.footerLogoMaxWidth
    var logoClearSpace: CGFloat = 0
    /// A screen with no door replaces the action run with a progress bar on the buttons'
    /// baseline. nil draws the action run.
    var footerProgress: Double?

    /// The footer's centre line, seated between the lockup and the actions. Carries the step's
    /// `footerNote`; nil or empty draws no line.
    var stateLine: String?

    /// The list and the band, given the whole window so each can pin its own band.
    @ViewBuilder let content: () -> Content

    @Environment(\.palette) private var palette

    /// `stateLine` with empty folded into absent; split out so the rule is testable without
    /// mounting SwiftUI.
    var resolvedStateLine: String? {
        guard let stateLine, !stateLine.isEmpty else { return nil }
        return stateLine
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            header
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Anchored to the bottom edge; the body's metrics stop at `footerRuleY`.
        .overlay(alignment: .bottom) { footerBand }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .topLeading) {
            // Eyebrow at the left, counter at the right, on one line.
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(size: ProvisioningM.eyebrowSize, weight: .semibold))
                    .tracking(ProvisioningM.eyebrowTracking)
                    .foregroundStyle(palette.textMuted)
                    .offset(x: ProvisioningM.rail, y: ProvisioningM.eyebrowY)
            }
            if let stepCounter {
                Text(stepCounter)
                    .font(.system(size: ProvisioningM.counterSize, weight: .medium,
                                  design: ProvisioningM.counterIsMonospaced ? .monospaced : .default))
                    .tracking(0.24)
                    .foregroundStyle(palette.textMuted)
                    .frame(width: metrics.column, alignment: .trailing)
                    .offset(x: ProvisioningM.rail, y: ProvisioningM.eyebrowY)
            }
            Text(title)
                .font(.system(size: ProvisioningM.titleSize, weight: .bold))
                .tracking(ProvisioningM.titleTracking)
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .frame(width: metrics.column, alignment: .leading)
                .offset(x: ProvisioningM.rail, y: ProvisioningM.titleY)
            if let lede {
                Text(lede)
                    .font(.system(size: ProvisioningM.ledeSize))
                    .lineSpacing(ProvisioningM.ledeLineSpacing)
                    .foregroundStyle(palette.textMuted)
                    // Hard ceiling: a third line collides with the list's top rule.
                    .lineLimit(ProvisioningM.ledeMaxLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: min(ProvisioningM.ledeMaxWidth, metrics.column), alignment: .leading)
                    .offset(x: ProvisioningM.rail, y: ProvisioningM.ledeY)
            }
        }
    }

    // MARK: - Footer

    /// The lockup line: customer mark, name, divider, attribution, vendor mark. Identical on
    /// every screen.
    @ViewBuilder private func lockup(_ name: String) -> some View {
        // `wordmarkPath` arrives fully resolved (`BrandArtwork.resolve`); the shell draws what it
        // is handed.
        BrandLockup(customer: customerMark, name: name, attribution: attribution,
                    vendorPath: wordmarkPath)
            .frame(height: ProvisioningM.footerRowHeight, alignment: .leading)
    }

    /// Lockup or mark, the state line and countdown in the free span, actions at the mirror.
    /// The rule runs edge to edge, ignoring the rail.
    private var footerBand: some View {
        FooterRow(rail: ProvisioningM.rail, rule: .over,
                  ruleInk: palette.text.opacity(ProvisioningM.footerRuleOpacity), gap: 0) {
            if let customerName {
                lockup(customerName)
            } else if let wordmarkPath {
                BrandMark(path: wordmarkPath,
                          box: BrandMarkBox(height: logoHeight, maxWidth: logoMaxWidth),
                          clearSpace: logoClearSpace)
            }
        } leading: {
            HStack(spacing: 0) {
                Spacer(minLength: 16)
                if let line = resolvedStateLine {
                    // `StateLine` is the shared drawing of `footerNote` across the chromes. One
                    // line: the band is a fixed height.
                    StateLine(text: line)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 16)
                }
                if let autoClose {
                    CardAutoCloseCountdown(model: autoClose)
                    Spacer(minLength: 16)
                }
            }
        } trailing: {
            if let footerProgress {
                // Right edge lands where the primary's would; the lockup keeps its place.
                MigrationFooterBar(fraction: footerProgress, accent: accent)
            } else if let secondaryTitle, let onSecondary {
                Group {
                    switch secondaryStyle {
                    case .text:
                        Door.word(ink: palette.text, size: 15,
                                  label: secondaryTitle, action: onSecondary)
                    case .chevron:
                        Door.back(plate: palette.text.opacity(0.08), ink: palette.text,
                                  label: secondaryTitle, action: onSecondary)
                    }
                }
                // The chevron carries no word, so it needs one for anyone not looking at it.
                .accessibilityLabel(secondaryTitle)
                .padding(.trailing, secondaryStyle == .chevron ? 14 : 24)
            }
            if footerProgress == nil {
                PrimaryActionButton(tint: accent, action: onPrimary) {
                    Text(primaryTitle)
                }
                .disabled(primaryDisabled || primaryHidden)
                // A hidden primary keeps its seat: invisible, untouchable, silent to VoiceOver.
                .opacity(primaryHidden ? 0 : 1)
                .allowsHitTesting(!primaryHidden)
                .accessibilityHidden(primaryHidden)
                .popover(isPresented: primaryPopoverShown ?? .constant(false), arrowEdge: .top) {
                    primaryPopover
                }
            }
        }
    }
}
