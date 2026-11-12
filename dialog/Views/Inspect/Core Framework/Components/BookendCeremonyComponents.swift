//
//  BookendCeremonyComponents.swift
//  dialog
//
//  The blocks the bookend (intro/outro) ceremony layouts compose from. Bookend-owned, not
//  card-owned: the two surfaces share palette, metrics and IconView, not bodies.
//

import SwiftUI

// MARK: - Hero band

/// Full-strength gradient hero band with a glyph badge, greeting and subtitle. The one place the
/// phase-backdrop opacity clamp does not apply: the band paints its text white for contrast.
struct BookendHeroBand: View {
    let colors: [Color]
    var glyph: String = "checkmark"
    let title: String
    var subtitle: String?
    let scaleFactor: CGFloat
    var height: CGFloat = 190

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12 * scaleFactor) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.22))
                    Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                    Image(systemName: glyph)
                        .font(.system(size: 22 * scaleFactor, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 52 * scaleFactor, height: 52 * scaleFactor)

                Text(title)
                    .font(.system(size: 32 * scaleFactor, weight: .bold))
                    .tracking(-0.75)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 14.5 * scaleFactor))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 44 * scaleFactor)
        }
        .frame(height: height * scaleFactor)
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Greeting header

/// Centred greeting: a success glyph disc over the title and subtitle.
struct BookendGreetingHeader: View {
    @Environment(\.palette) private var palette

    var glyph: String = "checkmark"
    let title: String
    var subtitle: String?
    let scaleFactor: CGFloat

    var body: some View {
        VStack(spacing: 16 * scaleFactor) {
            ZStack {
                Circle().fill(palette.success)
                    .glowShadow(palette.success, opacity: 0.35, radius: 11, y: 4)
                Image(systemName: glyph)
                    .font(.system(size: 24 * scaleFactor, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56 * scaleFactor, height: 56 * scaleFactor)

            Text(title)
                .font(.system(size: 38 * scaleFactor, weight: .bold))
                .tracking(-1)
                .multilineTextAlignment(.center)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 16 * scaleFactor))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460 * scaleFactor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Section label

/// Uppercase tracked section header at ceremony measure ("SUGGESTED NEXT").
struct BookendSectionLabel: View {
    let text: String
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.system(size: 11 * scaleFactor, weight: .semibold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(palette.textFaint)
    }
}

// MARK: - Action row

/// One suggested-next action row: icon, title, line and trailing button on a raised card.
struct BookendActionRow: View {
    @Environment(\.palette) private var palette

    let icon: String                // "SF=…" or a path
    let title: String
    var subtitle: String?
    var buttonText: String?         // nil hides the trailing button
    var action: (() -> Void)?
    let scaleFactor: CGFloat

    private var rowSurface: Color { palette.surfaceRaised }

    var body: some View {
        HStack(spacing: 14) {
            IconView(image: icon, defaultImage: "app.fill")
                .frame(width: 40, height: 40)
                .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5 * scaleFactor, weight: .semibold))
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.secondary)
                        // Rows keep one shared height; a long subtitle truncates.
                        .lineLimit(2)
                }
            }
            Spacer()
            if let buttonText, let action {
                Button(buttonText, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(rowSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Identity chip placement

/// Where the identity chip sits. Unknown values fall back to `.bandLeading`. A `.footerLeading` chip renders before the footnote
/// and link.
enum BookendChipPlacement: Equatable {
    case bandLeading
    case bandTrailing
    case footerLeading

    init(position: String?) {
        switch (position ?? "").lowercased() {
        case "bandtrailing": self = .bandTrailing
        case "footerleading": self = .footerLeading
        default: self = .bandLeading
        }
    }
}

// MARK: - Identity chip

/// Initials disc and badge line in a floating capsule. Initials come from the text itself:
/// "maya.kaur@example.com" gives "MK".
struct BookendIdentityChip: View {
    @Environment(\.palette) private var palette

    let text: String

    private var initials: String {
        guard !text.isEmpty else { return "" }
        let local = text.split(separator: "@").first.map(String.init) ?? text
        let parts = local.split(whereSeparator: { ".-_ ".contains($0) })
        return parts.prefix(2).compactMap { $0.first.map(String.init)?.uppercased() }.joined()
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().fill(Color.secondary.opacity(0.25))
                Text(initials)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 26, height: 26)

            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.leading, 6)
        .padding(.trailing, 16)
        .padding(.vertical, 5)
        .background(Capsule().fill(palette.cardSurface))
        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
    }
}

// MARK: - Stat strip

/// Equal-width stat tiles at one fixed height, each a `CardStatText` figure over its caption; a
/// wrapping label must not make its tile taller than its neighbours.
struct BookendStatStrip: View {
    struct Stat {
        let value: String
        let label: String
    }

    /// Same data and figure; a style, not a second component.
    enum Style {
        /// Separate rounded tiles; the default.
        case tiles
        /// One ruled band with column dividers, for a strip inside a card.
        case ruled
    }

    let stats: [Stat]
    let scaleFactor: CGFloat
    var style: Style = .tiles

    @Environment(\.palette) private var palette

    private var tileColor: Color { palette.surfaceRaised }
    private var hairline: Color { palette.hairline }

    var body: some View {
        switch style {
        case .tiles: tiles
        case .ruled: ruled
        }
    }

    /// Columns share the width equally and centre in it.
    private var ruled: some View {
        VStack(spacing: 0) {
            Rectangle().fill(hairline).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    if index > 0 {
                        Rectangle().fill(hairline).frame(width: 1)
                            .padding(.vertical, 10 * scaleFactor)
                    }
                    VStack(spacing: 3 * scaleFactor) {
                        Text(stat.label.uppercased())
                            .font(.system(size: 10.5 * scaleFactor, weight: .medium))
                            .tracking(0.6)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            // Captions are phrases; the column has height to spare, not width.
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                        CardStatText(value: stat.value)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 12 * scaleFactor)
                    .frame(maxWidth: .infinity)
                }
            }
            Rectangle().fill(hairline).frame(height: 1)
        }
    }

    private var tiles: some View {
        HStack(spacing: 14 * scaleFactor) {
            ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                VStack(alignment: .leading, spacing: 4) {
                    CardStatText(value: stat.value)
                        .lineLimit(1)
                    Text(stat.label)
                        .font(.system(size: 13 * scaleFactor))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 18 * scaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 84 * scaleFactor)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tileColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(hairline, lineWidth: 0.5)
                        )
                )
            }
        }
    }
}

// MARK: - Explainer cards

/// Three illustrated step cards. The built-in vignettes ("start", "install", "launch") draw
/// with the configured item icons; a per-card `image` overrides with a custom picture.
struct BookendExplainerCards: View {
    /// One card, strings already resolved by the host.
    struct Card {
        let eyebrow: String             // "Step 1"
        let title: String
        let body: String
        var art: String?                // built-in vignette name (default by position)
        var image: String?              // custom illustration path (overrides art)
    }

    let cards: [Card]
    let items: [InspectConfig.ItemConfig]   // icons the vignettes draw with
    let accent: Color
    let scaleFactor: CGFloat
    /// Launch-vignette tooltip pill; nil hides it.
    var pillText: String?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.palette) private var palette

    private var vignetteSurface: Color { palette.surfaceRaised }
    private var miniSurface: Color { palette.cardSurface }
    private var hairline: Color { palette.hairline }

    private func itemIcon(_ index: Int) -> String {
        guard !items.isEmpty else { return "SF=app.dashed" }
        return items[index % items.count].resolvedArt ?? "SF=app.dashed"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 20 * scaleFactor) {
            ForEach(Array(cards.prefix(3).enumerated()), id: \.offset) { index, card in
                VStack(alignment: .leading, spacing: 16 * scaleFactor) {
                    vignette(for: card, index: index)
                        .frame(height: 170 * scaleFactor)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vignetteSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(hairline, lineWidth: 0.5)
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 7 * scaleFactor) {
                        Text(card.eyebrow)
                            .font(.system(size: 12.5 * scaleFactor))
                            .foregroundStyle(palette.textFaint)
                        Text(card.title)
                            .font(.system(size: 19 * scaleFactor, weight: .bold))
                            .tracking(-0.25)
                        Text(card.body)
                            .font(.system(size: 13.5 * scaleFactor))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: Vignettes

    @ViewBuilder
    private func vignette(for card: Card, index: Int) -> some View {
        if let image = card.image, !image.isEmpty {
            IconView(image: image, defaultImage: "photo")
                .padding(12 * scaleFactor)
        } else {
            switch card.art ?? ["start", "install", "launch"][min(index, 2)] {
            case "install": installVignette
            case "launch": launchVignette
            default: startVignette
            }
        }
    }

    /// Mini app window with the first item's icon and an accent progress bar.
    private var startVignette: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle().fill(Color(hex: "#FF5F57")).frame(width: 6, height: 6)
                Circle().fill(Color(hex: "#FEBC2E")).frame(width: 6, height: 6)
                Circle().fill(Color(hex: "#28C840")).frame(width: 6, height: 6)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(palette.surfaceRaised)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    IconView(image: itemIcon(0), defaultImage: "app.fill")
                        .frame(width: 24, height: 24)
                        .clipShape(.rect(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 4) {
                        Capsule().fill(Color.secondary.opacity(0.35)).frame(width: 52, height: 5)
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(width: 32, height: 5)
                    }
                    Spacer()
                }
                Capsule().fill(Color.secondary.opacity(0.2))
                    .frame(height: 5)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule().fill(accent)
                                .frame(width: geo.size.width * 0.36)
                        }
                    }
            }
            .padding(12)
        }
        .background(RoundedRectangle(cornerRadius: 9).fill(miniSurface))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .shadow(color: .black.opacity(0.10), radius: 9, y: 3)
        .padding(.horizontal, 18)
    }

    /// Grid of real item icons → arrow → one app landing in its tile.
    private var installVignette: some View {
        HStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.fixed(38), spacing: 9), GridItem(.fixed(38))], spacing: 9) {
                ForEach(0..<4, id: \.self) { i in
                    IconView(image: itemIcon(i), defaultImage: "app.fill")
                        .frame(width: 38, height: 38)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.09), radius: 4, y: 1.5)
                }
            }
            .frame(width: 85)

            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.textFaint)

            IconView(image: itemIcon(4), defaultImage: "app.fill")
                .frame(width: 38, height: 38)
                .clipShape(.rect(cornerRadius: 11))
                .frame(width: 66, height: 66)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(miniSurface)
                        .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
                )
        }
    }

    /// Dock strip with the active app raised and its name in a tooltip pill.
    private var launchVignette: some View {
        VStack(spacing: 12) {
            if let pillText {
                Text(pillText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(scheme == .dark ? Color.black : .white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(scheme == .dark ? Color.white : Color(hex: "#1D1D1F")))
            }

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    let active = i == 2
                    IconView(image: itemIcon(i), defaultImage: "app.fill")
                        .frame(width: active ? 46 : 38, height: active ? 46 : 38)
                        .clipShape(.rect(cornerRadius: active ? 12 : 10))
                        .glowShadow(accent, opacity: 0.25, radius: 6, y: 2, active: active)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(miniSurface.opacity(scheme == .dark ? 1.0 : 0.75))
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
            )

            Circle().fill(Color.secondary.opacity(0.5)).frame(width: 4, height: 4)
        }
    }
}

// MARK: - Icon strip

/// The configured items in overlapping tiles, capped at `limit` with a "+N" overflow chip.
struct BookendIconStrip: View {
    @Environment(\.palette) private var palette

    let items: [InspectConfig.ItemConfig]
    let scaleFactor: CGFloat
    /// Icons shown before the "+N" chip collapses the rest.
    var limit: Int = 5

    private var chipSurface: Color { palette.surfaceRaised }
    private var hairline: Color { palette.hairline }

    var body: some View {
        let visible = Array(items.prefix(limit))
        let overflow = items.count - visible.count
        HStack(spacing: -10 * scaleFactor) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                IconView(image: item.resolvedArt ?? "SF=app.dashed")
                    .frame(width: 46 * scaleFactor, height: 46 * scaleFactor)
                    .padding(5 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(hairline, lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                    )
                    .zIndex(Double(index))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .font(.system(size: 15 * scaleFactor, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 46 * scaleFactor, height: 46 * scaleFactor)
                    .padding(5 * scaleFactor)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(chipSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(hairline, lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                    )
                    .zIndex(Double(limit))
            }
        }
    }
}

// MARK: - Status ledger

/// Two-column per-item ledger from live state: completed and failed rows settle with a coloured
/// glyph; everything else reads as explicitly skipped rather than silently absent.
struct BookendStatusLedger<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    @ObservedObject var state: Context
    var skippedLabel: String = "Skipped"
    let scaleFactor: CGFloat

    @Environment(\.palette) private var palette

    private var skippedSurface: Color { palette.surfaceRaised }

    var body: some View {
        let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
        LazyVGrid(columns: columns, spacing: 8 * scaleFactor) {
            ForEach(state.items, id: \.id) { item in
                let isCompleted = state.completedItems.contains(item.id)
                let isFailed = state.failedItems.contains(item.id)
                HStack(spacing: 12) {
                    IconView(image: item.resolvedArt ?? "SF=app.dashed")
                        .frame(width: 30, height: 30)
                        .clipShape(.rect(cornerRadius: 8))
                    Text(item.displayName)
                        .font(.system(size: 13.5 * scaleFactor, weight: .medium))
                        .foregroundStyle(isCompleted || isFailed ? Color.primary : Color.secondary)
                        .lineLimit(1)
                    Spacer()
                    if isCompleted {
                        ZStack {
                            Circle().fill(palette.success)
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 17, height: 17)
                    } else if isFailed {
                        ZStack {
                            Circle().fill(palette.error)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 17, height: 17)
                    } else {
                        Text(skippedLabel)
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(isCompleted || isFailed ? Color.clear : skippedSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(isCompleted || isFailed ? Color.clear : Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                )
            }
        }
    }
}

// MARK: - Info note

/// Config-supplied info banner above the footer.
struct BookendInfoNote: View {
    @Environment(\.palette) private var palette

    let text: String
    let scaleFactor: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 8).fill(palette.cardSurface))
                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
            Text(text)
                .font(.system(size: 13 * scaleFactor))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 11).fill(palette.surfaceRaised))
    }
}

// MARK: - Item-list popover

/// The footer link's item list. `.status` adds the per-item outcome from live state; `.names`
/// is plain display names for the intro, where there is nothing to report yet.
struct BookendItemListPopover<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    enum Style { case names, status }

    let style: Style
    @ObservedObject var state: Context
    var skippedLabel: String = "Skipped"

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(state.items, id: \.id) { item in
                HStack(spacing: 8) {
                    Text(item.displayName).font(.system(size: 13))
                    if style == .status {
                        Spacer()
                        if state.completedItems.contains(item.id) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.success).font(.system(size: 12))
                        } else if state.failedItems.contains(item.id) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(palette.error).font(.system(size: 12))
                        } else {
                            Text(skippedLabel)
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(minWidth: style == .status ? 230 : 200, alignment: .leading)
    }
}

// MARK: - Ceremony footer row

/// The bookend footer: footnote and item-list link leading, the shared primary button trailing,
/// drawn through `FooterRow`. Callers resolve strings first; this never consults the config.
struct BookendFooterRow<Context: UserInputContext & ProgressContext & ObservableObject>: View {
    @ObservedObject var state: Context
    let highlightColor: Color
    let scaleFactor: CGFloat
    var footnoteLine: String = ""
    var linkText: String?
    var popoverStyle: BookendItemListPopover<Context>.Style = .status
    var skippedLabel: String = "Skipped"
    var showsRule = true
    var spacing: CGFloat? = 8
    /// Pre-scale; nil uses `phaseFooterHorizontal`.
    var footerHorizontalPadding: CGFloat?
    /// `.vertical` stacks footnote and link into a two-line corner.
    var leadingAxis: Axis = .horizontal
    /// Identity chip for `userBadgePosition: "footerLeading"`; renders before footnote and link.
    var chipText: String?
    let buttonText: String
    let onContinue: () -> Void

    @State private var showItemList = false
    /// Seated at the end of the leading cluster when the host provides one; reported through
    /// `CardHeaderHelpSeatedKey` so a corner fallback stands down.
    @Environment(\.cardHeaderHelp) private var help

    private var rail: CGFloat {
        footerHorizontalPadding.map { $0 * scaleFactor } ?? InspectMetrics(scale: scaleFactor).phaseFooterHorizontal
    }

    var body: some View {
        FooterRow(rail: rail, rule: showsRule ? .over : .none) {
            EmptyView()
        } leading: {
            if leadingAxis == .vertical {
                VStack(alignment: .leading, spacing: 3) {
                    leadingPieces
                }
            } else {
                // `FooterRow` seats slots with no spacing of its own.
                HStack(spacing: spacing) {
                    leadingPieces
                }
            }
        } trailing: {
            PrimaryActionButton(tint: highlightColor, action: onContinue) {
                Text(buttonText)
            }
        }
    }

    @ViewBuilder private var leadingPieces: some View {
        if let chipText, !chipText.isEmpty {
            BookendIdentityChip(text: chipText)
        }
        if !footnoteLine.isEmpty {
            Text(footnoteLine)
                .font(.system(size: 12.5 * scaleFactor))
                .foregroundStyle(.secondary)
        }
        if let linkText, !linkText.isEmpty {
            Button {
                showItemList = true
            } label: {
                Text(linkText)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(highlightColor)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showItemList, arrowEdge: .top) {
                BookendItemListPopover(style: popoverStyle, state: state, skippedLabel: skippedLabel)
            }
        }
        if let help {
            HelpGlyphButton(icon: help.icon, tooltip: help.tooltip, tint: highlightColor,
                            action: help.action)
                .preference(key: CardHeaderHelpSeatedKey.self, value: true)
        }
    }
}
