//
//  GuidanceTemplateResolver.swift
//  dialog
//
//  Resolves {{fieldId}} / {{stepId.fieldId}} / system template variables in guidance content.
//

import Foundation

enum GuidanceTemplateResolver {

    /// Replaces every `{{variable}}` in `content` with its form value or system fact.
    static func resolve(_ content: String, formInputs: [String: GuidanceFormInputState]) -> String {
        var resolved = content

        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return content
        }

        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))

        // Reverse order keeps earlier ranges valid while replacing.
        for match in matches.reversed() {
            guard let matchRange = Range(match.range, in: content),
                  let variableRange = Range(match.range(at: 1), in: content) else {
                continue
            }

            let variable = String(content[variableRange])
            let value = resolveVariable(variable, formInputs: formInputs)

            resolved.replaceSubrange(matchRange, with: value)
        }

        return resolved
    }

    /// System variables win; then `stepId.fieldId` looks in one step and a bare `fieldId` in all.
    /// Checkboxes resolve to "Yes"/"No"; unmatched variables to "(not set)".
    private static func resolveVariable(_ variable: String, formInputs: [String: GuidanceFormInputState]) -> String {
        let trimmed = variable.trimmingCharacters(in: .whitespaces)

        if let systemValue = resolveSystemVariable(trimmed) {
            return systemValue
        }

        if trimmed.contains(".") {
            let components = trimmed.split(separator: ".", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                return "(invalid variable format)"
            }

            let stepId = components[0]
            let fieldId = components[1]

            if let formState = formInputs[stepId] {
                if let value = formState.dropdowns[fieldId], !value.isEmpty {
                    return value
                }
                if let value = formState.radios[fieldId], !value.isEmpty {
                    return value
                }
                if let value = formState.textfields[fieldId], !value.isEmpty {
                    return value
                }
                if let checked = formState.checkboxes[fieldId] {
                    return checked ? "Yes" : "No"
                }
            }

            return "(not set)"
        } else {
            let fieldId = trimmed

            for (_, formState) in formInputs {
                if let value = formState.dropdowns[fieldId], !value.isEmpty {
                    return value
                }
                if let value = formState.radios[fieldId], !value.isEmpty {
                    return value
                }
                if let value = formState.textfields[fieldId], !value.isEmpty {
                    return value
                }
                if let checked = formState.checkboxes[fieldId] {
                    return checked ? "Yes" : "No"
                }
            }

            return "(not set)"
        }
    }

    /// Host facts by template name (`serialNumber`, `computerModel`, `osVersion`, …); nil if not one.
    private static func resolveSystemVariable(_ variable: String) -> String? {
        let systemInfo = getEnvironmentVars()

        switch variable {
        case "serialNumber":
            return systemInfo["serialnumber"] ?? "Unknown"
        case "computerModel":
            return systemInfo["computermodel"] ?? "Unknown"
        case "computerName":
            return systemInfo["computername"] ?? "Unknown"
        case "userName":
            return systemInfo["username"] ?? "Unknown"
        case "userFullName":
            return systemInfo["userfullname"] ?? "Unknown"
        case "osVersion":
            let v = ProcessInfo.processInfo.operatingSystemVersion
            return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        case "osName":
            return systemInfo["osname"] ?? "macOS"
        default:
            return nil
        }
    }
}
