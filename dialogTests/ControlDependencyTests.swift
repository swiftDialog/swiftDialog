//
//  ControlDependencyTests.swift
//  dialogTests
//
//  enabledif / visibleif conditions: the condition language, how current values are collected from
//  the inputs, and how conditions are read from config.
//

import Testing
import SwiftyJSON
@testable import Dialog

struct ControlConditionTests {

    private let values: [String: String] = [
        "useproxy": "true", "vpn": "false", "channel": "Phone", "email": "a@b.c", "blank": "",
        "volume": "60", "gain": "0.50", "zero": "0"
    ]

    private func check(_ expression: String) -> Bool {
        ControlCondition.evaluate(expression, values: values)
    }

    @Test func emptyConditionIsTrue() {
        #expect(check(""))
        #expect(check("   "))
    }

    @Test func bareNameIsTruthiness() {
        #expect(check("useproxy"))
        #expect(!check("vpn"))
        #expect(check("email"))
        #expect(!check("blank"))
        #expect(check("volume"))
        #expect(!check("zero"))
    }

    @Test func negation() {
        #expect(!check("!useproxy"))
        #expect(check("!vpn"))
        #expect(check("! vpn"))
    }

    @Test func equalsIgnoresCase() {
        #expect(check("channel=Phone"))
        #expect(check("channel=phone"))
        #expect(check("channel==PHONE"))
        #expect(!check("channel=Email"))
        #expect(check("channel!=Email"))
        #expect(!check("channel!=Phone"))
    }

    @Test func quotedValues() {
        #expect(check("channel='Phone'"))
        #expect(check("channel=\"Phone\""))
    }

    @Test func numbersCompareAsNumbers() {
        #expect(check("volume>50"))
        #expect(!check("volume>60"))
        #expect(check("volume>=60"))
        #expect(check("volume<=60"))
        #expect(check("volume<100"))
        #expect(check("volume=60.0"))
        #expect(check("gain=0.5"))
        #expect(check("gain<1"))
    }

    @Test func orderingOnTextIsFalse() {
        #expect(!check("channel>Email"))
    }

    @Test func andRequiresAll() {
        #expect(check("useproxy && email"))
        #expect(!check("useproxy && vpn"))
    }

    @Test func orRequiresAny() {
        #expect(check("vpn || useproxy"))
        #expect(!check("vpn || blank"))
    }

    @Test func andBindsTighterThanOr() {
        // vpn && blank is false, so the result is decided by useproxy
        #expect(check("vpn && blank || useproxy"))
        #expect(!check("vpn && blank || zero"))
    }

    @Test func unknownNamesReadAsEmptyAndAreLogged() {
        var logs: [String] = []
        #expect(!ControlCondition.evaluate("nothere", values: values, log: { logs.append($0) }))
        #expect(ControlCondition.evaluate("!nothere", values: values))
        #expect(logs.contains { $0.contains("'nothere'") })
    }

    @Test func truthiness() {
        for falsy in ["", "false", "FALSE", "no", "off", "0", "0.00", " "] {
            #expect(!ControlCondition.isTruthy(falsy), "\(falsy)")
        }
        for truthy in ["true", "yes", "on", "1", "-1", "Phone"] {
            #expect(ControlCondition.isTruthy(truthy), "\(truthy)")
        }
    }

    @Test func isActiveNeedsVisibleAndEnabled() {
        #expect(ControlCondition.isActive(enabledIf: "", visibleIf: "", values: values))
        #expect(ControlCondition.isActive(enabledIf: "useproxy", visibleIf: "email", values: values))
        #expect(!ControlCondition.isActive(enabledIf: "vpn", visibleIf: "", values: values))
        #expect(!ControlCondition.isActive(enabledIf: "", visibleIf: "vpn", values: values))
    }
}

struct ControlValuesTests {

    @Test func collectsEveryKindOfInput() {
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "Use proxy", name: "useproxy", checked: true)]
        state.dropdownItems = [DropDownItems(title: "Channel", name: "channel", values: ["Email", "Phone"], defaultValue: "", selectedValue: "Phone")]
        var number = NumberInput(); number.name = "volume"; number.value = 40
        state.numberInputs = [number]
        state.buttonRows = [makeButtonRow(from: JSON([
            "name": "accent", "selectable": true, "default": "blue", "items": [["name": "blue", "label": "Blue"]]
        ])), makeButtonRow(from: JSON(["name": "brand", "type": "colour", "value": "#0066FF"]))]
        var field = TextFieldState(title: "Email"); field.name = "email"; field.value = "a@b.c"

        let values = controlValues(textFields: [field], state: state)
        #expect(values["email"] == "a@b.c")
        #expect(values["useproxy"] == "true")
        #expect(values["channel"] == "Phone")
        #expect(values["volume"] == "40")
        #expect(values["accent"] == "blue")
        #expect(values["brand"] == "#0066FF")
    }

    @Test func nameFallsBackToTitleOrLabel() {
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "Notify me")]
        let values = controlValues(textFields: [TextFieldState(title: "Host")], state: state)
        #expect(values["Notify me"] == "false")
        #expect(values["Host"] == "")
    }

    @Test func conditionsSeeLiveValues() {
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "Use proxy", name: "useproxy", checked: false)]
        #expect(!ControlCondition.evaluate("useproxy", values: controlValues(textFields: [], state: state)))
        state.checkBoxes[0].checked = true
        #expect(ControlCondition.evaluate("useproxy", values: controlValues(textFields: [], state: state)))
    }
}

struct ControlDependencyConfigTests {

    @Test func textFieldReadsConditions() {
        let field = makeTextFieldState(from: JSON(["title": "Host", "enabledif": "useproxy", "visibleif": "!vpn"]))
        #expect(field.enabledIf == "useproxy")
        #expect(field.visibleIf == "!vpn")
    }

    @Test func checkboxAndSelectReadConditions() {
        #expect(makeCheckBox(from: JSON(["label": "A", "enabledif": "x"])).enabledIf == "x")
        let select = makeDropDownItem(from: JSON(["title": "S", "values": ["a"], "visibleif": "y"]))
        #expect(select.visibleIf == "y")
    }

    @Test func numberAndButtonReadConditions() {
        let number = makeNumberInput(from: JSON(["title": "V", "enabledif": "mute=false"]), kind: "slider")
        #expect(number.enabledIf == "mute=false")
        let row = makeButtonRow(from: JSON(["name": "r", "enabledif": "a", "visibleif": "b",
                                            "items": [["label": "One", "enabledif": "c"]]]))
        #expect(row.enabledIf == "a")
        #expect(row.visibleIf == "b")
        #expect(row.items[0].enabledIf == "c")
    }

    @Test func conditionsDefaultToEmpty() {
        #expect(makeTextFieldState(from: JSON(["title": "Host"])).enabledIf.isEmpty)
        #expect(makeCheckBox(from: JSON(["label": "A"])).visibleIf.isEmpty)
        #expect(makeButtonRow(from: JSON(["label": "One"])).enabledIf.isEmpty)
    }

    @Test func conditionalRequiredFieldsDoNotForceAPageIncomplete() {
        // A required field that may be disabled shouldn't make an unvisited page demand a visit
        let conditional = JSON(["textfield": [["title": "Host", "required": true, "enabledif": "useproxy"]]])
        let plain = JSON(["textfield": [["title": "Host", "required": true]]])
        #expect(!CardState.hasRequiredFields(conditional))
        #expect(CardState.hasRequiredFields(plain))
    }
}

struct ControlResetTests {

    private func state() -> UserInputState {
        var state = UserInputState()
        state.checkBoxes = [
            CheckBoxes(label: "Auto updates", name: "autoupdates", checked: true),
            CheckBoxes(label: "Restart", name: "restart", checked: false, enabledIf: "autoupdates")
        ]
        return state
    }

    @Test func activeControlsAreLeftAlone() {
        var state = state()
        state.checkBoxes[1].checked = true                       // user turned it on while enabled
        let resets = inactiveControlResets(textFields: [], state: state, defaults: controlValues(textFields: [], state: self.state()))
        #expect(resets.isEmpty)
    }

    @Test func disabledCheckboxGoesBackToItsDefault() {
        let defaults = controlValues(textFields: [], state: state())
        var state = state()
        state.checkBoxes[1].checked = true
        state.checkBoxes[0].checked = false                      // parent turned off
        let resets = inactiveControlResets(textFields: [], state: state, defaults: defaults)
        #expect(resets.checkboxes == [1: false])
    }

    @Test func alreadyAtDefaultNeedsNoReset() {
        let defaults = controlValues(textFields: [], state: state())
        var state = state()
        state.checkBoxes[0].checked = false
        #expect(inactiveControlResets(textFields: [], state: state, defaults: defaults).isEmpty)
    }

    @Test func hiddenControlsResetToo() {
        var field = TextFieldState(title: "Bypass"); field.name = "bypass"; field.value = "*.local"; field.visibleIf = "useproxy"
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "Use proxy", name: "useproxy", checked: false)]
        let defaults = ["bypass": "*.local", "useproxy": "false"]
        field.value = "typed"
        let resets = inactiveControlResets(textFields: [field], state: state, defaults: defaults)
        #expect(resets.textFields == [0: "*.local"])
    }

    @Test func dateFieldsAreNeverReset() {
        var field = TextFieldState(title: "When"); field.name = "when"; field.showDate = true
        field.value = "2026-01-01"; field.enabledIf = "never"
        let resets = inactiveControlResets(textFields: [field], state: UserInputState(), defaults: ["when": ""])
        #expect(resets.textFields.isEmpty)
    }

    @Test func selectGoesBackToItsDefault() {
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "On", name: "on", checked: false)]
        state.dropdownItems = [DropDownItems(title: "Gateway", name: "gateway", values: ["Auto", "Sydney"],
                                             defaultValue: "Auto", selectedValue: "Sydney", enabledIf: "on")]
        #expect(inactiveControlResets(textFields: [], state: state, defaults: [:]).selects == [0: "Auto"])
    }

    @Test func radioWithoutDefaultFallsBackToItsFirstOption() {
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "On", name: "on", checked: false)]
        state.dropdownItems = [DropDownItems(title: "Mode", name: "mode", values: ["A", "B"], defaultValue: "",
                                             selectedValue: "B", style: "radio", enabledIf: "on")]
        #expect(inactiveControlResets(textFields: [], state: state, defaults: [:]).selects == [0: "A"])
    }

    @Test func numbersGoBackToTheirStartingValue() {
        var number = NumberInput(); number.name = "volume"; number.value = 80; number.enabledIf = "on"
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "On", name: "on", checked: false)]
        state.numberInputs = [number]
        let resets = inactiveControlResets(textFields: [], state: state, defaults: ["volume": "30"])
        #expect(resets.numbers == [0: 30])
    }

    @Test func selectableButtonRowAndColourReset() {
        var row = makeButtonRow(from: JSON(["name": "accent", "selectable": true, "default": "blue", "enabledif": "on",
                                            "items": [["value": "blue", "label": "Blue"], ["value": "red", "label": "Red"]]]))
        row.selectedValue = "red"
        var colour = makeButtonRow(from: JSON(["name": "brand", "type": "colour", "value": "#0066FF", "enabledif": "on"]))
        colour.items[0].value = "#FF0000"
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "On", name: "on", checked: false)]
        state.buttonRows = [row, colour]
        let resets = inactiveControlResets(textFields: [], state: state, defaults: ["brand": "#0066FF"])
        #expect(resets.buttonRowSelections == [0: "blue"])
        #expect(resets.colours == [[1, 0]: "#0066FF"])
    }

    @Test func controlsWithoutConditionsAreNeverTouched() {
        var state = UserInputState()
        state.checkBoxes = [CheckBoxes(label: "A", name: "a", checked: true)]
        #expect(inactiveControlResets(textFields: [], state: state, defaults: ["a": "false"]).isEmpty)
    }
}
