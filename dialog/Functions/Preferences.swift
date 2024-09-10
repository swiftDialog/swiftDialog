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

    if defaults.objectIsForced(forKey: "AuthorisationKey") {
        writeLog("auth key is managed", logLevel: .debug)
    }
    dialogPrefs.authorisationKey = defaults.string(forKey: "AuthorisationKey")
                                    ?? defaults.string(forKey: "AuthorizationKey")
                                    ?? defaults.string(forKey: "AuthKey")
                                    ?? defaults.string(forKey: "Key")
                                    ?? ""

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
