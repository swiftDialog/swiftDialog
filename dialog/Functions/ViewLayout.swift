//
//  ViewLayout.swift
//  dialog
//
//  `--vieworder` has two jobs. The original one orders whole input *types*
//  (e.g. "textfield,checkbox"). The extended one places individual inputs by name and
//  groups them. This file decides which job a value is for, parses the extended form
//  (CSV tokens or a JSON object) and resolves names to input indices.
//
//  Everything here is pure (no UI, no globals) so it can be unit tested.
//

import Foundation
import SwiftyJSON

/// A group as written by the author: a title and an ordered list of tokens. A token is either a
/// reserved type name ("textfield", "checkbox", ...) or the name of an individual input.
struct ViewLayoutGroupSpec: Equatable {
    var title: String?
    var description: String?
    var footer: String?
    var items: [String]
}

struct ViewLayoutSpec: Equatable {
    var groups: [ViewLayoutGroupSpec]
}

/// What a `vieworder` value means.
enum ViewOrderKind: Equatable {
    /// Original behaviour: order whole input types. Handled by `reorderViewArray`, unchanged.
    case typeOrder
    /// Extended behaviour: place individual inputs and/or groups.
    case layout(ViewLayoutSpec)
}

/// An input placed in a group, resolved to its index in the matching `userInputState` array.
enum ViewLayoutRow: Equatable {
    case textField(Int)
    case checkbox(Int)
    case radio(Int)
    case dropdown(Int)
    case button(Int)
    case slider(Int)
    case stepper(Int)
    /// Self-contained blocks that aren't per-item rows: textfile, webcontent, listitem
    case block(ViewType)
}

struct ResolvedViewLayoutGroup: Equatable, Identifiable {
    var id: Int
    var title: String?
    var description: String?
    var footer: String?
    var rows: [ViewLayoutRow]
}

/// Names of the inputs currently defined, in `userInputState` order.
struct ViewLayoutInputs {
    var textFields: [String] = []
    var checkboxes: [String] = []
    /// Select items; radio style items are drawn by `RadioView`, the rest by `DropdownView`
    var selects: [(name: String, isRadio: Bool)] = []
    /// Button rows, by their layout name
    var buttons: [String] = []
    /// Sliders and steppers share one array; `kind` is "slider" or "stepper"
    var numbers: [(name: String, kind: String)] = []
    /// Which self-contained blocks have content
    var blocks: Set<ViewType> = []

    var allNames: Set<String> {
        Set(textFields + checkboxes + selects.map { $0.name } + buttons + numbers.map { $0.name }).subtracting([""])
    }
}

enum ViewLayoutParser {

    /// Reserved words in the input ordering path: the seven input types.
    static let reservedWords: Set<String> = [
        ViewType.textfile, .webcontent, .listitem, .checkbox, .textfield, .radiobutton, .dropdown, .button, .slider, .stepper
    ].reduce(into: Set<String>()) { $0.insert($1.rawValue) }.union(["buttons"])

    /// Default order types are appended in when inputs aren't placed anywhere.
    static let defaultTypeOrder: [ViewType] = [
        .textfile, .webcontent, .listitem, .checkbox, .textfield, .radiobutton, .dropdown, .button, .slider, .stepper
    ]

    /// The type a reserved word stands for ("buttons" is a synonym of "button")
    static func viewType(for word: String) -> ViewType? {
        word == "buttons" ? .button : ViewType(rawValue: word)
    }

    // MARK: - Classify and parse

    /// Decide what a `--vieworder` value means.
    /// - A JSON object (with `groups`) is the extended form.
    /// - A CSV value is the extended form only if it has a `[Title]` token or a token naming an
    ///   input. Anything else (including unknown words) is the original type ordering, so every
    ///   value that works today keeps working exactly as before.
    static func classify(_ value: String, inputNames: Set<String>, log: (String) -> Void = { _ in }) -> ViewOrderKind {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("{") {
            let parsed = JSON(parseJSON: trimmed)
            if parsed.type == .dictionary {
                if let spec = parseJSON(parsed, log: log) { return .layout(spec) }
                return .typeOrder
            }
            log("vieworder looks like JSON but could not be parsed - treating it as a comma separated list")
        }

        let tokens = csvTokens(trimmed)
        let usesGroups = tokens.contains { groupTitle(in: $0) != nil }
        let namesInput = tokens.contains { !reservedWords.contains($0) && inputNames.contains($0) }
        guard usesGroups || namesInput else { return .typeOrder }
        return .layout(parseCSV(tokens))
    }

    /// Build a layout from a JSON object already parsed from the config file.
    static func parseJSON(_ json: JSON, log: (String) -> Void = { _ in }) -> ViewLayoutSpec? {
        guard json["groups"].type == .array else {
            log("vieworder object has no \"groups\" array - ignoring it")
            return nil
        }
        var groups: [ViewLayoutGroupSpec] = []
        for group in json["groups"].arrayValue {
            groups.append(ViewLayoutGroupSpec(
                title: nonEmpty(group["title"].string),
                description: nonEmpty(group["description"].string),
                footer: nonEmpty(group["footer"].string),
                items: group["items"].arrayValue.compactMap { nonEmpty($0.string) }))
        }
        return ViewLayoutSpec(groups: groups)
    }

    static func csvTokens(_ value: String) -> [String] {
        value.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// "[Title]" -> "Title", "[]" -> "" (an untitled group), anything else -> nil
    static func groupTitle(in token: String) -> String? {
        guard token.hasPrefix("["), token.hasSuffix("]") else { return nil }
        return String(token.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
    }

    static func parseCSV(_ tokens: [String]) -> ViewLayoutSpec {
        var groups: [ViewLayoutGroupSpec] = []
        for token in tokens {
            if let title = groupTitle(in: token) {
                groups.append(ViewLayoutGroupSpec(title: title.isEmpty ? nil : title, items: []))
            } else {
                if groups.isEmpty { groups.append(ViewLayoutGroupSpec(title: nil, items: [])) }
                groups[groups.count - 1].items.append(token)
            }
        }
        return ViewLayoutSpec(groups: groups)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        return value
    }

    // MARK: - Resolve

    /// Resolve a layout against the inputs that exist.
    ///
    /// - A reserved word is always "the inputs of that type that aren't placed individually",
    ///   even if an input happens to share its name (that input is still shown, in its type).
    /// - Any other token is an input name. Unknown names are skipped, an input placed twice keeps
    ///   its first placement.
    /// - Inputs not placed anywhere are appended in a final untitled group in default type order,
    ///   so nothing disappears.
    static func resolve(_ spec: ViewLayoutSpec,
                        inputs: ViewLayoutInputs,
                        log: (String) -> Void = { _ in }) -> [ResolvedViewLayoutGroup] {

        // Individually placeable inputs by name. First match wins in this order.
        var byName: [String: ViewLayoutRow] = [:]
        for (index, name) in inputs.textFields.enumerated() where !name.isEmpty && byName[name] == nil {
            byName[name] = .textField(index)
        }
        for (index, name) in inputs.checkboxes.enumerated() where !name.isEmpty && byName[name] == nil {
            byName[name] = .checkbox(index)
        }
        for (index, item) in inputs.selects.enumerated() where !item.name.isEmpty && byName[item.name] == nil {
            byName[item.name] = item.isRadio ? .radio(index) : .dropdown(index)
        }
        for (index, name) in inputs.buttons.enumerated() where !name.isEmpty && byName[name] == nil {
            byName[name] = .button(index)
        }
        for (index, item) in inputs.numbers.enumerated() where !item.name.isEmpty && byName[item.name] == nil {
            byName[item.name] = item.kind == "stepper" ? .stepper(index) : .slider(index)
        }

        // Warn about inputs that can't be placed individually because their name is a reserved word
        for name in inputs.allNames.intersection(reservedWords) {
            log("Input named '\(name)' uses a reserved word, so it can't be placed on its own in vieworder - it is shown with its type. Use a different name to place it individually")
        }

        // Pass 1: which inputs are placed individually (first placement wins)
        var placedIndividually: [ViewLayoutRow] = []
        for group in spec.groups {
            for token in group.items where !reservedWords.contains(token) {
                guard let row = byName[token] else { continue }
                if !placedIndividually.contains(row) { placedIndividually.append(row) }
            }
        }

        var emitted: [ViewLayoutRow] = []
        func emit(_ row: ViewLayoutRow, into rows: inout [ViewLayoutRow]) {
            guard !emitted.contains(row) else { return }
            emitted.append(row)
            rows.append(row)
        }

        /// Remaining (not individually placed) rows of a type, in input order
        func rows(ofType type: ViewType) -> [ViewLayoutRow] {
            let candidates: [ViewLayoutRow]
            switch type {
            case .textfield: candidates = inputs.textFields.indices.map { .textField($0) }
            case .checkbox:  candidates = inputs.checkboxes.indices.map { .checkbox($0) }
            case .radiobutton: candidates = inputs.selects.enumerated().filter { $0.element.isRadio }.map { .radio($0.offset) }
            case .dropdown:  candidates = inputs.selects.enumerated().filter { !$0.element.isRadio }.map { .dropdown($0.offset) }
            case .button:    candidates = inputs.buttons.indices.map { .button($0) }
            case .slider:    candidates = inputs.numbers.enumerated().filter { $0.element.kind == "slider" }.map { .slider($0.offset) }
            case .stepper:   candidates = inputs.numbers.enumerated().filter { $0.element.kind == "stepper" }.map { .stepper($0.offset) }
            case .textfile, .webcontent, .listitem: candidates = inputs.blocks.contains(type) ? [.block(type)] : []
            }
            return candidates.filter { !placedIndividually.contains($0) }
        }

        // Pass 2: build the groups
        var result: [ResolvedViewLayoutGroup] = []
        for group in spec.groups {
            var groupRows: [ViewLayoutRow] = []
            for token in group.items {
                if reservedWords.contains(token), let type = viewType(for: token) {
                    rows(ofType: type).forEach { emit($0, into: &groupRows) }
                } else if let row = byName[token] {
                    if emitted.contains(row) {
                        log("vieworder places '\(token)' more than once - keeping the first")
                    } else {
                        emit(row, into: &groupRows)
                    }
                } else {
                    log("vieworder refers to '\(token)' which is not an input name or type - skipping it")
                }
            }
            result.append(ResolvedViewLayoutGroup(id: result.count, title: group.title,
                                                  description: group.description, footer: group.footer,
                                                  rows: groupRows))
        }

        // Anything not placed goes in a final untitled group
        var leftover: [ViewLayoutRow] = []
        for type in defaultTypeOrder { rows(ofType: type).forEach { emit($0, into: &leftover) } }
        if !leftover.isEmpty {
            log("vieworder leaves \(leftover.count) input(s) unplaced - adding them at the end")
            result.append(ResolvedViewLayoutGroup(id: result.count, title: nil, description: nil, footer: nil, rows: leftover))
        }

        // Empty groups draw nothing
        return result.filter { !$0.rows.isEmpty }
    }
}
