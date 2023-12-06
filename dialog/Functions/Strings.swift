//
//  Strings.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation

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

