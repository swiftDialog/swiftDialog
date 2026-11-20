//
//  ActionFooterRow.swift
//  dialog
//
//  Main-phase footer for Presets 1 and 2: brand seat, install-details link and claim on the leading end,
//  the button area on the trailing end, seated in `FooterRow`'s slots. Preset 2 passes its variant knobs.

import SwiftUI

struct ActionFooterRow: View {
    @ObservedObject var state: InspectState
    let tint: Color
    let scaleFactor: CGFloat
    /// Opens a configured detailOverlay instead of the popover, when `infoOpensDetailOverlay` allows it.
    let onShowDetailOverlay: () -> Void
    var onButton1Action: (() -> Void)?
    var infoOpensDetailOverlay: Bool = true
    var popoverArrowEdge: Edge? = .top
    /// With these set, button exits remove the readiness file; an orchestrator waiting on that
    /// removal would otherwise hang on a config with no `summaryScreen`.
    var config: InspectConfig?
    var triggerFilePath: String?
    /// The flow's claim, centred in the free span between the link and the buttons so it never
    /// touches either. Preset 2 passes `config.footerText`; nil renders nothing.
    var centerText: String?

    @State private var showingAboutPopover = false
    /// The help control, seated after the details link when the preset provides one.
    @Environment(\.cardHeaderHelp) private var help
    @Environment(\.palette) private var palette
    /// Picks the dark wordmark file in `footerPath`; a file choice the palette cannot make.
    @Environment(\.colorScheme) private var scheme

    /// The brand seat. `PhaseContainer` hides its logo overlay when the position resolves to `.footer`,
    /// so this row must draw the mark. Same `FooterBrandSeat` as Preset 3, which scales the mark into the row.
    private var logoPath: String? {
        BrandArtwork.resolve(state.config?.logoConfig, isDark: scheme == .dark, gate: .footer)
    }

    var body: some View {
        FooterRow(rail: InspectMetrics(scale: scaleFactor).phaseFooterHorizontal, gap: 0) {
            if let logoPath {
                // The 8 gap is this row's spacing between the mark and the link.
                FooterBrandSeat(path: logoPath,
                                height: CGFloat(state.config?.logoConfig?.maxHeight ?? 22),
                                clearSpace: state.config?.logoConfig?.clearSpace ?? 0,
                                scale: scaleFactor, gap: 8)
            }
        } leading: {
            HStack(spacing: 0) {
                Button(state.uiConfiguration.popupButtonText) {
                    if infoOpensDetailOverlay, state.config?.detailOverlay != nil {
                        onShowDetailOverlay()
                    } else {
                        showingAboutPopover.toggle()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(tint)
                .font(.system(size: 13))
                .popover(isPresented: $showingAboutPopover, arrowEdge: popoverArrowEdge) {
                    InstallationInfoPopoverView(inspectState: state)
                }

                if let help {
                    HelpGlyphButton(icon: help.icon, tooltip: help.tooltip, tint: tint,
                                    action: help.action)
                        .padding(.leading, 10)
                        .preference(key: CardHeaderHelpSeatedKey.self, value: true)
                }

                if let centerText {
                    Spacer(minLength: 16)
                    Text(centerText)
                        .font(.system(size: 12))
                        .foregroundStyle(palette.textFaint)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                    Spacer(minLength: 16)
                }
            }
            // The free span goes to this slot, so the two Spacers centre the claim between link and buttons.
        } trailing: {
            PresetCommonViews.buttonArea(
                state: state,
                tintColor: tint,
                onButton1Action: onButton1Action,
                config: config,
                triggerFilePath: triggerFilePath
            )
        }
    }
}
