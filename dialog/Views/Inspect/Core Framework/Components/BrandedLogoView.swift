//
//  BrandedLogoView.swift
//  dialog
//
//  The brand logo: trimmed to its visible mark, dark-variant resolution, and the persistent
//  corner overlay the Preset 5 / Preset 6 roots draw once across step transitions.
//

import SwiftUI

// MARK: - Brand logo image (trim + clear-space)

/// In dark mode, "…/icon.png" resolves to "…/icon-dark.png" when that sibling exists on disk;
/// otherwise the original path. An authored `imagePathDark` takes precedence in `BrandArtwork`.
func darkVariantImagePath(_ path: String, dark: Bool) -> String {
    guard dark else { return path }
    let expanded = (path as NSString).expandingTildeInPath
    let ext = (expanded as NSString).pathExtension
    let base = (expanded as NSString).deletingPathExtension
    let candidate = ext.isEmpty ? "\(base)-dark" : "\(base)-dark.\(ext)"
    return FileManager.default.fileExists(atPath: candidate) ? candidate : expanded
}

/// A logo sized by its visible mark: the transparent border is trimmed first, so baked-in clear
/// space cannot shrink the mark inside its `height`.
struct BrandLogoImage: View {
    let path: String
    var basePath: String?        // resolve a relative logo path against this base
    let height: CGFloat
    /// When set, the mark fits inside a `maxWidth` × `height` box, leading-aligned; a wide
    /// wordmark renders shorter rather than wider. Nil lets the width follow the aspect ratio.
    var maxWidth: CGFloat?
    var clearSpace: CGFloat = 0        // fraction of `height` reserved as margin around the mark
    var opacity: Double = 1.0

    /// Absolute, tilde and URL paths pass through; a relative one resolves against `basePath`,
    /// then the config's base path, so every call site gets the same answer.
    private var resolvedPath: String {
        if path.hasPrefix("/") || path.hasPrefix("~") || path.hasPrefix("http") { return path }
        if let base = basePath ?? ImageResolver.shared.configBasePath, !base.isEmpty {
            return (base as NSString).appendingPathComponent(path)
        }
        return path
    }

    var body: some View {
        if let trimmed = LogoTrimCache.image(for: resolvedPath) {
            let markHeight = height * (1 - min(max(clearSpace, 0), 0.6) * 2)
            Group {
                if let maxWidth {
                    Image(nsImage: trimmed)
                        .resizable()
                        .scaledToFit()
                        .frame(width: maxWidth, height: markHeight, alignment: .leading)
                } else {
                    Image(nsImage: trimmed)
                        .resizable()
                        .scaledToFit()
                        .frame(height: markHeight)
                        .fixedSize()
                }
            }
            .frame(height: height)        // clear-space band around the mark
            .opacity(opacity)
        }
    }
}

/// Caches the trimmed image per path; trimming is a per-pixel scan.
enum LogoTrimCache {
    private static let cache = LockedValue<[String: NSImage]>([:])

    static func image(for path: String) -> NSImage? {
        let key = (path as NSString).expandingTildeInPath
        if let hit = cache.value[key] { return hit }
        guard let original = NSImage(contentsOfFile: key) else { return nil }
        let result = original.trimmingTransparentBorder()
        cache.withLock { $0[key] = result }
        return result
    }
}

extension NSImage {
    /// A copy cropped to the bounding box of non-transparent pixels; self if already tight or unreadable.
    func trimmingTransparentBorder() -> NSImage {
        guard let tiff = tiffRepresentation, let bmp = NSBitmapImageRep(data: tiff),
              let cg = bmp.cgImage else { return self }
        let w = bmp.pixelsWide, h = bmp.pixelsHigh
        guard w > 0, h > 0, let data = cg.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return self }
        let bpp = cg.bitsPerPixel / 8
        let rowBytes = cg.bytesPerRow
        let alphaFirst = cg.alphaInfo == .premultipliedFirst || cg.alphaInfo == .first
        let alphaOffset = alphaFirst ? 0 : bpp - 1
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * rowBytes
            for x in 0..<w where ptr[row + x * bpp + alphaOffset] > 2 {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY,
              minX > 0 || minY > 0 || maxX < w - 1 || maxY < h - 1 else { return self }
        let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let cropped = cg.cropping(to: rect) else { return self }
        return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
    }
}

/// The phase a logo is shown in; drives per-phase visibility, scale and offset.
enum LogoPhase { case intro, main, summary }

/// The persistent logo overlay, drawn once by the preset root. Callers use it only for the header
/// position; a footer mark is drawn inside the footer row. Every `LogoConfig` field has a
/// neutral default, so an unconfigured logo is a plain corner mark.
struct BrandedLogoView: View {
    let logoConfig: InspectConfig.LogoConfig
    let basePath: String?
    var phase: LogoPhase = .main
    /// Baseline padding for a bottom position; nil uses the default.
    var footerVerticalPadding: CGFloat?

    @Environment(\.colorScheme) private var colorScheme

    init(logoConfig: InspectConfig.LogoConfig, basePath: String? = nil,
         phase: LogoPhase = .main, footerVerticalPadding: CGFloat? = nil) {
        self.logoConfig = logoConfig
        self.basePath = basePath
        self.phase = phase
        self.footerVerticalPadding = footerVerticalPadding
    }

    // MARK: - Resolved Properties

    private var effectiveLogoPath: String {
        // `BrandArtwork.resolve` owns which file is shown; it cannot return nil for a non-optional config.
        BrandArtwork.resolve(logoConfig, isDark: colorScheme == .dark) ?? logoConfig.imagePath
    }

    private var pos: String {
        logoConfig.position?.lowercased() ?? "topright"
    }

    private var isBottom: Bool { pos.contains("bottom") }
    private var isLeft: Bool { pos.contains("left") }

    /// Bottom logos default to 28pt and are capped at 80pt; top corners default to 40pt.
    private var effectiveHeight: CGFloat {
        let raw = CGFloat(logoConfig.maxHeight ?? (isBottom ? 28 : 40))
        return isBottom ? min(raw, 80) : raw
    }

    private var effectiveOpacity: Double {
        logoConfig.opacity ?? (isBottom ? 0.95 : 1.0)
    }

    private var effectiveScale: CGFloat {
        switch phase {
        case .intro:   return CGFloat(logoConfig.introScale ?? logoConfig.scale ?? 1.0)
        case .main:    return CGFloat(logoConfig.scale ?? 1.0)
        case .summary: return CGFloat(logoConfig.outroScale ?? logoConfig.scale ?? 1.0)
        }
    }

    private var effectiveOffset: CGFloat {
        switch phase {
        case .intro:   return CGFloat(logoConfig.introVerticalOffset ?? logoConfig.verticalOffset ?? 0)
        case .main:    return CGFloat(logoConfig.verticalOffset ?? 0)
        case .summary: return CGFloat(logoConfig.outroVerticalOffset ?? logoConfig.verticalOffset ?? 0)
        }
    }

    private var isVisible: Bool {
        switch phase {
        case .intro:   return logoConfig.showOnIntro ?? true
        case .main:    return logoConfig.showOnMain ?? true
        case .summary: return logoConfig.showOnSummary ?? true
        }
    }

    private var edgePaddingH: CGFloat {
        isBottom ? 20 : CGFloat(logoConfig.padding ?? 12)
    }

    private var edgePaddingV: CGFloat {
        if isBottom {
            return footerVerticalPadding ?? CGFloat(logoConfig.padding ?? 20)
        }
        return CGFloat(logoConfig.padding ?? 16)
    }

    // MARK: - Body

    @ViewBuilder
    private var logoImage: some View {
        // Through `BrandMark`, so corner and footer logos share the trim and clear-space treatment.
        let image = BrandMark(
            path: effectiveLogoPath,
            box: BrandMarkBox(height: effectiveHeight, maxWidth: nil),
            basePath: basePath,
            clearSpace: logoConfig.clearSpace,
            opacity: effectiveOpacity
        )

        if let bg = logoConfig.backgroundColor {
            image
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat(logoConfig.cornerRadius ?? 8), style: .continuous)
                        .fill(Color(hex: bg).opacity(logoConfig.backgroundOpacity ?? 0.2))
                )
        } else {
            image
        }
    }

    var body: some View {
        if isVisible {
            VStack {
                if isBottom { Spacer() }
                HStack(alignment: .bottom) {
                    if !isLeft { Spacer() }
                    logoImage
                        .scaleEffect(effectiveScale)
                        .offset(y: effectiveOffset)
                        .padding(isLeft ? .leading : .trailing, edgePaddingH)
                        .padding(isBottom ? .bottom : .top, edgePaddingV)
                    if isLeft { Spacer() }
                }
                if !isBottom { Spacer() }
            }
            .allowsHitTesting(false)
        }
    }
}
