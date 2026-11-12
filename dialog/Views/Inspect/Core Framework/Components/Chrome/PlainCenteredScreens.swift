//
//  PlainCenteredScreens.swift
//  dialog
//
//  Screen bodies for the `plain-centered` construction, hosted as `content` by the shell: the
//  intro and summary hero (states 1 and 4), the item list (state 2) and the progress screen
//  (state 3).
//

import SwiftUI

// MARK: - Row/hero icon resolution

/// `GradientIconTile` draws an SF Symbol, but icons are authored as `SF=name` or as paths; a path
/// or an absent icon falls back to a default symbol rather than an empty tile.
enum PlainCenteredIcon {
    /// The same fallback the item-icon resolver uses for an item with no drawable icon.
    static let rowDefault = "app.fill"
    static let heroDefault = "apps.iphone.badge.plus"

    static func rowGlyph(for item: InspectConfig.ItemConfig) -> String {
        IconRef.symbol(item.icon ?? "") ?? rowDefault
    }

    /// An `SF=` main icon resolves synchronously, so no caching step is needed here.
    static func heroGlyph(mainIconPath: String) -> String {
        IconRef.symbol(mainIconPath) ?? heroDefault
    }
}

// MARK: - Type-stack rhythm and list-row geometry

extension PlainCenteredM {

    // MARK: Type stack; the list state uses the compressed values

    static let heroToTitle: CGFloat = 34
    static let heroToTitleList: CGFloat = 26
    static let titleToBody: CGFloat = 12
    static let titleToBodyList: CGFloat = 10
    static let bodyToCard: CGFloat = 34

    static let titleFontSize: CGFloat = 30
    static let titleFontSizeList: CGFloat = 27
    static let bodyFontSize: CGFloat = 16
    static let bodyFontSizeList: CGFloat = 15.5
    static let bodyMaxWidth: CGFloat = 430

    /// `-.022em` tracking, per font size because the list state's title is a different size.
    static func titleTracking(fontSize: CGFloat) -> CGFloat { fontSize * -0.022 }

    // MARK: List card row (state 2)

    static let rowPaddingVertical: CGFloat = 16
    static let rowPaddingHorizontal: CGFloat = 20
    static let rowGap: CGFloat = 16
    static let rowNameFontSize: CGFloat = 15.5
    static let rowDetailFontSize: CGFloat = 13
    static let rowTextGap: CGFloat = 3
    /// Leading padding + tile + gap, so the separator begins at the text column.
    static let rowSeparatorInset: CGFloat = rowPaddingHorizontal + rowTileSize + rowGap

    // MARK: Progress (state 3)

    static let bodyToBar: CGFloat = 38
    static let barToCaption: CGFloat = 14
    static let captionFontSize: CGFloat = 13
}

// MARK: - Shared hero/title/body stack (states 1, 3, 4)

/// Hero tile, title and body. The list state draws its own compressed rhythm.
private struct PlainCenteredHeroStack: View {
    let systemImage: String
    let title: String
    let bodyText: String
    let accent: Color
    var showsSuccessBadge: Bool = false

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            GradientIconTile(systemImage: systemImage, size: PlainCenteredM.heroSize,
                              treatment: .hero, accent: accent, showsSuccessBadge: showsSuccessBadge)
                .padding(.bottom, PlainCenteredM.heroToTitle)

            Text(title)
                .font(.system(size: PlainCenteredM.titleFontSize, weight: .bold))
                .tracking(PlainCenteredM.titleTracking(fontSize: PlainCenteredM.titleFontSize))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.bottom, PlainCenteredM.titleToBody)

            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(.system(size: PlainCenteredM.bodyFontSize))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: PlainCenteredM.bodyMaxWidth)
            }
        }
    }
}

// MARK: - Hero screen (states 1 and 4)

/// The intro and summary screens: the hero stack alone, with the success badge lit on summary.
struct PlainCenteredHeroScreen: View {
    let systemImage: String
    let title: String
    let bodyText: String
    let accent: Color
    var showsSuccessBadge: Bool = false

    var body: some View {
        PlainCenteredHeroStack(systemImage: systemImage, title: title, bodyText: bodyText,
                                accent: accent, showsSuccessBadge: showsSuccessBadge)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Progress screen (state 3)

/// The hero stack plus a determinate bar and caption. The bar's bright stop is the tile ramp's
/// hero 0% stop, so a branded accent shapes the bar the same way it shapes the tiles.
struct PlainCenteredProgressScreen: View {
    let systemImage: String
    let title: String
    let bodyText: String
    let accent: Color
    /// Drive the bar's fill fraction and the caption's "n of total".
    let completed: Int
    let total: Int
    /// Already localized; nil drops the "· name" suffix from the caption.
    let activeItemName: String?

    @Environment(\.palette) private var palette

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return min(1, max(0, CGFloat(completed) / CGFloat(total)))
    }

    private var caption: String {
        guard total > 0 else { return "" }
        let current = min(completed + 1, total)
        let base = "\(current) of \(total)"
        guard let activeItemName, !activeItemName.isEmpty else { return base }
        return "\(base) · \(activeItemName)"
    }

    var body: some View {
        VStack(spacing: 0) {
            PlainCenteredHeroStack(systemImage: systemImage, title: title, bodyText: bodyText, accent: accent)

            progressBar
                .padding(.top, PlainCenteredM.bodyToBar)

            if !caption.isEmpty {
                Text(caption)
                    .font(.system(size: PlainCenteredM.captionFontSize, weight: .medium))
                    .foregroundStyle(palette.textMuted)
                    .padding(.top, PlainCenteredM.barToCaption)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var progressBar: some View {
        let brightStop = GradientTileRamp.hero(from: accent).first ?? accent
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.surfaceRaised)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LinearGradient(colors: [brightStop, accent], startPoint: .leading, endPoint: .trailing))
                .frame(width: PlainCenteredM.progressBarSize.width * fraction)
        }
        .frame(width: PlainCenteredM.progressBarSize.width, height: PlainCenteredM.progressBarSize.height)
    }
}

// MARK: - List screen (state 2)

/// The compressed hero stack plus the list card, which has a fixed height and scrolls internally.
struct PlainCenteredListScreen: View {
    let systemImage: String
    let model: ItemSetModel
    let title: String
    let bodyText: String
    /// One ramp for every row tile, not a colour per item.
    let accent: Color
    let loc: PresetLocalization

    /// Scroll geometry for the bottom fade; the offset uses the overlay's `.frame(in:).minY` sign.
    @State private var hintContentHeight: CGFloat = 0
    @State private var hintScrollOffset: CGFloat = 0
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            GradientIconTile(systemImage: systemImage, size: PlainCenteredM.heroSizeCompact,
                              treatment: .hero, accent: accent)
                .padding(.bottom, PlainCenteredM.heroToTitleList)

            Text(title)
                .font(.system(size: PlainCenteredM.titleFontSizeList, weight: .bold))
                .tracking(PlainCenteredM.titleTracking(fontSize: PlainCenteredM.titleFontSizeList))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.bottom, PlainCenteredM.titleToBodyList)

            if !bodyText.isEmpty {
                Text(bodyText)
                    .font(.system(size: PlainCenteredM.bodyFontSizeList))
                    .foregroundStyle(palette.textMuted)
                    .multilineTextAlignment(.center)
            }

            card
                .padding(.top, PlainCenteredM.bodyToCard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var card: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if model.rows.isEmpty {
                    emptyState
                } else {
                    // Keyed on position: a duplicate item id would make SwiftUI drop a row.
                    ForEach(Array(model.rows.enumerated()), id: \.offset) { index, row in
                        rowView(row, showsSeparator: index < model.rows.count - 1)
                    }
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height
        } action: { _, newHeight in
            hintContentHeight = newHeight
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newOffsetY in
            hintScrollOffset = -newOffsetY
        }
        // Without a cue a six-item list reads as a three-item one; the fade draws only on overflow.
        .overlay(
            GeometryReader { geo in
                ScrollHintOverlay(containerHeight: geo.size.height,
                                  contentHeight: hintContentHeight,
                                  scrollOffset: hintScrollOffset)
            }
        )
        .frame(width: PlainCenteredM.cardWidth, height: PlainCenteredM.cardHeight)
        .background(
            RoundedRectangle(cornerRadius: PlainCenteredM.cardRadius, style: .continuous)
                // `surfaceRaised`, not `cardSurface`: the latter can resolve to the window's own
                // white and read as no fill at all.
                .fill(palette.surfaceRaised)
        )
        .clipShape(RoundedRectangle(cornerRadius: PlainCenteredM.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PlainCenteredM.cardRadius, style: .continuous)
                .strokeBorder(palette.hairline, lineWidth: 0.5)
        )
    }

    private func rowView(_ row: ItemSetModel.Row, showsSeparator: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: PlainCenteredM.rowGap) {
                GradientIconTile(systemImage: PlainCenteredIcon.rowGlyph(for: row.item),
                                  size: PlainCenteredM.rowTileSize, treatment: .row, accent: rowTileAccent(row))

                VStack(alignment: .leading, spacing: PlainCenteredM.rowTextGap) {
                    Text(loc.string("\(row.item.id).displayName", fallback: row.item.displayName) ?? row.item.displayName)
                        .font(.system(size: PlainCenteredM.rowNameFontSize, weight: .semibold))
                        .foregroundStyle(palette.text)
                    // Stays coloured: rows carry no status glyph, so colour is the only thing
                    // separating a failed row from an installed one.
                    Text(loc.itemStatus(for: row.item, baseStatus: row.statusText))
                        .font(.system(size: PlainCenteredM.rowDetailFontSize))
                        .foregroundStyle(ItemSetModel.itemStatusColor(row.status, hasWarning: row.hasWarning, palette: palette))
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, PlainCenteredM.rowPaddingHorizontal)
            .padding(.vertical, PlainCenteredM.rowPaddingVertical)

            if showsSeparator {
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: 0.5)
                    .padding(.leading, PlainCenteredM.rowSeparatorInset)
            }
        }
    }

    /// A failed row's tile takes `palette.error` so the failure is scannable without reading the
    /// status word. Only `.failed` retints: a warning row installed successfully and must not
    /// announce an install failure that did not happen.
    private func rowTileAccent(_ row: ItemSetModel.Row) -> Color {
        row.status == .failed ? palette.error : accent
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal")
                    .font(.system(size: 22))
                Text("Nothing to install.")
            }
            .foregroundStyle(palette.textMuted)
            Spacer()
        }
        .padding(.vertical, 40)
    }
}
