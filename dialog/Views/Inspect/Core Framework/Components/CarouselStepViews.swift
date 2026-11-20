//
// CarouselStepViews.swift
//
// Components for the "carousel" step type: item cards, the manifest rows, badge, progress bar
// and the shared `CarouselM` metrics.

import SwiftUI

// MARK: - Carousel Card

/// One item card: icon with status badge, name, claim, progress and a metadata row.
struct CarouselCardView: View {
    let item: InstallationItemData
    let accentColor: Color
    var compact: Bool = false

    /// Icon-led (64pt icon on top) when the item has a real app icon; glyph-led otherwise.
    var iconLed: Bool = false

    @Environment(\.palette) private var palette

    private var isActive: Bool { item.status.isActive }
    private var isDone: Bool { item.status == .completed }

    private var cornerRadius: CGFloat { compact ? 12 : 14 }
    private var cardWidth: CGFloat { compact ? 168 : CarouselM.wideCardWidth }
    private var cardHeight: CGFloat {
        let base = iconLed ? CarouselM.wideCardHeightIconLed : CarouselM.wideCardHeight
        return compact ? base * 0.82 : base
    }
    private var badgeSize: CGFloat { compact ? 18 : 22 }

    var body: some View {
        VStack(alignment: iconLed ? .center : .leading, spacing: compact ? 6 : 8) {
            if iconLed { iconLedHead } else { glyphHead }

            // Symmetric spacers centre the claim between the head and the meta row.
            Spacer(minLength: 0)

            if let claim = item.claim, !claim.isEmpty {
                Text(claim)
                    .font(.system(size: compact ? 13 : 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(iconLed ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: iconLed ? .center : .leading)
            }

            Spacer(minLength: 0)

            // Only the running card carries a progress line.
            if isActive, let progress = item.progress, progress > 0 {
                ProgressView(value: min(1, progress > 1 ? progress / 100 : progress))
                    .progressViewStyle(.linear)
                    .tint(accentColor)
            }

            metaRow
        }
        .padding(compact ? 10 : 12)
        // Fixed height so cards in a row end on the same baseline whatever the claim runs to.
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isActive ? accentColor.opacity(0.55) : palette.text.opacity(0.15),
                                lineWidth: isActive ? 1.5 : 1)
                )
        )
        // Done cards dim; the running card gets the accent outline; queued cards stay quiet.
        .opacity(isDone ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: item.status)
    }

    /// Glyph top-left, the name beside it, the status badge trailing.
    private var glyphHead: some View {
        HStack(spacing: 8) {
            IconView(image: item.icon ?? item.iconPath ?? "SF=app.dashed")
                .frame(width: CarouselM.glyphSize * (compact ? 0.8 : 1),
                       height: CarouselM.glyphSize * (compact ? 0.8 : 1))

            Text(item.displayName)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            CarouselStatusBadge(status: item.status, accentColor: accentColor, size: badgeSize)
        }
    }

    /// App icon on top, centred, with the name beneath it.
    private var iconLedHead: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                IconView(image: item.icon ?? item.iconPath ?? "SF=app.dashed")
                    .frame(width: CarouselM.appIconSize * (compact ? 0.75 : 1),
                           height: CarouselM.appIconSize * (compact ? 0.75 : 1))
                    .clipShape(.rect(cornerRadius: 12))

                CarouselStatusBadge(status: item.status, accentColor: accentColor, size: badgeSize)
                    .offset(x: 6, y: -6)
            }

            Text(item.displayName)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    /// Size and bundle id on a hairline at the card foot; absent when the item states neither.
    @ViewBuilder
    private var metaRow: some View {
        let size = item.size?.isEmpty == false ? item.size : nil
        let identifier = item.identifier?.isEmpty == false ? item.identifier : nil
        if size != nil || identifier != nil {
            VStack(spacing: 6) {
                Rectangle()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 0.5)

                HStack(spacing: 6) {
                    if let size {
                        Text(size)
                    }
                    if size != nil && identifier != nil {
                        Text("·")
                    }
                    if let identifier {
                        Text(CarouselM.truncatedIdentifier(identifier, maxChars: compact ? 18 : 24))
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.textFaint)
            }
        }
    }
}

// MARK: - The manifest form

/// One manifest row: the card's facts in columns, with no paging. Done rows dim, the running row
/// takes the accent.
struct CarouselManifestRow: View {
    let item: InstallationItemData
    let accentColor: Color
    var compact: Bool = false

    @Environment(\.palette) private var palette

    private var isActive: Bool { item.status.isActive }
    private var isDone: Bool { item.status == .completed }

    var body: some View {
        HStack(alignment: .center, spacing: 14 * (compact ? 0.85 : 1)) {
            IconView(image: item.icon ?? item.iconPath ?? "SF=app.dashed")
                .frame(width: CarouselM.glyphSize * (compact ? 0.8 : 1),
                       height: CarouselM.glyphSize * (compact ? 0.8 : 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayName)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let identifier = item.identifier, !identifier.isEmpty {
                    Text(CarouselM.truncatedIdentifier(identifier, maxChars: 30))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .frame(width: compact ? 150 : 190, alignment: .leading)

            Text(item.claim ?? "")
                .font(.system(size: compact ? 12 : 13))
                .foregroundStyle(isDone ? .secondary : .primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: CarouselM.manifestClaimWidth * (compact ? 0.8 : 1), alignment: .leading)

            Spacer(minLength: 8)

            // Fixed-width column so sizes line up down the page.
            Text(item.size ?? "")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(palette.textFaint)
                .frame(width: compact ? 54 : 64, alignment: .trailing)

            CarouselStatusBadge(status: item.status, accentColor: accentColor,
                                size: compact ? 18 : 20)
        }
        .padding(.vertical, compact ? 7 : 9)
        .opacity(isDone ? 0.55 : 1.0)
        .overlay(alignment: .leading) {
            if isActive {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: item.status)
    }
}

// MARK: - Status Badge

/// Circle badge: checkmark (completed), spinner (active), X (failed); nothing for pending or skipped.
struct CarouselStatusBadge: View {
    let status: StepStatus
    let accentColor: Color
    var size: CGFloat = 26

    @Environment(\.palette) private var palette

    private var iconSize: CGFloat { size * 0.46 }

    var body: some View {
        switch status {
        case .failed, .completed:
            StatusIndicatorCircle(status: status, accent: accentColor, size: size, glyphSize: iconSize)
        case .active:
            ProgressView()
                .scaleEffect(size < 24 ? 0.55 : 0.7)
                .tint(accentColor)
                .frame(width: size, height: size)
        case .pending, .skipped:
            EmptyView()
        }
    }
}

// MARK: - Placeholder Card

/// Empty card slot for when the carousel does not fill all visible positions.
struct CarouselPlaceholderCardView: View {
    @Environment(\.palette) private var palette
    var compact: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: compact ? 10 : 14)
                .fill(palette.text.opacity(0.05))
                .frame(width: compact ? 48 : 72, height: compact ? 48 : 72)

            RoundedRectangle(cornerRadius: 4)
                .fill(palette.text.opacity(0.05))
                .frame(width: compact ? 50 : 70, height: compact ? 8 : 10)
        }
        .frame(width: compact ? 90 : 110, height: compact ? 90 : 120)
        .padding(compact ? 4 : 6)
    }
}

// MARK: - Progress Bar

/// The carousel's dimensions in base (unscaled) points, so the card count, the card frames and the
/// progress bar under them are sized from the same numbers. Sizes only, no colour.
enum CarouselM {
    static let cardWidth: CGFloat = 130
    /// Padding is real layout width; the outer width is what tiles the row.
    static let cardPadding: CGFloat = 12
    static let cardSpacing: CGFloat = 12
    static let arrowWidth: CGFloat = 28
    static let arrowGap: CGFloat = 16

    static var cardOuterWidth: CGFloat { cardWidth + cardPadding }

    /// What a row of `cards` spans; the progress bar under it matches this.
    static func rowWidth(cards: Int, scale: CGFloat = 1) -> CGFloat {
        guard cards > 0 else { return 0 }
        return (CGFloat(cards) * cardOuterWidth + CGFloat(cards - 1) * cardSpacing) * scale
    }

    // MARK: - Wide cards

    /// Wide enough for a bundle identifier beside the glyph; three fit per page.
    static let wideCardWidth: CGFloat = 224

    /// Glyph row, a two-line claim and the meta row. Fixed so every card ends on the same baseline.
    static let wideCardHeight: CGFloat = 150

    /// Taller because the icon sits above the text rather than beside it.
    static let wideCardHeightIconLed: CGFloat = 214

    /// Glyph-led head glyph.
    static let glyphSize: CGFloat = 30

    /// Icon-led head icon.
    static let appIconSize: CGFloat = 64

    /// How many whole wide cards fit a row `contentWidth` wide, clamped to 1...5. `contentWidth`
    /// is already inside the shell's edge inset; only 8pt of rounding slack comes off.
    static func wideCardsThatFit(contentWidth: CGFloat, scale: CGFloat = 1) -> Int {
        let card = wideCardWidth * scale
        let gap = cardSpacing * scale
        let available = contentWidth - 8
        guard available > card else { return 1 }
        return max(1, min(5, Int((available + gap) / (card + gap))))
    }

    /// The slim capsule track under the row.
    static let trackHeight: CGFloat = 5

    static func wideRowWidth(cards: Int, scale: CGFloat = 1) -> CGFloat {
        guard cards > 0 else { return 0 }
        return (CGFloat(cards) * wideCardWidth + CGFloat(cards - 1) * cardSpacing) * scale
    }

    /// Which form a carousel step renders. Authored, never inferred from the item count.
    enum Form: Equatable {
        case cards      // glyph-led / icon-led cards
        case manifest   // one row per item, in columns
    }

    /// Absence and an unrecognised spelling are `cards`.
    static func form(_ authored: String?) -> Form {
        authored?.lowercased() == "manifest" ? .manifest : .cards
    }

    /// The manifest's claim column.
    static let manifestClaimWidth: CGFloat = 300

    /// Clip a bundle identifier from the left; the reverse-DNS tail is what tells ids apart.
    static func truncatedIdentifier(_ identifier: String, maxChars: Int) -> String {
        guard maxChars > 1, identifier.count > maxChars else { return identifier }
        return "…" + identifier.suffix(maxChars - 1)
    }
}

/// Bottom progress bar; `progressFormat` may carry `{completed}` and `{total}`.
struct CarouselProgressBarView: View {
    @Environment(\.palette) private var palette
    let completed: Int
    let total: Int
    let accentColor: Color
    let progressFormat: String?
    var compact: Bool = false
    /// The card row's width, so the bar's ends land on the cards' outer edges; absent, a fixed cap.
    var rowWidth: CGFloat?

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            // A real ProgressView so assistive technology sees a progress indicator with a frame.
            ProgressView(value: Double(completed), total: Double(total))
                .progressViewStyle(SlimTrackProgressStyle(track: palette.text.opacity(0.08), fill: accentColor))
                .frame(maxWidth: rowWidth ?? (compact ? 480 : 600))

            Text(formatProgressText())
                .font(compact ? .caption2 : .caption)
                .foregroundStyle(.secondary)
        }
        // The bottom pad keeps the caption clear of the body's fade.
        .padding(.top, compact ? 8 : 0)
        .padding(.bottom, compact ? 8 : 16)
    }

    private func formatProgressText() -> String {
        if let template = progressFormat {
            return template
                .replacingOccurrences(of: "{completed}", with: "\(completed)")
                .replacingOccurrences(of: "{total}", with: "\(total)")
        }
        return "\(completed) of \(total) completed"
    }
}

/// The slim capsule track as a `ProgressViewStyle`, so the styled view is still a ProgressView
/// to accessibility.
struct SlimTrackProgressStyle: ProgressViewStyle {
    let track: Color
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(fill)
                    .frame(width: geo.size.width * min(1, max(0, configuration.fractionCompleted ?? 0)))
            }
        }
        .frame(height: CarouselM.trackHeight)
    }
}
