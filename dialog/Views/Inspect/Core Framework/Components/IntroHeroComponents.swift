//
//  IntroHeroComponents.swift
//  dialog
//
//  Hero image (trim/shape/symbol) + progress dots for intro-style steps.
//

import SwiftUI

// MARK: - Hero Image Component

/// Configurable hero image for intro/outro screens
/// Supports SF Symbols, image files, and multiple shapes (circle, roundedSquare, square, none)
struct IntroHeroImage: View {
    let path: String
    let shape: String
    let size: Double
    let accentColor: Color
    let sfSymbolColor: Color?
    let sfSymbolWeight: Font.Weight
    let basePath: String?
    let padding: Double?            // nil = auto, 0 = none, >0 = explicit inset

    init(
        path: String,
        shape: String = "circle",
        size: Double = 200,
        accentColor: Color = .accentColor,
        sfSymbolColor: Color? = nil,
        sfSymbolWeight: Font.Weight = .medium,
        basePath: String? = nil,
        padding: Double? = nil
    ) {
        self.path = path
        self.shape = shape
        self.size = size
        self.accentColor = accentColor
        self.sfSymbolColor = sfSymbolColor
        self.sfSymbolWeight = sfSymbolWeight
        self.basePath = basePath
        self.padding = padding
    }

    /// Resolved padding: explicit value wins, SF symbols default to 0, images get proportional inset
    private var effectivePadding: Double {
        if let padding = padding { return padding }
        if IconRef.isSymbolReference(path) { return 0 }
        return size * 0.04
    }

    /// Glyph heroes (device icon / SF Symbol) are centered marks that look right in a
    /// circular medallion; real image files do not.
    private var isGlyphHero: Bool {
        IconRef.isComputer(path) || IconRef.isSymbolReference(path)
    }

    /// A file-based hero left at the default `"circle"` renders as a rounded rectangle so the
    /// whole image shows; explicit shapes and glyph heroes are honoured unchanged.
    private var effectiveShape: String {
        if !isGlyphHero && shape.lowercased() == "circle" { return "roundedSquare" }
        return shape
    }

    var body: some View {
        Group {
            if IconRef.isComputer(path) {
                // Device-specific hardware icon (MacBook, iMac, etc.)
                deviceIconView
            } else if let symbolName = IconRef.symbol(path) {
                sfSymbolView(symbolName: symbolName)
            } else {
                // Image file
                imageFileView(path: path)
            }
        }
        .frame(width: size, height: size)
        .modifier(ConditionalClipShape(shape: effectiveShape, size: size))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }

    @ViewBuilder
    private var deviceIconView: some View {
        let contentSize = size - 2 * effectivePadding
        Image(nsImage: NSImage(named: NSImage.computerName) ?? NSImage())
            .resizable()
            .scaledToFit()
            .frame(width: max(contentSize, 10), height: max(contentSize, 10))
    }

    /// Cap on a symbol glyph, not a size: anything smaller still gets what it asked for. Bounds
    /// what an authored `size` can mean while each call site's default shape interprets it.
    private static let markCeiling: CGFloat = 64

    @ViewBuilder
    private func sfSymbolView(symbolName: String) -> some View {
        let contentSize = size - 2 * effectivePadding
        // Only the glyph is capped; the tinted disc still scales with the authored size.
        let mark = min(contentSize * 0.5, Self.markCeiling)
        let color = sfSymbolColor ?? accentColor
        Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .font(.system(size: mark * 0.9, weight: sfSymbolWeight))
            .frame(width: mark, height: mark)
            .foregroundStyle(color)
            .frame(width: contentSize, height: contentSize)
            .background(
                Circle()
                    .fill(color.opacity(0.1))
            )
    }

    @ViewBuilder
    private func imageFileView(path: String) -> some View {
        let contentSize = size - 2 * effectivePadding
        // Aspect-fit unless an explicit fill shape was authored.
        let usesFit = effectiveShape.lowercased() == "none" || shape.lowercased() == "circle"
        if let nsImage = loadImage(path: path) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: usesFit ? .fit : .fill)
                .frame(width: max(contentSize, 10), height: max(contentSize, 10))
                .clipped()
        } else {
            // Fallback placeholder
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .frame(width: max(contentSize, 10), height: max(contentSize, 10))
                .foregroundStyle(.secondary)
        }
    }

    /// Absolute path, then relative to `basePath`, then `ImageResolver`, then the raw path.
    private func loadImage(path: String) -> NSImage? {
        if path.hasPrefix("/") {
            if let image = InspectImageCache.shared.image(atPath: path) {
                return image
            }
        }

        if let base = basePath {
            let fullPath = (base as NSString).appendingPathComponent(path)
            if let image = InspectImageCache.shared.image(atPath: fullPath) {
                return image
            }
        }

        if let resolvedPath = ImageResolver.shared.resolveImagePath(path, basePath: basePath, fallbackIcon: nil),
           resolvedPath.hasPrefix("/"),
           let image = InspectImageCache.shared.image(atPath: resolvedPath) {
            return image
        }

        return InspectImageCache.shared.image(atPath: path)
    }

    private var clipShape: some Shape {
        switch shape {
        case "roundedSquare":
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.12))
        case "square", "none":
            return AnyShape(Rectangle())
        default: // "circle"
            return AnyShape(Circle())
        }
    }
}

/// Conditional clip shape modifier for hero images
/// Only applies clipping when shape is not "none"
private struct ConditionalClipShape: ViewModifier {
    let shape: String
    let size: Double

    func body(content: Content) -> some View {
        if shape == "none" {
            content
        } else {
            content.clipShape(clipShapeFor(shape: shape, size: size))
        }
    }

    private func clipShapeFor(shape: String, size: Double) -> some Shape {
        switch shape {
        case "roundedSquare":
            return AnyShape(RoundedRectangle(cornerRadius: size * 0.12))
        case "square":
            return AnyShape(Rectangle())
        default: // "circle"
            return AnyShape(Circle())
        }
    }
}

