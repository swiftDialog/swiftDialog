//
//  GreetingResolver.swift
//  dialog
//
//  Placeholder resolution for phase chrome and the Preset 3 greeting: `{userName}`,
//  `{itemCount}` and `{managed:<domain>:<key>[|fallback]}`.
//

import Foundation

/// `{userName}`: the managed preference named by `greetingNameSource`, else the first token of
/// the full user name, else the account short name.
@MainActor
func resolveGreetingName(config: InspectConfig?) -> String {
    if let ref = config?.greetingNameSource,
       let dict = CadenceMonitorService.managedPrefDict(domain: ref.domain),
       let name = dict[ref.key] as? String,
       !name.trimmingCharacters(in: .whitespaces).isEmpty {
        return name.trimmingCharacters(in: .whitespaces)
    }
    let full = NSFullUserName()
    if !full.isEmpty {
        return full.components(separatedBy: " ").first ?? full
    }
    return NSUserName()
}

/// Replaces `{userName}`; strings without the placeholder pass through untouched.
func substituteGreeting(_ text: String, userName: String) -> String {
    text.replacingOccurrences(of: "{userName}", with: userName)
}

// MARK: - Managed-preference tokens

private let managedTokenRegex = try? NSRegularExpression(
    pattern: #"\{managed:([^:{}|]+):([^{}|]+?)(?:\|([^{}]*))?\}"#
)

/// Replaces `{managed:<domain>:<key>[|fallback]}` tokens with values from
/// `/Library/Managed Preferences/<domain>.plist`. Returns nil when a token without a fallback
/// cannot be resolved, so placeholder syntax is never shown to the user.
@MainActor
func substituteManagedValues(_ text: String) -> String? {
    guard text.contains("{managed:"), let regex = managedTokenRegex else { return text }
    var result = ""
    var cursor = text.startIndex
    let ns = text as NSString
    for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
        guard let range = Range(match.range, in: text) else { continue }
        result += text[cursor..<range.lowerBound]
        let domain = ns.substring(with: match.range(at: 1))
        let key = ns.substring(with: match.range(at: 2))
        let fallback = match.range(at: 3).location == NSNotFound ? nil : ns.substring(with: match.range(at: 3))
        let value = (CadenceMonitorService.managedPrefDict(domain: domain)?[key] as? String)?
            .trimmingCharacters(in: .whitespaces)
        if let value, !value.isEmpty {
            result += value
        } else if let fallback {
            result += fallback
        } else {
            return nil
        }
        cursor = range.upperBound
    }
    result += text[cursor...]
    return result
}

/// The phase-chrome pipeline: `{itemCount}`, then `{userName}`, then managed tokens by segment.
@MainActor
func resolvePhaseText(_ text: String, userName: String?, itemCount: Int) -> String {
    let counted = text.replacingOccurrences(of: "{itemCount}", with: "\(itemCount)")
    let greeted = userName.map { substituteGreeting(counted, userName: $0) } ?? counted
    return resolveManagedLine(greeted)
}

// MARK: - Sidecar localization (phase chrome)

/// Precedence for phase copy: sidecar key → config string → built-in default. Every phase screen
/// resolves through this; a nil localizer reduces to config ?? default.
func localizedPhaseValue(_ key: String, localize: ((String) -> String?)?,
                         config: String?, default defaultText: String? = nil) -> String? {
    localize?(key) ?? config ?? defaultText
}

/// `localizedPhaseValue` followed by `resolvePhaseText`; sidecar strings carry the same token
/// grammar as config strings, so localization runs first.
@MainActor
func resolveLocalizedPhaseText(key: String, config: String?, default defaultText: String? = nil,
                               localize: ((String) -> String?)?,
                               userName: String?, itemCount: Int) -> String? {
    guard let text = localizedPhaseValue(key, localize: localize, config: config, default: defaultText)
    else { return nil }
    return resolvePhaseText(text, userName: userName, itemCount: itemCount)
}

/// Resolves managed tokens per " · " segment; a segment whose token cannot resolve (and has no
/// fallback) is dropped, so one config string reads naturally with or without the profile.
@MainActor
func resolveManagedLine(_ text: String) -> String {
    let segments = text.components(separatedBy: " · ")
        .compactMap { substituteManagedValues($0) }
        .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    return segments.joined(separator: " · ")
}
