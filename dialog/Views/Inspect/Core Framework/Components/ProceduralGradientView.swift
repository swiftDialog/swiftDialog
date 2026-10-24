//
//  ProceduralGradientView.swift
//  dialog
//
//  Mesh gradient backgrounds generated from a seed string; the same seed draws the same
//  picture on every Mac.
//

import SwiftUI

// MARK: - Gradient Style

enum ProceduralGradientStyle: String, CaseIterable {
    case ethereal   // soft, pastel
    case vivid      // saturated, bold
    case subtle     // muted

    var saturationRange: ClosedRange<Double> {
        switch self {
        case .ethereal: return 0.5...0.85
        case .vivid:    return 0.75...1.0
        case .subtle:   return 0.3...0.6
        }
    }

    var brightnessRange: ClosedRange<Double> {
        switch self {
        case .ethereal: return 0.75...1.0
        case .vivid:    return 0.6...0.95
        case .subtle:   return 0.8...1.0
        }
    }

    /// Hue jitter, in degrees.
    var hueShift: Double {
        switch self {
        case .ethereal: return 30
        case .vivid:    return 20
        case .subtle:   return 15
        }
    }

    /// Control-point jitter, in unit-square fractions.
    var positionJitter: Float {
        switch self {
        case .ethereal: return 0.15
        case .vivid:    return 0.10
        case .subtle:   return 0.08
        }
    }
}

// MARK: - Seeded Random Number Generator

/// Linear congruential generator seeded from a string; the same seed gives the same sequence.
struct SeededRNG {
    private var state: UInt64

    init(seed: String) {
        self.state = Self.djb2Hash(seed)
    }

    /// DJB2, because Swift's `Hashable` is randomized per process launch.
    private static func djb2Hash(_ string: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in string.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return hash == 0 ? 1 : hash
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }

    /// In [0, 1).
    mutating func nextDouble() -> Double {
        return Double(next() >> 11) / Double(1 << 53)
    }

    /// In [0, 1).
    mutating func nextFloat() -> Float {
        return Float(nextDouble())
    }

    mutating func nextDouble(in range: ClosedRange<Double>) -> Double {
        return range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        return range.lowerBound + nextFloat() * (range.upperBound - range.lowerBound)
    }
}

// MARK: - Procedural Gradient View

/// A 3×3 `MeshGradient` generated deterministically from a seed string and up to three base colors.
struct ProceduralGradientView: View {
    let seed: String
    let palette: [Color]
    let style: ProceduralGradientStyle

    init(seed: String, palette: [Color] = [], style: ProceduralGradientStyle = .ethereal) {
        self.seed = seed
        self.palette = palette
        self.style = style
    }

    var body: some View {
        let generated = Self.generateGradientData(seed: seed, palette: palette, style: style)

        MeshGradient(
            width: 3,
            height: 3,
            points: generated.points,
            colors: generated.colors
        )
    }

    // MARK: - Generation

    struct GradientData {
        let points: [SIMD2<Float>]
        let colors: [Color]
    }

    static func generateGradientData(
        seed: String,
        palette: [Color],
        style: ProceduralGradientStyle
    ) -> GradientData {
        var rng = SeededRNG(seed: seed)
        let colors = expandPalette(base: palette, rng: &rng, style: style)
        let points = generatePoints(rng: &rng, style: style)
        return GradientData(points: points, colors: colors)
    }

    // MARK: - Point Generation

    /// A 3×3 grid of control points. Edge points jitter only along their edge, at half strength,
    /// so the mesh keeps covering the frame.
    private static func generatePoints(rng: inout SeededRNG, style: ProceduralGradientStyle) -> [SIMD2<Float>] {
        let jitter = style.positionJitter
        var points: [SIMD2<Float>] = []

        for row in 0..<3 {
            for col in 0..<3 {
                let baseX = Float(col) / 2.0
                let baseY = Float(row) / 2.0

                var x = baseX
                var y = baseY

                let isEdgeX = (col == 0 || col == 2)
                let isEdgeY = (row == 0 || row == 2)

                if !isEdgeX {
                    x += rng.nextFloat(in: -jitter...jitter)
                }
                if !isEdgeY {
                    y += rng.nextFloat(in: -jitter...jitter)
                }

                if isEdgeX && !isEdgeY {
                    y += rng.nextFloat(in: -(jitter * 0.5)...(jitter * 0.5))
                }
                if isEdgeY && !isEdgeX {
                    x += rng.nextFloat(in: -(jitter * 0.5)...(jitter * 0.5))
                }

                x = max(0, min(1, x))
                y = max(0, min(1, y))

                points.append(SIMD2<Float>(x, y))
            }
        }

        return points
    }

    // MARK: - Palette Expansion

    /// Expands 0–3 base colors into the 9 mesh colors by jittering hue, saturation and brightness.
    private static func expandPalette(
        base: [Color],
        rng: inout SeededRNG,
        style: ProceduralGradientStyle
    ) -> [Color] {
        var baseHSBs: [(h: Double, s: Double, b: Double)] = []

        if base.isEmpty {
            let hue1 = rng.nextDouble()
            let hue2 = fmod(hue1 + rng.nextDouble(in: 0.15...0.45), 1.0)
            baseHSBs = [
                (h: hue1, s: 0.7, b: 0.9),
                (h: hue2, s: 0.6, b: 0.95)
            ]
        } else {
            for color in base.prefix(3) {
                let hsb = color.hsb
                baseHSBs.append(hsb)
            }
        }

        var colors: [Color] = []
        for i in 0..<9 {
            let baseIndex = i % baseHSBs.count
            let baseHSB = baseHSBs[baseIndex]

            let hueOffset = rng.nextDouble(in: -style.hueShift...style.hueShift) / 360.0
            let hue = fmod(baseHSB.h + hueOffset + 1.0, 1.0)

            let saturation = rng.nextDouble(in: style.saturationRange)
            let brightness = rng.nextDouble(in: style.brightnessRange)

            colors.append(Color(hue: hue, saturation: saturation, brightness: brightness))
        }

        return colors
    }
}

// MARK: - Color HSB Extension

private extension Color {
    var hsb: (h: Double, s: Double, b: Double) {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h: Double(h), s: Double(s), b: Double(b))
    }
}

// MARK: - Preview

#if DEBUG
struct ProceduralGradientView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ProceduralGradientView(seed: "outset", palette: [.purple, .pink], style: .ethereal)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            ProceduralGradientView(seed: "sofa", palette: [.blue, .cyan], style: .vivid)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            ProceduralGradientView(seed: "pique", style: .subtle)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
