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
    static let background = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.underPageBackgroundColor)
    static let tertiaryBackground = Color(NSColor.controlBackgroundColor)

    static let code = Color(
        light: Color(rgba: 0xdc1c_50ff), dark: Color(rgba: 0xdb58_7bff)
    )
    static let text = Color(
        light: Color(rgba: 0x0606_06ff), dark: Color(rgba: 0xfbfb_fcff)
    )
    static let secondaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x9294_a0ff)
    )
    static let tertiaryText = Color(
        light: Color(rgba: 0x6b6e_7bff), dark: Color(rgba: 0x6d70_7dff)
    )
    static let link = Color(
        light: Color(rgba: 0x2c65_cfff), dark: Color(rgba: 0x4c8e_f8ff)
    )
    static let border = Color(
        light: Color(rgba: 0xe4e4_e8ff), dark: Color(rgba: 0x4244_4eff)
    )
    static let divider = Color(
        light: Color(rgba: 0xd0d0_d3ff), dark: Color(rgba: 0x3334_38ff)
    )
    static let checkbox = Color(rgba: 0xb9b9_bbff)
    static let checkboxBackground = Color(rgba: 0xeeee_efff)
}
