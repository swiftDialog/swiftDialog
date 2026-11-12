//
//  Preset2Components.swift
//  dialog
//
//  Preset 2's content components: the paged card grid, its cards and the progress block.
//  Progress and status text come only from real item data; nothing is estimated.
//

import SwiftUI

// MARK: - Card state

enum Preset2CardState {
    case completed, active, failed, queued
}

// MARK: - Pager math

/// Cards per page: how many target-width columns fit between the gutters and the peek column.
/// The target only decides the count; the columns flex to divide the row. 168 keeps 4-across
/// at the 800pt base window.
func preset2CardsPerPage(windowWidth: CGFloat, scaleFactor: CGFloat) -> Int {
    let gutters = InspectMetrics(scale: scaleFactor).phaseFooterHorizontal + 44
    let available = windowWidth - gutters
    let cardWidth: CGFloat = 168 * scaleFactor
    let cardSpacing: CGFloat = 14 * scaleFactor
    return max(2, min(6, Int((available + cardSpacing) / (cardWidth + cardSpacing))))
}

// MARK: - Paged card grid

struct Preset2CardPager: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let accent: Color
    let loc: PresetLocalization
    let onItemInfo: (InspectConfig.ItemConfig) -> Void

    /// Index of the first visible card. Following the install slides it one card at a time; the arrow
    /// and the dots move it a page at a time.
    @State private var startIndex = 0

    private var items: [InspectConfig.ItemConfig] { inspectState.items }

    private var cardsPerPage: Int {
        preset2CardsPerPage(windowWidth: windowSize.width, scaleFactor: scaleFactor)
    }

    private var pageCount: Int { max(1, Int(ceil(Double(items.count) / Double(cardsPerPage)))) }

    private var maxStart: Int { max(0, items.count - cardsPerPage) }

    /// The page the dots mark: the last one once the window reaches the end.
    private var pageIndex: Int { startIndex >= maxStart ? pageCount - 1 : startIndex / cardsPerPage }

    private var visibleItems: [InspectConfig.ItemConfig] {
        let start = min(startIndex, maxStart)
        guard start < items.count else { return [] }
        return Array(items[start..<min(start + cardsPerPage, items.count)])
    }

    private func show(page: Int) {
        withAnimation(.easeInOut(duration: InspectConstants.standardAnimationDuration)) {
            startIndex = min(page * cardsPerPage, maxStart)
        }
    }

    private func cardState(_ item: InspectConfig.ItemConfig) -> Preset2CardState {
        if inspectState.failedItems.contains(item.id) { return .failed }
        if inspectState.completedItems.contains(item.id) {
            // Completed-but-validation-failed must not read "Ready to use".
            return PresetCommonViews.hasValidationWarning(for: item, state: inspectState) ? .failed : .completed
        }
        if inspectState.downloadingItems.contains(item.id) { return .active }
        return .queued
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                HStack(spacing: 14 * scaleFactor) {
                    if visibleItems.count < cardsPerPage { Spacer(minLength: 0) }
                    ForEach(visibleItems, id: \.id) { item in
                        Preset2AppCard(
                            item: item,
                            state: cardState(item),
                            accent: accent,
                            progress: inspectState.itemProgress[item.id],
                            statusLine: inspectState.logMonitorStatuses[item.id],
                            statusText: statusText(for: item),
                            displayName: localizedDisplayName(for: item),
                            resolvedIconPath: iconCache.getItemIconPath(for: item, state: inspectState)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 14))
                        .onTapGesture { onItemInfo(item) }
                        // Sliding left: a finished card leaves at the leading edge, the next one enters
                        // at the trailing edge, and the cards between move over by one.
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                removal: .move(edge: .leading).combined(with: .opacity)))
                    }
                    if visibleItems.count < cardsPerPage { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity)

                if startIndex < maxStart {
                    Preset2PeekColumn(accent: accent) { show(page: pageIndex + 1) }
                } else if pageCount > 1 {
                    Preset2PeekColumn(accent: accent, backwards: true) { show(page: 0) }
                }
            }
            .padding(.leading, InspectMetrics(scale: scaleFactor).phaseFooterHorizontal)
            .padding(.trailing, pageCount > 1 ? 0 : InspectMetrics(scale: scaleFactor).phaseFooterHorizontal)

            if pageCount > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        Button { show(page: page) } label: {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(page == pageIndex ? accent : Color.secondary.opacity(0.4))
                                .frame(width: page == pageIndex ? 20 : 5, height: 5)
                                .padding(4)  // hit target around a 5pt dot
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8 * scaleFactor)
            }
        }
        // Auto-follow (#565): the pager must advance even when items skip the download phase.
        .onChange(of: inspectState.downloadingItems) { _, _ in followProgress() }
        .onChange(of: inspectState.completedItems) { _, _ in followProgress() }
        .onChange(of: inspectState.failedItems) { _, _ in followProgress() }
    }

    /// The card the pager keeps in view: the one installing, else the first not yet finished.
    /// A failed card counts as finished.
    static func followAnchor(ids: [String], downloading: Set<String>, completed: Set<String>,
                             failed: Set<String>) -> Int {
        if let idx = ids.firstIndex(where: { downloading.contains($0) && !completed.contains($0) && !failed.contains($0) }) {
            return idx
        }
        if let idx = ids.firstIndex(where: { !completed.contains($0) && !failed.contains($0) }) { return idx }
        return max(0, ids.count - 1)
    }

    /// The first visible card that keeps `anchor` in view with one waiting card after it (done, done,
    /// installing, waiting at four per page): unchanged while it sits in that range; past it the window
    /// slides one card per finished card; before the first slot it sits first. Under three per page there
    /// is no room for the look-ahead.
    static func followStart(anchor: Int, start: Int, perPage: Int, count: Int) -> Int {
        let maxStart = max(0, count - perPage)
        let lastSlot = perPage >= 3 ? perPage - 2 : perPage - 1
        let target: Int
        if anchor > start + lastSlot { target = anchor - lastSlot }
        else if anchor < start { target = anchor }
        else { target = start }
        return min(max(0, target), maxStart)
    }

    private func followProgress() {
        let anchorIndex = Self.followAnchor(ids: items.map(\.id), downloading: inspectState.downloadingItems,
                                            completed: inspectState.completedItems, failed: inspectState.failedItems)
        let target = Self.followStart(anchor: anchorIndex, start: startIndex, perPage: cardsPerPage, count: items.count)
        guard target != startIndex else { return }
        // After the card's own state change (colour, status line, badge) has drawn, so the slide moves each
        // card as one piece. In the same transaction its name jumps to the new slot ahead of the card; a
        // plain `async` still lands in that render pass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.6)) { startIndex = target }
        }
    }

    // MARK: Localized / customized status copy

    private func localizedDisplayName(for item: InspectConfig.ItemConfig) -> String {
        loc.string("\(item.id).displayName", fallback: item.displayName) ?? item.displayName
    }

    /// The card's localized status word; the live log-monitor line (`statusLine`) wins over it.
    private func statusText(for item: InspectConfig.ItemConfig) -> String {
        loc.itemStatus(for: item, baseStatus: ItemSetModel.row(for: item, state: inspectState).statusText)
    }
}

// MARK: - App card

/// The card's fixed seats. The card is always `height` tall and the name seat always two lines,
/// so a wrapping name never moves the status under it.
enum Preset2CardM {
    /// Badge offset from the tile corner; 0 centres it inside the icon's corner.
    static let badgeInset: CGFloat = 0
    static let height: CGFloat = 168
    static let padTop: CGFloat = 12
    static let padBottom: CGFloat = 12
    /// 64 icon + 2 × 6 tile padding.
    static let tile: CGFloat = 76
    static let gap: CGFloat = 8
    static let nameSize: CGFloat = 12
    /// Measured height of a 12pt semibold line.
    static let nameLineHeight: CGFloat = 15
    static let nameLines = 2
    static var nameSeat: CGFloat { nameLineHeight * CGFloat(nameLines) }
    static let statusLineHeight: CGFloat = 15
    /// The seats and gaps the card must hold with no claim authored.
    static var fixedContent: CGFloat {
        padTop + tile + gap + nameSeat + gap + statusLineHeight + padBottom
    }
}

struct Preset2AppCard: View {
    let item: InspectConfig.ItemConfig
    let state: Preset2CardState
    let accent: Color
    let progress: Int?          // real per-item percentage when one exists
    let statusLine: String?     // live log-monitor text when one exists
    let statusText: String      // resolved static copy
    let displayName: String
    let resolvedIconPath: String
    @Environment(\.palette) private var palette

    @Environment(\.inspectGlow) private var glow
    private var isActive: Bool { state == .active }

    private var cardBackground: Color {
        isActive ? palette.cardSurface : palette.surfaceRaised
    }
    private var hairline: Color { palette.hairline }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                // No `defaultImage:`: IconView fills an empty path itself before any default applies.
                IconView(image: resolvedIconPath)
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(cornerRadius: 15))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(isActive ? accent.opacity(0.08 * glow.factor) : Color.clear)
                    )

                switch state {
                case .completed, .failed:
                    StatusIndicatorCircle(status: state == .failed ? .failed : .completed, accent: accent,
                                          size: 22, glyphSize: 11, ring: cardBackground)
                        .offset(x: Preset2CardM.badgeInset, y: Preset2CardM.badgeInset)
                case .active:
                    Preset2SpinnerRing(accent: accent, ring: cardBackground)
                        .offset(x: Preset2CardM.badgeInset, y: Preset2CardM.badgeInset)
                case .queued:
                    EmptyView()
                }
            }

            Text(displayName)
                .font(.system(size: Preset2CardM.nameSize, weight: .semibold))
                .lineLimit(Preset2CardM.nameLines)
                .multilineTextAlignment(.center)
                .foregroundStyle(isActive ? accent : .primary)
                .frame(height: Preset2CardM.nameSeat, alignment: .top)

            // No claim or identifier on the card; both open in the card's sheet.
            switch state {
            case .completed:
                // Green as in 3.1.1; a validation warning already turns the card `.failed`.
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.success)
            case .queued:
                Text(statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            case .failed:
                Text(statusLine ?? statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.error)
                    .lineLimit(1)
            case .active:
                VStack(spacing: 4) {
                    if let pct = progress {
                        AccentProgressCapsule(progress: Double(pct) / 100, accent: accent, height: 4,
                                              track: palette.surfaceRaised, animation: nil)
                            .frame(width: 0.78 * 130)
                    }
                    // Mono only for the live log-monitor line.
                    Text(statusLine ?? statusText)
                        .font(statusLine != nil
                              ? .system(size: 11.5, design: .monospaced)
                              : .system(size: 12))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, Preset2CardM.padTop)
        .padding(.horizontal, 12)
        .padding(.bottom, Preset2CardM.padBottom)
        .frame(maxWidth: 176)
        .frame(height: Preset2CardM.height)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isActive ? accent : hairline,
                            lineWidth: isActive ? 1.5 : 0.5
                        )
                )
        )
        .glowShadow(accent, opacity: 0.22, radius: 22, y: 8, active: isActive)
        .opacity(state == .queued ? 0.62 : 1.0)
        .layoutPriority(isActive ? 1.15 : 1)
    }
}

/// The active card's badge: a spinning ring cut out of the card surface.
struct Preset2SpinnerRing: View {
    @Environment(\.palette) private var palette

    let accent: Color
    let ring: Color

    var body: some View {
        ZStack {
            Circle().fill(ring).frame(width: 30, height: 30)
            // 27 inset by half the stroke is a 24pt path.
            IndeterminateRing(size: 27, color: accent, track: palette.surfaceRaised)
        }
    }
}

// MARK: - Peek column

/// Right-edge chevron column signalling more cards. No background fade: it reads as a white
/// strip on tinted backdrops.
struct Preset2PeekColumn: View {
    let accent: Color
    var backwards: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: backwards ? "chevron.left.circle.fill" : "chevron.right.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white, accent)
        }
        .buttonStyle(.plain)
        .frame(width: 44)
    }
}

// MARK: - Progress block

/// Overall progress bar with its count label underneath.
struct Preset2ProgressBlock: View {
    let completed: Int
    let total: Int
    let accent: Color
    let localizedFormat: String?

    private var label: String {
        if let format = localizedFormat {
            return PresetCommonViews.fillProgressTokens(format, completed: completed, total: total)
        }
        return "\(completed) of \(total) installed"
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.10))
                    RoundedRectangle(cornerRadius: 4).fill(accent)
                        .frame(width: total > 0 ? geo.size.width * CGFloat(completed) / CGFloat(total) : 0)
                        .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: completed)
                }
            }
            .frame(height: 8)

            // Centred like every other element in the column; a left label read as off-balance.
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }
}
