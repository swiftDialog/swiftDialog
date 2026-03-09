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

            let colourRedValue = "\(argument[1])\(argument[2])"
            let colourRed = Double(Int(colourRedValue, radix: 16)!)/255

            let colourGreenValue = "\(argument[3])\(argument[4])"
            let colourGreen = Double(Int(colourGreenValue, radix: 16)!)/255

            let colourBlueValue = "\(argument[5])\(argument[6])"
            let colourBlue = Double(Int(colourBlueValue, radix: 16)!)/255

            self.init(red: colourRed, green: colourGreen, blue: colourBlue)

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

    /// Relative luminance (0 = black, 1 = white) per WCAG 2.0
    var luminance: CGFloat {
        let components = self.cgColor?.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// Lighten the color by a factor (0 = unchanged, 1 = white).
    /// Preserves hue by mixing toward white in RGB space.
    func lightened(by factor: CGFloat) -> Color {
        let components = self.cgColor?.components
        let r: CGFloat = components?[0] ?? 0.0
        let g: CGFloat = components?[1] ?? 0.0
        let b: CGFloat = components?[2] ?? 0.0
        return Color(
            .sRGB,
            red: Double(r + (1 - r) * factor),
            green: Double(g + (1 - g) * factor),
            blue: Double(b + (1 - b) * factor)
        )
    }

    /// Returns a version of this color that's guaranteed visible on dark backgrounds.
    /// Very dark brand colors (luminance < 0.15) get lightened so they remain legible
    /// on macOS dark mode surfaces. Brighter colors pass through unchanged.
    var darkModeAdapted: Color {
        let lum = self.luminance
        if lum < 0.08 {
            return self.lightened(by: 0.55) // very dark → significant lift
        } else if lum < 0.15 {
            return self.lightened(by: 0.40) // dark → moderate lift
        }
        return self
    }
}
