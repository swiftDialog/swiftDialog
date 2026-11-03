//
//  ButtonHandling.swift
//  dialog
//
//  Click handling and state updates for page buttons (--button / "button").
//  Actions are "in the blind": swiftDialog starts them, records the exit code and gets out of the
//  way. It's up to the admin to make sure they do something sensible.
//

import Foundation
import AppKit

/// Content for a message sheet opened by a button's `sheet` action
struct MessageSheetContent: Identifiable {
    let id = UUID()
    var text: String
    var image: String = ""
    var buttonText: String = ""
}

extension DialogUpdatableContent {

    /// Apply a change to a button wherever its state lives (the observed copy the views read and the
    /// global copy used for output). Found by id so a late completion after a page change is ignored.
    func updateButton(id: UUID, _ change: (inout ButtonItem) -> Void) {
        for rowIndex in observedUserInputState.buttonRows.indices {
            if let itemIndex = observedUserInputState.buttonRows[rowIndex].items.firstIndex(where: { $0.id == id }) {
                change(&observedUserInputState.buttonRows[rowIndex].items[itemIndex])
            }
        }
        for rowIndex in userInputState.buttonRows.indices {
            if let itemIndex = userInputState.buttonRows[rowIndex].items.firstIndex(where: { $0.id == id }) {
                change(&userInputState.buttonRows[rowIndex].items[itemIndex])
            }
        }
    }

    func setButtonSelection(rowID: UUID, value: String) {
        if let index = observedUserInputState.buttonRows.firstIndex(where: { $0.id == rowID }) {
            observedUserInputState.buttonRows[index].selectedValue = value
        }
        if let index = userInputState.buttonRows.firstIndex(where: { $0.id == rowID }) {
            userInputState.buttonRows[index].selectedValue = value
        }
    }

    /// Name a button is reported under in the output
    func buttonKey(row: ButtonRow, item: ButtonItem) -> String {
        if !item.name.isEmpty { return item.name }
        if !row.name.isEmpty { return row.name }
        return item.label
    }

    func clickButton(rowID: UUID, itemID: UUID) {
        guard let row = observedUserInputState.buttonRows.first(where: { $0.id == rowID }),
              let button = row.items.first(where: { $0.id == itemID }) else { return }
        // Disabled buttons, and buttons whose command is still running, ignore clicks
        guard button.type == "action", !button.disabled, !button.isRunning else { return }

        if !button.confirm.isEmpty && !confirmButtonAction(button.confirm) { return }

        if row.selectable {
            setButtonSelection(rowID: rowID, value: button.value)
        }
        updateButton(id: itemID) { $0.clicked = true }
        let key = buttonKey(row: row, item: button)

        if !button.shell.isEmpty {
            updateButton(id: itemID) { $0.isRunning = true; $0.showSpinner = false; $0.lastExitCode = nil }
            // Only show a spinner if the action is still going after 500ms, so quick ones never flicker
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.updateButton(id: itemID) { if $0.isRunning { $0.showSpinner = true } }
            }
            ButtonActionRunner.shared.run(button.shell, label: key) { [weak self] code in
                self?.updateButton(id: itemID) { $0.isRunning = false; $0.showSpinner = false; $0.lastExitCode = code }
            }
        } else if !button.url.isEmpty {
            let code = openButtonURL(button.url)
            updateButton(id: itemID) { $0.lastExitCode = code }
        } else if !button.sheet.isEmpty {
            let text = button.sheet.lowercased().hasSuffix(".md")
                ? processTextString(getMarkdown(mdFilePath: button.sheet), tags: appvars.systemInfo)
                : button.sheet
            messageSheet = MessageSheetContent(text: text, image: button.sheetImage, buttonText: button.sheetButtonText)
            updateButton(id: itemID) { $0.lastExitCode = 0 }
        } else {
            writeLog("Button '\(key)' has no url, shell or sheet action", logLevel: .error)
        }
    }

    private func confirmButtonAction(_ message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK".localized)
        alert.addButton(withTitle: "Cancel".localized)
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Show the "actions still running" sheet and return true if dismissal should be blocked.
    func blockDismissalWhileButtonActionsRun() -> Bool {
        guard ButtonActionRunner.shared.hasRunning else { return false }
        writeLog("Dismissal blocked: button actions are still running")
        sheetErrorMessage = "One or more button actions are still running.\nPlease wait for them to finish.".localized
        showSheet = true
        return true
    }
}

// MARK: - Output, collect and restore

/// What a button reports in the final output: whether it was clicked and the exit code of its
/// last run, a selected value, or a chosen colour. `value` is shaped for `--json`; `lines` for plain text.
struct ButtonOutputEntry {
    let key: String
    let value: Any
    let lines: [String]
}

func buttonOutputEntries(_ rows: [ButtonRow]) -> [ButtonOutputEntry] {
    var entries: [ButtonOutputEntry] = []

    func state(_ item: ButtonItem) -> [String: Any] {
        var dictionary: [String: Any] = ["clicked": item.clicked]
        if let code = item.lastExitCode { dictionary["exitcode"] = Int(code) }
        return dictionary
    }

    for row in rows {
        if row.selectable {
            let key = row.name.isEmpty ? row.layoutName : row.name
            guard !key.isEmpty else { continue }
            let selected = row.items.first { $0.value == row.selectedValue && !row.selectedValue.isEmpty }
            var dictionary: [String: Any] = ["selectedValue": row.selectedValue, "clicked": selected?.clicked ?? false]
            var lines = ["\"\(key)\" : \"\(row.selectedValue)\""]
            if let code = selected?.lastExitCode {
                dictionary["exitcode"] = Int(code)
                lines.append("\"\(key)\" exitcode : \"\(code)\"")
            }
            entries.append(ButtonOutputEntry(key: key, value: dictionary, lines: lines))
            continue
        }
        for item in row.items {
            let key = !item.name.isEmpty ? item.name : (!row.name.isEmpty ? row.name : item.label)
            guard !key.isEmpty else { continue }
            switch item.type {
            case "colour":
                entries.append(ButtonOutputEntry(key: key, value: item.value, lines: ["\"\(key)\" : \"\(item.value)\""]))
            case "info":
                continue
            default:
                var lines = ["\"\(key)\" : \"\(item.clicked ? "clicked" : "not clicked")\""]
                if let code = item.lastExitCode { lines.append("\"\(key)\" exitcode : \"\(code)\"") }
                entries.append(ButtonOutputEntry(key: key, value: state(item), lines: lines))
            }
        }
    }
    return entries
}

extension DialogUpdatableContent {

    /// Button state for cards: keyed like the output so it can be restored when a page is revisited.
    func collectButtonInput() -> [String: Any] {
        var input: [String: Any] = [:]
        for entry in buttonOutputEntries(userInputState.buttonRows) {
            input[entry.key] = entry.value
        }
        return input
    }

    /// Restore selections, colours and click state when a page is revisited.
    func restoreButtonInput(from stored: [String: Any]) {
        for rowIndex in userInputState.buttonRows.indices {
            let row = userInputState.buttonRows[rowIndex]
            if row.selectable {
                let key = row.name.isEmpty ? row.layoutName : row.name
                if let dictionary = stored[key] as? [String: Any], let selected = dictionary["selectedValue"] as? String {
                    userInputState.buttonRows[rowIndex].selectedValue = selected
                }
                continue
            }
            for itemIndex in row.items.indices {
                let item = row.items[itemIndex]
                let key = !item.name.isEmpty ? item.name : (!row.name.isEmpty ? row.name : item.label)
                if item.type == "colour", let hex = stored[key] as? String {
                    userInputState.buttonRows[rowIndex].items[itemIndex].value = hex
                } else if item.type == "action", let dictionary = stored[key] as? [String: Any] {
                    userInputState.buttonRows[rowIndex].items[itemIndex].clicked = dictionary["clicked"] as? Bool ?? false
                    if let code = dictionary["exitcode"] as? Int {
                        userInputState.buttonRows[rowIndex].items[itemIndex].lastExitCode = Int32(code)
                    }
                }
            }
        }
    }
}

// MARK: - Sliders and steppers

/// A slider/stepper in the final output: plain text line and the `--json` value (a number).
struct NumberOutputEntry {
    let key: String
    let value: Any
    let line: String
}

func numberOutputEntries(_ inputs: [NumberInput]) -> [NumberOutputEntry] {
    inputs.compactMap { input in
        guard !input.key.isEmpty else { return nil }
        let value: Any = input.decimals == 0 ? Int(input.value.rounded()) as Any : (Double(input.displayValue) ?? input.value) as Any
        return NumberOutputEntry(key: input.key, value: value, line: "\"\(input.key)\" : \"\(input.displayValue)\"")
    }
}

extension DialogUpdatableContent {

    /// Set a slider/stepper value (kept inside its range) in both the observed and global copy.
    func setNumberValue(id: UUID, _ newValue: Double, snapToStep: Bool = false) {
        func apply(_ inputs: inout [NumberInput]) {
            guard let index = inputs.firstIndex(where: { $0.id == id }) else { return }
            inputs[index].value = inputs[index].constrained(newValue, snapToStep: snapToStep)
        }
        apply(&observedUserInputState.numberInputs)
        apply(&userInputState.numberInputs)
    }

    /// Slider/stepper values for cards, as text so plain and --json output stay consistent.
    func collectNumberInput() -> [String: Any] {
        var input: [String: Any] = [:]
        for number in userInputState.numberInputs where !number.key.isEmpty {
            input[number.key] = number.displayValue
        }
        return input
    }

    func restoreNumberInput(from stored: [String: Any]) {
        for index in userInputState.numberInputs.indices {
            let key = userInputState.numberInputs[index].key
            if let text = stored[key] as? String, let value = Double(text) {
                let number = userInputState.numberInputs[index]
                userInputState.numberInputs[index].value = number.constrained(value)
            }
        }
    }
}

// MARK: - Control dependencies

extension DialogUpdatableContent {
    /// Current value of every input, read from the published copies so views refresh when one changes.
    func currentControlValues() -> [String: String] {
        controlValues(textFields: textFieldArray, state: observedUserInputState)
    }
}

extension DialogUpdatableContent {
    /// Put controls that are disabled or hidden by a condition back to their defaults, so they
    /// neither keep nor report a value set while they were available. Runs whenever an input changes;
    /// a reset can make another control inactive, which the resulting change then picks up.
    func resetInactiveControls() {
        let resets = inactiveControlResets(textFields: textFieldArray, state: observedUserInputState, defaults: controlDefaults)
        guard !resets.isEmpty else { return }

        for (index, value) in resets.textFields {
            for isObserved in [true, false] {
                if isObserved {
                    guard textFieldArray.indices.contains(index) else { continue }
                    textFieldArray[index].value = value
                    textFieldArray[index].validationValue = ""
                } else {
                    guard userInputState.textFields.indices.contains(index) else { continue }
                    userInputState.textFields[index].value = value
                    userInputState.textFields[index].validationValue = ""
                }
            }
        }
        for (index, checked) in resets.checkboxes {
            if observedUserInputState.checkBoxes.indices.contains(index) { observedUserInputState.checkBoxes[index].checked = checked }
            if userInputState.checkBoxes.indices.contains(index) { userInputState.checkBoxes[index].checked = checked }
        }
        for (index, value) in resets.selects {
            if observedUserInputState.dropdownItems.indices.contains(index) { observedUserInputState.dropdownItems[index].selectedValue = value }
            if userInputState.dropdownItems.indices.contains(index) { userInputState.dropdownItems[index].selectedValue = value }
        }
        for (index, value) in resets.numbers {
            if observedUserInputState.numberInputs.indices.contains(index) { setNumberValue(id: observedUserInputState.numberInputs[index].id, value) }
        }
        for (index, value) in resets.buttonRowSelections {
            if observedUserInputState.buttonRows.indices.contains(index) { setButtonSelection(rowID: observedUserInputState.buttonRows[index].id, value: value) }
        }
        for (position, value) in resets.colours {
            let row = position[0], item = position[1]
            if observedUserInputState.buttonRows.indices.contains(row), observedUserInputState.buttonRows[row].items.indices.contains(item) {
                updateButton(id: observedUserInputState.buttonRows[row].items[item].id) { $0.value = value }
            }
        }
        writeLog("Reset inactive controls to their defaults", logLevel: .debug)
    }
}
