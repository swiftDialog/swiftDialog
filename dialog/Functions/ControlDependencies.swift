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
