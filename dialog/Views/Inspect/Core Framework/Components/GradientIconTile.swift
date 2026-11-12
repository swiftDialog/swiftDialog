//
//  GradientIconTile.swift
//  dialog
//
//  A rounded-square icon tile with a gradient fill and a white glyph, drawn in code so any item
//  can have one. `hero` has three stops, a shadow and an inset highlight; `row` has two stops and
//  neither. Both ramps derive from the resolved accent.
//

import SwiftUI

// MARK: - Ramp derivation

/// Derives the hero and row gradient ramps from one accent colour. Every stop is an HSB offset
/// from the accent, calibrated so the reference accent `#2f4ec9` reproduces the reference stops.
/// Pure (no view, no environment) so the ramp can be tested without rendering.
enum GradientTileRamp {

    /// Offsets applied to the accent's own HSB, not absolute colours.
    private struct HSBOffset {
        var hue: Double
        var saturation: Double
        var brightness: Double
    }

    // Deltas between the reference stops and the HSB of `#2f4ec9`, full precision.

    /// Hero 0% stop: brighter and slightly less saturated than the accent.
    private static let heroVividTop = HSBOffset(hue: -9.3746, saturation: -0.0265, brightness: 0.1608)

    /// Row 0% stop: close to the accent; a 46pt tile has no room for a highlight.
    private static let rowMutedTop = HSBOffset(hue: -7.2509, saturation: -0.0060, brightness: -0.0196)

    /// The 100% stop both ramps share: deeper, darker and more saturated than the accent.
    private static let deepBottom = HSBOffset(hue: -5.1498, saturation: 0.1198, brightness: -0.3412)

    /// Three stops (0%, 52%, 100%) for the hero treatment. The middle stop is interpolated in HSB
    /// space and drifts slightly from the reference; the endpoints are exact.
    static func hero(from accent: Color) -> [Color] {
        let base = hsb(of: accent)
        return [0, 0.52, 1].map { t in
            apply(lerp(heroVividTop, deepBottom, t), to: base)
        }
    }

    /// Two stops (0%, 100%) for the row treatment.
    static func row(from accent: Color) -> [Color] {
        let base = hsb(of: accent)
        return [
            apply(rowMutedTop, to: base),
            apply(deepBottom, to: base)
        ]
    }

    // MARK: - HSB plumbing

    private struct HSB {
        var hue: Double
        var saturation: Double
        var brightness: Double
        var alpha: Double
    }

    /// Resolves through `NSColor`: `Color.cgColor` is nil for dynamic colours such as `.accentColor`.
    private static func hsb(of color: Color) -> HSB {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return HSB(hue: Double(h) * 360, saturation: Double(s), brightness: Double(b), alpha: Double(a))
    }

    private static func lerp(_ a: HSBOffset, _ b: HSBOffset, _ t: Double) -> HSBOffset {
        HSBOffset(hue: a.hue + (b.hue - a.hue) * t,
                  saturation: a.saturation + (b.saturation - a.saturation) * t,
                  brightness: a.brightness + (b.brightness - a.brightness) * t)
    }

    private static func apply(_ offset: HSBOffset, to base: HSB) -> Color {
        let hue = (base.hue + offset.hue).truncatingRemainder(dividingBy: 360)
        let normalizedHue = hue < 0 ? hue + 360 : hue
        let saturation = min(max(base.saturation + offset.saturation, 0), 1)
        let brightness = min(max(base.brightness + offset.brightness, 0), 1)
        return Color(nsColor: NSColor(hue: normalizedHue / 360, saturation: saturation, brightness: brightness, alpha: base.alpha))
    }
}

// MARK: - GradientIconTile

/// A rounded-square icon tile with a gradient fill and a white glyph. Corner radius is
/// `size × 0.25`, glyph `size × 0.5`; sizes in use are 104 and 76 (hero) and 46 (row).
struct GradientIconTile: View {

    enum Treatment {
        case hero
        case row
    }

    let systemImage: String
    let size: CGFloat
    var treatment: Treatment = .hero
    /// Passed explicitly rather than read from the environment, so a tile never drifts from the
    /// palette its caller resolved.
    let accent: Color
    /// Hero only.
    var showsSuccessBadge: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.palette) private var palette

    private var cornerRadius: CGFloat { size * 0.25 }
    private var glyphSize: CGFloat { size * 0.5 }

    /// A CSS 165° gradient as `UnitPoint`s: direction `(sin θ, −cos θ)`, endpoints half the
    /// gradient line `|sin θ| + |cos θ|` either side of the centre. Out-of-range points are
    /// intended; the line extends past the box so the corners are covered.
    private static let gradientStart = UnitPoint(x: 0.3415, y: -0.0915)
    private static let gradientEnd = UnitPoint(x: 0.6585, y: 1.0915)

    /// The accent-derived ramp, lifted in dark mode.
    private var stops: [Color] {
        let base = treatment == .hero ? GradientTileRamp.hero(from: accent) : GradientTileRamp.row(from: accent)
        return colorScheme == .dark ? base.map(liftForDark) : base
    }

    /// Light mode: the ramp's own darkest stop, so a branded shadow tints toward its accent.
    /// Dark mode: black, the one colour reliably darker than any dark window ground.
    private var heroShadowColor: Color {
        colorScheme == .dark ? .black : (GradientTileRamp.hero(from: accent).last ?? .black)
    }

    /// Mixes each stop 16% toward white so the ramp keeps its shape but lifts off a dark ground.
    /// `Color.darkModeAdapted`'s threshold sits just below the darkest stop and would leave it.
    private func liftForDark(_ color: Color) -> Color {
        color.mix(with: .white, by: 0.16)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(LinearGradient(colors: stops, startPoint: Self.gradientStart, endPoint: Self.gradientEnd))
                .overlay {
                    // Inset highlight approximated as a top hairline; white because it simulates
                    // light on a glossy edge, not a palette surface.
                    if treatment == .hero {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    }
                    // Dark mode: a hairline edge so the row tile, which has no shadow or highlight,
                    // still separates from the ground. Derived from `palette.text` like every hairline.
                    if colorScheme == .dark {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(palette.text.opacity(0.12), lineWidth: 0.5)
                    }
                }
                .frame(width: size, height: size)
                // Hero only: a tight soft lift rather than the reference's wide blur, which
                // renders as a halo here. Dark mode needs the higher opacity to show at all.
                .shadow(color: treatment == .hero ? heroShadowColor.opacity(colorScheme == .dark ? 0.55 : 0.22) : .clear,
                        radius: treatment == .hero ? 7 : 0,
                        y: treatment == .hero ? 6 : 0)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: glyphSize, weight: .semibold))
                        .foregroundStyle(.white)
                }

            if treatment == .hero && showsSuccessBadge {
                successBadge
                    .offset(x: 6, y: 6)
            }
        }
    }

    /// The 36pt success badge: `palette.success` fill (brandable via `successColor`), ringed in
    /// the window background so the ring reads in both appearances, white checkmark.
    private var successBadge: some View {
        ZStack {
            Circle()
                .fill(palette.success)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle().strokeBorder(palette.windowBackground, lineWidth: 4)
                )
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
