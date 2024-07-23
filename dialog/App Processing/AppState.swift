//
//  appVaribles.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI

var iconVisible: Bool = true

// Probably a way to work all this out as a nice dictionary. For now, long form.

// declare our app var in case we want to update values - e.g. future use, multiple dialog sizes
var appvars = AppVariables()
var appArguments = CommandLineArguments()
var userInputState = UserInputState()
var blurredScreen = BlurWindow()

let displayAsInt: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 0
    formatter.numberStyle = .decimal
    return formatter
}()

let displayAsDouble: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.maximumFractionDigits = 1
    formatter.numberStyle = .decimal
    return formatter
}()

struct UserInputState {
    // These items can get quite large so we declare them here and not as part of the main ObservableObject
    // Doing so saves on performance as the states only need to be updated to the value entered in, not re-evaluated on every keystroke
    var dropdownItems = [DropDownItems]()
    var listItems = [ListItems]()
    var textFields = [TextFieldState]()
    var checkBoxes = [CheckBoxes]()
}

struct TextFieldState {
    var editor: Bool       = false
    var fileSelect: Bool   = false
    var fileType: String   = ""
    var passwordFill: Bool = false
    var prompt: String     = ""
    var regex: String      = ""
    var regexError: String = ""
    var backgroundColour: Color = .clear
    var required: Bool     = false
    var secure: Bool       = false
    var title: String
    var name: String       = ""
    var value: String      = ""
    var date: Date         = Date.now
    var isDate: Bool       = false
    var confirm: Bool     = false
    var validationValue: String = ""
    var requiredTextfieldHighlight: Color = .clear
    var dictionary: [String: Any] {
            return ["title": title,
                    "name": name,
                    "required": required,
                    "secure": secure,
                    "prompt": prompt,
                    "regex": regex,
                    "regexerror": regexError,
                    "value": value
            ]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct DropDownItems {
    var title: String
    var name: String = ""
    var values: [String]
    var defaultValue: String
    var selectedValue: String = ""
    var required: Bool   = false
    var style: String = "list"
    var requiredfieldHighlight: Color = .clear
}

struct CheckBoxes {
    var label: String
    var name: String = ""
    var icon: String = ""
    var checked: Bool = false
    var disabled: Bool = false
    var enablesButton1: Bool = false
}

struct ListItems: Codable {
    var title: String
    var subTitle: String = ""
    var icon: String = ""
    var statusText: String = ""
    var statusIcon: String = ""
    var progress: CGFloat = 0
    var dictionary: [String: Any] {
            return ["title": title,
                    "subtitle": subTitle,
                    "icon": icon,
                    "statustext": statusText,
                    "status": statusIcon,
                    "progress": progress]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

struct MainImage {
    var title: String = ""
    var path: String
    var caption: String = ""
    var dictionary: [String: Any] {
        return ["imagename": "\(path)",
                    "caption": caption]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}

