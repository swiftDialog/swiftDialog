//
//  Strings.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation
import CryptoKit
import SwiftUI

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

