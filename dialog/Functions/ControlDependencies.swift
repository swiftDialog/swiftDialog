//
//  ControlDependencies.swift
//  dialog
//
//  `enabledif` / `visibleif` on an input: the control is only enabled (or shown) while a condition
//  about other inputs holds. Everything here is pure so it can be unit tested.
//
//  Conditions (names are the input names used in the output):
//
//      useproxy                   a checkbox is on / a field has text / a select has a choice / a number isn't 0
//      !useproxy                  the opposite
//      channel=Phone              equals (not case sensitive; numbers compare as numbers)
//      channel!=Email             does not equal
//      volume>50   volume<=10     numeric comparison (>, <, >=, <=)
//      a && b      a || b         both / either. && binds tighter than ||. No brackets.
//
//  A condition that can't be understood never locks anything: unknown names read as empty (and are
//  logged), and the control stays as it would be without a condition if there is nothing to compare.
//

import Foundation

enum ControlCondition {

    /// Comparison operators, longest first so ">=" isn't read as ">" followed by "="
    private static let operators = ["!=", ">=", "<=", "==", "=", ">", "<"]

    /// Evaluate a condition against the current values (see `controlValues`).
    /// An empty condition is always true.
    static func evaluate(_ expression: String, values: [String: String], log: (String) -> Void = { _ in }) -> Bool {
        let trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        return trimmed.components(separatedBy: "||").contains { orPart in
            orPart.components(separatedBy: "&&").allSatisfy { term in
                evaluateTerm(term.trimmingCharacters(in: .whitespaces), values: values, log: log)
            }
        }
    }

    /// True when a control with these conditions is both shown and enabled (used to skip validation
    /// of required inputs the user can't reach).
    static func isActive(enabledIf: String, visibleIf: String, values: [String: String]) -> Bool {
        evaluate(visibleIf, values: values) && evaluate(enabledIf, values: values)
    }

    // MARK: - Terms

    private static func evaluateTerm(_ term: String, values: [String: String], log: (String) -> Void) -> Bool {
        guard !term.isEmpty else { return true }

        if let (name, op, expected) = splitComparison(term) {
            guard let actual = value(for: name, in: values, log: log) else { return false }
            return compare(actual, op, expected, log: log)
        }

        // A bare name, optionally negated
        let negated = term.hasPrefix("!")
        let name = negated ? String(term.dropFirst()).trimmingCharacters(in: .whitespaces) : term
        let truth = isTruthy(value(for: name, in: values, log: log) ?? "")
        return negated ? !truth : truth
    }

    /// "name>=5" -> ("name", ">=", "5"). Nil if the term has no operator.
    private static func splitComparison(_ term: String) -> (String, String, String)? {
        var best: (range: Range<String.Index>, op: String)?
        for op in operators {
            guard let range = term.range(of: op) else { continue }
            // earliest wins; at the same position the longer operator (listed first) wins
            if best == nil || range.lowerBound < best!.range.lowerBound {
                best = (range, op)
            }
        }
        guard let found = best else { return nil }
        let name = term[..<found.range.lowerBound].trimmingCharacters(in: .whitespaces)
        var expected = term[found.range.upperBound...].trimmingCharacters(in: .whitespaces)
        if expected.count >= 2, let first = expected.first, let last = expected.last,
           (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            expected = String(expected.dropFirst().dropLast())
        }
        guard !name.isEmpty else { return nil }
        return (name, found.op, expected)
    }

    private static func value(for name: String, in values: [String: String], log: (String) -> Void) -> String? {
        if let found = values[name] { return found }
        log("Condition refers to '\(name)' which is not an input name - treating it as empty")
        return ""
    }

    private static func compare(_ actual: String, _ op: String, _ expected: String, log: (String) -> Void) -> Bool {
        let a = actual.trimmingCharacters(in: .whitespaces)
        let e = expected.trimmingCharacters(in: .whitespaces)

        if let x = Double(a), let y = Double(e) {
            switch op {
            case "=", "==": return x == y
            case "!=": return x != y
            case ">": return x > y
            case "<": return x < y
            case ">=": return x >= y
            case "<=": return x <= y
            default: return false
            }
        }
        switch op {
        case "=", "==": return a.caseInsensitiveCompare(e) == .orderedSame
        case "!=": return a.caseInsensitiveCompare(e) != .orderedSame
        default:
            log("Condition '\(op)' needs numbers but got '\(a)' and '\(e)' - treating it as false")
            return false
        }
    }

    /// Empty, "false", "no", "off", "0" (or any number equal to 0) are false; everything else is true
    static func isTruthy(_ value: String) -> Bool {
        let text = value.trimmingCharacters(in: .whitespaces).lowercased()
        if ["", "false", "no", "off"].contains(text) { return false }
        if let number = Double(text) { return number != 0 }
        return true
    }
}

/// The current value of every input, by output name, as text. Checkboxes are "true"/"false", selects
/// their chosen option, numbers their value, selectable button rows their selection and colour
/// wells their hex colour.
func controlValues(textFields: [TextFieldState], state: UserInputState) -> [String: String] {
    var values: [String: String] = [:]
    for field in textFields {
        let key = field.name.isEmpty ? field.title : field.name
        if !key.isEmpty { values[key] = field.value }
    }
    for box in state.checkBoxes {
        let key = box.name.isEmpty ? box.label : box.name
        if !key.isEmpty { values[key] = box.checked ? "true" : "false" }
    }
    for item in state.dropdownItems {
        let key = item.name.isEmpty ? item.title : item.name
        if !key.isEmpty { values[key] = item.selectedValue }
    }
    for number in state.numberInputs where !number.key.isEmpty {
        values[number.key] = number.displayValue
    }
    for row in state.buttonRows {
        if row.selectable {
            let key = row.name.isEmpty ? row.layoutName : row.name
            if !key.isEmpty { values[key] = row.selectedValue }
        }
        for item in row.items where item.type == "colour" {
            let key = !item.name.isEmpty ? item.name : (!row.name.isEmpty ? row.name : item.label)
            if !key.isEmpty { values[key] = item.value }
        }
    }
    return values
}

// MARK: - Resetting inactive controls

/// Values that inactive controls (disabled by `enabledif` or hidden by `visibleif`) should be put
/// back to, keyed by index into the matching array. A control the user can't reach shouldn't keep
/// (or report) a value they set before it became unavailable.
struct ControlResets: Equatable {
    var textFields: [Int: String] = [:]
    var checkboxes: [Int: Bool] = [:]
    var selects: [Int: String] = [:]
    var numbers: [Int: Double] = [:]
    var buttonRowSelections: [Int: String] = [:]
    /// Colour wells: (row, item) -> hex
    var colours: [[Int]: String] = [:]

    var isEmpty: Bool {
        textFields.isEmpty && checkboxes.isEmpty && selects.isEmpty && numbers.isEmpty
            && buttonRowSelections.isEmpty && colours.isEmpty
    }
}

/// Work out which inactive controls differ from their defaults.
///
/// - Parameter defaults: values as loaded (see `controlValues`), used for text fields, checkboxes,
///   sliders / steppers and colour wells. Selects use their configured default (a radio without one
///   uses its first option, as it does when shown).
/// - Date / time fields are left alone: they set their own value when shown.
func inactiveControlResets(textFields: [TextFieldState], state: UserInputState, defaults: [String: String]) -> ControlResets {
    var resets = ControlResets()
    let values = controlValues(textFields: textFields, state: state)
    func inactive(_ enabledIf: String, _ visibleIf: String) -> Bool {
        (!enabledIf.isEmpty || !visibleIf.isEmpty)
            && !ControlCondition.isActive(enabledIf: enabledIf, visibleIf: visibleIf, values: values)
    }

    for (index, field) in textFields.enumerated() where !field.isDatePicker && inactive(field.enabledIf, field.visibleIf) {
        let key = field.name.isEmpty ? field.title : field.name
        let target = defaults[key] ?? ""
        if field.value != target || !field.validationValue.isEmpty { resets.textFields[index] = target }
    }
    for (index, box) in state.checkBoxes.enumerated() where inactive(box.enabledIf, box.visibleIf) {
        let key = box.name.isEmpty ? box.label : box.name
        let target = (defaults[key] ?? "false") == "true"
        if box.checked != target { resets.checkboxes[index] = target }
    }
    for (index, item) in state.dropdownItems.enumerated() where inactive(item.enabledIf, item.visibleIf) {
        let target = item.defaultValue.isEmpty && item.style == "radio" ? (item.values.first ?? "") : item.defaultValue
        if item.selectedValue != target { resets.selects[index] = target }
    }
    for (index, number) in state.numberInputs.enumerated() where inactive(number.enabledIf, number.visibleIf) {
        let target = number.constrained(Double(defaults[number.key] ?? "") ?? number.minValue)
        if number.value != target { resets.numbers[index] = target }
    }
    for (rowIndex, row) in state.buttonRows.enumerated() {
        let rowInactive = inactive(row.enabledIf, row.visibleIf)
        if row.selectable && rowInactive && row.selectedValue != row.defaultValue {
            resets.buttonRowSelections[rowIndex] = row.defaultValue
        }
        for (itemIndex, item) in row.items.enumerated() where item.type == "colour" && (rowInactive || inactive(item.enabledIf, "")) {
            let key = !item.name.isEmpty ? item.name : (!row.name.isEmpty ? row.name : item.label)
            if let target = defaults[key], item.value != target { resets.colours[[rowIndex, itemIndex]] = target }
        }
    }
    return resets
}
