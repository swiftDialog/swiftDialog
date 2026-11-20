//
//  ProvisioningRow.swift
//  dialog
//
//  The provisioning body component: one 52-tall row spanning the column for checks, packages and
//  choices alike, plus its list, sectioned, preview and tile variants. The left slot holds state
//  (circles), the right rail identity (brand marks), so brand colour never reads as state.

import SwiftUI

/// What the left mark says. The trailing word is separate, so a queued mark can sit beside "Blocked".
enum ProvisioningRowMark: Equatable {
    /// A row the user can pick: one of one (`choice`) or one of several (`check`).
    var isChoice: Bool {
        switch self {
        case .choice, .check, .symbol: return true
        default: return false
        }
    }

    case done
    case active
    case queued
    case failed
    /// A choice row; selection is the accent radio plus a 10% row tint.
    case choice(selected: Bool)
    /// One of several choices: a checkbox, same accent and tint as `choice`.
    case check(selected: Bool)
    /// A switch row's leading glyph, accented when on; it echoes the trailing `ProvisioningRowTrailing.toggle`.
    case symbol(String, on: Bool)
}

/// How the trailing slot reads: a state word, a notice chip, a brand mark, or a switch.
enum ProvisioningRowTrailing: Equatable {
    /// "Installed", "Queued", "Not found", "Blocked".
    case state(String, failed: Bool)
    /// A temporary notice such as "Removed", drawn as a chip. The row's state stays pending (its mark
    /// is `.queued`); the notice expires after `AppInspector.removalNoticeDwell`. A separate case so
    /// every renderer's exhaustive switch has to handle it.
    case notice(String)
    /// The right-hand identity rail.
    case identity(ProvisioningIdentity)
    /// A switch showing the row's state; the whole row is the target.
    case toggle(on: Bool)
    case none
}

/// The right rail's fallback ladder: supplied mark → authored SF Symbol → name as wordmark → nothing.
/// Every rung resolves fully (swatch colour and initial included, which tests assert on), but no
/// renderer paints a swatch tile; a brand with no usable mark is shown by its name.
enum ProvisioningIdentity: Equatable {
    case mark(path: String)
    /// An SF Symbol authored as the brand's mark: outranks the wordmark, loses to a real mark.
    case symbol(String, color: Color)
    case wordmark(String, swatch: Color)
    case swatch(initial: String, color: Color)
}

/// The row's payload: flat strings and one enum, built by the cadence, carousel and brandPicker adapters.
struct ProvisioningRowModel: Identifiable, Equatable {
    let id: String
    let name: String
    /// Mono for machine strings (paths, sizes, bundle ids), system font otherwise; the adapter decides.
    var detail: String?
    var detailIsMachine: Bool = true
    var mark: ProvisioningRowMark = .queued
    var trailing: ProvisioningRowTrailing = .none
    /// false shows the option dimmed with its reason in the detail, and it takes no pointer or keyboard input.
    var enabled: Bool = true
    /// The item's authored `icon`, for renderers with an artwork slot (`JourneyCardGrid`).
    var art: String?
    /// The item's authored `claim`, shown by the card grid while the card is unfinished.
    var claim: String?
    /// Division mode: this card's share of items done, 0…1, drawn as a ring by the glass card. nil otherwise.
    var share: Double?
}

/// One row. 52 tall, spanning the column, with the mark centred in a fixed 18-wide slot.
struct ProvisioningRowView: View {
    @Environment(\.provisioningMarksCelebrate) private var marksCelebrate
    let model: ProvisioningRowModel
    /// The column width; nil fills the container, for hosts that measure their own column.
    let width: CGFloat?
    let accent: Color

    @Environment(\.palette) private var palette

    /// Active and failed rows are emphasised, so the list has one emphasis at a time.
    private var nameProminent: Bool {
        switch model.mark {
        case .active, .failed: return true
        case .choice(let selected), .check(let selected): return selected
        case .symbol(_, let on): return on
        case .done, .queued: return false
        }
    }

    var body: some View {
        HStack(spacing: ProvisioningM.markGap) {
            markView
                // A row carrying its own icon gets an icon-sized slot; every other row keeps 18.
                .frame(width: hasIcon ? ProvisioningRowIcon.slot : ProvisioningM.markSlot)
            Text(model.name)
                .font(.system(size: ProvisioningM.nameSize,
                              weight: nameProminent ? .semibold : .regular))
                .foregroundStyle(model.enabled
                                 ? (nameProminent ? palette.text : palette.textMuted)
                                 : palette.textFaint)
                .lineLimit(1)
                .fixedSize()
            if let detail = model.detail {
                Text(detail)
                    .font(model.detailIsMachine
                          ? .system(size: ProvisioningM.detailSize, design: .monospaced)
                          : .system(size: ProvisioningM.detailSize))
                    .foregroundStyle(palette.textFaint)
                    .lineLimit(1)
                    // The detail truncates first, so a brand mark is never clipped.
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
            }
            trailingView
        }
        .frame(width: width, height: ProvisioningM.rowHeight)
        .frame(maxWidth: width == nil ? .infinity : nil)
        .background(rowTint)
        // The whole row dims together.
        .opacity(model.enabled ? 1 : 0.55)
    }

    /// A switch row naming its own artwork (`art`): an app, an image file, a URL.
    private var hasIcon: Bool {
        if case .symbol = model.mark, let art = model.art, !art.isEmpty { return true }
        return false
    }

    /// The 10% "chosen" tint, only on a selected choice row.
    @ViewBuilder private var rowTint: some View {
        if model.mark == .choice(selected: true) || model.mark == .check(selected: true) {
            accent.opacity(0.1)
        } else {
            Color.clear
        }
    }

    // MARK: - Marks
    // Marks differ in size but share a centre line in a fixed slot.

    @ViewBuilder private var markView: some View {
        switch model.mark {
        case .done:
            // Muted check by default; the celebrate flag from the environment turns every mark green
            // at once on the receipt screen.
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(marksCelebrate ? palette.success : palette.textFaint)
        case .active:
            ProvisioningActiveMark(accent: accent)
        case .queued:
            Circle()
                .fill(palette.text.opacity(0.22))
                .frame(width: 5, height: 5)
        case .failed:
            ZStack {
                Circle().fill(palette.error)
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    // Knocked out in the window's ground so the mark reads in both appearances.
                    .foregroundStyle(palette.windowBackground)
            }
            .frame(width: 16, height: 16)
        case .choice(let selected):
            if selected {
                ZStack {
                    Circle().fill(accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.windowBackground)
                }
                .frame(width: 16, height: 16)
            } else {
                Circle()
                    .strokeBorder(palette.text.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }
        case .check(let selected):
            if selected {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous).fill(accent)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.windowBackground)
                }
                .frame(width: 16, height: 16)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(palette.text.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }
        case .symbol(let name, let on):
            if let art = model.art, !art.isEmpty {
                ProvisioningRowIcon(path: art, symbol: name, on: on, accent: accent)
            } else {
                Image(systemName: name)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(on ? accent : palette.textMuted)
                    .frame(width: 18, height: 18)
            }
        }
    }

    // MARK: - Trailing

    @ViewBuilder private var trailingView: some View {
        switch model.trailing {
        case .state(let word, let failed):
            Text(word)
                .font(.system(size: ProvisioningM.detailSize))
                .foregroundStyle(failed ? palette.error : palette.textMuted)
                .lineLimit(1)
                .fixedSize()
        case .notice(let word):
            ProvisioningNoticeChip(word: word)
        case .identity(let identity):
            ProvisioningIdentityBox(identity: identity)
        case .toggle(let on):
            ProvisioningSwitch(on: on, accent: accent)
        case .none:
            EmptyView()
        }
    }
}

/// The notice chip: glyph 9, word 11.5/600, spacing 5, padding 7 / 9 / 3, radius 20, fill only.
/// The 7 · 9 padding optically centres the arrow and word. Colours come from the palette's `notice` tokens.
private struct ProvisioningNoticeChip: View {
    let word: String

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 9))
                .frame(width: 9, height: 9)
                .foregroundStyle(palette.notice)
            Text(word)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(palette.notice)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(palette.noticeBackground))
    }
}

/// The only animation on the screen.
private struct ProvisioningActiveMark: View {
    let accent: Color

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: 14, height: 14)
            .clockSpin()
    }
}

/// The identity lockup box: 120 × 24, right-aligned, marks fitted to a 20pt cap height with width free,
/// so marks of very different aspect ratios read as one set.
struct ProvisioningIdentityBox: View {
    let identity: ProvisioningIdentity

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            switch identity {
            case .mark(let path):
                // No `maxWidth`: the mark keeps the 20pt cap height and hugs its ratio. Over-ratio marks
                // never reach here. A `-dark` sibling is picked in dark mode; supplied marks are never recoloured.
                BrandMark(path: darkVariantImagePath(path, dark: colorScheme == .dark),
                          box: BrandMarkBox(height: ProvisioningM.logoCapHeight, maxWidth: nil))
            case .symbol(let name, let color):
                // A 24 box, so a list mixing rungs keeps its rhythm.
                Image(systemName: name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
            case .wordmark(let text, _):
                // Type only; the resolved swatch is not painted.
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textMuted)
                    .lineLimit(1)
            case .swatch:
                // Nothing: the row already prints the name; no initial tile.
                EmptyView()
            }
        }
        .frame(width: ProvisioningM.logoMaxWidth, height: 24, alignment: .trailing)
    }
}

/// Bound rule, rows and separators at a given width, placed by the caller (`ProvisioningRowList` or a card).
struct ProvisioningRowStack: View {
    let rows: [ProvisioningRowModel]
    /// nil fills the container; see `ProvisioningRowView.width`.
    let width: CGFloat?
    let accent: Color
    var onSelect: ((String) -> Void)?

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { rule(ProvisioningM.separatorOpacity) }
                rowView(row)
            }
        }
    }

    @ViewBuilder private func rowView(_ row: ProvisioningRowModel) -> some View {
        let view = ProvisioningRowView(model: row, width: width, accent: accent)
        if let onSelect, row.mark.isChoice, row.enabled {
            // The whole row is the hit target; a `.plain` button only hit-tests what it draws.
            Button { onSelect(row.id) } label: { view.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isButton)
        } else {
            view
        }
    }

    private func rule(_ opacity: CGFloat) -> some View {
        Rectangle().fill(palette.text.opacity(opacity))
            .frame(width: width, height: 1)
            .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

/// The shell's list: the stack pinned to the list top at a fixed height, scrolling past the row cap.
struct ProvisioningRowList: View {
    let rows: [ProvisioningRowModel]
    let metrics: ProvisioningM
    let accent: Color
    var onSelect: ((String) -> Void)?

    @Environment(\.palette) private var palette

    private var scrolls: Bool { rows.count > metrics.maxVisibleRows }
    /// Leaves the scroller's lane, so trailing content does not sit under the overlay scroller.
    private var rowWidth: CGFloat {
        scrolls ? metrics.column - ProvisioningSectionedList.scrollerGutter : metrics.column
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rule()
            if scrolls {
                ScrollView(.vertical, showsIndicators: true) {
                    stack.frame(width: metrics.column, alignment: .leading)
                }
                .frame(width: metrics.column, height: metrics.scrollingListHeight())
            } else {
                stack
            }
            rule()
        }
        .frame(width: metrics.column, alignment: .leading)
        .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
    }

    private var stack: some View {
        ProvisioningRowStack(rows: rows, width: rowWidth, accent: accent, onSelect: onSelect)
    }

    private func rule() -> some View {
        Rectangle()
            .fill(palette.text.opacity(ProvisioningM.boundRuleOpacity))
            .frame(width: metrics.column, height: 1)
    }
}


/// A drawn 32 × 18 switch showing the row's state; the row is the button, so it has no hit area or binding.
struct ProvisioningSwitch: View {
    let on: Bool
    let accent: Color

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? accent : palette.text.opacity(0.16))
            // Knob is the card surface with a hairline edge, so it paints from the palette.
            Circle().fill(palette.cardSurface)
                .overlay(Circle().strokeBorder(palette.text.opacity(0.12), lineWidth: 0.5))
                .padding(2)
        }
        .frame(width: 32, height: 18)
        .animation(.easeOut(duration: 0.15), value: on)
        .accessibilityHidden(true)
    }
}

/// A switch row's icon: an app bundle's icon, an image file or `https` URL (`AsyncImageView`), else the
/// card's SF Symbol.
struct ProvisioningRowIcon: View {
    let path: String
    let symbol: String
    let on: Bool
    let accent: Color

    var size: CGFloat = 22
    static let slot: CGFloat = 24

    @Environment(\.palette) private var palette

    /// What `BrandMark` cannot draw: an app bundle or a remote image.
    static func handles(_ path: String) -> Bool {
        let lower = path.lowercased()
        return lower.hasSuffix(".app") || lower.hasPrefix("http://") || lower.hasPrefix("https://")
    }

    var body: some View {
        content.frame(width: size, height: size)
    }

    @ViewBuilder private var content: some View {
        let expanded = (path as NSString).expandingTildeInPath
        if path.lowercased().hasSuffix(".app") {
            if FileManager.default.fileExists(atPath: expanded) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: expanded))
                    .resizable().interpolation(.high)
            } else {
                fallback
            }
        } else {
            AsyncImageView(iconPath: path, basePath: nil,
                           maxWidth: size, maxHeight: size,
                           imageFit: .fit, showLoadingState: false,
                           fallback: { fallback })
        }
    }

    private var fallback: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(on ? accent : palette.textMuted)
    }
}

/// One labelled group of rows ("QUICK FIXES · 6"). `warns` draws the header in the error colour.
struct ProvisioningRowSection: Identifiable, Equatable {
    let id: String
    let title: String?
    let warns: Bool
    let rows: [ProvisioningRowModel]
}

/// The shell's list in labelled groups: the same rows, rules and fixed region as `ProvisioningRowList`.
struct ProvisioningSectionedList: View {
    let sections: [ProvisioningRowSection]
    let metrics: ProvisioningM
    let accent: Color
    var onSelect: ((String) -> Void)?

    @Environment(\.palette) private var palette

    static let headerHeight: CGFloat = 30
    /// The overlay scroller's lane on the right edge, where switches sit.
    static let scrollerGutter: CGFloat = 16

    /// Each row's top and height in layout order: headers 30, rows 52, 1pt separators within a section. Pure.
    static func rowSpans(_ sections: [ProvisioningRowSection]) -> [(top: CGFloat, height: CGFloat)] {
        var y: CGFloat = 0
        var spans: [(CGFloat, CGFloat)] = []
        for section in sections {
            if section.title != nil { y += headerHeight }
            for (index, _) in section.rows.enumerated() {
                if index > 0 { y += 1 }
                spans.append((y, ProvisioningM.rowHeight))
                y += ProvisioningM.rowHeight
            }
        }
        return spans
    }

    /// The total height the content asks for.
    static func contentHeight(_ sections: [ProvisioningRowSection]) -> CGFloat {
        rowSpans(sections).last.map { $0.top + $0.height } ?? 0
    }

    /// A scrolling list's viewport, ending through the middle of a row so the cut signals more below.
    static func peekHeight(_ sections: [ProvisioningRowSection], room: CGFloat) -> CGFloat {
        let mids = rowSpans(sections).map { $0.top + $0.height / 2 }.filter { $0 <= room }
        return mids.last ?? min(room, contentHeight(sections))
    }

    private var room: CGFloat { metrics.listRegionHeight - ProvisioningM.minimumBandSlack }
    private var scrolls: Bool { Self.contentHeight(sections) > room }
    private var rowWidth: CGFloat { scrolls ? metrics.column - Self.scrollerGutter : metrics.column }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rule()
            if scrolls {
                // The content keeps the full column and the rows are inset, so the scroller lands in the empty lane.
                ScrollView(.vertical, showsIndicators: true) {
                    stack.frame(width: metrics.column, alignment: .leading)
                }
                .frame(width: metrics.column, height: Self.peekHeight(sections, room: room))
            } else {
                stack
            }
            rule()
        }
        .frame(width: metrics.column, alignment: .leading)
        .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
    }

    private var stack: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                if let title = section.title {
                    Text("\(title.uppercased()) · \(section.rows.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(section.warns ? palette.error : palette.textMuted)
                        .padding(.bottom, 6)
                        .frame(width: rowWidth, height: Self.headerHeight, alignment: .bottomLeading)
                }
                ProvisioningRowStack(rows: section.rows, width: rowWidth, accent: accent,
                                     onSelect: onSelect)
            }
        }
    }

    private func rule() -> some View {
        Rectangle()
            .fill(palette.text.opacity(ProvisioningM.boundRuleOpacity))
            .frame(width: metrics.column, height: 1)
    }
}

/// The preview-led body: one large preview of the current pick beside the same 52pt rows. Scales to
/// many options; the caption ties the preview to the selection.
struct ProvisioningPreviewList: View {
    let rows: [ProvisioningRowModel]
    /// The preview for the current pick; nil draws a hairline box saying what to drop.
    let previewPath: String?
    let caption: String?
    let metrics: ProvisioningM
    let accent: Color
    var onSelect: ((String) -> Void)?

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack(alignment: .topLeading) {
            preview
                .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
            VStack(alignment: .leading, spacing: 0) {
                rule()
                if scrolls {
                    // Long lists scroll inside the region with a half-row peek, like the other lists.
                    ScrollView(.vertical, showsIndicators: true) {
                        ProvisioningRowStack(rows: rows,
                                             width: ProvisioningM.previewRowsWidth - ProvisioningSectionedList.scrollerGutter,
                                             accent: accent, onSelect: onSelect)
                            .frame(width: ProvisioningM.previewRowsWidth, alignment: .leading)
                    }
                    .frame(width: ProvisioningM.previewRowsWidth, height: metrics.scrollingListHeight())
                } else {
                    ProvisioningRowStack(rows: rows, width: ProvisioningM.previewRowsWidth,
                                         accent: accent, onSelect: onSelect)
                }
                rule()
            }
            .frame(width: ProvisioningM.previewRowsWidth, alignment: .leading)
            .offset(x: ProvisioningM.previewRowsX, y: ProvisioningM.listTop)
        }
    }

    private var scrolls: Bool { rows.count > metrics.maxVisibleRows }

    @ViewBuilder private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let previewPath {
                    BrandLogoImage(path: darkVariantImagePath(previewPath, dark: colorScheme == .dark),
                                   height: ProvisioningM.previewHeight,
                                   maxWidth: ProvisioningM.previewWidth, clearSpace: 0)
                } else {
                    // Empty state: a hairline box and a sentence.
                    RoundedRectangle(cornerRadius: ProvisioningM.previewRadius)
                        .strokeBorder(palette.text.opacity(0.10), lineWidth: 1)
                }
            }
            .frame(width: ProvisioningM.previewWidth, height: ProvisioningM.previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: ProvisioningM.previewRadius))
            if let caption {
                Text(caption)
                    .font(.system(size: ProvisioningM.previewCaptionSize))
                    .foregroundStyle(palette.textFaint)
                    .lineLimit(1)
            }
        }
    }

    private func rule() -> some View {
        Rectangle()
            .fill(palette.text.opacity(ProvisioningM.boundRuleOpacity))
            .frame(width: ProvisioningM.previewRowsWidth, height: 1)
    }
}


/// What a tile draws above its label.
enum ProvisioningTileArt: Equatable {
    /// A real application icon, resolved the way the rest of the app resolves one.
    case appIcon(path: String?, bundleId: String?)
    case symbol(String)
    /// A drawn appearance preview (light · dark · auto) at 208 × 130.
    case appearance(String)
    /// A Dock flavour's apps as their real icons.
    case appRow([(label: String, path: String?)])
    case none

    static func == (a: ProvisioningTileArt, b: ProvisioningTileArt) -> Bool {
        switch (a, b) {
        case (.none, .none): return true
        case (.symbol(let x), .symbol(let y)): return x == y
        case (.appearance(let x), .appearance(let y)): return x == y
        case (.appIcon(let p1, let b1), .appIcon(let p2, let b2)): return p1 == p2 && b1 == b2
        case (.appRow(let x), .appRow(let y)):
            return x.map(\.label) == y.map(\.label) && x.map(\.path) == y.map(\.path)
        default: return false
        }
    }
}

struct ProvisioningTileModel: Identifiable, Equatable {
    let id: String
    let name: String
    var detail: String?
    var art: ProvisioningTileArt = .none
    var selected: Bool = false
    var enabled: Bool = true
}

/// The filled tile: 236 × 224, r12, no border; chosen adds a tinted fill and a 1.5 inset accent ring.
/// Three across fill the 740 column.
struct ProvisioningTileGrid: View {
    let tiles: [ProvisioningTileModel]
    let metrics: ProvisioningM
    let accent: Color
    var onSelect: ((String) -> Void)?

    @Environment(\.palette) private var palette

    private var columns: Int { min(max(tiles.count, 1), 3) }

    var body: some View {
        HStack(spacing: ProvisioningM.tileGap) {
            ForEach(tiles) { tile in
                if let onSelect, tile.enabled {
                    Button { onSelect(tile.id) } label: { view(tile) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(.isButton)
                } else {
                    view(tile)
                }
            }
        }
        .frame(width: ProvisioningM.tileGridWidth(columns), alignment: .leading)
        .offset(x: ProvisioningM.rail, y: ProvisioningM.listTop)
    }

    @ViewBuilder private func view(_ tile: ProvisioningTileModel) -> some View {
        VStack(spacing: ProvisioningM.tileInnerGap) {
            art(tile)
            VStack(spacing: 3) {
                Text(tile.name)
                    .font(.system(size: ProvisioningM.tileLabelSize, weight: .semibold))
                    .foregroundStyle(palette.text)
                    .lineLimit(1)
                if let detail = tile.detail {
                    // On an unavailable tile this is the only reason shown.
                    Text(detail)
                        .font(.system(size: ProvisioningM.detailSize))
                        .foregroundStyle(palette.textFaint)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
        }
        .padding(ProvisioningM.tilePad)
        .frame(width: ProvisioningM.tileWidth, height: ProvisioningM.tileHeight)
        .background(
            RoundedRectangle(cornerRadius: ProvisioningM.tileRadius)
                .fill(tile.selected ? accent.opacity(0.12) : palette.text.opacity(0.05)))
        .overlay(
            // The ring is inset so the tile's footprint never changes.
            RoundedRectangle(cornerRadius: ProvisioningM.tileRadius)
                .strokeBorder(tile.selected ? accent : .clear, lineWidth: 1.5))
        .opacity(tile.enabled ? 1 : 0.45)
    }

    private func isAppBundle(_ path: String?) -> Bool {
        (path?.lowercased().hasSuffix(".app")) == true
    }

    @ViewBuilder private func art(_ tile: ProvisioningTileModel) -> some View {
        switch tile.art {
        case .appIcon(let path, let bundleId):
            // `.app` bundles go through filesystem icon resolution; `iconPath` only loads image files.
            AppIconView(iconPath: isAppBundle(path) ? nil : path,
                        bundleId: bundleId,
                        paths: isAppBundle(path) ? [path!] : [],
                        size: 64, status: nil, accent: accent)
        case .appearance(let kind):
            AppearanceSwatch(kind: kind)
                .frame(width: ProvisioningM.tilePreviewWidth, height: ProvisioningM.tilePreviewHeight)
                .clipShape(RoundedRectangle(cornerRadius: ProvisioningM.tilePreviewRadius))
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(accent)
                .frame(height: 64)
        case .appRow(let apps):
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(Array(apps.prefix(4).enumerated()), id: \.offset) { _, app in
                        AppIconView(iconPath: isAppBundle(app.path) ? nil : app.path,
                                    bundleId: nil,
                                    paths: isAppBundle(app.path) ? [app.path!] : [],
                                    size: 34, status: nil, accent: accent)
                    }
                }
                Text(apps.map(\.label).joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textFaint)
                    .lineLimit(1)
            }
            .frame(height: 64)
        case .none:
            Color.clear.frame(height: 64)
        }
    }
}

/// Whether finished marks are reported (grey, the default) or celebrated (green, all at once).
/// Set by the body, since a row cannot know which screen it is on; `MigrationBodies` sets it.
private struct ProvisioningMarksCelebrateKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var provisioningMarksCelebrate: Bool {
        get { self[ProvisioningMarksCelebrateKey.self] }
        set { self[ProvisioningMarksCelebrateKey.self] = newValue }
    }
}

