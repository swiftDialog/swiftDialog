//
//  PlainCenteredShell.swift
//  dialog
//
//  The `plain-centered` construction's frame: back-chevron band, body centred on both axes,
//  footer with a hairline rule. The shell owns the frame; each screen fills the body region.
//  Palette tokens only, no literal colours.
//

import SwiftUI

/// Geometry for the `plain-centered` shell and the screens it hosts. Sizes only, never theme.
/// Also carries the tile, card and progress-bar sizes that `PlainCenteredScreens.swift` draws.
enum PlainCenteredM {

    // MARK: - Window

    static let window = CGSize(width: 800, height: 688)

    // MARK: - Footer

    static let footerHeight: CGFloat = FooterBandM.band
    static let footerHorizontalPadding: CGFloat = FooterBandM.rail
    /// Seat height for the footer wordmark image.
    static let footerWordmarkHeight: CGFloat = 20

    // MARK: - Back chevron

    static let backChevronSize: CGFloat = 32
    static let backChevronTop: CGFloat = 46
    static let backChevronLeading: CGFloat = 26
    static let backChevronGlyphSize: CGFloat = 13
    /// Reserved whether or not the chevron draws, so the body never shifts between screens.
    static let topBandHeight: CGFloat = backChevronTop + backChevronSize

    // MARK: - Body padding

    static let bodyPadding = EdgeInsets(top: 88, leading: 64, bottom: 64, trailing: 64)
    /// The list screen's budget: 688 − 78 top band − 84 footer leaves 526; the list stack is 430.5.
    static let bodyPaddingList = EdgeInsets(top: 56, leading: 64, bottom: 32, trailing: 64)

    // MARK: - Hero / row tiles

    static let heroSize: CGFloat = 104
    /// The hero beside the list, smaller so the list has room.
    static let heroSizeCompact: CGFloat = 76
    static let rowTileSize: CGFloat = 46

    // MARK: - List card

    static let cardWidth: CGFloat = 500
    static let cardRadius: CGFloat = 14
    /// Fixed; the card scrolls internally. Three rows of `16 + 46 + 16`.
    static let cardHeight: CGFloat = 234

    // MARK: - Progress bar

    static let progressBarSize = CGSize(width: 340, height: 7)
}

/// The `plain-centered` frame: a back-chevron band, a body region centred on both axes, and a
/// footer with a hairline top rule.
struct PlainCenteredShell<Content: View>: View {
    var showsBack: Bool = false
    /// Localized back label for VoiceOver; `nil` falls back to "Back".
    var backLabel: String?
    var onBack: (() -> Void)?
    let buttonTitle: String
    /// A disabled primary stays visible and greyed rather than disappearing.
    var buttonDisabled: Bool = false
    let onPrimaryAction: () -> Void
    /// The flow's resolved accent, the primary button's tint. Required so a call site cannot fall
    /// back to the system accent by omission.
    let accent: Color
    /// The footer wordmark's resolved path. Pass `BrandArtwork.resolve(_:isDark:gate: .footer)`,
    /// which also gates on a `bottom*` logo position so `PhaseContainer` and this footer never
    /// both draw the mark; never read `imagePath` directly.
    var logoPath: String?
    /// `logoConfig.maxHeight`, else this construction's constant.
    var logoHeight: CGFloat = PlainCenteredM.footerWordmarkHeight
    /// `logoConfig.maxWidth`; nil is height-only sizing. Marks are sized by trimmed content, so a
    /// wide wordmark follows its aspect ratio unless this bounds it.
    var logoMaxWidth: CGFloat?

    /// `logoConfig.logoClearSpace`, handed to `BrandMark`.
    var logoClearSpace: CGFloat = 0
    /// The caller picks `PlainCenteredM.bodyPaddingList` for the list screen.
    var bodyPadding: EdgeInsets = PlainCenteredM.bodyPadding
    @ViewBuilder let content: () -> Content

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            topBand
            // A body taller than its region is clipped rather than pushing the footer out.
            content()
                .padding(bodyPadding)
                .frame(maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
            footerBand
        }
    }

    /// The back chevron, or nothing; the band's height never changes.
    private var topBand: some View {
        ZStack(alignment: .topLeading) {
            if showsBack, let onBack {
                Door.back(plate: palette.surfaceRaised, ink: palette.text,
                          label: backLabel ?? "Back", action: onBack)
                    .accessibilityLabel(backLabel ?? "Back")
                .padding(.top, PlainCenteredM.backChevronTop)
                .padding(.leading, PlainCenteredM.backChevronLeading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: PlainCenteredM.topBandHeight)
    }

    /// Wordmark leading, primary action trailing. The primary goes through `PrimaryActionButton`
    /// so it picks up the Return-key default, the footer control size and the button shape.
    private var footerBand: some View {
        FooterRow(rail: PlainCenteredM.footerHorizontalPadding, rule: .over) {
            if let logoPath {
                BrandMark(path: logoPath, box: BrandMarkBox(height: logoHeight, maxWidth: logoMaxWidth),
                          clearSpace: logoClearSpace)
            }
        } leading: {
            EmptyView()
        } trailing: {
            PrimaryActionButton(tint: accent, action: onPrimaryAction) {
                Text(buttonTitle)
            }
            .disabled(buttonDisabled)
        }
    }
}
