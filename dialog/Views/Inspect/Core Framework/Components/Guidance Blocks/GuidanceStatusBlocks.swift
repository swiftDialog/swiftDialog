//
//  GuidanceStatusBlocks.swift
//  dialog
//
//  Status guidance blocks: the progress bar and the install list.
//

import SwiftUI

// MARK: - Progress bar (type: "progress-bar")

/// Determinate shows the percentage beside the label; `content` is a second line under the bar
/// when a label exists, else it stands in for the label.
struct GuidanceProgressBarBlock: View {
    let block: InspectConfig.GuidanceContent
    let scaleFactor: CGFloat
    /// The fill colour (the host's accent); nil keeps the palette accent.
    var accentColor: Color?

    @Environment(\.palette) private var palette

    var body: some View {
        let progressStyle = block.style ?? "indeterminate"
        let progressValue = min(max(block.progress ?? 0.0, 0), 1.0)
        // A non-zero progress value implies determinate.
        let isDeterminate = progressStyle == "determinate" || (block.progress != nil && progressValue > 0)

        VStack(alignment: .leading, spacing: 8 * scaleFactor) {
            if let label = block.label ?? block.content, !label.isEmpty {
                HStack {
                    Text(label)
                        .font(.system(size: 13 * scaleFactor, weight: .medium))
                        .foregroundStyle(palette.text)

                    Spacer()

                    if isDeterminate {
                        Text("\(Int(progressValue * 100))%")
                            .font(.system(size: 12 * scaleFactor, weight: .medium))
                            .foregroundStyle(palette.textMuted)
                            .monospacedDigit()
                    }
                }
            }

            if isDeterminate {
                FractionBar(fraction: progressValue, fill: accentColor ?? palette.accent, animateChanges: true)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * scaleFactor))
            } else {
                IndeterminateProgressView(tint: accentColor)
                    .frame(height: 8 * scaleFactor)
            }

            // With no label, `content` is already the label above.
            if block.label != nil, let content = block.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 12 * scaleFactor))
                    .foregroundStyle(palette.textMuted)
            }
        }
    }
}

// MARK: - Install list (type: "install-list")

/// Installation progress list with app icons and status. Pure display: live status comes from
/// the completed and downloading sets when an item's `itemId` links to `items[]`.
struct GuidanceInstallListBlock: View {
    let installItems: [InspectConfig.GuidanceContent.InstallItem]
    let completedItems: Set<String>
    let downloadingItems: Set<String>
    let iconBasePath: String?
    let scaleFactor: CGFloat
    /// `cards` and `manifest` reuse the carousel step's card and manifest row.
    var layout: InstallListLayout = .rows
    var accentColor: Color?
    @Environment(\.palette) private var palette

    /// The one place an install item becomes a status word, shared by every layout.
    private func resolvedStatus(_ item: InspectConfig.GuidanceContent.InstallItem) -> String {
        if let linkedId = item.itemId {
            if completedItems.contains(linkedId) {
                return "success"
            } else if downloadingItems.contains(linkedId) {
                // Spinner until a real progress value exists; a perpetual 0% ring reads as stuck.
                return (item.progress ?? 0) > 0 ? "progress" : "wait"
            }
        }
        return item.status ?? "pending"
    }

    var body: some View {
        switch layout {
        case .rows:
            VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                ForEach(installItems.indices, id: \.self) { index in
                    let item = installItems[index]
                    InstallRow28(
                        item: item,
                        status: resolvedStatus(item),
                        scaleFactor: scaleFactor,
                        iconBasePath: iconBasePath
                    )
                }
            }
        case .cards:
            // Wraps where the step pages: the cards are a fixed width and a block has no claim on
            // the window's width, so it grows downward instead of clipping.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: CarouselM.wideCardWidth * scaleFactor),
                                   spacing: 12 * scaleFactor)],
                alignment: .leading,
                spacing: 12 * scaleFactor
            ) {
                ForEach(installItems.indices, id: \.self) { index in
                    CarouselCardView(item: bridged(installItems[index]),
                                     accentColor: accentColor ?? palette.accent,
                                     compact: false,
                                     iconLed: !IconRef.isSymbolReference(
                                        installItems[index].icon ?? ""))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .manifest:
            VStack(spacing: 0) {
                ForEach(installItems.indices, id: \.self) { index in
                    CarouselManifestRow(item: bridged(installItems[index]),
                                        accentColor: accentColor ?? palette.accent,
                                        compact: false)
                    if index < installItems.count - 1 {
                        Rectangle()
                            .fill(palette.text.opacity(0.08))
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }

    /// Bridges a block item to the step engine's `InstallationItemData`. Status goes through the
    /// shared lenient parse; "progress" is the block's own word and maps to `.active` explicitly.
    private func bridged(_ item: InspectConfig.GuidanceContent.InstallItem)
        -> InstallationItemData {
        let word = resolvedStatus(item)
        let status: StepStatus = word == "progress" ? .active
            : (StepStatus(lenient: word) ?? .pending)
        return InstallationItemData(
            id: item.itemId ?? item.title,
            displayName: item.title,
            icon: item.icon,
            iconPath: nil,
            status: status,
            progress: item.progress,
            statusMessage: item.stateLabel ?? item.subtitle,
            // Only the facts the card and manifest draw get block keys.
            claim: item.claim,
            size: item.size ?? item.badge,
            identifier: item.identifier
        )
    }
}

/// The three installation designs, as the authored `installLayout` word.
enum InstallListLayout {
    /// The vertical list, `InstallRow28`. The default.
    case rows
    /// Fixed-width cards in an adaptive grid that wraps.
    case cards
    /// Hairline-separated manifest rows.
    case manifest

    /// Unrecognised or absent falls back to `rows`.
    init(_ authored: String?) {
        switch authored?.lowercased() {
        case "cards":    self = .cards
        case "manifest": self = .manifest
        default:         self = .rows
        }
    }
}

// MARK: - Install row

/// One item of an install list. The right column carries the state as a word, a glyph only for
/// failure, and a bar only on the item in flight.
struct InstallRow28: View {
    let item: InspectConfig.GuidanceContent.InstallItem
    let status: String
    let scaleFactor: CGFloat
    let iconBasePath: String?
    @Environment(\.palette) private var palette

    private var isFailed: Bool { status == "fail" || status == "failed" }
    private var isInFlight: Bool { status == "progress" || status == "wait" || status == "installing" }

    /// An authored `stateLabel` wins; only the config knows what this stage is called.
    private var stateWord: String? {
        if let label = item.stateLabel, !label.isEmpty { return label }
        switch status {
        case "success", "complete": return "Done"
        case "fail", "failed":      return "Failed"
        case "pending":             return "Queued"
        case "skipped":             return "Skipped"
        default:                    return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7 * scaleFactor) {
            HStack(alignment: .center, spacing: 11 * scaleFactor) {
                iconSlot
                    .frame(width: 28 * scaleFactor, height: 28 * scaleFactor)

                VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                    Text(item.title)
                        .font(.system(size: 13 * scaleFactor, weight: .medium))
                        .foregroundStyle(palette.text)
                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(isFailed ? palette.error : palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 12 * scaleFactor)

                // Only the item in flight carries a bar, so it never competes with the phase bar.
                if isInFlight, let progress = item.progress, progress > 0 {
                    FractionBar(fraction: min(1, progress > 1 ? progress / 100 : progress),
                                height: 3 * scaleFactor,
                                fill: palette.accent)
                        // A cap, not a width: a fixed width would steal the title's column.
                        .frame(maxWidth: 180 * scaleFactor)
                } else if let stateWord {
                    HStack(spacing: 5 * scaleFactor) {
                        // Done carries no mark; a tick beside "Done" is a second hue for one fact.
                        if isFailed {
                            Image(systemName: "xmark")
                                .font(.system(size: 11 * scaleFactor, weight: .semibold))
                                .foregroundStyle(palette.error)
                        }
                        Text(stateWord)
                            .font(.system(size: 12 * scaleFactor))
                            .foregroundStyle(isFailed ? palette.error : palette.textMuted)
                    }
                }
            }

            // The failure explains itself and the retry is scoped to this app, not the run.
            if isFailed, item.failureNote != nil || item.retryLabel != nil {
                HStack(alignment: .top, spacing: 10 * scaleFactor) {
                    if let retryLabel = item.retryLabel {
                        Button(retryLabel) {
                            if let urlString = item.retryURL, let url = URL(string: urlString) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if let note = item.failureNote {
                        Text(note)
                            .font(.system(size: 11 * scaleFactor))
                            .foregroundStyle(palette.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 24 * scaleFactor)
            }
        }
        .padding(.vertical, 8 * scaleFactor)
        .padding(.horizontal, isFailed ? 10 * scaleFactor : 0)
        .background(isFailed ? palette.error.opacity(0.06) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8 * scaleFactor, style: .continuous))
    }

    /// A file path (including an `.app` bundle), an SF Symbol name, or a neutral placeholder so
    /// the row keeps its rhythm. In flight, a spinner sits on the corner rather than replacing
    /// the icon.
    @ViewBuilder
    private var iconSlot: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let iconPath = item.icon, !iconPath.isEmpty {
                    if iconPath.hasPrefix("/") || iconPath.hasPrefix("~") || iconPath.contains(".app") {
                        if let nsImage = loadIcon(path: iconPath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 6 * scaleFactor))
                        } else {
                            placeholderIcon
                        }
                    } else {
                        Image(systemName: iconPath)
                            .font(.system(size: 18 * scaleFactor))
                            .foregroundStyle(palette.textMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    placeholderIcon
                }
            }
            .opacity(status == "skipped" ? 0.45 : 1)

            if isInFlight {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.5)
                    .frame(width: 12 * scaleFactor, height: 12 * scaleFactor)
                    .background(Circle().fill(.background))
                    .offset(x: 3 * scaleFactor, y: 3 * scaleFactor)
            }
        }
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 6 * scaleFactor, style: .continuous)
            .fill(palette.textMuted.opacity(0.12))
            .overlay(
                Image(systemName: "app.dashed")
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(palette.textFaint)
            )
    }

    private func loadIcon(path: String) -> NSImage? {
        let resolved = (path as NSString).expandingTildeInPath
        if resolved.hasSuffix(".app") {
            return NSWorkspace.shared.icon(forFile: resolved)
        }
        return InspectImageCache.shared.image(atPath: resolved)
    }
}
