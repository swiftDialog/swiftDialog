//
//  BentoCellView.swift
//  dialog
//
//  One bento grid cell (image, text, icon or mixed content) and its image loader.
//

import SwiftUI

// MARK: - The balanced cell type

/// Type metrics shared by the image and icon tiles so they cannot drift apart.
enum BentoCellM {
    static let eyebrowSize: CGFloat = 11
    static let eyebrowTracking: CGFloat = 0.9      // .08em at 11pt
    static let eyebrowGap: CGFloat = 6
    static let titleSize: CGFloat = 17
    static let titleGap: CGFloat = 4
    static let subtitleSize: CGFloat = 12.5
    static let padding: CGFloat = 16
    static let iconSize: CGFloat = 20
}

// MARK: - Bento Cell View

/// One cell in the bento grid. A cell with rows is a plain container; any other cell is one button.
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
    @Environment(\.colorScheme) private var bentoScheme
    @Environment(\.palette) private var palette

    /// Named in config, else assigned round-robin by position.
    private var surface: BentoSurface {
        BentoSurface(configValue: config.surface, fallback: .rotating(index: cellIndex))
    }

    /// A cell binds to the compliance item whose plist key equals the cell's `id`; the binding
    /// drives the subtitle and icon colour.
    private var boundItem: PlistAggregator.ComplianceItem? {
        guard let aggregator = complianceAggregator else { return nil }
        return aggregator.allItems.first(where: { $0.id == config.id })
    }

    /// The aggregator's healthy/attention label when bound; otherwise the config subtitle.
    private var resolvedSubtitle: String? {
        if let item = boundItem, let aggregator = complianceAggregator {
            return item.finding ? aggregator.healthyLabel : aggregator.attentionLabel
        }
        return config.subtitle
    }

    private var resolvedIconColor: Color? {
        if let item = boundItem {
            return item.finding ? palette.success : palette.warning
        }
        return nil
    }

    private var cornerRadius: CGFloat {
        CGFloat(config.cornerRadius ?? 12) * scaleFactor
    }

    private var resolvedGradientStyle: ProceduralGradientStyle {
        switch config.gradientStyle?.lowercased() {
        case "vivid": return .vivid
        case "subtle": return .subtle
        default: return .ethereal
        }
    }

    /// Config palette, then tint, then background colour, then the cell's surface.
    private var gradientPalette: [Color] {
        if let hexColors = config.gradientPalette, !hexColors.isEmpty {
            return hexColors.map { Color(hex: $0) }
        }
        if let tint = tintColor {
            return [tint]
        }
        if let bgHex = config.backgroundColor {
            return [Color(hex: bgHex)]
        }
        // Never empty: an empty palette would seed unrelated colours from each cell's own id.
        return [surface.fill(accent: tintColor ?? accentColor, palette: palette, scheme: bentoScheme),
                surface.fill(accent: accentColor, palette: palette, scheme: bentoScheme)]
    }

    private var backgroundColor: Color {
        if let colorHex = config.backgroundColor {
            return Color(hex: colorHex)
        }
        return surface.fill(accent: tintColor ?? accentColor, palette: palette, scheme: bentoScheme)
    }

    var body: some View {
        // Row buttons cannot nest inside a tile-sized Button, so a tile with rows is a plain container.
        if config.bentoRows.isEmpty {
            tappableTile
        } else {
            rowsTile
        }
    }

    /// Heading zone, then the rows.
    private var rowsTile: some View {
        let rows = config.bentoRows
        return VStack(alignment: .leading, spacing: 0) {
            contentView
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    BentoRowView(
                        row: row,
                        showsHairline: BentoRowModel.showsHairline(at: index, of: rows.count),
                        scaleFactor: scaleFactor
                    )
                }
            }
            .padding(.horizontal, 12 * scaleFactor)
            .padding(.bottom, 12 * scaleFactor)

            Spacer(minLength: 0)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .inset(by: 0.25)
                .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var tileBackground: some View {
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
    }

    private var tappableTile: some View {
        Button(action: onTap) {
            ZStack {
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

                contentView
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                // One inset hairline and no drop shadow; inset by half its width so the edge stays crisp.
                RoundedRectangle(cornerRadius: cornerRadius)
                    .inset(by: 0.25)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// An explicit `contentType` wins; otherwise `imagePath` means "mixed", `sfSymbol` "icon", else "text".
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

            // Titles never truncate: the subtitle is dropped whole when both do not fit.
            ViewThatFits(in: .vertical) {
                cellTitleBlock(includeSubtitle: true)
                cellTitleBlock(includeSubtitle: false)
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
                    .scaledToFit()
                    .font(.system(size: CGFloat(config.iconSize ?? 48) * scaleFactor, weight: iconWeight))
                    .frame(width: CGFloat(config.iconSize ?? 48) * scaleFactor, height: CGFloat(config.iconSize ?? 48) * scaleFactor)
                    .foregroundStyle(iconColor)
            }

            ViewThatFits(in: .vertical) {
                iconTitleBlock(includeSubtitle: true)
                iconTitleBlock(includeSubtitle: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Label, title and subtitle for the icon cell. Uses `resolvedSubtitle`, so a bound cell shows
    /// its live compliance verdict.
    private func iconTitleBlock(includeSubtitle: Bool) -> some View {
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

            if includeSubtitle, let subtitle = resolvedSubtitle {
                Text(subtitle)
                    .font(.system(size: 12 * scaleFactor, weight: .semibold))
                    .foregroundStyle(textColor.opacity(0.85))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Live binding, then config `iconColor`, then the accent.
    private var iconColor: Color {
        if let bound = resolvedIconColor {
            return bound
        }
        if let colorHex = config.iconColor {
            return Color(hex: colorHex)
        }
        return accentColor
    }

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

    private var hasGradientBackground: Bool {
        if let bgStyle = config.backgroundStyle {
            return bgStyle == "gradient" || bgStyle == "mesh"
        }
        return false
    }

    @ViewBuilder
    private var mixedContent: some View {
        if config.imagePath != nil {
            imageBackedMixedContent
        } else if config.sfSymbol != nil {
            iconBackedMixedContent
        } else {
            textContent
        }
    }

    @ViewBuilder
    private var imageBackedMixedContent: some View {
        ZStack(alignment: .bottomLeading) {
            if !hasGradientBackground, let imagePath = config.imagePath {
                AsyncBentoImageView(
                    imagePath: imagePath,
                    basePath: iconBasePath,
                    width: width,
                    height: height,
                    imageFit: config.imageFit ?? "fill"
                )
            }

            // Darkens the lower half for text legibility; lighter over a gradient background.
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(hasGradientBackground ? 0.35 : 0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.5)
            .frame(maxHeight: .infinity, alignment: .bottom)

            VStack(alignment: .leading, spacing: BentoCellM.eyebrowGap * scaleFactor) {
                if let label = config.label {
                    Text(label)
                        .font(.system(size: BentoCellM.eyebrowSize * scaleFactor, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(BentoCellM.eyebrowTracking)
                        .foregroundStyle(.white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                }

                ViewThatFits(in: .vertical) {
                    mixedTitleBlock(includeSubtitle: true, titleColor: .white,
                                    subtitleColor: .white.opacity(0.9), shadowed: true)
                    mixedTitleBlock(includeSubtitle: false, titleColor: .white,
                                    subtitleColor: .white.opacity(0.9), shadowed: true)
                }
            }
            .padding(BentoCellM.padding * scaleFactor)
        }
    }

    /// Icon directly above the eyebrow, stack bottom-aligned, so icon and image tiles share a baseline.
    @ViewBuilder
    private var iconBackedMixedContent: some View {
        let iconSide = CGFloat(config.iconSize ?? Double(BentoCellM.iconSize)) * scaleFactor
        VStack(alignment: .leading, spacing: 10 * scaleFactor) {
            if let sfSymbol = config.sfSymbol {
                Image(systemName: sfSymbol)
                    .resizable()
                    .scaledToFit()
                    .font(.system(size: iconSide, weight: iconWeight))
                    .frame(width: iconSide, height: iconSide)
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: BentoCellM.eyebrowGap * scaleFactor) {
                if let label = config.label {
                    Text(label)
                        .font(.system(size: BentoCellM.eyebrowSize * scaleFactor, weight: .bold))
                        .textCase(.uppercase)
                        .tracking(BentoCellM.eyebrowTracking)
                        .foregroundStyle(textColor.opacity(0.6))
                }

                ViewThatFits(in: .vertical) {
                    mixedTitleBlock(includeSubtitle: true, titleColor: textColor,
                                    subtitleColor: textColor.opacity(0.7), shadowed: false)
                    mixedTitleBlock(includeSubtitle: false, titleColor: textColor,
                                    subtitleColor: textColor.opacity(0.7), shadowed: false)
                }
            }
        }
        .padding(BentoCellM.padding * scaleFactor)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
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
            size = BentoCellM.titleSize
        }
        return size * scaleFactor
    }

    /// Title with or without subtitle: the two candidates `ViewThatFits` chooses between.
    @ViewBuilder
    private func cellTitleBlock(includeSubtitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4 * scaleFactor) {
            if let title = config.title {
                Text(title)
                    .font(titleFont)
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if includeSubtitle, let subtitle = config.subtitle {
                Text(subtitle)
                    .font(.system(size: 13 * scaleFactor))
                    .foregroundStyle(textColor.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The same rule for the mixed branches; the image-backed one draws white, shadowed text.
    @ViewBuilder
    private func mixedTitleBlock(includeSubtitle: Bool,
                                 titleColor: Color,
                                 subtitleColor: Color,
                                 shadowed: Bool) -> some View {
        VStack(alignment: .leading, spacing: BentoCellM.titleGap * scaleFactor) {
            if let title = config.title {
                Text(title)
                    .font(.system(size: mixedTitleSize, weight: .bold))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: shadowed ? .black.opacity(0.3) : .clear, radius: 2, y: 1)
            }
            if includeSubtitle, let subtitle = resolvedSubtitle {
                Text(subtitle)
                    .font(.system(size: BentoCellM.subtitleSize * scaleFactor))
                    .foregroundStyle(subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: shadowed ? .black.opacity(0.3) : .clear, radius: 2, y: 1)
            }
        }
    }

    private var textColor: Color {
        if let colorHex = config.textColor {
            return Color(hex: colorHex)
        }
        // The surface owns its text colour; `.primary` is only a guess on a tinted ground.
        return surface.textColor(scheme: bentoScheme)
    }
}

// MARK: - Async Bento Image View

/// Loads a cell's image off the main thread, with a placeholder while loading or on failure.
struct AsyncBentoImageView: View {
    @Environment(\.palette) private var palette
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
                    .fill(palette.text.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else {
                Rectangle()
                    .fill(palette.text.opacity(0.1))
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

            if let path = resolvedPath, let image = InspectImageCache.shared.image(atPath: path) {
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

    /// Touches only its arguments, the file system and the `Sendable` resolver, so it can run off
    /// the main actor.
    nonisolated private func resolveImagePath(_ path: String, basePath: String?) -> String? {
        if path.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: path) ? path : nil
        }

        if let base = basePath {
            let fullPath = (base as NSString).appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        if let resolved = ImageResolver.shared.resolveImagePath(path, basePath: basePath, fallbackIcon: nil),
           resolved.hasPrefix("/"),
           FileManager.default.fileExists(atPath: resolved) {
            return resolved
        }

        return nil
    }
}
