//
//  System.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import AppKit
import SystemConfiguration
import SwiftUI
import SwiftyJSON

func openSpecifiedURL(urlToOpen: String) {
    // Open the selected URL (no checking is performed)
    writeLog("Opening URL \(urlToOpen)")
    if let url = URL(string: urlToOpen) {
        NSWorkspace.shared.open(url)
    }
}

func shell(_ command: String) -> String {
    writeLog("Running shell command \(command)")
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

// taken wholesale from DEPNotify because Joel and team and jsut awesome so why re-invent the wheel?
func checkRegexPattern(regexPattern: String, textToValidate: String) -> Bool {
    var returnValue = true
    writeLog("Checking regex")
    do {
        let regex = try NSRegularExpression(pattern: regexPattern)
        let nsString = textToValidate as NSString
        let results = regex.matches(in: textToValidate, range: NSRange(location: 0, length: nsString.length))

        if results.count == 0 {
            returnValue = false
        }

    } catch let error as NSError {
        writeLog("invalid regex: \(error.localizedDescription)")
        returnValue = false
    }

    return  returnValue
}

func buttonAction(action: String, exitCode: Int32, executeShell: Bool, shouldQuit: Bool = true, observedObject: DialogUpdatableContent) {
    writeLog("processing button action \(action)")
    if action != "" {
        if executeShell {
            print(shell(action))
        } else {
            openSpecifiedURL(urlToOpen: action)
        }
    }
    if shouldQuit {
        quitDialog(exitCode: exitCode, observedObject: observedObject)
    }
}

func printVersionString() {
    //what it says on the tin
    print(getVersionString())
}

func quitDialog(exitCode: Int32, exitMessage: String? = "", observedObject: DialogUpdatableContent? = nil) {
    writeLog("About to quit with exit code \(exitCode)")
    if exitMessage != "" {
        print("\(exitMessage!)")
    }

    // force quit
    if exitCode == 255 {
        exit(0)
    }

    // only print if exit code os 0
    if exitCode == 0 {

        // build json using SwiftyJSON
        var json = JSON()

        //build output array
        var outputArray: Array = [String]()
        var dontQuit = false
        var requiredString = ""

        if appArguments.textField.present {
            writeLog("Textfield present - checking requirements are met")
            // check to see if fields marked as required have content before allowing the app to exit
            // if there is an empty field, update the highlight colour

            for index in 0..<(userInputState.textFields.count) {
                //check for required fields
                let textField = userInputState.textFields[index]
                let textfieldValue = textField.value
                let textfieldTitle = textField.title
                let textfieldRequired = textField.required
                userInputState.textFields[index].requiredTextfieldHighlight = Color.clear

                if textfieldRequired && textfieldValue == "" { // && userInputState.textFields[index].regex.isEmpty {
                    NSSound.beep()
                    requiredString += "  - \"\(textfieldTitle)\" \("is-required".localized)<br>"
                    userInputState.textFields[index].requiredTextfieldHighlight = Color.red
                    dontQuit = true
                    writeLog("Required text field \(textfieldTitle) has no value")

                //check for regex requirements
                } else if !(textfieldValue.isEmpty)
                            && !(textField.regex.isEmpty)
                            && !checkRegexPattern(regexPattern: textField.regex, textToValidate: textfieldValue) {
                    NSSound.beep()
                    userInputState.textFields[index].requiredTextfieldHighlight = Color.green
                    requiredString += "  - "+(textField.regexError)+"<br>"
                    dontQuit = true
                    writeLog("Textfield \(textfieldTitle) value \(textfieldValue) does not meet regex requirements \(String(describing: textField.regex))")
                }

                outputArray.append("\(textfieldTitle) : \(textfieldValue)")
                json[textfieldTitle].string = textfieldValue
            }
        }

        if observedObject?.args.dropdownValues.present != nil {
            writeLog("Select items present - checking require,ments are met")
            if userInputState.dropdownItems.count == 1 {
                let selectedValue = userInputState.dropdownItems[0].selectedValue
                let selectedIndex = userInputState.dropdownItems[0].values

                outputArray.append("\"SelectedOption\" : \"\(selectedValue)\"")
                json["SelectedOption"].string = selectedValue
                outputArray.append("\"SelectedIndex\" : \(selectedIndex.firstIndex(of: (selectedValue)) ?? -1)")
                json["SelectedIndex"].int = selectedIndex.firstIndex(of: selectedValue) ?? -1
            }
            // check to see if fields marked as required have content before allowing the app to exit
            // if there is an empty field, update the highlight colour
            for index in 0..<(userInputState.dropdownItems.count) {
                let dropdownItem = userInputState.dropdownItems[index]
                let dropdownItemValues = dropdownItem.values
                let dropdownItemSelectedValue = dropdownItem.selectedValue
                let dropdownItemTitle = dropdownItem.title
                let dropdownItemRequired = dropdownItem.required
                userInputState.dropdownItems[index].requiredfieldHighlight = Color.clear

                if dropdownItemRequired && dropdownItemSelectedValue == "" {
                    NSSound.beep()
                    requiredString += "  - \"\(dropdownItemTitle)\" \("is-required".localized)<br>"
                    userInputState.dropdownItems[index].requiredfieldHighlight = Color.red
                    dontQuit = true
                    writeLog("Required select item \(dropdownItemTitle) has no value")
                } else {
                    outputArray.append("\"\(dropdownItemTitle)\" : \"\(dropdownItemSelectedValue)\"")
                    outputArray.append("\"\(dropdownItemTitle)\" index : \"\(dropdownItemValues.firstIndex(of: dropdownItemSelectedValue) ?? -1)\"")
                    json[dropdownItemTitle] = ["selectedValue": dropdownItemSelectedValue, "selectedIndex": dropdownItemValues.firstIndex(of: dropdownItemSelectedValue) ?? -1]
                }
            }
        }

        if dontQuit {
            writeLog("Requirements were not met. Dialog will not quit at this time")
            observedObject?.sheetErrorMessage = requiredString.replacingOccurrences(of: "<br>", with: "\n")
            observedObject?.showSheet = true
            return
        }

        if observedObject?.args.checkbox.present != nil {
            for index in 0..<(observedObject?.appProperties.checkboxArray.count ?? 0) {
                outputArray.append("\"\(observedObject?.appProperties.checkboxArray[index].label ?? "checkbox \(index)")\" : \"\(observedObject?.appProperties.checkboxArray[index].checked ?? false)\"")
                json[observedObject?.appProperties.checkboxArray[index].label ?? 0].boolValue = observedObject?.appProperties.checkboxArray[index].checked ?? false
            }
        }

        // print the output
        if observedObject?.args.jsonOutPut.present ?? false {
            print(json)
        } else {
            for index in 0..<outputArray.count {
                print(outputArray[index])
            }
        }
    }
    exit(exitCode)
}

func textToFontWeight(_ weight: String) -> Font.Weight {
    switch weight {
        case "bold":
            return Font.Weight.bold
        case "heavy":
            return Font.Weight.heavy
        case "light":
            return Font.Weight.light
        case "medium":
            return Font.Weight.medium
        case "regular":
            return Font.Weight.regular
        case "thin":
            return Font.Weight.thin
        default:
            return Font.Weight.thin
    }
}

func plistFromData(_ data: Data) throws -> [String: Any] {
    try PropertyListSerialization.propertyList(
        from: data,
        format: nil
    ) as! [String: Any]
}

func isDNDEnabled() -> Bool {
    // check for DND and return true if it is on

    let processInfo = ProcessInfo.processInfo
    let bigSur = OperatingSystemVersion(majorVersion: 11, minorVersion: 0, patchVersion: 0)
    let monterey = OperatingSystemVersion(majorVersion: 12, minorVersion: 0, patchVersion: 0)

    guard processInfo.isOperatingSystemAtLeast(bigSur) else {
        return false
    }

    if processInfo.isOperatingSystemAtLeast(monterey) {

        let suite = UserDefaults(suiteName: "com.apple.controlcenter")

        return suite?.bool(forKey: "NSStatusItem Visible FocusModes") ?? false

    } else if processInfo.isOperatingSystemAtLeast(bigSur) {

        let suite = UserDefaults(suiteName: "com.apple.controlcenter")

        return suite?.bool(forKey: "NSStatusItem Visible DoNotDisturb") ?? false

    }
    return false
}

func getVideoStreamingURLFromID(videoid: String, autoplay: Bool = false) -> String {
    var fullURL: String = videoid
    switch videoid.components(separatedBy: "=").first!.lowercased() {
    case "youtubeid":
        writeLog("Youtube ID detected")
        let youTubeID = videoid.replacingOccurrences(of: "youtubeid=", with: "")
        let youtubeURL = "https://www.youtube.com/embed/\(youTubeID)?autoplay=\(autoplay ? 1 : 0)&controls=0&showinfo=0"
        fullURL = youtubeURL
    case "vimeoid":
        let vimeoID = videoid.replacingOccurrences(of: "vimeoid=", with: "")
        let vimeoURL = "https://player.vimeo.com/video/\(vimeoID)\(vimeoID.contains("?") ? "&" : "?")autoplay=\(autoplay ? 1 : 0)&controls=\(autoplay ? 0 : 1)"
        fullURL = vimeoURL
    default:
        break
    }
    writeLog("video url is \(fullURL)")
    return fullURL
}
