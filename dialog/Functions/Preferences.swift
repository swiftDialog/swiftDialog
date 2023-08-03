//
//  Preferences.swift
//  Dialog
//
//  Created by Bart E Reardon on 3/8/2023.
//

import Foundation

struct DialogPreferences: Codable {
    var authorisationKey: String = ""
}

func loadPreferences() -> DialogPreferences {
    let defaults = UserDefaults.standard
    var dialogPrefs = DialogPreferences()

    dialogPrefs.authorisationKey = defaults.string(forKey: "AuthorisationKey") ?? ""

    return dialogPrefs
}

func dialogAuthorisationKey() -> String {
    return loadPreferences().authorisationKey
}

func checkAuthorisationKey(key: String) -> Bool {
    let storedKey = dialogAuthorisationKey()
    writeLog("key :\(key)", logLevel: .debug)
    writeLog("stored key :\(storedKey)", logLevel: .debug)
    return storedKey.isEmpty || key == dialogAuthorisationKey()
}
