//
//  Strings.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import CryptoKit
import SwiftUI

func hashForString(_ string: String) -> String {
    // Returns a sha256 hash of the given text
    let inputData = Data(string.utf8)
    let hashed = SHA256.hash(data: inputData)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

func string2float(string: String, defaultValue: CGFloat = 0) -> CGFloat {
    // take a umber in scring format and return a float
    let numberFormatter = NumberFormatter()
    numberFormatter.numberStyle = .decimal

    var number: CGFloat?
    if let num = numberFormatter.number(from: string) {
        number = CGFloat(truncating: num)
    } else {
        numberFormatter.locale = Locale(identifier: "en")
        if let num = numberFormatter.number(from: string) {
            number = CGFloat(truncating: num)
        }
    }
    return number ?? defaultValue
}

func getVersionString() -> String {
    // return the cf bundle version
    var appVersion: String = appvars.cliversion
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            appVersion = "\(version).\(build)"
        } else {
            appVersion = version
        }
    }
    return appVersion
}

func stringToColour(_ colourValue: String) -> Color {
    // convert a colour from a string representation to Color
    var returnColor: Color

    if isValidColourHex(colourValue) {

        let colourRedValue = "\(colourValue[1])\(colourValue[2])"
        let colourRed = Double(Int(colourRedValue, radix: 16)!)/255

        let colourGreenValue = "\(colourValue[3])\(colourValue[4])"
        let colourGreen = Double(Int(colourGreenValue, radix: 16)!)/255

        let colourBlueValue = "\(colourValue[5])\(colourValue[6])"
        let colourBlue = Double(Int(colourBlueValue, radix: 16)!)/255

        returnColor = Color(red: colourRed, green: colourGreen, blue: colourBlue)

    } else {
        switch colourValue {

        case "black":
            returnColor = Color.black
        case "blue":
            returnColor = Color.blue
        case "gray":
            returnColor = Color.gray
        case "green":
            returnColor = Color.green
        case "orange":
            returnColor = Color.orange
        case "pink":
            returnColor = Color.pink
        case "purple":
            returnColor = Color.purple
        case "red":
            returnColor = Color.red
        case "white":
            returnColor = Color.white
        case "yellow":
            returnColor = Color.yellow
        case "mint":
            returnColor = Color.mint
        case "cyan":
            returnColor = Color.cyan
        case "indigo":
            returnColor = Color.indigo
        case "teal":
            returnColor = Color.teal
        default:
            returnColor = Color.primary
        }
    }

    return returnColor

}

func colourToString(color: Color) -> String {
    let components = color.cgColor?.components
    let red: CGFloat = components?[0] ?? 0.0
    let green: CGFloat = components?[1] ?? 0.0
    let blue: CGFloat = components?[2] ?? 0.0

    let hexString = String.init(format: "#%02lX%02lX%02lX", lroundf(Float(red * 255)), lroundf(Float(green * 255)), lroundf(Float(blue * 255)))
    return hexString
 }

func isValidColourHex(_ hexvalue: String) -> Bool {
    let hexRegEx = "^#([a-fA-F0-9]{6})$"
    let hexPred = NSPredicate(format: "SELF MATCHES %@", hexRegEx)
    return hexPred.evaluate(with: hexvalue)
}
