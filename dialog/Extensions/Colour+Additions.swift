//
//  Colour+Additions.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import SwiftUI

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
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
