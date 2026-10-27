//
//  FormInheritance.swift
//  dialog
//
//  Resolves inherit specs for InspectState.
//  Formats: plist:/path.plist:key.path · defaults:domain:key.path · env:NAME · field:itemId.fieldId.
//

import Foundation

@MainActor
func resolveFormInheritValue(_ inheritSpec: String, basePath: String?, fieldLookup: (String, String) -> String?) -> String? {
    let parts = inheritSpec.components(separatedBy: ":")
    guard parts.count >= 2 else { return nil }

    switch parts[0] {
    case "plist":
        guard parts.count >= 3 else { return nil }
        return Validation.shared.getPlistValue(at: parts[1], key: parts.dropFirst(2).joined(separator: ":"), basePath: basePath)

    case "defaults":
        guard parts.count >= 3 else { return nil }
        return Validation.shared.getUserDefaultsValue(domain: parts[1], key: parts.dropFirst(2).joined(separator: ":"))

    case "env":
        return ProcessInfo.processInfo.environment[parts[1]]

    case "field":
        let fieldParts = parts[1].components(separatedBy: ".")
        guard fieldParts.count == 2 else { return nil }
        return fieldLookup(fieldParts[0], fieldParts[1])

    default:
        return nil
    }
}
