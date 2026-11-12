//
//  Colour+Additions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import SwiftUI

extension Color {

    var hexValue: String {
        let components = self.cgColor?.components
        let red: CGFloat = components?[0] ?? 0.0
        let green: CGFloat = components?[1] ?? 0.0
        let blue: CGFloat = components?[2] ?? 0.0

        let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(red * 255)), lroundf(Float(green * 255)), lroundf(Float(blue * 255)))
        return hexString
    }

    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }

    /// convert to a colour from an argument string representation
    init(argument: String) {
        let hexRegEx = "^#([a-fA-F0-9]{6})$"
        let hexPred = NSPredicate(format: "SELF MATCHES %@", hexRegEx)

        if hexPred.evaluate(with: argument) {
            // Delegate to the Scanner-based hex initialiser rather than hand-parsing
            // with force-unwrapped Int(_, radix:) conversions.
            self.init(hex: argument)
            return
        }

        switch argument {
            case "accent": self = .accentColor
            case "red": self = .red
            case "orange": self = .orange
            case "yellow": self = .yellow
            case "green": self = .green
            case "mint": self = .mint
            case "teal": self = .teal
            case "cyan": self = .cyan
            case "blue": self = .blue
            case "indigo": self = .indigo
            case "purple": self = .purple
            case "pink": self = .pink
            case "brown": self = .brown
            case "white": self = .white
            case "gray": self = .gray
            case "black": self = .black
            case "primary": self = .primary
            case "secondary": self = .secondary
            case "clear": self = .clear
            default: self = .clear
        }
    }
}

extension Color {
    init(hex: String) {
        // Handle hex strings with or without the # prefix
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension Color {
    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor)    
}

extension Color {
    var isDark: Bool {
        let components = self.cgColor?.components
        let red: CGFloat = components?[0] ?? 0.0
        let green: CGFloat = components?[1] ?? 0.0
        let blue: CGFloat = components?[2] ?? 0.0

        let lum = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return lum < 0.5
    }

    /// Resolves this color to concrete sRGB components via `NSColor`, not `Color.cgColor`.
    /// `Color.cgColor` returns nil for DYNAMIC/catalog colors — `.accentColor` chief among
    /// them — because it has no way to resolve a semantic color without an environment.
    /// `Color.accentColor.cgColor` is nil, while `NSColor(Color.accentColor).usingColorSpace(.sRGB)`
    /// resolves to the real accent RGB. Reading `cgColor?.components` would default every channel
    /// to 0 and report the accent as pure black — and `lightened` would then lift that phantom
    /// black into a hue-less grey. `BentoSurface.blend`/`hueShift` resolve colors the same way.
    private var resolvedSRGBComponents: (r: CGFloat, g: CGFloat, b: CGFloat) {
        let resolved = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        return (resolved.redComponent, resolved.greenComponent, resolved.blueComponent)
    }

    /// Relative luminance (0 = black, 1 = white) per WCAG 2.0
    var luminance: CGFloat {
        let (r, g, b) = resolvedSRGBComponents
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Lighten the color by a factor (0 = unchanged, 1 = white).
    /// Preserves hue by mixing toward white in RGB space.
    func lightened(by factor: CGFloat) -> Color {
        let (r, g, b) = resolvedSRGBComponents
        return Color(
            .sRGB,
            red: Double(r + (1 - r) * factor),
            green: Double(g + (1 - g) * factor),
            blue: Double(b + (1 - b) * factor)
        )
    }

    /// Returns a version of this color that's guaranteed visible on dark backgrounds.
    ///
    /// LIFTS BRIGHTNESS, KEEPS HUE AND SATURATION. Blending every channel toward white
    /// (`lightened(by:)`, `r + (1 - r) * factor`) raises lightness by DESTROYING saturation,
    /// because the three channels converge as the factor climbs: a deep navy such as #05164D at a
    /// 0.55 factor goes 0.02 → 0.56, 0.09 → 0.59, 0.30 → 0.69, roughly #8F96AF, a grey-lavender.
    /// Legible, and no longer the brand — on the one accent-coloured object on the screen.
    ///
    /// In HSB the same colour is hue 226°, saturation .94, brightness .30. Raising the BRIGHTNESS
    /// and leaving the other two alone keeps it unmistakably that navy, only lighter. A grey
    /// stays grey for free: saturation 0 has no hue to preserve or lose.
    ///
    /// Saturation is nudged UP rather than left flat on the darkest inputs. A very dark colour
    /// carries its identity almost entirely in hue, and lifting brightness alone reads slightly
    /// chalky next to the same brand in light mode; the small boost holds it, and the cap keeps
    /// it off neon.
    var darkModeAdapted: Color {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &sat, brightness: &b, alpha: &a)

        // Brighter colours pass through untouched, exactly as before — the thresholds are the
        // ones this method already used, still read off luminance so the entry condition has
        // not moved.
        let lum = self.luminance
        guard lum < 0.15 else { return self }

        let target: CGFloat = lum < 0.08 ? 0.72 : 0.62
        let liftedBrightness = max(b, target)
        let liftedSaturation = sat > 0 ? min(max(sat, 0.55), 0.92) : 0

        return Color(nsColor: NSColor(hue: h, saturation: liftedSaturation,
                                      brightness: liftedBrightness, alpha: a))
    }
}
