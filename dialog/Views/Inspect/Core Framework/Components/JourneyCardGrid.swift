//
//  JourneyCardGrid.swift
//  dialog
//
//  The delivery journey's rows (`ProvisioningRowModel`, the same rows as the checklist) as a card grid:
//  artwork tile, name, state word, and a ring on the active card. A window of `columns` cards slides to
//  keep the frontier in `JourneyGridM.anchorSlot`. Includes the glass card style and division mode.
import SwiftUI

/// The card grid's numbers at 820 wide; everything derives from the capsule width the shell hands in.
enum JourneyGridM {
    /// Four slots always; a two-item grid keeps tile-sized cards, left-aligned.
    static let columns = 4
    /// The frontier card's slot once the row has moved: index 2, two finished cards to its left.
    static let anchorSlot = 2
    static let gap: CGFloat = 16                 // between cards
    static let tileRadius: CGFloat = 12
    static let ringWidth: CGFloat = 2            // outside the tile edge
    static let hairline: CGFloat = 0.5
    static let textGap: CGFloat = 8              // tile → name → word
    static let nameSize: CGFloat = 14            // semibold
    /// The name may wrap once, with the space always reserved; division mode names cards by long messages.
    static let nameLines = 2
    static let nameMinScale: CGFloat = 0.8       // a long name shrinks to this before it truncates
    /// Type steps down at five columns so the row reads as one; the per-name shrink is a last resort.
    static func nameSize(columns: Int) -> CGFloat { columns >= 5 ? 12.5 : nameSize }
    static func wordSize(columns: Int) -> CGFloat { columns >= 5 ? 11.5 : wordSize }
    /// Three reserved name lines at five columns, so names keep one size.
    static func nameLines(columns: Int) -> Int { columns >= 5 ? 3 : nameLines }
    static let wordSize: CGFloat = 12.5          // regular
    /// The second line reserves three lines (claims can wrap), so row height never depends on content.
    static let wordLines = 3
    static let wordLineHeight: CGFloat = 1.2     // line-height multiple
    static let headerSize: CGFloat = 13          // "4 items"
    static let headerGap: CGFloat = 16           // header → cards
    /// Artwork's fraction of the tile side; leaves the tile's edge visible around the icon.
    static let artFraction: CGFloat = 0.8
    static let initialFraction: CGFloat = 0.34

    /// A card's artwork from its `art` path, an image file or an app bundle (`ItemArt.image(at:)` handles both).
    static func artwork(at path: String?) -> NSImage? { ItemArt.image(at: path) }
    static let tileHairlineOpacity: CGFloat = 0.08
    /// The grid's capsule on the flat panel: radius 14, text ink at 4%, padding 20 × 22.
    /// The setup-assistant shell brings its own capsule.
    static let capsuleRadius: CGFloat = 14
    static let capsulePadH: CGFloat = 22
    static let capsulePadV: CGFloat = 20
    static let capsuleFillOpacity: CGFloat = 0.04
    // The optional `gridProgress` bar: 4 tall, r2, 12% ink track, half the row's width, centred.
    static let progressHeight: CGFloat = 4
    static let progressRadius: CGFloat = 2
    static let progressTrack: CGFloat = 0.12
    static let progressWidthFraction: CGFloat = 0.5
    static func tileSide(width: CGFloat, columns: Int = columns) -> CGFloat {
        (width - gap * CGFloat(columns - 1)) / CGFloat(max(columns, 1))
    }
    /// Everything that is not the tile: count line, gaps, name and reserved claim lines. Fixed.
    static var textBlockHeight: CGFloat {
        headerSize * 1.2 + headerGap
            + textGap + nameSize * wordLineHeight * CGFloat(nameLines)
            + textGap + wordSize * wordLineHeight * CGFloat(wordLines)
    }
    /// The smallest tile side.
    static let minTileSide: CGFloat = 96
    /// The tile the width allows, capped by the host's height; the tile shrinks, the text block never does.
    static func tileSide(width: CGFloat, maxHeight: CGFloat?, columns: Int = columns) -> CGFloat {
        let byWidth = tileSide(width: width, columns: columns)
        guard let maxHeight else { return byWidth }
        return max(minTileSide, min(byWidth, maxHeight - textBlockHeight))
    }
}

/// The step's `layout`: "grid" draws cards, anything else keeps the checklist.
enum JourneyLayout {
    static func isGrid(_ layout: String?) -> Bool {
        layout?.trimmingCharacters(in: .whitespaces).lowercased() == "grid"
    }
}

extension JourneyScroll {
    /// The `size` rows the grid shows: the frontier in `JourneyGridM.anchorSlot`, the first rows before
    /// anything moves, the last rows once everything is terminal. Pure, for tests.
    static func window(rows: [ProvisioningRowModel], size: Int) -> [ProvisioningRowModel] {
        guard size > 0, rows.count > size else { return rows }
        // Anchor on the active card, else the last finished one, so the window only moves forward.
        let anchorIndex: Int
        if let active = rows.firstIndex(where: { $0.mark == .active }) {
            anchorIndex = active
        } else if let lastTerminal = rows.lastIndex(where: isTerminal) {
            anchorIndex = lastTerminal
        } else {
            anchorIndex = 0
        }
        // The anchor stays in `anchorSlot`; the window clamps at either end of the row.
        let slot = min(JourneyGridM.anchorSlot, size - 1)
        let start = min(max(anchorIndex - slot, 0), rows.count - size)
        return Array(rows[start ..< start + size])
    }
}

// MARK: - Division mode

/// Division mode (`divisionMode`): the step's authored cadence entries are cards, and each card
/// completes on its share of the real item count. Pure, for tests.
enum JourneyPacing {
    /// The finished-item count at which each card completes.
    /// Fractional (no final message): boundary k = ceil((k+1) × total / cards).
    /// Whole shares (final message authored): boundary k = (k+1) × floor(total / cards); the remainder
    /// is the final stretch, where the last card shows the final message until every item is done.
    static func boundaries(cards: Int, total: Int, wholeShares: Bool) -> [Int] {
        guard cards > 0 else { return [] }
        guard total > 0 else { return Array(repeating: 0, count: cards) }
        if wholeShares, total >= cards {
            let share = total / cards
            return (0..<cards).map { ($0 + 1) * share }
        }
        return (0..<cards).map { k in
            Int((Double(k + 1) * Double(total) / Double(cards)).rounded(.up))
        }
    }

    /// True in the final stretch: every card's share is done but items remain (whole shares only).
    static func inFinalStretch(completed: Int, total: Int, boundaries: [Int]) -> Bool {
        guard let last = boundaries.last, total > 0 else { return false }
        return completed >= last && completed < total
    }

    /// Each card's mark: done past its boundary, the first undone card active once anything has
    /// happened, the rest queued. Zero items leaves every card queued.
    static func marks(completed: Int, total: Int, anyActive: Bool,
                      boundaries: [Int]) -> [ProvisioningRowMark] {
        guard total > 0 else { return Array(repeating: .queued, count: boundaries.count) }
        var marks: [ProvisioningRowMark] = []
        var frontierFound = false
        for boundary in boundaries {
            if completed >= boundary && !(inFinalStretch(completed: completed, total: total,
                                                          boundaries: boundaries)
                                          && boundary == boundaries.last) {
                marks.append(.done)
            } else if !frontierFound {
                frontierFound = true
                marks.append((completed > 0 || anyActive) ? .active : .queued)
            } else {
                marks.append(.queued)
            }
        }
        return marks
    }

    /// The cards as grid rows. Name is the entry's label, else its message; in the final stretch the
    /// last card shows the authored final message.
    static func rows(entries: [InspectConfig.CadenceEntry], completed: Int, total: Int,
                     anyActive: Bool, vocabulary: ProvisioningVocabulary,
                     finalMessage: String? = nil) -> [ProvisioningRowModel] {
        let final = finalMessage?.trimmingCharacters(in: .whitespaces)
        let wholeShares = !(final ?? "").isEmpty
        let bounds = boundaries(cards: entries.count, total: total, wholeShares: wholeShares)
        let marks = marks(completed: completed, total: total, anyActive: anyActive, boundaries: bounds)
        let stretch = inFinalStretch(completed: completed, total: total, boundaries: bounds)
        return zip(entries, marks).enumerated().map { index, pair in
            let (entry, mark) = pair
            let isLast = index == entries.count - 1
            // Items (lower, upper]; the last card's upper is the total when a final stretch follows.
            let lower = index == 0 ? 0 : bounds[index - 1]
            let upper = (isLast && stretch) ? total : bounds[index]
            let share: Double? = upper > lower
                ? min(max(Double(completed - lower) / Double(upper - lower), 0), 1) : nil
            let word: String
            switch mark {
            case .done:            word = vocabulary.done
            case .active:          word = vocabulary.active
            case .queued, .choice, .check, .symbol: word = vocabulary.queued
            case .failed:          word = vocabulary.failed
            }
            let name = (entry.label?.isEmpty == false) ? entry.label! : entry.message
            var claim: String? = (entry.label?.isEmpty == false) ? entry.message : nil
            if stretch, isLast, let final, !final.isEmpty { claim = final }
            var row = ProvisioningRowModel(id: entry.id, name: name, mark: mark,
                                           trailing: .state(word, failed: false))
            row.art = entry.imagePath
            row.claim = claim
            row.share = share
            return row
        }
    }
}

/// Division mode resolved once per render: card rows, the header count, and whether the primary stays
/// shut through the final stretch. nil when not in division mode or no cadence entries are authored.
enum JourneyDivision {
    struct Result {
        let cardRows: [ProvisioningRowModel]
        let total: Int
        let completed: Int
        let primaryDisabled: Bool
        /// `holdPrimary: "hidden"`: the door is not drawn until the last item completes.
        let primaryHidden: Bool
    }

    static func resolve(step: InspectConfig.IntroStep, rows: [ProvisioningRowModel],
                        vocabulary: ProvisioningVocabulary) -> Result? {
        guard step.divisionMode == true,
              let entries = step.cadence?.entries, !entries.isEmpty else { return nil }
        let completed = rows.filter(JourneyScroll.isTerminal).count
        let anyActive = rows.contains { $0.mark == .active }
        let cardRows = JourneyPacing.rows(entries: entries, completed: completed, total: rows.count,
                                          anyActive: anyActive, vocabulary: vocabulary,
                                          finalMessage: step.finalMessage)
        let primaryDisabled: Bool
        var primaryHidden = false
        switch step.holdPrimary {
        case "disabled":
            primaryDisabled = completed < rows.count
        case "hidden":
            primaryHidden = completed < rows.count
            primaryDisabled = false
        case "none":
            primaryDisabled = false
        default:
            let hasFinal = !(step.finalMessage?.trimmingCharacters(in: .whitespaces) ?? "").isEmpty
            primaryDisabled = hasFinal && completed < rows.count
        }
        return Result(cardRows: cardRows, total: rows.count, completed: completed,
                      primaryDisabled: primaryDisabled, primaryHidden: primaryHidden)
    }
}

/// The grid inside the shell's capsule: a count line, then one row of cards.
struct JourneyCardGrid: View {
    let rows: [ProvisioningRowModel]
    let accent: Color
    let width: CGFloat
    /// The height available to the whole grid. nil lets width decide the tile; with a value the tile
    /// shrinks, never the text.
    var maxHeight: CGFloat?
    /// The header count: rows in per-app mode, items in scope in division mode.
    var total: Int?
    /// The tile's soft fill; off on the plain ground.
    var tileFill: Bool = true
    /// Cards per row (`gridColumns`): four, or five with smaller tiles. Exactly five cards never slide.
    var columns: Int = JourneyGridM.columns
    /// `gridProgress`: 0…1 draws the centred bar under the row; nil draws nothing.
    var progress: Double?
    @Environment(\.palette) private var palette

    private var shown: [ProvisioningRowModel] {
        JourneyScroll.window(rows: rows, size: columns)
    }

    var body: some View {
        let side = JourneyGridM.tileSide(width: width, maxHeight: maxHeight, columns: columns)
        let count = total ?? rows.count
        VStack(alignment: .leading, spacing: JourneyGridM.headerGap) {
            // The count is state and stays, in the muted weight.
            Text("\(count) \(count == 1 ? "item" : "items")")
                .font(.system(size: JourneyGridM.headerSize))
                .foregroundStyle(palette.textMuted)
            HStack(alignment: .top, spacing: JourneyGridM.gap) {
                ForEach(shown) { row in
                    // The slot keeps the column width when the tile shrinks, so the claim keeps its measure.
                    JourneyCardTile(row: row, accent: accent, side: side,
                                    slotWidth: JourneyGridM.tileSide(width: width, columns: columns),
                                    tileFill: tileFill,
                                    nameSize: JourneyGridM.nameSize(columns: columns),
                                    wordSize: JourneyGridM.wordSize(columns: columns),
                                    nameLines: JourneyGridM.nameLines(columns: columns))
                        // Leaving cards exit left, arriving ones enter right: the direction the window slides.
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)))
                }
            }
            // Clip the slide to the row, widened and heightened by `ringWidth` so edge rings are not shaved.
            .padding(JourneyGridM.ringWidth)
            .frame(width: width + JourneyGridM.ringWidth * 2, alignment: .leading)
            .clipped()
            .padding(-JourneyGridM.ringWidth)
            .animation(.easeInOut(duration: 0.35), value: shown.map(\.id))
            if let progress {
                let barWidth = width * JourneyGridM.progressWidthFraction
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: JourneyGridM.progressRadius)
                        .fill(palette.text.opacity(JourneyGridM.progressTrack))
                    RoundedRectangle(cornerRadius: JourneyGridM.progressRadius)
                        .fill(accent)
                        .frame(width: barWidth * min(max(progress, 0), 1))
                        .animation(.easeInOut(duration: 0.35), value: progress)
                }
                .frame(width: barWidth, height: JourneyGridM.progressHeight)
                .frame(width: width)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")
                .accessibilityIdentifier("grid-progress")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Apps")
    }
}

/// One card: tile (artwork or initial), name, word. Only the ring marks "active"; the tile does not change.
struct JourneyCardTile: View {
    let row: ProvisioningRowModel
    let accent: Color
    let side: CGFloat
    /// The card's width; defaults to the tile side. A height-capped host passes the full slot.
    var slotWidth: CGFloat?
    /// The tile's soft fill; off on the plain ground.
    var tileFill: Bool = true
    /// Type size for this column count (`JourneyGridM.nameSize(columns:)`).
    var nameSize: CGFloat = JourneyGridM.nameSize
    var wordSize: CGFloat = JourneyGridM.wordSize
    var nameLines: Int = JourneyGridM.nameLines
    @Environment(\.palette) private var palette

    private var isActive: Bool { row.mark == .active }
    private var cardWidth: CGFloat { max(slotWidth ?? side, side) }

    var body: some View {
        VStack(alignment: .leading, spacing: JourneyGridM.textGap) {
            tile
            // `nameLines` reserved, like the claim; division-mode names are long messages.
            Text(row.name)
                .font(.system(size: nameSize, weight: .semibold))
                .foregroundStyle(palette.text)
                .lineLimit(nameLines)
                // Long names shrink to 80% before truncating; the reserved height never moves.
                .minimumScaleFactor(JourneyGridM.nameMinScale)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: nameSize * JourneyGridM.wordLineHeight
                                  * CGFloat(nameLines),
                       alignment: .top)
            // Three reserved lines (`wordLines`), so a claim turning into a word never resizes the card.
            Text(word)
                .font(.system(size: wordSize))
                .foregroundStyle(wordInk)
                .lineLimit(JourneyGridM.wordLines)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: wordSize * JourneyGridM.wordLineHeight
                                  * CGFloat(JourneyGridM.wordLines),
                       alignment: .top)
        }
        .frame(width: cardWidth, alignment: .leading)
        .opacity(row.enabled ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(word)")
        .accessibilityIdentifier("card-\(row.id)")
    }

    private var tile: some View {
        RoundedRectangle(cornerRadius: JourneyGridM.tileRadius, style: .continuous)
            .fill(tileFill ? palette.surfaceRaised : Color.clear)
            .frame(width: side, height: side)
            .overlay(artwork)
            .overlay {
                RoundedRectangle(cornerRadius: JourneyGridM.tileRadius, style: .continuous)
                    .strokeBorder(palette.text.opacity(JourneyGridM.tileHairlineOpacity),
                                  lineWidth: JourneyGridM.hairline)
            }
            .overlay {
                if isActive {
                    // Drawn outside the edge so the tile keeps its size when active.
                    RoundedRectangle(cornerRadius: JourneyGridM.tileRadius + JourneyGridM.ringWidth,
                                     style: .continuous)
                        .strokeBorder(accent, lineWidth: JourneyGridM.ringWidth)
                        .padding(-JourneyGridM.ringWidth)
                }
            }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = JourneyGridM.artwork(at: row.art) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: side * JourneyGridM.artFraction,
                       height: side * JourneyGridM.artFraction)
        } else {
            // No usable artwork: the initial in muted ink.
            Text(String(row.name.prefix(1)).uppercased())
                .font(.system(size: side * JourneyGridM.initialFraction, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
    }

    private var word: String { Self.secondLine(for: row) }

    /// The card's second line: the cadence claim while unfinished, the state word once terminal.
    /// A card with no claim shows its state word throughout.
    static func secondLine(for row: ProvisioningRowModel) -> String {
        let stateWord: String
        switch row.trailing {
        case .state(let word, _): stateWord = word
        case .notice(let word):
            // A notice ("Removed") outranks the claim.
            return word
        case .identity, .toggle, .none: stateWord = ""
        }
        guard let claim = row.claim?.trimmingCharacters(in: .whitespaces), !claim.isEmpty else {
            return stateWord
        }
        switch row.mark {
        case .queued, .active, .choice, .check, .symbol: return claim
        case .done, .failed:            return stateWord
        }
    }

    private var wordInk: Color {
        switch row.trailing {
        case .state(_, let failed) where failed: return palette.warning
        case .notice:                            return palette.notice
        default:                                 return palette.textMuted
        }
    }
}


// MARK: - Glass card

/// The card style (`gridStyle`): `tile` puts art above name and word; `glass` puts glyph, name and
/// status in one glass tile, the active one ringed and lifted.
enum JourneyGridStyle: String {
    case tile
    case glass

    static func resolve(_ authored: String?) -> JourneyGridStyle {
        authored?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "glass" ? .glass : .tile
    }
}

/// The glass grid's numbers for the 820×600 sheet. The column sits at 48 rails (724 wide), so five cards
/// are (724 − 4·14) / 5 = 133.6. Y positions are fixed from the top of the host.
enum JourneyGlassM {
    /// The content grid: 48 leading / 48 trailing. The footer band keeps `FooterBandM.rail`.
    static let rail: CGFloat = 48
    static var column: CGFloat { SetupAssistantM.recommended.width - rail * 2 }   // 724
    static let gap: CGFloat = 14
    static let radius: CGFloat = 16
    static let padTop: CGFloat = 16
    static let padH: CGFloat = 12
    static let padBottom: CGFloat = 14
    static let innerGap: CGFloat = 8
    /// 36pt inside a 133.6 card, so a line-art mark stays legible.
    static let glyph: CGFloat = 36
    static let nameSize: CGFloat = 12
    /// Name line height multiple (12pt semibold).
    static let nameLineHeight: CGFloat = 1.3
    /// The name's line ceiling. Names wrap, never shrink; the row grows to its longest card.
    static let nameMaxLines = 4
    /// Status: 11pt medium, pinned to the tile bottom.
    static let statusSize: CGFloat = 11
    static let fillOpacity: CGFloat = 0.05
    static let activeFillOpacity: CGFloat = 0.07
    static let hairlineOpacity: CGFloat = 0.10
    static let nameInkOpacity: CGFloat = 0.7
    static let statusInkOpacity: CGFloat = 0.35
    static let doneGlyphOpacity: CGFloat = 0.55
    static let queuedOpacity: CGFloat = 0.5
    static let ringWidth: CGFloat = 1.5
    static let lift: CGFloat = 4
    static let shadowY: CGFloat = 8
    static let shadowRadius: CGFloat = 11      // SwiftUI radius for a 22px blur
    static let shadowOpacity: CGFloat = 0.18   // lighter than on dark; on a light ground the ink does the lifting
    /// The track under the row: 6pt, radius to match.
    static let trackHeight: CGFloat = 6
    static let trackRadius: CGFloat = 3
    static let trackOpacity: CGFloat = 0.14
    /// Header top, measured from the top of the host.
    static let headerTop: CGFloat = 48
    /// Tile row top: 87 below the header (header bottom 120).
    static let rowTop: CGFloat = 207
    /// The card height varies with its name lines, so the track and caption are pinned as gaps
    /// below the row (24 each), not as positions.
    static let trackGap: CGFloat = 24
    static let supportGap: CGFloat = 24
    /// Title: 34pt bold.
    static let titleSize: CGFloat = 34
    static let titleTracking: CGFloat = -0.68  // −.02em at 34
    /// Lede 10 under the title, 15pt regular, max width 520.
    static let ledeSize: CGFloat = 15
    static let ledeMaxWidth: CGFloat = 520
    static let headerGap: CGFloat = 10
    /// Counter: 14pt mono medium, white 40%.
    static let counterSize: CGFloat = 14
    static let counterOpacity: CGFloat = 0.4
    /// Caption: 14pt regular, line height 21, white 40%, max width 400.
    static let supportSize: CGFloat = 14
    static let supportOpacity: CGFloat = 0.4
    static let supportMaxWidth: CGFloat = 400
    /// On the banded ground the band ends here, under the lede and above the row.
    static let bandFoot: CGFloat = 176

    static func cardWidth(width: CGFloat, columns: Int) -> CGFloat {
        (width - gap * CGFloat(columns - 1)) / CGFloat(max(columns, 1))
    }

    /// How many lines `name` needs inside a card of `cardWidth`, measured with the card's own font.
    nonisolated static func lines(for name: String, cardWidth: CGFloat) -> Int {
        let text = cardWidth - padH * 2
        guard text > 0, !name.isEmpty else { return 1 }
        let font = NSFont.systemFont(ofSize: nameSize, weight: .semibold)
        let box = (name as NSString).boundingRect(
            with: NSSize(width: text, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])
        return max(1, min(nameMaxLines, Int(ceil(box.height / (nameSize * nameLineHeight)))))
    }

    /// Lines reserved for the name on every card of every deck, so card height never changes as the
    /// row moves. With the 148 floor, three-line labels draw every card at 148 × 133.6; a four-line label
    /// grows its row (`nameMaxLines`). Check a deck with `lines(for:cardWidth:)`.
    static let nameSeat = 3
    /// Card minimum height, padding included.
    static let minHeight: CGFloat = 148

    // Marks change at once; the window slides after `slideDelay` so the eye reads state, then movement.
    /// How long the new active ring runs before the row moves (about a third of `CadenceM.ringRevolution`).
    static let slideDelay: Duration = .milliseconds(650)
    /// `.smooth`: a bounce-free spring.
    static let slideDuration: TimeInterval = 0.7
}

/// One glass card: glyph, name and status in a glass tile. Active is ringed, lifted 4 and shadowed;
/// queued sits at half opacity; finished dims its glyph.
struct JourneyGlassCard: View {
    let row: ProvisioningRowModel
    let accent: Color
    let width: CGFloat
    /// Lines held for the name; `JourneyGlassM.nameSeat` keeps every card the same height.
    var nameLines: Int = JourneyGlassM.nameSeat
    @Environment(\.palette) private var palette

    private var isActive: Bool { row.mark == .active }
    private var isQueued: Bool {
        switch row.mark {
        case .queued, .choice: return true
        default: return false
        }
    }
    private var word: String { JourneyCardTile.secondLine(for: row) }
    private var statusInk: Color {
        switch row.trailing {
        case .state(_, let failed) where failed: return palette.warning
        case .notice:                            return palette.notice
        default: return isActive ? accent : palette.text.opacity(JourneyGlassM.statusInkOpacity)
        }
    }

    var body: some View {
        // The word sits on the card's floor, so words line up across the row.
        VStack(spacing: 0) {
            glyph
                .frame(width: JourneyGlassM.glyph, height: JourneyGlassM.glyph)
                .opacity(row.mark == .done ? JourneyGlassM.doneGlyphOpacity : 1)
            Text(row.name)
                .font(.system(size: JourneyGlassM.nameSize, weight: .semibold))
                .foregroundStyle(isActive ? palette.text : palette.text.opacity(JourneyGlassM.nameInkOpacity))
                .multilineTextAlignment(.center)
                .lineLimit(JourneyGlassM.nameMaxLines)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: JourneyGlassM.nameSize * JourneyGlassM.nameLineHeight * CGFloat(nameLines),
                       alignment: .top)
                .padding(.top, JourneyGlassM.innerGap)
            Spacer(minLength: JourneyGlassM.innerGap)
            Text(word)
                .font(.system(size: JourneyGlassM.statusSize, weight: .medium))
                .foregroundStyle(statusInk)
                .lineLimit(1)
        }
        .frame(width: width - JourneyGlassM.padH * 2)
        .padding(.top, JourneyGlassM.padTop)
        .padding(.bottom, JourneyGlassM.padBottom)
        .padding(.horizontal, JourneyGlassM.padH)
        // The 148 floor; the Spacer above the word takes the slack.
        .frame(minHeight: JourneyGlassM.minHeight)
        .background(
            RoundedRectangle(cornerRadius: JourneyGlassM.radius, style: .continuous)
                .fill(palette.text.opacity(isActive ? JourneyGlassM.activeFillOpacity : JourneyGlassM.fillOpacity))
                .overlay(ring))
        .shadow(color: isActive ? palette.text.opacity(JourneyGlassM.shadowOpacity) : .clear,
                radius: JourneyGlassM.shadowRadius, y: JourneyGlassM.shadowY)
        .offset(y: isActive ? -JourneyGlassM.lift : 0)
        .opacity(isQueued ? JourneyGlassM.queuedOpacity : 1)
        .animation(.easeInOut(duration: 0.25), value: row.mark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.name), \(word)")
        .accessibilityIdentifier("card-\(row.id)")
    }

    /// The card's border: a hairline while queued or done; while active, `CadenceActiveRing`'s sweep.
    @ViewBuilder private var ring: some View {
        let shape = RoundedRectangle(cornerRadius: JourneyGlassM.radius, style: .continuous)
        if isActive {
            CadenceActiveRing(cornerRadius: JourneyGlassM.radius, color: accent)
        } else {
            shape.strokeBorder(palette.text.opacity(JourneyGlassM.hairlineOpacity), lineWidth: 0.5)
        }
    }

    @ViewBuilder private var glyph: some View {
        if let image = JourneyGridM.artwork(at: row.art) {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            Text(String(row.name.prefix(1)).uppercased())
                .font(.system(size: JourneyGlassM.glyph * 0.5, weight: .semibold))
                .foregroundStyle(palette.textMuted)
        }
    }
}

/// The glass row: `columns` glass cards at `JourneyGlassM.gap`, windowed like the tile grid. The header
/// carries the counter and the shell the track.
struct JourneyGlassRow: View {
    let rows: [ProvisioningRowModel]
    let accent: Color
    let width: CGFloat
    var columns: Int = 5

    /// The ids on screen. `.task(id:)` moves `held` to `desired` after `JourneyGlassM.slideDelay`,
    /// restarting on each receipt so a burst slides once. Empty until first render, which shows `desired`.
    @State private var held: [String] = []

    private var desired: [String] { JourneyScroll.window(rows: rows, size: columns).map(\.id) }

    /// Cards on screen: membership from `held`, marks from `rows`, so state updates at once and only the slide waits.
    private var shown: [ProvisioningRowModel] {
        let ids = held.isEmpty ? desired : held
        let byID = Dictionary(rows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return ids.compactMap { byID[$0] }
    }

    var body: some View {
        let cardWidth = JourneyGlassM.cardWidth(width: width, columns: columns)
        HStack(alignment: .top, spacing: JourneyGlassM.gap) {
            ForEach(shown) { row in
                JourneyGlassCard(row: row, accent: accent, width: cardWidth,
                                 nameLines: JourneyGlassM.nameSeat)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
        }
        // One row height; each card's floor spacer absorbs the difference so words line up.
        .fixedSize(horizontal: false, vertical: true)
        // The lift and shadow reach outside the row's box; clip generously.
        .padding(.vertical, JourneyGlassM.lift + JourneyGlassM.shadowY + JourneyGlassM.shadowRadius)
        .padding(.horizontal, JourneyGlassM.ringWidth)
        .frame(width: width + JourneyGlassM.ringWidth * 2, alignment: .leading)
        .clipped()
        .padding(.vertical, -(JourneyGlassM.lift + JourneyGlassM.shadowY + JourneyGlassM.shadowRadius))
        .padding(.horizontal, -JourneyGlassM.ringWidth)
        .animation(.smooth(duration: JourneyGlassM.slideDuration), value: shown.map(\.id))
        // `.task(id:)` cancels a pending slide when `desired` changes, so one burst slides once.
        .task(id: desired) {
            if held.isEmpty { held = desired; return }
            guard held != desired else { return }
            try? await Task.sleep(for: JourneyGlassM.slideDelay)
            guard !Task.isCancelled else { return }
            held = desired
        }
    }
}

/// The glass row's track: 6pt, radius 3, a 14% ink wash under the accent, full row width.
struct JourneyGlassTrack: View {
    let progress: Double
    let accent: Color
    let width: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: JourneyGlassM.trackRadius)
                .fill(palette.text.opacity(JourneyGlassM.trackOpacity))
            RoundedRectangle(cornerRadius: JourneyGlassM.trackRadius)
                .fill(accent)
                .frame(width: width * min(max(progress, 0), 1))
                .animation(.easeInOut(duration: 0.35), value: progress)
        }
        .frame(width: width, height: JourneyGlassM.trackHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")
        .accessibilityIdentifier("grid-progress")
    }
}
