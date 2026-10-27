//
//  InspectState+FormInputs.swift
//  dialog
//
//  Form input state for guidance content: seeding defaults and the required-field gate.
//

import SwiftUI

extension InspectState {
    // MARK: - Guidance Form Input Management

    /// Resolves a textfield `inherit` spec: plist:path:key, defaults:domain:key, env:NAME,
    /// field:itemId.fieldId.
    @MainActor
    func resolveInheritValue(_ inheritSpec: String, basePath: String?) -> String? {
        resolveFormInheritValue(inheritSpec, basePath: basePath) { itemId, fieldId in
            guidanceFormInputs[itemId]?.textfields[fieldId]
        }
    }

    /// Seeds an item's form state from its guidance content defaults; a no-op once state exists.
    func initializeGuidanceFormState(for itemId: String) {
        if guidanceFormInputs[itemId] != nil {
            return
        }

        // Items first, then preset 5 steps.
        let stepContent = config?.introSteps?.first(where: { $0.id == itemId })
            .flatMap { $0.guidanceContent ?? $0.content }
        guard let guidanceContent = items.first(where: { $0.id == itemId })?.guidanceContent
                ?? stepContent else {
            guidanceFormInputs[itemId] = GuidanceFormInputState()
            writeLog("InspectState: Initialized empty form state for item '\(itemId)' (no guidance content)", logLevel: .debug)
            return
        }

        var newState = GuidanceFormInputState()

        for block in guidanceContent {
            guard let fieldId = block.id else { continue }

            switch block.type {
            case "checkbox":
                if let value = block.value?.lowercased() {
                    let isChecked = value == "true" || value == "yes" || value == "1"
                    newState.checkboxes[fieldId] = isChecked
                    writeLog("InspectState: Set default checkbox '\(fieldId)' = \(isChecked)", logLevel: .debug)
                }

            case "dropdown":
                if let seed = languagePickerSeed(fieldId: fieldId, options: block.options) {
                    newState.dropdowns[fieldId] = seed
                    writeLog("InspectState: Seeded language picker '\(fieldId)' = '\(seed)' from defaultLanguage", logLevel: .debug)
                } else if let value = block.value, !value.isEmpty,
                          let options = block.options, options.contains(value) {
                    newState.dropdowns[fieldId] = value
                    writeLog("InspectState: Set default dropdown '\(fieldId)' = '\(value)'", logLevel: .debug)
                }

            case "radio":
                if let seed = languagePickerSeed(fieldId: fieldId, options: block.options) {
                    newState.radios[fieldId] = seed
                    writeLog("InspectState: Seeded language picker '\(fieldId)' = '\(seed)' from defaultLanguage", logLevel: .debug)
                } else if let value = block.value, !value.isEmpty,
                          let options = block.options, options.contains(value) {
                    newState.radios[fieldId] = value
                    writeLog("InspectState: Set default radio '\(fieldId)' = '\(value)'", logLevel: .debug)
                }

            case "textfield":
                // `inherit` is resolved lazily by the getter.
                if let value = block.value, !value.isEmpty {
                    newState.textfields[fieldId] = value
                    writeLog("InspectState: Set default textfield '\(fieldId)' = '\(value)'", logLevel: .debug)
                }

            case "toggle":
                if let value = block.value?.lowercased() {
                    let isOn = value == "true" || value == "yes" || value == "1"
                    newState.toggles[fieldId] = isOn
                    writeLog("InspectState: Set default toggle '\(fieldId)' = \(isOn)", logLevel: .debug)
                }

            case "slider":
                if let value = block.value, let number = Double(value) {
                    newState.sliders[fieldId] = number
                    writeLog("InspectState: Set default slider '\(fieldId)' = \(number)", logLevel: .debug)
                }

            default:
                continue
            }
        }

        guidanceFormInputs[itemId] = newState
        writeLog("InspectState: Initialized form state for item '\(itemId)' with \(newState.checkboxes.count) checkboxes, \(newState.dropdowns.count) dropdowns, \(newState.radios.count) radios, \(newState.textfields.count) textfields, \(newState.toggles.count) toggles, \(newState.sliders.count) sliders", logLevel: .info)
    }

    /// The language picker's seed: the config's `defaultLanguage` when the block is the
    /// localization picker (its id is the `selectionKey`) and the default is one of its options.
    /// Nil otherwise, and the block's own `value` stands. The seed is what `manualLanguageSelection`
    /// reads, so seeding from the authored `value` would count as a choice nobody made.
    func languagePickerSeed(fieldId: String, options: [String]?) -> String? {
        guard let localization = config?.localization,
              fieldId == (localization.selectionKey ?? "preferredLanguage"),
              let options, let authored = localization.defaultLanguage else { return nil }
        if authored != "auto", options.contains(authored) { return authored }
        // A code ("de", or "auto"'s system code) maps to the options' display names through `languages`.
        guard let key = LocalizationService.defaultLanguageKey(localization) else { return nil }
        return options.contains(key) ? key : nil
    }

    /// Whether every required block of an item is answered.
    @MainActor
    func validateGuidanceInputs(for item: InspectConfig.ItemConfig) -> Bool {
        guard let guidanceContent = item.guidanceContent else { return true }
        return validateGuidanceInputs(content: guidanceContent, itemId: item.id)
    }

    /// The same gate for a step. Reads `content`: canonicalization has folded `guidanceContent`
    /// onto it by then.
    @MainActor
    func validateGuidanceInputs(for step: InspectConfig.IntroStep) -> Bool {
        guard let content = step.content else { return true }
        return validateGuidanceInputs(content: content, itemId: step.id)
    }

    /// The shared gate: every `required` block has a stored answer.
    @MainActor
    func validateGuidanceInputs(content guidanceContent: [InspectConfig.GuidanceContent], itemId: String) -> Bool {
        // Never initializes state here (that would publish during a view update). A missing form
        // state is not an early return: pickers answer into the selection stores, not this one.
        let formState = guidanceFormInputs[itemId]

        for block in guidanceContent {
            guard block.required == true else { continue }

            // Selection-backed blocks are keyed by their selection key, not `block.id`.
            if let requirement = RequiredSelection.rule(for: block.type) {
                let key = requirement.key(block)
                let answer: String?
                switch requirement.store {
                case .userValues:         answer = userValues[key]
                case .dockSelection:      answer = dockSelection[key]
                case .wallpaperSelection: answer = wallpaperSelection[key]
                }
                if (answer ?? "").isEmpty {
                    writeLog("InspectState: Required \(block.type) '\(key)' has no selection", logLevel: .info)
                    return false
                }
                continue
            }

            guard let fieldId = block.id, let formState else { continue }

            switch block.type {
            case "checkbox":
                if formState.checkboxes[fieldId] != true {
                    writeLog("InspectState: Required checkbox '\(fieldId)' not checked", logLevel: .info)
                    return false
                }

            case "toggle":
                if formState.toggles[fieldId] != true {
                    writeLog("InspectState: Required toggle '\(fieldId)' not enabled", logLevel: .info)
                    return false
                }

            case "dropdown", "segmented":
                if formState.dropdowns[fieldId]?.isEmpty != false {
                    writeLog("InspectState: Required \(block.type) '\(fieldId)' not selected", logLevel: .info)
                    return false
                }

            case "radio":
                if formState.radios[fieldId]?.isEmpty != false {
                    writeLog("InspectState: Required radio '\(fieldId)' not selected", logLevel: .info)
                    return false
                }

            case "slider":
                if formState.sliders[fieldId] == nil {
                    writeLog("InspectState: Required slider '\(fieldId)' has no value", logLevel: .info)
                    return false
                }

            case "textfield":
                // A resolved inherit counts as filled; a dangling inherit spec does not.
                var effectiveValue = formState.textfields[fieldId] ?? ""
                if effectiveValue.isEmpty, let inheritSpec = block.inherit {
                    effectiveValue = resolveInheritValue(inheritSpec, basePath: uiConfiguration.iconBasePath) ?? ""
                }
                if effectiveValue.isEmpty {
                    writeLog("InspectState: Required textfield '\(fieldId)' is empty", logLevel: .info)
                    return false
                }
                if let regex = block.regex, !regex.isEmpty {
                    let pattern = try? NSRegularExpression(pattern: regex)
                    let range = NSRange(effectiveValue.startIndex..<effectiveValue.endIndex, in: effectiveValue)
                    if pattern?.firstMatch(in: effectiveValue, range: range) == nil {
                        writeLog("InspectState: Textfield '\(fieldId)' failed regex validation", logLevel: .info)
                        return false
                    }
                }
                // Confirm mode blocks on any difference unless both fields are empty.
                if block.textfieldMode == "confirm" {
                    let confirmValue = formState.confirmations[fieldId] ?? ""
                    if effectiveValue != confirmValue && !(effectiveValue.isEmpty && confirmValue.isEmpty) {
                        writeLog("InspectState: Textfield '\(fieldId)' confirmation does not match", logLevel: .info)
                        return false
                    }
                }

            case "select-list", "select-grid", "multi-select":
                // Stored in `textfields`; multi-select joins its values with U+001F.
                if (formState.textfields[fieldId] ?? "").isEmpty {
                    writeLog("InspectState: Required \(block.type) '\(fieldId)' has no selection", logLevel: .info)
                    return false
                }

            default:
                continue
            }
        }

        writeLog("InspectState: All required fields validated for '\(itemId)'", logLevel: .debug)
        return true
    }
}

// MARK: - Required selection rules

/// Where a selection-backed block's answer lands and how its key is derived. The derivations must
/// mirror the picker components: `GuidanceSelectionKeys.resolvedKey`, and `"slot"` for the slot picker.
enum RequiredSelection {
    enum Store {
        case userValues
        case dockSelection
        case wallpaperSelection
    }

    struct Rule {
        let store: Store
        let key: (InspectConfig.GuidanceContent) -> String
    }

    static func rule(for type: String) -> Rule? {
        switch type {
        case "option-picker", "grid-picker":
            return Rule(store: .userValues) {
                GuidanceSelectionKeys.resolvedKey(for: $0) ?? (type == "grid-picker" ? "grid" : "option")
            }
        case "dock-picker":
            return Rule(store: .dockSelection) {
                GuidanceSelectionKeys.resolvedKey(for: $0) ?? "dock"
            }
        case "wallpaper-picker":
            return Rule(store: .wallpaperSelection) {
                GuidanceSelectionKeys.resolvedKey(for: $0) ?? "wallpaper"
            }
        case "slot-picker":
            return Rule(store: .userValues) {
                SelectionEmission.resolveKey($0.id, fallback: "slot").key
            }
        default:
            return nil
        }
    }
}
