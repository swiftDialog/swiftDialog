//
//  BrandMark.swift
//
//  The footer kit's brand mark. `BrandArtwork` decides which file, `BrandMarkBox` which box, and
//  `BrandMark` draws one in the other through `BrandLogoImage`. None knows a footer or a preset.
//

import SwiftUI

enum BrandArtwork {
    /// What the mark sits on. `.photograph` is dark whatever the window's appearance, so it takes
    /// the dark art in a light window.
    enum Surface { case window, photograph }
    /// `.footer` honours the authored position (a mark asked for elsewhere draws nothing here);
    /// `.any` is for chromes that seat the mark themselves.
    enum Gate { case any, footer }

    /// The one place appearance, surface, position gate and the `-dark` sibling convention
    /// combine. Dark takes an authored `imagePathDark`, else a `-dark` sibling on disk.
    static func resolve(_ logo: InspectConfig.LogoConfig?, isDark: Bool,
                        surface: Surface = .window, gate: Gate = .any) -> String? {
        guard let logo else { return nil }
        if gate == .footer, logo.resolvedPosition != .footer { return nil }
        let dark = isDark || surface == .photograph
        if dark, let authored = logo.imagePathDark { return authored }
        return darkVariantImagePath(logo.imagePath, dark: dark)
    }
}

/// The box a mark is drawn into; each seat computes it once from its own default and cap.
struct BrandMarkBox: Equatable {
    let height: CGFloat
    let maxWidth: CGFloat?

    /// `authored` is `logoConfig.maxHeight`; `cap` shrinks only. With `maxWidth` and an
    /// `aspectRatio`, the height that keeps the clear-space-trimmed mark inside the width wins.
    static func fit(authored: Double?, default defaultHeight: CGFloat, cap: CGFloat? = nil,
                    maxWidth: CGFloat? = nil, clearSpace: CGFloat = 0,
                    aspectRatio: CGFloat? = nil) -> BrandMarkBox {
        var height = authored.map { CGFloat($0) } ?? defaultHeight
        if let cap { height = min(height, cap) }
        if let maxWidth, let aspectRatio, aspectRatio > 0 {
            let visible = 1 - min(max(clearSpace, 0), 0.6) * 2
            let widthBound = (maxWidth / aspectRatio) / max(visible, 0.01)
            height = min(height, widthBound)
        }
        return BrandMarkBox(height: height, maxWidth: maxWidth)
    }
}

/// A brand mark in its box. Sets no accessibility: whether a mark is decoration is the seat's
/// fact, and each seat keeps its own `.accessibilityHidden(true)` where it needs one.
struct BrandMark: View {
    let path: String
    let box: BrandMarkBox
    var basePath: String?
    var clearSpace: CGFloat = 0
    var opacity: Double = 1

    var body: some View {
        BrandLogoImage(path: path, basePath: basePath, height: box.height,
                       maxWidth: box.maxWidth, clearSpace: clearSpace, opacity: opacity)
    }
}
