//
//  BentoSurface.swift
//  dialog
//
//  The palette of tinted surfaces a bento cell sits on when its config names no colour. Tint
//  strength is fixed per surface, never by the cell's position, so identical cells render alike.
//

import SwiftUI

/// The tinted surfaces a bento cell can sit on. Explicit colours in the cell config still win.
enum BentoSurface: String, CaseIterable {
    case accent     // the brand colour
    case cool
    case warm
    case neutral

    /// Semantic surfaces: authorable only, never handed out by `rotating(index:)`.
    case success
    case warning
    case info

    /// An unrecognised name falls back rather than disabling the cell's styling.
    init(configValue: String?, fallback: BentoSurface = .neutral) {
        self = BentoSurface(rawValue: configValue?.lowercased() ?? "") ?? fallback
    }

    /// The surfaces rotation may hand out to unauthored cells. Growing this list re-tints every
    /// unauthored cell in existing configs; a cell must never be assigned a semantic meaning.
    static let rotationCases: [BentoSurface] = [.accent, .cool, .warm, .neutral]

    /// Round-robin surface for a cell that names none; `accent` first so the first cell carries
    /// the brand colour. Cycles `rotationCases`, not `allCases`.
    static func rotating(index: Int) -> BentoSurface {
        rotationCases[index % rotationCases.count]
    }

    /// The unblended colour of this surface: the same hue `fill` blends. Semantic surfaces read
    /// the palette so they follow a tenant's overrides.
    func tint(accent: Color, palette: ResolvedPalette) -> Color {
        switch self {
        case .accent, .neutral: return accent
        case .cool:    return hueShift(accent, by: -0.10)
        case .warm:    return hueShift(accent, by: 0.10)
        case .success: return palette.success
        case .warning: return palette.warning
        case .info:    return palette.info
        }
    }

    /// The cell fill; blend strength is fixed per surface. Only the semantic surfaces read `palette`.
    func fill(accent: Color, palette: ResolvedPalette, scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch self {
        case .accent:  return blend(accent, toward: dark ? .black : .white, amount: dark ? 0.62 : 0.86)
        case .cool:    return blend(hueShift(accent, by: -0.10), toward: dark ? .black : .white, amount: dark ? 0.70 : 0.92)
        case .warm:    return blend(hueShift(accent, by: 0.10), toward: dark ? .black : .white, amount: dark ? 0.70 : 0.92)
        case .neutral: return dark ? Color(white: 0.16) : Color(white: 0.965)
        case .success: return blend(palette.success, toward: dark ? .black : .white, amount: dark ? 0.70 : 0.92)
        case .warning: return blend(palette.warning, toward: dark ? .black : .white, amount: dark ? 0.70 : 0.92)
        case .info:    return blend(palette.info,    toward: dark ? .black : .white, amount: dark ? 0.70 : 0.92)
        }
    }

    /// Every surface is a light tint carrying dark text (the reverse in dark mode), so a title
    /// is always legible.
    func textColor(scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(white: 0.96) : Color(white: 0.11)
    }

    // MARK: - Colour helpers

    private func blend(_ color: Color, toward target: Color, amount: Double) -> Color {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let t = NSColor(target).usingColorSpace(.sRGB) ?? NSColor(target)
        let a = min(max(amount, 0), 1)
        return Color(red: c.redComponent   + (t.redComponent   - c.redComponent)   * a,
                     green: c.greenComponent + (t.greenComponent - c.greenComponent) * a,
                     blue: c.blueComponent  + (t.blueComponent  - c.blueComponent)  * a)
    }

    /// A small hue rotation keeps cool/warm reading as siblings of the accent.
    private func hueShift(_ color: Color, by delta: Double) -> Color {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let shifted = (h + CGFloat(delta)).truncatingRemainder(dividingBy: 1.0)
        return Color(nsColor: NSColor(hue: shifted < 0 ? shifted + 1 : shifted,
                                      saturation: s, brightness: b, alpha: a))
    }
}
