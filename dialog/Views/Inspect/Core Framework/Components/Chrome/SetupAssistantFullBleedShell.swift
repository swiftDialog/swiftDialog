//
//  SetupAssistantFullBleedShell.swift
//  dialog
//
//  The full-bleed Setup Assistant shell (state α): the picture is the payload and the words sit in
//  a scrim over it; BrandGroundFallback is its ground when no artwork is authored.
//

import SwiftUI

/// State α, full-bleed: the picture is the payload, text sits in the scrim, the background is black.
struct SetupAssistantFullBleedShell<Media: View>: View {
    let title: String
    var lede: String?
    var capsule: SetupAssistantCapsule = .none

    /// Which way the scrim ramps. Default `.dark`.
    var ground: SetupAssistantGround = .dark
    /// How the ground is built. Default `.ramp`.
    var groundStyle: SetupAssistantGroundStyle = .ramp
    /// How the screen is arranged. Default `.stack`.
    var arrangement: SetupAssistantArrangement = .stack
    /// The centred arrangement's icon tile: the step's `heroImage` (file path or SF Symbol); nil omits it.
    var heroImage: String?
    /// The content arrangement's model, when the step authors one.
    var content: SetupAssistantContent?
    /// The content arrangement's tag chip (the step's `eyebrow`); nil draws no chip.
    var tag: String?
    /// The `.status` pill: the phase and its detail line.
    var statusTitle: String?
    var statusDetail: String?
    /// The `.status` bar, 0…1, inside the centred column.
    var statusProgress: Double?
    /// `stepCounterPlacement: "dots"`: the rail's position and length; nil draws no rail.
    var dots: (index: Int, count: Int)?
    /// The customer mark on the footer's left, so a screen that takes over the display says who is asking.
    var logoPath: String?
    /// The footer's state line ("how long, and who do I ask"), per screen.
    var footerLine: String?
    /// The primary door, in the footer.
    var primaryTitle: String?
    /// Shown greyed on the wait screen, so nothing appears between steps.
    var primaryDisabled: Bool = false
    /// Division mode's `holdPrimary: "hidden"`: no door until the last item lands.
    var primaryHidden: Bool = false
    var onPrimary: (() -> Void)?
    /// The footer mark's height: `logoConfig.maxHeight` when authored, capped by the seat.
    var logoHeight: CGFloat = SetupAssistantM.footerLogoHeight
    /// The line under the glass track, from root key `supportText`; nil draws nothing.
    var supportLine: String?
    /// The glass header's "N / M" counter (`showGridCounter`). Default true.
    var showCounter: Bool = true
    /// The quiet door ("What changes?"), a pill in the footer row.
    var secondaryTitle: String?
    var onSecondary: (() -> Void)?
    /// The back door, leftmost; nil omits it.
    var backLabel: String?
    var onBack: (() -> Void)?
    /// The flow's accent for the one door.
    let accent: Color
    @ViewBuilder var media: () -> Media

    @Environment(\.palette) private var palette

    /// The ramp's height, chosen by what the capsule carries. Internal so a test pins it: journey 420,
    /// standard 380.
    var scrimHeight: CGFloat {
        // A bar is shorter than three marks.
        if case .progress = capsule { return SetupAssistantM.scrimShort }
        // 52pt rows need a taller ramp than 28pt marks.
        if case .checklist = capsule { return SetupAssistantM.scrimJourney }
        // The grid capsule is about five rows tall, so it takes the journey ramp too.
        if case .cardGrid = capsule { return SetupAssistantM.scrimJourney }
        return SetupAssistantM.scrimTall
    }

    var body: some View {
        // Pinned to `hostHeight` (the window including its chrome), not the 600 asked for, so the footer
        // reaches the window's bottom. A constant, not a GeometryReader read (see `windowChrome`). Width
        // is pinned so a wide `.fill` picture cannot push the 40 rail off the left edge.
        ZStack(alignment: .bottomLeading) {
            if isGlass {
                // Ground first, then the top-anchored glass arrangement at `JourneyGlassM`'s y positions.
                switch groundStyle {
                case .banded:
                    palette.cardSurface
                    VStack(spacing: 0) {
                        accent.frame(height: JourneyGlassM.bandFoot)
                        Rectangle()
                            .fill(palette.text.opacity(SetupAssistantM.bandRuleAlpha))
                            .frame(height: SetupAssistantM.bandRuleWidth)
                        Spacer(minLength: 0)
                    }
                case .plain:
                    palette.cardSurface
                case .ramp:
                    Color.black.overlay { media() }.clipped()
                    scrim
                }
                glassArrangement
            } else if arrangement == .content {
                // Content arrangement: the ground, then the left-aligned header and content model.
                switch groundStyle {
                case .banded:
                    palette.cardSurface
                    VStack(spacing: 0) {
                        accent.frame(height: JourneyGlassM.bandFoot)
                        Rectangle().fill(palette.text.opacity(SetupAssistantM.bandRuleAlpha))
                            .frame(height: SetupAssistantM.bandRuleWidth)
                        Spacer(minLength: 0)
                    }
                case .plain:
                    palette.cardSurface
                case .ramp:
                    Color.black.overlay { media() }.clipped()
                    scrim
                }
                contentArrangement
            } else if arrangement != .stack {
                // Centred arrangement on any ground.
                switch groundStyle {
                case .banded:
                    palette.cardSurface
                    VStack(spacing: 0) {
                        accent.frame(height: JourneyGlassM.bandFoot)
                        Rectangle().fill(palette.text.opacity(SetupAssistantM.bandRuleAlpha))
                            .frame(height: SetupAssistantM.bandRuleWidth)
                        Spacer(minLength: 0)
                    }
                case .plain:
                    palette.cardSurface
                case .ramp:
                    Color.black.overlay { media() }.clipped()
                    scrim
                }
                centeredArrangement
            } else if groundStyle == .banded {
                // The band is drawn by the stack, which knows where the copy ends and the capsule begins.
                palette.cardSurface
                bandedStack
            } else if groundStyle == .plain {
                // Plain surface: no ground behind the copy and no capsule box (see `capsuleBox`).
                palette.cardSurface
                stack
            } else {
            // Media bleeds to all four edges over black, so a non-covering still letterboxes into the shell.
            // An overlay, not a sibling, so the oversized picture cannot set the shell's size.
            Color.black
                .overlay { media() }
                .clipped()
            scrim
            stack
            }
            SetupAssistantFooter(
                surface: .alpha,
                ground: ground,
                logoPath: logoPath,
                line: footerLine,
                primaryTitle: primaryTitle,
                primaryDisabled: primaryDisabled,
                primaryHidden: primaryHidden,
                onPrimary: onPrimary,
                logoOpacity: groundStyle == .ramp ? SetupAssistantM.footerLogoOpacity : 1,
                logoHeight: logoHeight,
                secondaryTitle: secondaryTitle,
                onSecondary: onSecondary,
                backLabel: backLabel,
                onBack: onBack,
                accent: accent)
        }
        .frame(width: SetupAssistantM.recommended.width, height: SetupAssistantM.hostHeight)
        .clipShape(RoundedRectangle(cornerRadius: SetupAssistantM.frameRadius, style: .continuous))
        // After the frame, so the transparent title bar region is painted too.
        .ignoresSafeArea()
    }

    /// Transparent → `scrimEndOpacity` (.95); text starts past 60%. See `scrimTall`.
    private var scrim: some View {
        // Same geometry and stops on both grounds; only the end colour changes.
        let ink: Color = ground.isDark ? .black : .white
        return LinearGradient(
            stops: [
                .init(color: ink.opacity(0), location: 0),
                .init(color: ink.opacity(SetupAssistantM.scrimMidOpacity),
                      location: SetupAssistantM.scrimMidStop),
                .init(color: ink.opacity(SetupAssistantM.scrimEndOpacity), location: 1)],
            startPoint: .top, endPoint: .bottom)
        .frame(height: scrimHeight)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    /// White on the dark ramp; the palette's text on the light one (a light ramp may sit in a dark window).
    private var stackInk: Color { ground.isDark ? .white : palette.text }

    /// The capsule's glass ink: opposite the ground, so the box stays visible on either ramp.
    private var glassInk: Color { ground.isDark ? .white : .black }

    private var stack: some View {
        VStack(alignment: .leading, spacing: SetupAssistantM.stackGap) {
            Text(title)
                .font(.system(size: SetupAssistantM.titleSize, weight: .bold))
                .tracking(SetupAssistantM.titleTracking)
                .foregroundStyle(stackInk)
            if let lede {
                Text(lede)
                    .font(.system(size: SetupAssistantM.ledeSize))
                    .foregroundStyle(stackInk.opacity(SetupAssistantM.ledeOpacity))
                    // Two lines at 560 wide.
                    .lineLimit(2)
                    .frame(width: SetupAssistantM.ledeMaxWidth, alignment: .leading)
            }
            capsuleView
        }
        .padding(.horizontal, SetupAssistantM.rail)
        // Content clears the footer band by 24.
        .padding(.bottom, SetupAssistantM.footerHeight + SetupAssistantM.footerClearance)
    }

    /// The centred column, with the status pill above it for `.status`. One stack: a Spacer with a
    /// `dotClearance` floor sits above the bottom-anchored rail, so a tall capsule pushes the rail
    /// instead of overlapping it.
    @ViewBuilder private var centeredArrangement: some View {
        let hasTile = arrangement == .centered && heroImage != nil
        let top = arrangement == .status ? SetupAssistantMetrics.columnTopStatus
            : (hasTile ? SetupAssistantMetrics.columnTopWithTile : SetupAssistantMetrics.columnTop)
        ZStack(alignment: .top) {
            if arrangement == .status, let statusTitle, !statusTitle.isEmpty {
                statusPill(statusTitle, detail: statusDetail)
                    .padding(.top, SetupAssistantMetrics.statusTop)
            }
            VStack(spacing: 0) {
                VStack(spacing: SetupAssistantMetrics.tileGap) {
                    if hasTile, let heroImage {
                        iconTile(heroImage)
                    }
                    VStack(spacing: SetupAssistantMetrics.titleGap) {
                        Text(title)
                            .font(.system(size: hasTile ? SetupAssistantMetrics.titleWithTile
                                                        : SetupAssistantMetrics.title, weight: .bold))
                            .tracking(SetupAssistantM.titleTracking)
                            .foregroundStyle(stackInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if let lede {
                            // Vertical fixedSize keeps a wrapping lede from being truncated to one line.
                            Text(lede)
                                .font(.system(size: SetupAssistantMetrics.ledeSize))
                                .foregroundStyle(stackInk.opacity(SetupAssistantM.ledeOpacity))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: SetupAssistantMetrics.ledeMaxWidth)
                        }
                        if arrangement == .status, let statusProgress {
                            AccentProgressCapsule(progress: statusProgress, accent: accent,
                                                  height: SetupAssistantMetrics.barHeight,
                                                  track: stackInk.opacity(SetupAssistantM.barTrack),
                                                  animation: .easeInOut(duration: 0.35))
                            .frame(width: SetupAssistantMetrics.barWidth)
                            .padding(.top, SetupAssistantMetrics.barGap - SetupAssistantMetrics.titleGap)
                            .accessibilityIdentifier("wait-progress")
                        }
                    }
                    capsuleView
                }
                .frame(width: SetupAssistantM.column)
                .padding(.top, top)
                if let dots {
                    Spacer(minLength: SetupAssistantMetrics.dotClearance)
                    dotRail(index: dots.index, count: dots.count)
                        .padding(.bottom, SetupAssistantMetrics.dotsBottom - SetupAssistantMetrics.dotHeight)
                } else {
                    Spacer(minLength: 0)
                }
            }
        }
        // Pinned to `hostHeight` so an arrangement that outgrows the frame cannot push the footer off the window.
        .frame(width: SetupAssistantM.recommended.width,
               height: SetupAssistantM.hostHeight, alignment: .top)
    }

    /// The content arrangement: header block, content model, then the rail.
    @ViewBuilder private var contentArrangement: some View {
        VStack(alignment: .leading, spacing: SetupAssistantMetrics.headerBlockGap) {
            VStack(alignment: .leading, spacing: SetupAssistantMetrics.headerGap) {
                if let tag, !tag.isEmpty {
                    Text(tag)
                        .font(.system(size: SetupAssistantMetrics.tagSize, weight: .semibold))
                        .foregroundStyle(accent)
                        .padding(.horizontal, SetupAssistantMetrics.tagPadH)
                        .frame(height: SetupAssistantMetrics.tagHeight)
                        .background(RoundedRectangle(cornerRadius: SetupAssistantMetrics.tagRadius)
                            .fill(accent.opacity(SetupAssistantMetrics.tagFillOpacity)))
                }
                Text(title)
                    .font(.system(size: SetupAssistantMetrics.contentTitleSize, weight: .bold))
                    .tracking(SetupAssistantM.titleTracking)
                    .foregroundStyle(stackInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let lede {
                    Text(lede)
                        .font(.system(size: SetupAssistantMetrics.contentLedeSize))
                        .foregroundStyle(stackInk.opacity(SetupAssistantM.ledeOpacity))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: SetupAssistantMetrics.contentLedeMaxWidth, alignment: .leading)
                }
            }
            switch content {
            case .features(let rows):   featureGrid(rows)
            case .permissions(let rows): permissionList(rows)
            case .none:                  EmptyView()
            }
            Spacer(minLength: 0)
            if let dots {
                dotRail(index: dots.index, count: dots.count)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, SetupAssistantMetrics.dotsBottom
                             - SetupAssistantMetrics.contentBottom - SetupAssistantMetrics.dotHeight)
            }
        }
        .frame(width: SetupAssistantM.column, alignment: .leading)
        .padding(.top, SetupAssistantMetrics.contentTop)
        .padding(.bottom, SetupAssistantMetrics.contentBottom)
        // Pinned to `hostHeight` so an arrangement that outgrows the frame cannot push the footer off the window.
        .frame(width: SetupAssistantM.recommended.width,
               height: SetupAssistantM.hostHeight, alignment: .top)
    }

    /// Three columns of cards, each a glyph zone over a hairline over its label.
    private func featureGrid(_ rows: [ProvisioningRowModel]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: SetupAssistantMetrics.featureGap),
                            count: SetupAssistantMetrics.featureColumns)
        return LazyVGrid(columns: columns, spacing: SetupAssistantMetrics.featureGap) {
            ForEach(rows) { row in
                VStack(spacing: 0) {
                    ZStack {
                        // A row's art may be an installed `.app`, drawn as its icon.
                        if let image = ItemArt.image(at: row.art) {
                            Image(nsImage: image).resizable().scaledToFit()
                                .frame(width: SetupAssistantMetrics.featureGlyph,
                                       height: SetupAssistantMetrics.featureGlyph)
                        } else {
                            Text(String(row.name.prefix(1)).uppercased())
                                .font(.system(size: SetupAssistantMetrics.featureGlyph * 0.7, weight: .semibold))
                                .foregroundStyle(stackInk.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: SetupAssistantMetrics.featureGlyphZone)
                    Rectangle().fill(glassInk.opacity(SetupAssistantMetrics.featureStrokeOpacity))
                        .frame(height: 1)
                    Text(row.name)
                        .font(.system(size: SetupAssistantMetrics.featureLabelSize, weight: .semibold))
                        .foregroundStyle(stackInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SetupAssistantMetrics.featureLabelPadH)
                        .padding(.vertical, SetupAssistantMetrics.featureLabelPadV)
                }
                .background(RoundedRectangle(cornerRadius: SetupAssistantMetrics.featureRadius, style: .continuous)
                    .fill(glassInk.opacity(SetupAssistantMetrics.featureFillOpacity))
                    .overlay(RoundedRectangle(cornerRadius: SetupAssistantMetrics.featureRadius, style: .continuous)
                        .strokeBorder(glassInk.opacity(SetupAssistantMetrics.featureStrokeOpacity), lineWidth: 0.5)))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.name)
            }
        }
    }

    /// One row per permission: tile, name and description, and the row's trailing state.
    private func permissionList(_ rows: [ProvisioningRowModel]) -> some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(spacing: SetupAssistantMetrics.permissionGap) {
                    ZStack {
                        // A row's art may be an installed `.app`, drawn as its icon.
                        if let image = ItemArt.image(at: row.art) {
                            Image(nsImage: image).resizable().scaledToFit()
                                .frame(width: SetupAssistantMetrics.permissionGlyph,
                                       height: SetupAssistantMetrics.permissionGlyph)
                        } else {
                            Text(String(row.name.prefix(1)).uppercased())
                                .font(.system(size: SetupAssistantMetrics.permissionGlyph * 0.8, weight: .semibold))
                                .foregroundStyle(stackInk.opacity(0.7))
                        }
                    }
                    .frame(width: SetupAssistantMetrics.permissionTile, height: SetupAssistantMetrics.permissionTile)
                    .background(RoundedRectangle(cornerRadius: SetupAssistantMetrics.permissionTileRadius,
                                                 style: .continuous)
                        .fill(glassInk.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.name)
                            .font(.system(size: SetupAssistantMetrics.permissionTitleSize, weight: .semibold))
                            .foregroundStyle(stackInk)
                        if let detail = row.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: SetupAssistantMetrics.permissionDetailSize))
                                .foregroundStyle(stackInk.opacity(0.55))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: SetupAssistantMetrics.permissionGap)
                    permissionTrailing(row)
                }
                .padding(.vertical, SetupAssistantMetrics.permissionPadV)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(glassInk.opacity(SetupAssistantMetrics.permissionDividerOpacity))
                        .frame(height: 1)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// A done row reads as granted in the accent; anything else shows its word. The footer door is the control.
    @ViewBuilder private func permissionTrailing(_ row: ProvisioningRowModel) -> some View {
        switch row.trailing {
        case .state(let word, let failed):
            HStack(spacing: 6) {
                if row.mark == .done {
                    Image(systemName: "checkmark")
                        .font(.system(size: SetupAssistantMetrics.permissionTrailingSize, weight: .semibold))
                }
                Text(word)
            }
            .font(.system(size: SetupAssistantMetrics.permissionTrailingSize, weight: .medium))
            .foregroundStyle(failed ? palette.warning : (row.mark == .done ? accent : stackInk.opacity(0.4)))
        case .notice(let word):
            Text(word)
                .font(.system(size: SetupAssistantMetrics.permissionTrailingSize, weight: .medium))
                .foregroundStyle(palette.notice)
        case .identity, .toggle, .none:
            // The mark decides: done is granted, anything else is still required.
            if row.mark == .done {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: SetupAssistantMetrics.permissionTrailingSize, weight: .semibold))
                    Text("Granted")
                }
                .font(.system(size: SetupAssistantMetrics.permissionTrailingSize, weight: .medium))
                .foregroundStyle(accent)
            } else {
                Text("Required")
                    .font(.system(size: SetupAssistantMetrics.permissionTrailingSize, weight: .medium))
                    .foregroundStyle(stackInk.opacity(0.4))
            }
        }
    }

    /// The centred arrangement's 88pt tile: a file or SF Symbol on lifted glass.
    private func iconTile(_ hero: String) -> some View {
        RoundedRectangle(cornerRadius: SetupAssistantMetrics.tileRadius, style: .continuous)
            .fill(glassInk.opacity(SetupAssistantMetrics.tileFillOpacity))
            .overlay(
                RoundedRectangle(cornerRadius: SetupAssistantMetrics.tileRadius, style: .continuous)
                    .strokeBorder(glassInk.opacity(SetupAssistantMetrics.tileStrokeOpacity), lineWidth: 0.5))
            .overlay {
                if hero.hasPrefix("/"), let image = InspectImageCache.shared.image(atPath: hero) {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(width: SetupAssistantMetrics.tileGlyph, height: SetupAssistantMetrics.tileGlyph)
                } else {
                    Image(systemName: hero)
                        .font(.system(size: SetupAssistantMetrics.tileGlyph * 0.62, weight: .regular))
                        .foregroundStyle(stackInk)
                }
            }
            .frame(width: SetupAssistantMetrics.tileSide, height: SetupAssistantMetrics.tileSide)
    }

    /// The status pill: the phase, with its count line underneath.
    private func statusPill(_ text: String, detail: String?) -> some View {
        HStack(spacing: SetupAssistantMetrics.statusGap) {
            VStack(alignment: .leading, spacing: 1) {
                Text(text)
                    .font(.system(size: SetupAssistantMetrics.statusTitleSize, weight: .medium))
                    .foregroundStyle(stackInk)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: SetupAssistantMetrics.statusDetailSize))
                        .foregroundStyle(stackInk.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, SetupAssistantMetrics.statusPadH)
        .frame(height: SetupAssistantMetrics.statusHeight)
        .background(
            Capsule().fill(glassInk.opacity(SetupAssistantM.capsuleFill))
                .overlay(Capsule().strokeBorder(glassInk.opacity(SetupAssistantM.capsuleStroke), lineWidth: 0.5)))
        .accessibilityIdentifier("status-pill")
    }

    /// `stepCounterPlacement: "dots"`: the current step wide, the rest short, in the accent.
    private func dotRail(index: Int, count: Int) -> some View {
        HStack(spacing: SetupAssistantMetrics.dotGap) {
            ForEach(0..<max(count, 0), id: \.self) { i in
                Capsule()
                    .fill(i == index ? accent : stackInk.opacity(SetupAssistantMetrics.dotIdleOpacity))
                    .frame(width: i == index ? SetupAssistantMetrics.dotActiveWidth : SetupAssistantMetrics.dotWidth,
                           height: SetupAssistantMetrics.dotHeight)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(index + 1) of \(count)")
        .accessibilityIdentifier("step-dots")
    }

    /// Whether the capsule is the glass grid.
    private var isGlass: Bool {
        if case .cardGrid(_, _, _, _, let style, _) = capsule { return style == .glass }
        return false
    }

    /// The header's ink on the glass arrangement: white on the band (the header sits inside it),
    /// the ground's own ink otherwise.
    private var glassHeaderInk: Color { groundStyle == .banded ? Color.white : stackInk }

    /// The glass arrangement, top-anchored at fixed y positions in the 724-wide glass column (48 rails);
    /// the support line centres in it and the footer keeps the band's 40.
    @ViewBuilder private var glassArrangement: some View {
        if case .cardGrid(let rows, let total, let columns, let progress, _, let done) = capsule {
            let column = JourneyGlassM.column
            // Count items, not cards: in division mode the seat passes the item count.
            let completed = done ?? rows.filter(JourneyScroll.isTerminal).count
            ZStack(alignment: .top) {
                HStack(alignment: .top, spacing: SetupAssistantM.footerGap) {
                    VStack(alignment: .leading, spacing: JourneyGlassM.headerGap) {
                        Text(title)
                            .font(.system(size: JourneyGlassM.titleSize, weight: .bold))
                            .tracking(JourneyGlassM.titleTracking)
                            .foregroundStyle(glassHeaderInk)
                        if let lede {
                            Text(lede)
                                .font(.system(size: JourneyGlassM.ledeSize))
                                .foregroundStyle(glassHeaderInk.opacity(SetupAssistantM.ledeOpacity))
                                .lineLimit(2)
                                .frame(maxWidth: JourneyGlassM.ledeMaxWidth, alignment: .leading)
                        }
                    }
                    Spacer(minLength: 0)
                    // "9 / 20", monospaced, in the header's right seat.
                    if showCounter {
                        Text("\(completed) / \(total ?? rows.count)")
                            .font(.system(size: JourneyGlassM.counterSize, weight: .medium, design: .monospaced))
                            .foregroundStyle(glassHeaderInk.opacity(JourneyGlassM.counterOpacity))
                            .padding(.top, 2)
                            .accessibilityIdentifier("grid-counter")
                    }
                }
                .frame(width: column)
                .padding(.top, JourneyGlassM.headerTop)
                // The row at `JourneyGlassM.rowTop`; the track and support line follow by fixed gaps.
                VStack(spacing: 0) {
                    JourneyGlassRow(rows: rows, accent: accent, width: column, columns: columns)
                    if let progress {
                        JourneyGlassTrack(progress: progress, accent: accent, width: column)
                            .padding(.top, JourneyGlassM.trackGap)
                    }
                    if let supportLine, !supportLine.isEmpty {
                        // The sentence stays quiet; the address inside it takes the accent.
                        Text(SupportLineText.attributed(supportLine, emphasis: accent,
                                                        size: JourneyGlassM.supportSize))
                            .font(.system(size: JourneyGlassM.supportSize))
                            .foregroundStyle(stackInk.opacity(JourneyGlassM.supportOpacity))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: JourneyGlassM.supportMaxWidth)
                            .frame(width: column)
                            .padding(.top, JourneyGlassM.supportGap)
                    }
                }
                .padding(.top, JourneyGlassM.rowTop)
            }
            .frame(width: SetupAssistantM.recommended.width, alignment: .top)
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    /// `.banded`: a band from the top edge to the copy, the rule, then the capsule on the window surface.
    /// A Spacer in the band keeps the boundary `bandGap` above whatever capsule the screen carries.
    private var bandedStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: SetupAssistantM.stackGap) {
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: SetupAssistantM.titleSize, weight: .bold))
                    .tracking(SetupAssistantM.titleTracking)
                    // Fixed white in both appearances: the ink sits on the brand, not the window.
                    .foregroundStyle(Color.white)
                if let lede {
                    Text(lede)
                        .font(.system(size: SetupAssistantM.ledeSize))
                        .foregroundStyle(Color.white.opacity(SetupAssistantM.ledeOpacity))
                        .lineLimit(2)
                        .frame(width: SetupAssistantM.ledeMaxWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, SetupAssistantM.rail)
            .padding(.bottom, SetupAssistantM.bandPadBottom)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent)
            Rectangle()
                .fill(palette.text.opacity(SetupAssistantM.bandRuleAlpha))
                .frame(height: SetupAssistantM.bandRuleWidth)
            capsuleView
                .padding(.horizontal, SetupAssistantM.rail)
                .padding(.top, SetupAssistantM.bandGap)
        }
        .padding(.bottom, SetupAssistantM.footerHeight + SetupAssistantM.footerClearance)
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var capsuleView: some View {
        switch capsule {
        case .none:
            EmptyView()
        case .marks(let lines, let met):
            capsuleBox(padV: SetupAssistantM.marksPadV, padBottom: SetupAssistantM.marksPadV) {
                // The rows carry the 28pt height; no stack spacing.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 10) {
                            mark(met: met)
                            Text(line)
                                .font(.system(size: 13.5))
                                .foregroundStyle(stackInk.opacity(0.92))
                        }
                        .frame(height: SetupAssistantM.markRowHeight, alignment: .leading)
                    }
                }
            }
        case .checklist(let rows):
            // A list capsule takes the marks capsule's tighter 12 padding; the rows carry their own height.
            capsuleBox(padV: SetupAssistantM.marksPadV, padBottom: SetupAssistantM.marksPadV) {
                // No separators: the capsule's hairline is the only container edge. Rows are fixed 52pt boxes.
                journeyRows(rows)
                // The ground is dark in both appearances, so declare the scheme and `.primary`/`.secondary`
                // resolve light. `ResolvedPalette` hues are resolved once at the root and do not follow this.
                .environment(\.colorScheme, ground.isDark ? .dark : .light)
            }
        case .cardGrid(let rows, let total, let columns, let progress, _, _):
            // Capsule padding 20 horizontal, 12 vertical; the scheme override matches the checklist's.
            capsuleBox(padV: SetupAssistantM.marksPadV, padBottom: SetupAssistantM.marksPadV) {
                JourneyCardGrid(rows: rows, accent: accent,
                                width: SetupAssistantM.column - SetupAssistantM.capsulePadH * 2,
                                total: total,
                                tileFill: groundStyle != .plain,
                                columns: columns,
                                progress: progress)
                    .environment(\.colorScheme, ground.isDark ? .dark : .light)
            }
        case .progress(let text, let count, let fraction):
            capsuleBox(padV: SetupAssistantM.capsulePadVBar,
                       padBottom: SetupAssistantM.capsulePadBottomBar) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Text(text)
                            .font(.system(size: 13.5))
                            .foregroundStyle(stackInk.opacity(0.92))
                            .lineLimit(1)
                        if let count {
                            Spacer(minLength: 12)
                            // Quieter than the phase name: the same fact read another way.
                            Text(count)
                                .font(.system(size: 13.5))
                                .foregroundStyle(stackInk.opacity(0.6))
                                .lineLimit(1)
                        }
                    }
                    // Fill is the ink, not the accent, which does not read over a photograph.
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: SetupAssistantM.barRadius)
                                .fill(stackInk.opacity(SetupAssistantM.barTrack))
                            RoundedRectangle(cornerRadius: SetupAssistantM.barRadius)
                                .fill(stackInk)
                                .frame(width: geo.size.width * min(max(fraction, 0), 1))
                        }
                    }
                    .frame(height: SetupAssistantM.barHeight)
                }
            }
        }
    }

    /// The journey list, capped at `journeyRowsVisible` and self-scrolling past it. Short lists get a bare
    /// VStack (no ScrollView). No scroll indicators or fade: at loginwindow there is no pointer to scroll with.
    @ViewBuilder private func journeyRows(_ rows: [ProvisioningRowModel]) -> some View {
        if rows.count > SetupAssistantM.journeyRowsVisible {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) { journeyStack(rows) }
                    // The height the layout gives it; otherwise the capsule pushes the title off the top.
                    .frame(height: SetupAssistantM.journeyRowsHeight)
                    // A screen entered mid-run starts at the target, without an animated jump.
                    .onAppear {
                        if let target = JourneyScroll.target(rows: rows) {
                            proxy.scrollTo(target.id, anchor: target.anchor)
                        }
                    }
                    // Driven by the target, not a timer. Keyed on the whole `Target`, so the final `.bottom` fires.
                    .onChange(of: JourneyScroll.target(rows: rows)) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(target.id, anchor: target.anchor)
                        }
                    }
            }
        } else {
            journeyStack(rows)
        }
    }

    /// The rows, shared by both branches.
    private func journeyStack(_ rows: [ProvisioningRowModel]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                // The shared provisioning row at 52pt; `ProvisioningRowBuilder` already decided its content.
                ProvisioningRowView(model: row, width: nil, accent: accent)
            }
        }
    }

    /// The promise mark: a ring while outstanding, a filled tick once kept.
    @ViewBuilder private func mark(met: Bool) -> some View {
        if met {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: SetupAssistantM.markSize))
                .foregroundStyle(palette.success)
        } else {
            Circle()
                .strokeBorder(stackInk.opacity(SetupAssistantM.markUnmet),
                              lineWidth: SetupAssistantM.markRingWidth)
                .frame(width: SetupAssistantM.markSize, height: SetupAssistantM.markSize)
        }
    }

    /// 740 × auto, r12, white 10% on a 0.5pt white 18% hairline.
    @ViewBuilder private func capsuleBox<C: View>(padV: CGFloat, padBottom: CGFloat,
                                                 @ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(width: SetupAssistantM.column - SetupAssistantM.capsulePadH * 2,
                   alignment: .leading)
            .padding(.top, padV)
            .padding(.bottom, padBottom)
            .padding(.horizontal, SetupAssistantM.capsulePadH)
            .background(capsuleBackground)
    }

    /// The capsule's glass: a wash of the ink opposite the ground with a hairline. The plain ground draws
    /// none but keeps the padding.
    @ViewBuilder private var capsuleBackground: some View {
        if groundStyle != .plain {
            RoundedRectangle(cornerRadius: SetupAssistantM.capsuleRadius, style: .continuous)
                .fill(glassInk.opacity(SetupAssistantM.capsuleFill))
                .overlay(
                    RoundedRectangle(cornerRadius: SetupAssistantM.capsuleRadius,
                                     style: .continuous)
                        .strokeBorder(glassInk.opacity(SetupAssistantM.capsuleStroke),
                                      lineWidth: 0.5))
        }
    }

}


/// The α ground when no artwork is authored: an accent-to-near-black ramp in place of the shell's black,
/// so the screen reads minimal rather than broken. Scrim, capsule and footer are unchanged.
struct BrandGroundFallback: View {
    let accent: Color
    /// Which way the shell's scrim ramps; must match it, or a light scrim lands on a dark ramp.
    var ground: SetupAssistantGround = .dark

    var body: some View {
        ZStack {
            // Its own base: the shell's black would darken the light variant.
            (ground.isDark ? Color.black : Color.white)
            LinearGradient(
                stops: [
                    // Full brand at the top on both grounds; it clears before the text.
                    .init(color: accent.opacity(ground.isDark ? 0.85 : 0.92), location: 0),
                    .init(color: accent.opacity(ground.isDark ? 0.35 : 0.22), location: 0.34),
                    // Ends on the scrim's colour so the ramps compose; early on the pale ground so the
                    // lower half is clean.
                    .init(color: ground.isDark ? .black : .white,
                          location: ground.isDark ? 1 : 0.62),
                    .init(color: ground.isDark ? .black : .white, location: 1)],
                startPoint: .top, endPoint: .bottom)
        }
    }
}
