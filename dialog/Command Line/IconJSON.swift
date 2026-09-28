//
//  IconJSON.swift
//  dialog
//
//  Converts a JSON-object icon value into swiftDialog's legacy icon string form so the icon
//  can be described as JSON (e.g. {"sf":"gear","colour":"blue"}) while the existing string/CSV
//  parser in IconView stays the single source of truth. Foundation-only (no SwiftyJSON) so it is
//  safe to call from the view layer.
//

import Foundation

/// If `raw` (trimmed) is a JSON object, returns the equivalent legacy icon string; otherwise
/// returns `raw` unchanged. Arrays, scalars and invalid JSON all fall through untouched, so any
/// existing value (path, "SF=…", "qr=…", "text=…", "none", "a.png:dark=b.png", …) is preserved.
func normalizedIconValue(_ raw: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    // Fast, safe reject: only a leading "{" can be a JSON object. Keeps paths and text={…} cheap
    // and prevents a "text=" value that happens to contain braces from being parsed as JSON.
    guard trimmed.hasPrefix("{") else { return raw }
    guard let data = trimmed.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return raw
    }
    return legacyIconString(fromJSONObject: object)
}

/// Converts a parsed JSON icon object into the legacy icon string
/// (e.g. ["sf": "gear", "colour": "blue"] -> "SF=gear,colour=blue"). Recurses for light/dark.
func legacyIconString(fromJSONObject object: [String: Any]) -> String {
    // Case-insensitive lookup returning the first present key's value as a trimmed string.
    func string(_ keys: String...) -> String? {
        for (key, value) in object where keys.contains(where: { $0.caseInsensitiveCompare(key) == .orderedSame }) {
            if let array = value as? [Any] {
                return array.map { "\($0)" }.joined(separator: ",")
            }
            return "\(value)"
        }
        return nil
    }
    func bool(_ key: String) -> Bool {
        for (k, value) in object where k.caseInsensitiveCompare(key) == .orderedSame {
            if let b = value as? Bool { return b }
            return "\(value)".lowercased() == "true"
        }
        return false
    }

    // Dark-mode: build each side independently and join with the existing separator.
    if object["light"] != nil || object["dark"] != nil {
        let light = sideString(object["light"])
        let dark = sideString(object["dark"])
        if !dark.isEmpty { return "\(light):dark=\(dark)" }
        return light
    }

    let symbol = string("sf", "name", "symbol")

    // Non-symbol form: a plain value (path, qr=, base64, text=, none, warning/caution/info/default…)
    guard let symbol else {
        return string("icon", "path", "value") ?? ""
    }

    var tokens = ["SF=\(symbol)"]
    if let weight = string("weight") { tokens.append("weight=\(weight)") }

    // Colour: explicit colour(s)/palette win over `auto`.
    if let colour = string("colour", "color") {
        tokens.append("colour=\(colour)")
    } else if bool("auto") {
        tokens.append("colour=auto")
    }
    if let colour2 = string("colour2", "color2") { tokens.append("colour2=\(colour2)") }
    if let colour3 = string("colour3", "color3") { tokens.append("colour3=\(colour3)") }
    // palette is split on comma by the parser, so join array elements with commas.
    if let palette = string("palette"), !palette.isEmpty { tokens.append("palette=\(palette)") }

    if let animation = string("animation") { tokens.append("animation=\(animation)") }
    if let bgcolour = string("bgcolour", "bgcolor") { tokens.append("bgcolour=\(bgcolour)") }

    return tokens.joined(separator: ",")
}

/// Renders one side of a light/dark icon, which may be a plain string or a nested icon object.
private func sideString(_ value: Any?) -> String {
    switch value {
    case let string as String:
        return string
    case let object as [String: Any]:
        return legacyIconString(fromJSONObject: object)
    default:
        return ""
    }
}
