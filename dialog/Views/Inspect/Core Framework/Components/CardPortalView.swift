//
//  CardPortalView.swift
//  dialog
//
//  The portal step in the card design language: one web view given the whole window (no title
//  bar, no horizontal inset, since narrow widths make sites serve their mobile layout) over the
//  setup-assistant footer row. The stage is injected so the web view and its load state stay
//  with the arm that owns them.
//

import SwiftUI

/// Everything the bands need, already resolved; the URL chain, load state and exit contracts
/// are the arm's business.
struct CardPortalModel {
    let title: String?
    let layout: PortalLayout
    /// Where the view is, falling back to the configured URL before the first navigation commits.
    let displayURL: URL?
    let isLoading: Bool
    let footerText: String?
    /// Authored footer background, or nil for the card's own surface.
    let footerBackground: Color?
    /// Authored footer text colour, or nil for the muted token.
    let footerTextColor: Color?
    /// Drawn 18pt tall at its own aspect, never recoloured.
    let logoPath: String?
    let accent: Color
    let doneText: String
    /// nil hides Back. Not gated on the step index: at index 0 the arm's handler treats Back as
    /// the exit-code-2 cancel, which gating would make unreachable.
    let backText: String?
    /// nil hides Skip.
    let skipText: String?
    /// False only when a failure is on screen and Skip can carry the user forward instead; a
    /// failure never disables the only way out.
    let doneEnabled: Bool

    /// The footer carries the browser escape for every layout; there is no title bar to hold it.
    var footerRepeatsEscape: Bool { layout.footerRepeatsEscape }
}

struct CardPortalView<Stage: View>: View {
    @Environment(\.palette) private var palette
    let model: CardPortalModel
    var scaleFactor: CGFloat = 1.0
    let onRefresh: () -> Void
    /// nil when no Skip is authored; the button is absent, not disabled.
    let onSkip: (() -> Void)?
    let onBack: (() -> Void)?
    let onDone: () -> Void
    @ViewBuilder let stage: () -> Stage

    var body: some View {
        VStack(spacing: 0) {
            stage()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The setup-assistant footer row with one extra seat: mark, address pill, reload, Skip, Back,
    /// Done. Every figure is `SetupAssistantM`'s; the band height is what `PortalGeometry` reserves.
    private var footer: some View {
        FooterRow(rail: SetupAssistantM.rail * scaleFactor, rule: .over,
                  ruleInk: palette.text.opacity(SetupAssistantM.footerRuleBeta),
                  fill: model.footerBackground ?? palette.cardSurface,
                  gap: SetupAssistantM.footerGap) {
            if let logoPath = model.logoPath {
                BrandLogoImage(path: logoPath,
                               height: SetupAssistantM.footerLogoHeight,
                               opacity: SetupAssistantM.footerLogoOpacity)
                    .padding(.trailing, SetupAssistantM.footerGap)
            }
        } leading: {
            // Before the first navigation resolves a URL the slot shows the brand text, not an
            // empty pill.
            switch portalFooterLead(hasURL: model.displayURL != nil,
                                    hasFooterText: model.footerText != nil) {
            case .address:
                if let url = model.displayURL {
                    // The pill takes the slack so a long path truncates as late as the row allows.
                    PortalAddressPill(url: url, isLoading: model.isLoading,
                                      accent: model.accent, scaleFactor: scaleFactor)
                        .frame(maxWidth: .infinity)
                }
            case .brandText:
                if let footerText = model.footerText {
                    Text(footerText)
                        .font(.system(size: SetupAssistantM.footerLineSize * scaleFactor))
                        .foregroundStyle(model.footerTextColor ?? palette.textFaint)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            case .nothing:
                EmptyView()
            }
        } trailing: {
            HStack(spacing: SetupAssistantM.footerDoorGap) {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14 * scaleFactor, weight: .medium))
                        .frame(width: PortalAddressPill.height * scaleFactor,
                               height: PortalAddressPill.height * scaleFactor)
                }
                .buttonStyle(.borderless)
                .disabled(model.isLoading)
                .help("Reload this page")
                // Skip stays live through a failure.
                if let skipText = model.skipText, let onSkip {
                    Door.pill(.large, label: skipText, action: onSkip)
                }
                if let backText = model.backText, let onBack {
                    Door.pill(.large, label: backText, action: onBack)
                        .help(backText)
                }
                PrimaryActionButton(tint: model.accent, controlSize: .large, action: onDone) {
                    Text(model.doneText)
                }
                .disabled(!model.doneEnabled)
            }
            // The doors never yield width to the address; the address truncates instead.
            .fixedSize()
        }
        .tint(model.accent)
    }
}
