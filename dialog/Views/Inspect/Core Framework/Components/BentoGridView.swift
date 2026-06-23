//
//  BentoGridView.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/01/2026
//
//  Bento-Grid Component for Preset5
//  CSS Grid-like layouts with variable cell sizes (1x1, 2x1, 1x2, 2x2)
//

import SwiftUI

// MARK: - Bento Layout Engine

/// Calculates precise cell positions for bento grid layout
struct BentoLayoutEngine {
    /// Calculated placement for a single cell
    struct CellPlacement: Identifiable {
        let id: String
        let cellId: String
        let row: Int
        let column: Int
        let columnSpan: Int
        let rowSpan: Int
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat
    }

    /// Calculate placements for all cells
    /// - Parameters:
    ///   - cells: Array of cell configurations
    ///   - columns: Total number of columns in grid
    ///   - cellWidth: Width of a single column (including gaps calculated in)
    ///   - rowHeight: Height of a single row
    ///   - gap: Gap between cells
    /// - Returns: Array of calculated cell placements
    static func calculate(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        columns: Int,
        cellWidth: CGFloat,
        rowHeight: CGFloat,
        gap: CGFloat
    ) -> [CellPlacement] {
        var placements: [CellPlacement] = []

        for cell in cells {
            let colSpan = min(cell.columnSpan ?? 1, columns - cell.column)
            let rowSpan = cell.rowSpan ?? 1

            // Calculate position
            let x = CGFloat(cell.column) * (cellWidth + gap)
            let y = CGFloat(cell.row) * (rowHeight + gap)

            // Calculate size (spanning cells include the gaps between spanned columns/rows)
            let width = CGFloat(colSpan) * cellWidth + CGFloat(colSpan - 1) * gap
            let height = CGFloat(rowSpan) * rowHeight + CGFloat(rowSpan - 1) * gap

            let placement = CellPlacement(
                id: cell.id,
                cellId: cell.id,
                row: cell.row,
                column: cell.column,
                columnSpan: colSpan,
                rowSpan: rowSpan,
                x: x,
                y: y,
                width: width,
                height: height
            )

            placements.append(placement)
        }

        return placements
    }

    /// Calculate the total height needed for the grid
    static func calculateGridHeight(cells: [InspectConfig.GuidanceContent.BentoCellConfig], rowHeight: CGFloat, gap: CGFloat) -> CGFloat {
        guard !cells.isEmpty else { return 0 }

        var maxRow = 0
        for cell in cells {
            let rowSpan = cell.rowSpan ?? 1
            let cellEndRow = cell.row + rowSpan
            maxRow = max(maxRow, cellEndRow)
        }

        return CGFloat(maxRow) * rowHeight + CGFloat(maxRow - 1) * gap
    }
}

// MARK: - Bento Cell View

/// Individual cell in the bento grid with 4 content modes: image, text, icon, mixed
struct BentoCell: View {
    let config: InspectConfig.GuidanceContent.BentoCellConfig
    let width: CGFloat
    let height: CGFloat
    let scaleFactor: CGFloat
    let accentColor: Color
    let iconBasePath: String?
    let tintColor: Color?
    let cellIndex: Int
    let onTap: () -> Void

    @Environment(\.complianceAggregator) private var complianceAggregator

    /// The compliance item bound to this cell, if any.
    /// Zero new schema: a cell auto-binds when its existing `id` matches a plist key
    /// in the injected `ComplianceAggregatorService`. Users get live subtitle + icon color,
    /// and the existing `detailOverlay` click-to-sheet flow fires automatically (via a
    /// synthesized overlay in the parent grid) so they don't have to author one by hand.
    private var boundItem: PlistAggregator.ComplianceItem? {
        guard let aggregator = complianceAggregator else { return nil }
        return aggregator.allItems.first(where: { $0.id == config.id })
    }

    /// Subtitle override when a plist binding exists; otherwise the config-supplied subtitle.
    /// Status labels come from the aggregator (configurable via `healthyLabel`/`attentionLabel`
    /// on `PlistSourceConfig`).
    private var resolvedSubtitle: String? {
        if let item = boundItem, let aggregator = complianceAggregator {
            return item.finding ? aggregator.healthyLabel : aggregator.attentionLabel
        }
        return config.subtitle
    }

    /// Icon color override when a plist binding exists; otherwise falls through to iconColor computed property.
    private var resolvedIconColor: Color? {
        if let item = boundItem {
            return item.finding ? Color.semanticSuccess : Color.semanticWarning
        }
        return nil
    }

    private var cornerRadius: CGFloat {
        CGFloat(config.cornerRadius ?? 12) * scaleFactor
    }

    /// Resolve gradient style from config string
    private var resolvedGradientStyle: ProceduralGradientStyle {
        switch config.gradientStyle?.lowercased() {
        case "vivid": return .vivid
        case "subtle": return .subtle
        default: return .ethereal
        }
    }

    /// Build gradient palette from config colors, tintColor, or backgroundColor
    private var gradientPalette: [Color] {
        // Explicit palette from config
        if let hexColors = config.gradientPalette, !hexColors.isEmpty {
            return hexColors.map { Color(hex: $0) }
        }
        // Fall back to tintColor
        if let tint = tintColor {
            return [tint]
        }
        // Fall back to backgroundColor hex
        if let bgHex = config.backgroundColor {
            return [Color(hex: bgHex)]
        }
        // Empty — ProceduralGradientView will generate from seed
        return []
    }

    private var backgroundColor: Color {
        if let colorHex = config.backgroundColor {
            return Color(hex: colorHex)
        }
        if let tint = tintColor {
            // Blend base color with white at varying ratios for distinct shades
            // Lower = lighter (more white), higher = darker (more base color)
            let strengths: [Double] = [0.18, 0.30, 0.12, 0.24, 0.38, 0.15, 0.22, 0.34, 0.14, 0.28]
            let strength = strengths[cellIndex % strengths.count]
            let nsColor = NSColor(tint).usingColorSpace(.sRGB) ?? NSColor(tint)
            let r = nsColor.redComponent
            let g = nsColor.greenComponent
            let b = nsColor.blueComponent
            return Color(
                red: 1.0 - (1.0 - r) * strength,
                green: 1.0 - (1.0 - g) * strength,
                blue: 1.0 - (1.0 - b) * strength
            )
        }
        return Color(.windowBackgroundColor).opacity(0.6)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background — procedural gradient or flat color
                if let bgStyle = config.backgroundStyle,
                   bgStyle == "gradient" || bgStyle == "mesh" {
                    ProceduralGradientView(
                        seed: config.id,
                        palette: gradientPalette,
                        style: resolvedGradientStyle
                    )
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                }

                // Content based on type
                contentView
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Resolve the effective content type.
    /// If `contentType` is explicit, use it. Otherwise derive from which fields are set:
    /// `imagePath` → "mixed", `sfSymbol` → "icon", else → "text".
    /// This lets users omit `contentType` and still get the expected rendering.
    private var resolvedContentType: String {
        if !config.contentType.isEmpty { return config.contentType }
        if config.imagePath != nil { return "mixed" }
        if config.sfSymbol != nil { return "icon" }
        return "text"
    }

    @ViewBuilder
    private var contentView: some View {
        switch resolvedContentType {
        case "image":
            imageContent
        case "text":
            textContent
        case "icon":
            iconContent
        case "mixed":
            mixedContent
        default:
            EmptyView()
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var imageContent: some View {
        if let imagePath = config.imagePath {
            AsyncBentoImageView(
                imagePath: imagePath,
                basePath: iconBasePath,
                width: width,
                height: height,
                imageFit: config.imageFit ?? "fill"
            )
        }
    }

    @ViewBuilder
    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4 * scaleFactor) {
            if let label = config.label {
                Text(label)
                    .font(.system(size: 10 * scaleFactor, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(textColor.opacity(0.6))
            }

            if let title = config.title {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(textColor)
                    .lineLimit(3)
            }

            if let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(textColor.opacity(0.7))
                    .lineLimit(2)
            }
        }
        .padding(12 * scaleFactor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var iconContent: some View {
        VStack(spacing: 8 * scaleFactor) {
            if let sfSymbol = config.sfSymbol {
                Image(systemName: sfSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: CGFloat(config.iconSize ?? 48) * scaleFactor, weight: iconWeight))
                    .frame(width: CGFloat(config.iconSize ?? 48) * scaleFactor, height: CGFloat(config.iconSize ?? 48) * scaleFactor)
                    .foregroundStyle(iconColor)
            }

            VStack(spacing: 2 * scaleFactor) {
                if let label = config.label {
                    Text(label)
                        .font(.system(size: 10 * scaleFactor, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(textColor.opacity(0.6))
                }

                if let title = config.title {
                    Text(title)
                        .font(.system(size: 14 * scaleFactor, weight: .medium))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Icon color - live plist binding wins; then iconColor from config; then accentColor.
    private var iconColor: Color {
        if let bound = resolvedIconColor {
            return bound
        }
        if let colorHex = config.iconColor {
            return Color(hex: colorHex)
        }
        return accentColor
    }

    /// Icon weight from config string
    private var iconWeight: Font.Weight {
        switch config.iconWeight?.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }

    /// Whether this cell uses a procedural gradient background
    private var hasGradientBackground: Bool {
        if let bgStyle = config.backgroundStyle {
            return bgStyle == "gradient" || bgStyle == "mesh"
        }
        return false
    }

    @ViewBuilder
    private var mixedContent: some View {
        // Image-backed mixed: retain original image + gradient + bottom-leading text layout.
        if config.imagePath != nil {
            imageBackedMixedContent
        } else if config.sfSymbol != nil {
            // Icon-backed mixed: SF Symbol hero + label/title/subtitle stack.
            // This is the common case for compliance bento cards — previously the icon
            // was silently dropped because mixedContent only checked imagePath.
            iconBackedMixedContent
        } else {
            // No image, no icon — fall back to plain text layout.
            textContent
        }
    }

    @ViewBuilder
    private var imageBackedMixedContent: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image (skip when procedural gradient is the background)
            if !hasGradientBackground, let imagePath = config.imagePath {
                AsyncBentoImageView(
                    imagePath: imagePath,
                    basePath: iconBasePath,
                    width: width,
                    height: height,
                    imageFit: config.imageFit ?? "fill"
                )
            }

            // Gradient overlay for text readability (lighter when gradient bg is present)
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(hasGradientBackground ? 0.35 : 0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.5)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Text overlay
            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                if let label = config.label {
                    Text(label)
                        .font(.system(size: 10 * scaleFactor, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }

                if let title = config.title {
                    Text(title)
                        .font(.system(size: mixedTitleSize, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }

                if let subtitle = resolvedSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }
            }
            .padding(12 * scaleFactor)
        }
    }

    @ViewBuilder
    private var iconBackedMixedContent: some View {
        VStack(alignment: .leading, spacing: 10 * scaleFactor) {
            if let sfSymbol = config.sfSymbol {
                Image(systemName: sfSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .font(.system(size: CGFloat(config.iconSize ?? 40) * scaleFactor, weight: iconWeight))
                    .frame(
                        width: CGFloat(config.iconSize ?? 40) * scaleFactor,
                        height: CGFloat(config.iconSize ?? 40) * scaleFactor
                    )
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2 * scaleFactor) {
                if let label = config.label {
                    Text(label)
                        .font(.system(size: 10 * scaleFactor, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(textColor.opacity(0.6))
                }

                if let title = config.title {
                    Text(title)
                        .font(.system(size: mixedTitleSize, weight: .semibold))
                        .foregroundStyle(textColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }

                if let subtitle = resolvedSubtitle {
                    Text(subtitle)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(textColor.opacity(0.7))
                        .lineLimit(2)
                }
            }
        }
        .padding(12 * scaleFactor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Helpers

    private var titleFont: Font {
        let size: CGFloat
        switch config.textSize {
        case "large":
            size = 32
        case "small":
            size = 14
        default: // "medium"
            size = 20
        }
        return .system(size: size * scaleFactor, weight: .bold)
    }

    private var mixedTitleSize: CGFloat {
        let size: CGFloat
        switch config.textSize {
        case "large":
            size = 24
        case "small":
            size = 14
        default:
            size = 18
        }
        return size * scaleFactor
    }

    private var textColor: Color {
        if let colorHex = config.textColor {
            return Color(hex: colorHex)
        }
        return .primary
    }
}

// MARK: - Async Bento Image View

/// Asynchronous image loader for bento cells
private struct AsyncBentoImageView: View {
    let imagePath: String
    let basePath: String?
    let width: CGFloat
    let height: CGFloat
    let imageFit: String

    @State private var loadedImage: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = loadedImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: imageFit == "fill" ? .fill : .fit)
                    .frame(width: width, height: height)
                    .clipped()
            } else if isLoading {
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                // Fallback placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolvedPath = resolveImagePath(imagePath, basePath: basePath)

            if let path = resolvedPath, let image = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async {
                    self.loadedImage = image
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func resolveImagePath(_ path: String, basePath: String?) -> String? {
        // Absolute path
        if path.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: path) ? path : nil
        }

        // Try with base path
        if let base = basePath {
            let fullPath = (base as NSString).appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        // Try ImageResolver if available
        if let resolved = ImageResolver.shared.resolveImagePath(path, basePath: basePath, fallbackIcon: nil),
           resolved.hasPrefix("/"),
           FileManager.default.fileExists(atPath: resolved) {
            return resolved
        }

        return nil
    }
}

// MARK: - Sheet Context (payload passed through presentation)

/// Bundles the cell + resolved detail payload so SwiftUI's `.sheet(item:)` receives
/// the data directly in its content closure rather than reading `@State` at presentation time.
struct BentoSheetContext: Identifiable {
    enum Payload {
        case overlay(InspectConfig.DetailOverlayConfig)
        case plistBinding(PlistAggregator.ComplianceItem)
    }
    let id: String
    let cell: InspectConfig.GuidanceContent.BentoCellConfig
    let payload: Payload
}

// MARK: - Bento Plist Detail Sheet

/// Compact sheet shown when a plist-bound bento cell (no explicit `detailOverlay`) is
/// tapped. Reuses the same sheet presentation as `BentoDetailView`, but is auto-populated
/// from the live `ComplianceItem`. No extra schema needed — the cell's existing `id` is
/// the plist key.
struct BentoPlistDetailSheet: View {
    let cellConfig: InspectConfig.GuidanceContent.BentoCellConfig
    let item: PlistAggregator.ComplianceItem
    /// User-facing label to display when the check passes. Comes from the aggregator so
    /// `healthyLabel` / `attentionLabel` on `PlistSourceConfig` brand the sheet too.
    let healthyLabel: String
    /// User-facing label for a failing check.
    let attentionLabel: String
    /// Scale factor for the whole sheet — mirrors the rest of the bento system so
    /// users with a larger inspect window get a proportionally larger popover.
    let scaleFactor: CGFloat
    /// Inspect state, used to log remediation-button interactions through the same
    /// channel as other button actions (FR #667).
    let inspectState: InspectState
    let onClose: () -> Void

    private var tint: Color {
        switch item.severity {
        case .healthy: return .semanticSuccess
        case .warning: return .semanticWarning
        case .failure: return item.finding ? .semanticSuccess : .semanticWarning
        }
    }
    private var statusLabel: String { item.finding ? healthyLabel : attentionLabel }
    private var actionURL: URL? {
        guard let raw = item.actionURL, !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header ribbon
            HStack(alignment: .center, spacing: 14 * scaleFactor) {
                Image(systemName: cellConfig.sfSymbol ?? (item.finding ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"))
                    .font(.system(size: 28 * scaleFactor, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44 * scaleFactor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(.system(size: 17 * scaleFactor, weight: .semibold))
                    Text(item.category)
                        .font(.system(size: 12 * scaleFactor))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12 * scaleFactor)
                Text(statusLabel)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10 * scaleFactor)
                    .padding(.vertical, 5 * scaleFactor)
                    .background(Capsule().fill(tint.opacity(0.15)))
            }
            .padding(.horizontal, 20 * scaleFactor)
            .padding(.vertical, 16 * scaleFactor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.06))

            Divider()

            // Details list
            VStack(alignment: .leading, spacing: 10 * scaleFactor) {
                detailRow("Status", statusLabel, tint: tint)
                detailRow("Category", item.category)
                if item.isCritical {
                    detailRow("Criticality", "Critical", tint: .semanticWarning)
                }
                detailRow("Plist key", item.id, monospaced: true)
            }
            .padding(20 * scaleFactor)
            .frame(maxWidth: .infinity, alignment: .leading)

            // FR #667: Rich remediation content
            if item.explanation != nil || (item.severity != .healthy && (item.remediation != nil || actionURL != nil)) {
                Divider()
                VStack(alignment: .leading, spacing: 14 * scaleFactor) {
                    if let explanation = item.explanation {
                        markdownBlock(label: "Explanation", text: explanation)
                    }
                    if item.severity != .healthy, let remediation = item.remediation {
                        markdownBlock(label: "Remediation", text: remediation)
                    }
                    if item.severity != .healthy, let url = actionURL {
                        Button(item.actionButtonText ?? "Open") {
                            NSWorkspace.shared.open(url)
                            inspectState.writeToInteractionLog(
                                "button:\(item.id):remediation:url:\(url.absoluteString)"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .tint(tint)
                    }
                }
                .padding(.horizontal, 20 * scaleFactor)
                .padding(.vertical, 16 * scaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Footer
            HStack {
                Spacer(minLength: 0)
                Button("Close", action: onClose)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20 * scaleFactor)
            .padding(.bottom, 16 * scaleFactor)
            .padding(.top, 4 * scaleFactor)
        }
        .frame(width: InspectSizes.Bento.plistDetailWidth * scaleFactor)
        .fixedSize(horizontal: true, vertical: true)
    }

    @ViewBuilder
    private func markdownBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6 * scaleFactor) {
            Text(label)
                .font(.system(size: 11 * scaleFactor, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(parseMarkdown(text))
                .font(.system(size: 13 * scaleFactor))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func parseMarkdown(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        )) ?? AttributedString(markdown)
    }

    @ViewBuilder
    private func detailRow(_ label: String, _ value: String, tint: Color? = nil, monospaced: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12 * scaleFactor) {
            Text(label)
                .font(.system(size: 11 * scaleFactor, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(width: 88 * scaleFactor, alignment: .leading)
            if monospaced {
                // Only plist keys (the one thing users actually copy) are selectable.
                Text(value)
                    .font(.system(size: 12 * scaleFactor, design: .monospaced))
                    .foregroundStyle(tint ?? .primary)
                    .textSelection(.enabled)
            } else {
                Text(value)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(tint ?? .primary)
            }
            Spacer()
        }
    }
}

// MARK: - Bento Detail View

/// Large overlay view for bento item details with full GuidanceContent support
struct BentoDetailView: View {
    let cellConfig: InspectConfig.GuidanceContent.BentoCellConfig
    let overlay: InspectConfig.DetailOverlayConfig
    let accentColor: Color
    let iconBasePath: String?
    @ObservedObject var inspectState: InspectState
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        if let hex = overlay.backgroundColor {
            return Color(hex: hex)
        }
        return Color(NSColor.windowBackgroundColor)
    }

    private var headerIcon: String? {
        overlay.icon ?? cellConfig.sfSymbol
    }

    private var headerTitle: String {
        overlay.title ?? cellConfig.title ?? "Details"
    }

    private var headerSubtitle: String? {
        overlay.subtitle ?? cellConfig.subtitle
    }

    private var overlayWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        if overlay.wide == true {
            return (900, 1000, 1100)  // Wide mode
        }
        return (720, 800, 880)  // Default (20% narrower)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with gradient background
            headerView
                .background(
                    LinearGradient(
                        colors: [accentColor.opacity(0.15), backgroundColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Divider()

            // Scrollable content area
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Rich content using GuidanceContentView
                    if let content = overlay.content, !content.isEmpty {
                        GuidanceContentView(
                            contentBlocks: content,
                            scaleFactor: 1.0,
                            iconBasePath: iconBasePath,
                            inspectState: inspectState,
                            itemId: "bento-detail-\(cellConfig.id)",
                            onOverlayTap: nil
                        )
                    } else {
                        // Fallback if no content
                        Text("No additional details available.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer with close button
            footerView
        }
        .frame(minWidth: overlayWidth.min, idealWidth: overlayWidth.ideal, maxWidth: overlayWidth.max)
        .frame(minHeight: 550, idealHeight: 650, maxHeight: 750)
        .background(backgroundColor)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon
            if let iconName = headerIcon {
                Group {
                    if iconName.hasPrefix("sf=") || !iconName.contains("/") && !iconName.contains(".") {
                        // SF Symbol
                        let symbolName = iconName.hasPrefix("sf=") ? String(iconName.dropFirst(3)) : iconName
                        Image(systemName: symbolName)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(accentColor)
                    } else {
                        // Image path
                        if let image = loadHeaderImage(iconName) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(accentColor)
                        }
                    }
                }
                .frame(width: 48, height: 48)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                if let subtitle = headerSubtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            Spacer()

            Button(action: onClose) {
                Text(overlay.closeButtonText ?? "Close")
                    .frame(minWidth: 80)
            }
            .keyboardShortcut(.escape, modifiers: [])
            .controlSize(.large)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func loadHeaderImage(_ path: String) -> NSImage? {
        // Try absolute path first
        if path.hasPrefix("/") && FileManager.default.fileExists(atPath: path) {
            return NSImage(contentsOfFile: path)
        }

        // Try with base path
        if let basePath = iconBasePath {
            let fullPath = (basePath as NSString).appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: fullPath) {
                return NSImage(contentsOfFile: fullPath)
            }
        }

        return nil
    }
}

// MARK: - Bento Inline Detail View

/// Streamlined detail view for inline presentation within the bento grid area.
/// Fills the entire grid bounds with a spring animation, replacing the cell grid.
struct BentoInlineDetailView: View {
    let cellConfig: InspectConfig.GuidanceContent.BentoCellConfig
    let overlay: InspectConfig.DetailOverlayConfig
    let gridSize: CGSize
    let accentColor: Color
    let iconBasePath: String?
    @ObservedObject var inspectState: InspectState
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    private var headerIcon: String? {
        overlay.icon ?? cellConfig.sfSymbol
    }

    private var headerTitle: String {
        overlay.title ?? cellConfig.title ?? "Details"
    }

    private var headerSubtitle: String? {
        overlay.subtitle ?? cellConfig.subtitle
    }

    /// Resolved media path: explicit detailMedia, or fall back to cell's imagePath
    private var resolvedMediaPath: String? {
        overlay.detailMedia ?? cellConfig.imagePath
    }

    /// Whether to show the split media layout (wide enough + media available)
    private var showMediaPanel: Bool {
        resolvedMediaPath != nil && gridSize.width >= 700
    }

    /// Width ratio for the media panel
    private let mediaRatio: CGFloat = 0.4

    /// Whether this cell has a procedural gradient background
    private var hasGradientBackground: Bool {
        if let bgStyle = cellConfig.backgroundStyle {
            return bgStyle == "gradient" || bgStyle == "mesh"
        }
        return false
    }

    /// Resolve gradient style from config
    private var resolvedGradientStyle: ProceduralGradientStyle {
        switch cellConfig.gradientStyle?.lowercased() {
        case "vivid": return .vivid
        case "subtle": return .subtle
        default: return .ethereal
        }
    }

    /// Build gradient palette from cell config
    private var gradientPalette: [Color] {
        if let hexColors = cellConfig.gradientPalette, !hexColors.isEmpty {
            return hexColors.map { Color(hex: $0) }
        }
        if let bgHex = cellConfig.backgroundColor {
            return [Color(hex: bgHex)]
        }
        return [accentColor]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Gradient header banner (when cell has gradient background)
            if hasGradientBackground {
                ZStack {
                    // Gradient background — fills entire banner
                    ProceduralGradientView(
                        seed: cellConfig.id,
                        palette: gradientPalette,
                        style: resolvedGradientStyle
                    )

                    // Soft vignette for depth
                    LinearGradient(
                        colors: [.black.opacity(0.15), .clear, .black.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Content layered on the gradient
                    VStack(alignment: .leading, spacing: 0) {
                        // Nav bar
                        HStack(spacing: 12) {
                            Button(action: onClose) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Back")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 22))
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Close (Esc)")
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 20)

                        Spacer()

                        // Icon + title at the bottom of the banner
                        HStack(alignment: .center, spacing: 16) {
                            if let iconName = headerIcon {
                                let symbolName = iconName.hasPrefix("sf=") ? String(iconName.dropFirst(3)) : iconName
                                if !iconName.contains("/") && !iconName.contains(".") {
                                    ZStack {
                                        Circle()
                                            .fill(.white.opacity(0.2))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: symbolName)
                                            .font(.system(size: 24, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(headerTitle)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                                if let subtitle = headerSubtitle {
                                    Text(subtitle)
                                        .font(.system(size: 14))
                                        .foregroundStyle(.white.opacity(0.85))
                                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                    }
                }
                .frame(height: gridSize.height * 0.35)
            } else {
                // Plain navigation bar (no gradient)
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(accentColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            // Content area: text-only or split with media
            if showMediaPanel {
                HStack(spacing: 0) {
                    textContentPanel(skipHeader: hasGradientBackground)
                        .frame(width: gridSize.width * (1 - mediaRatio))

                    detailMediaPanel
                        .frame(width: gridSize.width * mediaRatio)
                        .clipped()
                }
            } else {
                textContentPanel(skipHeader: hasGradientBackground)
            }
        }
        .frame(width: gridSize.width, height: gridSize.height)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(hasGradientBackground ? (gradientPalette.first ?? Color(NSColor.windowBackgroundColor)) : Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onAppear {
            // Delay focus acquisition to avoid race with animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        .onDisappear {
            isFocused = false
        }
        .onKeyPress(.escape) {
            isFocused = false
            onClose()
            return .handled
        }
    }

    // MARK: - Text Content Panel

    private func textContentPanel(skipHeader: Bool = false) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !skipHeader {
                    // Apple-style hero header: icon in tinted circle + title + subtitle
                    HStack(alignment: .top, spacing: 18) {
                        // Icon in tinted circle
                        if let iconName = headerIcon {
                            let symbolName = iconName.hasPrefix("sf=") ? String(iconName.dropFirst(3)) : iconName
                            if !iconName.contains("/") && !iconName.contains(".") {
                                ZStack {
                                    Circle()
                                        .fill(accentColor.opacity(0.12))
                                        .frame(width: 56, height: 56)
                                    Image(systemName: symbolName)
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundStyle(accentColor)
                                }
                                .padding(.top, 2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            // Title
                            Text(headerTitle)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            // Subtitle
                            if let subtitle = headerSubtitle {
                                Text(subtitle)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 28)

                    // Thin divider
                    Rectangle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 32)
                }

                // Rich content from detailOverlay
                if let content = overlay.content, !content.isEmpty {
                    GuidanceContentView(
                        contentBlocks: content,
                        scaleFactor: 1.0,
                        iconBasePath: iconBasePath,
                        inspectState: inspectState,
                        itemId: "bento-inline-\(cellConfig.id)",
                        onOverlayTap: nil
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, skipHeader ? 16 : 24)
                    .padding(.bottom, 28)
                }
            }
            .padding(.top, skipHeader ? 0 : 8)
        }
    }

    // MARK: - Detail Media Panel

    @ViewBuilder
    private var detailMediaPanel: some View {
        if let mediaPath = resolvedMediaPath {
            let url: URL = mediaPath.hasPrefix("http")
                ? (URL(string: mediaPath) ?? URL(fileURLWithPath: mediaPath))
                : URL(fileURLWithPath: mediaPath)
            let mediaType = IntroMediaType.detect(from: url)
            let useFit = (overlay.detailMediaFit ?? cellConfig.imageFit ?? "fill").lowercased() == "fit"
            let cornerRadius: CGFloat = 12
            let inset: CGFloat = 16

            GeometryReader { geo in
                let mediaW = geo.size.width - inset * 2
                let mediaH = geo.size.height - inset * 2

                VStack {
                    Spacer(minLength: 0)

                    Group {
                        switch mediaType {
                        case .staticImage:
                            AsyncImageView(
                                iconPath: mediaPath,
                                basePath: iconBasePath,
                                maxWidth: mediaW,
                                maxHeight: mediaH,
                                imageFit: useFit ? .fit : .fill,
                                fallback: { Color.secondary.opacity(0.1) }
                            )

                        case .animatedImage:
                            IntroAnimatedImageView(url: url, maxWidth: mediaW, maxHeight: mediaH)

                        case .video:
                            IntroNativeVideoPlayer(url: url, autoplay: true)

                        default:
                            AsyncImageView(
                                iconPath: mediaPath,
                                basePath: iconBasePath,
                                maxWidth: mediaW,
                                maxHeight: mediaH,
                                imageFit: useFit ? .fit : .fill,
                                fallback: { Color.secondary.opacity(0.1) }
                            )
                        }
                    }
                    .frame(width: mediaW, height: mediaH)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

                    Spacer(minLength: 0)
                }
                .padding(inset)
            }
        }
    }
}

// MARK: - Bento Grid View

/// Main bento grid container using GeometryReader for precise sizing
struct BentoGridView: View {
    let cells: [InspectConfig.GuidanceContent.BentoCellConfig]
    let columns: Int
    let rowHeight: CGFloat
    let gap: CGFloat
    let scaleFactor: CGFloat
    let accentColor: Color
    let iconBasePath: String?
    let tintColor: Color?
    let inlineExpansion: Bool
    let containerHeight: CGFloat?
    @ObservedObject var inspectState: InspectState

    @State private var selectedCell: InspectConfig.GuidanceContent.BentoCellConfig?
    @State private var showDetail: Bool = false
    @State private var expandedCellId: String?
    @State private var visibleCells: Set<String> = []
    @State private var sheetContext: BentoSheetContext?

    @Environment(\.complianceAggregator) private var complianceAggregator

    /// Stagger delay between each cell appearing (seconds)
    private let staggerDelay: Double = 0.12

    /// The live compliance item bound to a cell, if any. A cell auto-binds when its
    /// existing `id` matches a plist key in the injected aggregator — zero new schema.
    private func boundItem(for cell: InspectConfig.GuidanceContent.BentoCellConfig) -> PlistAggregator.ComplianceItem? {
        guard let aggregator = complianceAggregator else { return nil }
        return aggregator.allItems.first(where: { $0.id == cell.id })
    }

    /// Backward-compatible initializer (inlineExpansion defaults to false)
    init(
        cells: [InspectConfig.GuidanceContent.BentoCellConfig],
        columns: Int,
        rowHeight: CGFloat,
        gap: CGFloat,
        scaleFactor: CGFloat,
        accentColor: Color,
        iconBasePath: String?,
        tintColor: Color?,
        inspectState: InspectState,
        inlineExpansion: Bool = false,
        containerHeight: CGFloat? = nil
    ) {
        self.cells = cells
        self.columns = columns
        self.rowHeight = rowHeight
        self.gap = gap
        self.scaleFactor = scaleFactor
        self.accentColor = accentColor
        self.iconBasePath = iconBasePath
        self.tintColor = tintColor
        self.inlineExpansion = inlineExpansion
        self.containerHeight = containerHeight
        self._inspectState = ObservedObject(wrappedValue: inspectState)
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let cellWidth = (availableWidth - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let placements = BentoLayoutEngine.calculate(
                cells: cells,
                columns: columns,
                cellWidth: cellWidth,
                rowHeight: rowHeight * scaleFactor,
                gap: gap * scaleFactor
            )
            let gridHeight = BentoLayoutEngine.calculateGridHeight(
                cells: cells,
                rowHeight: rowHeight * scaleFactor,
                gap: gap * scaleFactor
            )
            // let gridSize = CGSize(width: availableWidth, height: gridHeight)
            // For inline detail, use the full container height (not just the grid)
            // let detailHeight = containerHeight ?? max(gridHeight, 480)
            // let detailSize = CGSize(width: availableWidth, height: detailHeight)

            ZStack(alignment: .topLeading) {
                // Grid cells
                ForEach(Array(placements.enumerated()), id: \.element.id) { index, placement in
                    if let cellConfig = cells.first(where: { $0.id == placement.cellId }) {
                        let isVisible = visibleCells.contains(cellConfig.id)
                        let isExpanded = expandedCellId == cellConfig.id
                        let isDimmed = expandedCellId != nil && !isExpanded

                        BentoCell(
                            config: cellConfig,
                            width: placement.width,
                            height: placement.height,
                            scaleFactor: scaleFactor,
                            accentColor: accentColor,
                            iconBasePath: iconBasePath,
                            tintColor: tintColor,
                            cellIndex: index,
                            onTap: {
                                // Inline expansion is only meaningful for user-authored overlays
                                // (BentoInlineDetailView renders `detailOverlay.content`).
                                if inlineExpansion, cellConfig.detailOverlay != nil {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                                        expandedCellId = cellConfig.id
                                    }
                                    return
                                }

                                // Build the sheet payload at click time so the sheet's
                                // content closure receives the data directly (see BentoSheetContext).
                                if let overlay = cellConfig.detailOverlay {
                                    sheetContext = BentoSheetContext(id: cellConfig.id, cell: cellConfig, payload: .overlay(overlay))
                                } else if let bound = boundItem(for: cellConfig) {
                                    sheetContext = BentoSheetContext(id: cellConfig.id, cell: cellConfig, payload: .plistBinding(bound))
                                }
                            }
                        )
                        .offset(x: placement.x, y: placement.y)
                        .opacity(isVisible ? (isDimmed ? 0.0 : 1) : 0)
                        .scaleEffect(isVisible ? 1 : 0.85)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: isVisible)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isDimmed)
                        .allowsHitTesting(!isDimmed && expandedCellId == nil)
                    }
                }

            }
            .frame(width: availableWidth, height: gridHeight, alignment: .topLeading)
        }
        .frame(height: BentoLayoutEngine.calculateGridHeight(cells: cells, rowHeight: rowHeight * scaleFactor, gap: gap * scaleFactor))
        // Inline detail — presented as sheet for consistent window-centered positioning
        .sheet(isPresented: Binding(
            get: { expandedCellId != nil },
            set: { if !$0 { expandedCellId = nil } }
        )) {
            if let expandedId = expandedCellId,
               let cellConfig = cells.first(where: { $0.id == expandedId }),
               let detailConfig = cellConfig.detailOverlay {
                BentoInlineDetailView(
                    cellConfig: cellConfig,
                    overlay: detailConfig,
                    gridSize: CGSize(width: 720, height: 540),
                    accentColor: accentColor,
                    iconBasePath: iconBasePath,
                    inspectState: inspectState,
                    onClose: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            expandedCellId = nil
                        }
                    }
                )
                .frame(minWidth: 720, idealWidth: 720, minHeight: 540)
            }
        }
        .onAppear {
            staggerCellAppearance()
        }
        // Single sheet driven by an Identifiable payload — SwiftUI passes the value
        // into the content closure, so we never read `@State` at sheet-content time.
        .sheet(item: $sheetContext) { context in
            switch context.payload {
            case .overlay(let overlay):
                BentoDetailView(
                    cellConfig: context.cell,
                    overlay: overlay,
                    accentColor: accentColor,
                    iconBasePath: iconBasePath,
                    inspectState: inspectState,
                    onClose: { sheetContext = nil }
                )
            case .plistBinding(let item):
                BentoPlistDetailSheet(
                    cellConfig: context.cell,
                    item: item,
                    healthyLabel: complianceAggregator?.healthyLabel ?? "Healthy",
                    attentionLabel: complianceAggregator?.attentionLabel ?? "Needs Attention",
                    scaleFactor: scaleFactor,
                    inspectState: inspectState,
                    onClose: { sheetContext = nil }
                )
            }
        }
    }

    /// Animate cells appearing one by one in reading order (left-to-right, top-to-bottom)
    private func staggerCellAppearance() {
        // Sort cells by row then column for natural reading-order entrance
        let sorted = cells.sorted { a, b in
            if a.row != b.row { return a.row < b.row }
            return a.column < b.column
        }

        for (index, cell) in sorted.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + staggerDelay * Double(index)) {
                withAnimation {
                    _ = visibleCells.insert(cell.id)
                }
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct BentoGridView_Previews: PreviewProvider {
    static var previews: some View {
        BentoGridView(
            cells: [
                InspectConfig.GuidanceContent.BentoCellConfig(
                    id: "hero",
                    column: 0,
                    row: 0,
                    columnSpan: 2,
                    rowSpan: 2,
                    contentType: "text",
                    imagePath: nil,
                    imageFit: nil,
                    title: "Welcome",
                    subtitle: "Getting Started",
                    textSize: "large",
                    textColor: nil,
                    sfSymbol: nil,
                    iconSize: nil,
                    iconColor: nil,
                    iconWeight: nil,
                    backgroundColor: "#E8F4FD",
                    cornerRadius: nil,
                    backgroundStyle: "gradient",
                    gradientStyle: "ethereal",
                    gradientPalette: nil,
                    label: nil,
                    detailOverlay: nil
                ),
                InspectConfig.GuidanceContent.BentoCellConfig(
                    id: "apps",
                    column: 2,
                    row: 0,
                    columnSpan: nil,
                    rowSpan: nil,
                    contentType: "icon",
                    imagePath: nil,
                    imageFit: nil,
                    title: "Apps",
                    subtitle: nil,
                    textSize: nil,
                    textColor: nil,
                    sfSymbol: "square.grid.2x2",
                    iconSize: 48,
                    iconColor: nil,
                    iconWeight: nil,
                    backgroundColor: "#F5F5F5",
                    cornerRadius: nil,
                    backgroundStyle: nil,
                    gradientStyle: nil,
                    gradientPalette: nil,
                    label: nil,
                    detailOverlay: nil
                ),
                InspectConfig.GuidanceContent.BentoCellConfig(
                    id: "year",
                    column: 3,
                    row: 0,
                    columnSpan: nil,
                    rowSpan: nil,
                    contentType: "text",
                    imagePath: nil,
                    imageFit: nil,
                    title: "2025",
                    subtitle: nil,
                    textSize: "large",
                    textColor: nil,
                    sfSymbol: nil,
                    iconSize: nil,
                    iconColor: nil,
                    iconWeight: nil,
                    backgroundColor: "#E8FDE8",
                    cornerRadius: nil,
                    backgroundStyle: "gradient",
                    gradientStyle: "vivid",
                    gradientPalette: ["#22C55E", "#10B981"],
                    label: nil,
                    detailOverlay: nil
                )
            ],
            columns: 4,
            rowHeight: 140,
            gap: 12,
            scaleFactor: 1.0,
            accentColor: .accentColor,
            iconBasePath: nil,
            tintColor: nil,
            inspectState: InspectState()
        )
        .frame(width: 600, height: 400)
        .padding()
    }
}
#endif
