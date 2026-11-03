//
//  appVaribles.swift
//  dialog
//
//  Created by Bart Reardon on 10/3/21.
//

import Foundation
import SwiftUI
import OSLog

// Log Stuff
let bundleID = Bundle.main.bundleIdentifier ?? "au.csiro.dialog"
let osLog: OSLog = OSLog(subsystem: bundleID, category: "main")

var iconVisible: Bool = true

// Probably a way to work all this out as a nice dictionary. For now, long form.

// declare our app var in case we want to update values - e.g. future use, multiple dialog sizes
var appvars = AppVariables()
var appDefaults = AppDefaults()
var appArguments = CommandLineArguments()
var userInputState = UserInputState()
var blurredScreen = BlurWindow()

var darkMode: Bool {
    let mode = UserDefaults.standard.string(forKey: "AppleInterfaceStyle")
    if appArguments.preferredAppearance.value.lowercased() == "light" { return false }
    return mode == "Dark" || appArguments.preferredAppearance.value.lowercased() == "dark"
}

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
    var buttonRows = [ButtonRow]()
    var numberInputs = [NumberInput]()
    var iconItems = [Icons]()
}

struct TextFieldState: Identifiable, Equatable {
    var id = UUID()
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
    var showDate: Bool     = false
    var showTime: Bool     = false
    var minDate: Date?     = nil        // earliest selectable date (date/time pickers only)
    var maxDate: Date?     = nil        // latest selectable date (date/time pickers only)
    var minTime: DateComponents? = nil  // earliest selectable time (time-only pickers)
    var maxTime: DateComponents? = nil  // latest selectable time (time-only pickers)
    var dateOutputFormat: String = ""   // strftime-style (e.g. "+%s"); empty = default ISO
    var confirm: Bool     = false
    var validationValue: String = ""
    var requiredTextfieldHighlight: Color = .clear
    var initialPath: String = ""
    /// Subtext shown under the title when not empty
    var detail: String = ""
    /// Only enabled while this condition holds (see ControlCondition). Empty = always.
    var enabledIf: String = ""
    /// Only shown while this condition holds. Empty = always.
    var visibleIf: String = ""

    /// True when this field should render a date/time picker instead of a text field.
    var isDatePicker: Bool { showDate || showTime }

    /// The (min, max) Date bounds handed to the DatePicker. Date and date+time pickers use
    /// minDate/maxDate directly. A time-only picker translates minTime/maxTime into instants
    /// anchored to the field's own day — a DatePicker range is a single continuous span, so it
    /// only behaves as a daily window when the bounds and the selection share a calendar day.
    /// (A consequence: a window that wraps past midnight, e.g. 6pm–4am, can't be expressed.)
    var pickerBounds: (min: Date?, max: Date?) {
        guard showTime && !showDate else { return (minDate, maxDate) }
        return (anchorTime(minTime, to: date), anchorTime(maxTime, to: date))
    }

    /// The SwiftUI DatePicker components implied by the date/time modifiers.
    var dateComponents: DatePickerComponents {
        var components: DatePickerComponents = []
        if showDate { components.insert(.date) }
        if showTime { components.insert(.hourAndMinute) }
        return components.isEmpty ? [.date] : components
    }

    /// A locale-stable format string for the returned value based on the components.
    var dateFormat: String {
        switch (showDate, showTime) {
        case (true, true):  return "yyyy-MM-dd HH:mm"
        case (false, true): return "HH:mm"
        default:            return "yyyy-MM-dd"
        }
    }

    var dictionary: [String: Any] {
            return ["title": title,
                    "name": name,
                    "required": required,
                    "secure": secure,
                    "prompt": prompt,
                    "regex": regex,
                    "regexerror": regexError,
                    "value": value,
                    "path": initialPath
            ]
        }
    var nsDictionary: NSDictionary {
            return dictionary as NSDictionary
        }
}
struct Icons {
    var value: String
}

struct DropDownItems: Equatable, Identifiable {
    var id = UUID()
    var title: String
    var name: String = ""
    var values: [String]
    var defaultValue: String
    var selectedValue: String = ""
    var required: Bool   = false
    var style: String = "list"
    var requiredfieldHighlight: Color = .clear
    /// Subtext shown under the title when not empty
    var detail: String = ""
    /// Only enabled while this condition holds (see ControlCondition). Empty = always.
    var enabledIf: String = ""
    /// Only shown while this condition holds. Empty = always.
    var visibleIf: String = ""
}

struct CheckBoxes: Identifiable, Equatable {
    var id = UUID()
    var label: String
    var name: String = ""
    var icon: String = ""
    var sfSymbol: String = ""
    var sfColour: String = ""
    var sfPicker: Bool = false
    var checked: Bool = false
    var disabled: Bool = false
    var enablesButton1: Bool = false
    /// Subtext shown under the label when not empty
    var detail: String = ""
    /// Only enabled while this condition holds (see ControlCondition). Empty = always.
    var enabledIf: String = ""
    /// Only shown while this condition holds. Empty = always.
    var visibleIf: String = ""
    var dictionary: [String: Any] {
            return ["label": label,
                    "name": name,
                    "icon": icon,
                    "checked": checked,
                    "disabled": disabled,
                    "enablesButton1": enablesButton1
            ]
        }
}

/// A slider or stepper: one shared numeric model (min / max / step / value), two views.
struct NumberInput: Identifiable, Equatable {
    var id = UUID()
    /// "slider" or "stepper"
    var kind: String = "slider"
    var title: String = ""
    var name: String = ""
    /// Subtext shown under the title when not empty
    var detail: String = ""
    var minValue: Double = 0
    var maxValue: Double = 100
    var step: Double = 1
    var value: Double = 0
    var unit: String = ""
    var minLabel: String = ""
    var maxLabel: String = ""
    /// slider: show the current value next to the slider
    var showValue: Bool = true
    /// Only enabled while this condition holds (see ControlCondition). Empty = always.
    var enabledIf: String = ""
    /// Only shown while this condition holds. Empty = always.
    var visibleIf: String = ""

    /// Name used in the output and by vieworder
    var key: String { name.isEmpty ? title : name }

    /// Decimal places implied by the step (0.25 -> 2). Values are never reported with more than 2.
    var decimals: Int {
        var places = 0
        while places < 2 && abs(step * pow(10, Double(places)) - (step * pow(10, Double(places))).rounded()) > 1e-9 {
            places += 1
        }
        return places
    }

    /// The value as text, with as many decimals as the step needs ("42", "0.75")
    var displayValue: String { String(format: "%.\(decimals)f", value) }

    /// A raw value (e.g. from dragging) held to the range, optionally snapped to the nearest step
    /// from `minValue`, and rounded to 2 decimal places so floating point noise never reaches the output.
    func constrained(_ raw: Double, snapToStep: Bool = false) -> Double {
        var result = min(max(raw, minValue), maxValue)
        if snapToStep && step > 0 {
            result = minValue + ((result - minValue) / step).rounded() * step
            result = min(max(result, minValue), maxValue)
        }
        return (result * 100).rounded() / 100
    }

    /// Make the configuration safe: positive step, max above min, value inside the range.
    func sanitised() -> NumberInput {
        var input = self
        if input.step <= 0 { input.step = 1 }
        if input.maxValue <= input.minValue {
            writeLog("\(input.kind) '\(input.key)': max must be greater than min - using max = min + 100", logLevel: .error)
            input.maxValue = input.minValue + 100
        }
        input.value = input.constrained(input.value)
        return input
    }
}

/// One button in a row. `type` decides what it is: "action" runs url / shell / sheet when clicked,
/// "colour" is a colour well (value = hex), "info" is a read-only value.
struct ButtonItem: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var label: String = ""
    /// SF Symbol spec, same vocabulary as --button1symbol
    var symbol: String = ""
    var image: String = ""
    /// "both" (default), "symbol" (symbol/image only) or "label"
    var display: String = "both"
    var value: String = ""
    var type: String = "action"
    var url: String = ""
    var shell: String = ""
    var sheet: String = ""
    var sheetImage: String = ""
    var sheetButtonText: String = ""
    var confirm: String = ""
    var disabled: Bool = false
    /// colour type: allow choosing opacity
    var opacity: Bool = false
    /// This button is only enabled while the condition holds
    var enabledIf: String = ""

    // Runtime state (not configuration)
    var clicked: Bool = false
    var isRunning: Bool = false
    /// Set 500ms after a click if the action is still running, so quick actions never show a spinner
    var showSpinner: Bool = false
    var lastExitCode: Int32?
}

/// A row of one or more buttons laid out horizontally. One --button / --buttons argument = one row.
struct ButtonRow: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var title: String = ""
    var detail: String = ""
    /// "bordered" (standard push buttons) or "plain" (no surround - swatches, thumbnails)
    var style: String = "bordered"
    /// Row behaves like a radio choice: the clicked item is selected and its value output
    var selectable: Bool = false
    var selectedValue: String = ""
    var defaultValue: String = ""
    /// "leading", "trailing" or "center"; applies when the row has no title
    var alignment: String = "trailing"
    /// Symbol/image size in points (0 = automatic)
    var size: CGFloat = 0
    /// "inline", "below", "selected" or "hidden"
    var labelPosition: String = "inline"
    var items: [ButtonItem] = []
    /// Only enabled while this condition holds (see ControlCondition). Empty = always.
    var enabledIf: String = ""
    /// Only shown while this condition holds. Empty = always.
    var visibleIf: String = ""

    /// Name used by vieworder to place the row
    var layoutName: String {
        if !name.isEmpty { return name }
        if let first = items.first {
            if !first.name.isEmpty { return first.name }
            return first.label
        }
        return title
    }
}

struct ListItems: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var subTitle: String = ""
    var icon: String = ""
    var sfSymbol: String = ""
    var sfColour: String = ""
    var sfPicker: Bool = false
    var iconAlpha: CGFloat = 1
    var statusText: String = ""
    var statusIcon: String = ""
    var progress: CGFloat = 0
    var action: String = ""
    var selected: Bool = false

    // `id` is intentionally excluded so the encoded shape is unchanged
    private enum CodingKeys: String, CodingKey {
        case title, subTitle, icon, sfSymbol, sfColour, sfPicker
        case iconAlpha, statusText, statusIcon, progress, action, selected
    }

    var dictionary: [String: Any] {
            return ["title": title,
                    "subtitle": subTitle,
                    "icon": icon,
                    "statustext": statusText,
                    "status": statusIcon,
                    "progress": progress,
                    "action": action]
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

