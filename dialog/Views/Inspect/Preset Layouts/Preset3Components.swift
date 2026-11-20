//
//  Preset3Components.swift
//  dialog
//
//  Preset 3's content components: greeting header, tile grid, tile state and footer.
//

import SwiftUI

// MARK: - Greeting resolution

enum OnboardingGreeting {
    /// Managed-pref name → local user's first name → account short name (shared resolver).
    @MainActor
    static func resolveUserName(config: InspectConfig?) -> String {
        resolveGreetingName(config: config)
    }

    /// Replaces {userName}; strings without the placeholder pass through.
    static func substitute(_ text: String, userName: String) -> String {
        substituteGreeting(text, userName: userName)
    }
}

// MARK: - Per-tile resolved state

/// One tile's resolved presentation. Status text and colour come from the shared row; the bar,
/// percentage and dimmed icon are the tile's own.
struct OnboardingTileState {
    let statusText: String
    let statusColor: Color
    let barFraction: Double
    let barColor: Color
    let iconDimmed: Bool

    @MainActor
    init(item: InspectConfig.ItemConfig, state: InspectState, accent: Color, palette: ResolvedPalette) {
        let row = ItemSetModel.row(for: item, state: state)
        let color = ItemSetModel.itemStatusColor(row.status, hasWarning: row.hasWarning, palette: palette)
        let pct = state.itemProgress[item.id]
        switch row.status {
        case .failed, .completed:
            statusText = row.statusText
            statusColor = color
            barFraction = 1.0
            barColor = color
            iconDimmed = false
        case .active:
            // The percentage joins the status word, never a script's or log monitor's own line.
            let ownLine = state.itemStatusText[item.id] != nil || state.logMonitorStatuses[item.id] != nil
            statusText = (!ownLine && pct != nil) ? "\(row.statusText) \(pct!)%" : row.statusText
            statusColor = color
            barFraction = Double(pct ?? 0) / 100.0
            barColor = accent
            iconDimmed = false
        case .pending, .skipped:
            statusText = row.statusText
            statusColor = color
            barFraction = 0
            barColor = accent
            iconDimmed = true
        }
    }
}

// MARK: - Admin details chip

struct AdminDetailsChip: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(isOn ? StatusGlyph.success.color : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text("Admin details")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Show version, plist, and profile details")
    }
}

// MARK: - Header

/// Preset 3's horizontal metrics. The progress zone and the items start at `textColumn`, the
/// header text's leading edge, so header, progress and items share one edge.
enum Preset3M {
    static let margin: CGFloat = 28
    static let icon: CGFloat = 72
    static let iconGap: CGFloat = 24
    static var textColumn: CGFloat { margin + icon + iconGap }
}

struct OnboardingHeader: View, InspectLayoutProtocol {
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let title: String
    let message: String?
    /// The rotating `sideMessage` line, under the message as in 3.1.1; nil when none is set.
    var sideMessage: String? = nil
    /// Every rotating line, so the seat holds the longest.
    var sideMessages: [String] = []
    @Binding var showDetails: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Preset3M.iconGap * scaleFactor) {
            IconView(
                image: iconCache.getMainIconPath(for: inspectState),
                overlay: iconCache.getOverlayIconPath(for: inspectState),
                defaultImage: "sparkles",
                defaultColour: "accent"
            )
            .frame(width: Preset3M.icon * scaleFactor, height: Preset3M.icon * scaleFactor)
            .onAppear { iconCache.cacheMainIcon(for: inspectState) }

            VStack(alignment: .leading, spacing: 6 * scaleFactor) {
                HStack(alignment: .top, spacing: 16) {
                    Text(title)
                        .font(.system(size: 20 * scaleFactor, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if inspectState.config?.hideSystemDetails != true {
                        AdminDetailsChip(isOn: $showDetails)
                    }
                }

                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 13 * scaleFactor))    // Setup Assistant body: 13pt
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let sideMessage, !sideMessage.isEmpty {
                    RotatingMessageLine(messages: sideMessages.isEmpty ? [sideMessage] : sideMessages,
                                        current: sideMessage,
                                        index: sideMessages.firstIndex(of: sideMessage) ?? 0,
                                        font: .system(size: 13 * scaleFactor))
                }
            }
        }
        // Trailing sits on the footer rail so header, progress, tiles and button share one edge.
        .padding(.leading, Preset3M.margin * scaleFactor)
        .padding(.trailing, FooterBandM.rail * scaleFactor)
        .padding(.top, 28 * scaleFactor)
        .padding(.bottom, 4 * scaleFactor)
    }
}

// MARK: - Shared by the grid and the list

/// Groups in first-occurrence order; uncategorized items form the leading unlabeled group.
private func preset3Groups(_ items: [InspectConfig.ItemConfig]) -> [(label: String?, items: [InspectConfig.ItemConfig])] {
    var order: [String] = []
    var buckets: [String: [InspectConfig.ItemConfig]] = [:]
    var uncategorized: [InspectConfig.ItemConfig] = []
    for item in items {
        if let category = item.category, !category.isEmpty {
            if buckets[category] == nil { order.append(category) }
            buckets[category, default: []].append(item)
        } else {
            uncategorized.append(item)
        }
    }
    var result: [(String?, [InspectConfig.ItemConfig])] = []
    if !uncategorized.isEmpty { result.append((nil, uncategorized)) }
    for category in order { result.append((category, buckets[category] ?? [])) }
    return result
}

/// Admin meta line: bundle info, else profile domain, else plist key, else first path.
@MainActor
private func preset3MetaLine(for item: InspectConfig.ItemConfig, state: InspectState) -> String? {
    if let bundleInfo = state.getBundleInfoForItem(item) { return bundleInfo }
    if let domain = item.managedPrefDomain { return "profile · \(domain)" }
    if let plistKey = item.plistKey { return "plist · \(plistKey)" }
    return item.paths.first.map { ($0 as NSString).lastPathComponent }
}

/// A group's uppercase category caption.
private struct Preset3GroupLabel: View {
    let text: String
    let scale: CGFloat
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11 * scale, weight: .semibold))
            .kerning(0.7)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Tile grid (`chrome: "grid"`)

struct AppTileGrid: View, InspectLayoutProtocol {
    @Environment(\.palette) private var palette
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let accent: Color
    let showDetails: Bool

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8 * scaleFactor), count: 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * scaleFactor) {
            ForEach(Array(preset3Groups(inspectState.items).enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 10 * scaleFactor) {
                    if let label = group.label { Preset3GroupLabel(text: label, scale: scaleFactor) }
                    LazyVGrid(columns: columns, spacing: 8 * scaleFactor) {
                        ForEach(group.items, id: \.id) { item in
                            AppTile(
                                item: item,
                                tile: OnboardingTileState(item: item, state: inspectState, accent: accent, palette: palette),
                                iconPath: iconCache.getItemIconPath(for: item, state: inspectState),
                                meta: showDetails ? preset3MetaLine(for: item, state: inspectState) : nil,
                                scale: scaleFactor
                            )
                        }
                    }
                }
            }
        }
        // Tiles sit in the header text column.
        .padding(.leading, Preset3M.textColumn * scaleFactor)
        .padding(.trailing, FooterBandM.rail * scaleFactor)
    }
}

// MARK: - Row list (default; the 3.1.1 look)

/// One full-width row per item: icon, name, status on the trailing edge. Rows sit in the header
/// text column like the tiles, so header, progress and items share one leading edge.
struct AppRowList: View, InspectLayoutProtocol {
    @Environment(\.palette) private var palette
    @ObservedObject var inspectState: InspectState
    @ObservedObject var iconCache: PresetIconCache
    let accent: Color
    let showDetails: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18 * scaleFactor) {
            ForEach(Array(preset3Groups(inspectState.items).enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 8 * scaleFactor) {
                    if let label = group.label { Preset3GroupLabel(text: label, scale: scaleFactor) }
                    ForEach(group.items, id: \.id) { item in
                        AppRow(
                            item: item,
                            tile: OnboardingTileState(item: item, state: inspectState, accent: accent, palette: palette),
                            iconPath: iconCache.getItemIconPath(for: item, state: inspectState),
                            meta: showDetails ? preset3MetaLine(for: item, state: inspectState) : nil,
                            scale: scaleFactor
                        )
                    }
                }
            }
        }
        .padding(.leading, Preset3M.textColumn * scaleFactor)
        .padding(.trailing, FooterBandM.rail * scaleFactor)
    }
}

private struct AppRow: View {
    let item: InspectConfig.ItemConfig
    let tile: OnboardingTileState
    let iconPath: String
    let meta: String?
    let scale: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12 * scale) {
            IconView(image: iconPath)
                .frame(width: 32 * scale, height: 32 * scale)
                .opacity(tile.iconDimmed ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: tile.iconDimmed)

            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(item.displayName)
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                ItemClaimAndIdentifier(claim: item.claim,
                                       identifier: item.displayIdentifier,
                                       scaleFactor: scale,
                                       identifierChars: 40)
                if let meta {
                    Text(meta)
                        .font(.system(size: 9 * scale, design: .monospaced))
                        .foregroundStyle(palette.textFaint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8 * scale)

            Text(tile.statusText)
                .font(.system(size: 12 * scale))
                .foregroundStyle(tile.statusColor)
                .lineLimit(1)
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 6 * scale)
        .frame(minHeight: 44 * scale)    // matches the 44pt row in InspectSizes' list sizing
        .background(
            RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}

private struct AppTile: View {
    let item: InspectConfig.ItemConfig
    let tile: OnboardingTileState
    let iconPath: String
    let meta: String?
    let scale: CGFloat

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8 * scale) {
            // No `defaultImage:`: IconView fills an empty path itself before any default applies.
            IconView(image: iconPath)
                .frame(width: 40 * scale, height: 40 * scale)
                .opacity(tile.iconDimmed ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: tile.iconDimmed)

            Text(item.displayName)
                .font(.system(size: 12 * scale, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)

            ItemClaimAndIdentifier(claim: item.claim,
                                   identifier: item.displayIdentifier,
                                   scaleFactor: scale,
                                   identifierChars: 18)

            FractionBar(
                fraction: tile.barFraction,
                height: 3 * scale,
                cornerRadius: 2,
                fill: tile.barColor,
                animateChanges: true
            )

            Text(tile.statusText)
                .font(.system(size: 11 * scale))
                .foregroundStyle(tile.statusColor)
                .lineLimit(1)
                .frame(minHeight: 14 * scale)

            if let meta {
                Text(meta)
                    .font(.system(size: 9 * scale, design: .monospaced))
                    .foregroundStyle(palette.textFaint)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6 * scale)
        .padding(.top, 12 * scale)
        .padding(.bottom, 10 * scale)
        .background(
            RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                        .stroke(palette.text.opacity(0.15), lineWidth: 1)
                )
        )
    }
}
