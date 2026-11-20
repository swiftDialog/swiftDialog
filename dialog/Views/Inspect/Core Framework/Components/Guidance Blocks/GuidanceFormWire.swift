//
//  GuidanceFormWire.swift
//  dialog
//
//  The interaction-log line shape a host hands to the shared form blocks. Orchestrators cut these
//  lines by field position, so both shapes are a public API:
//      shared    checkbox:prefs:analytics:true     owner id interposed
//      Preset 5  checkbox:analytics:true           no owner id

import Foundation

/// Which shape a form block's interaction-log line takes.
enum FormWireDialect {
    /// `type:itemId:fieldId:value` — the shared blocks' line, and the default.
    case item4Part
    /// `type:fieldId:value` — Preset 5's frozen contract. No owner id.
    case step3Part
}

/// The wire behaviour a host hands to the form blocks: what its lines look like, and what
/// else should happen when a field is committed.
struct FormWire {
    var dialect: FormWireDialect = .item4Part

    /// Preset 5 writes each committed value to its preferences plist (only with `preferencesOutput`).
    var onValueCommit: ((_ fieldId: String, _ value: Any) -> Void)?

    /// Builds the interaction-log line; the one place either shape is spelled out.
    func line(type: String, owner: String, field: String, value: String) -> String {
        switch dialect {
        case .item4Part: return "\(type):\(owner):\(field):\(value)"
        case .step3Part: return "\(type):\(field):\(value)"
        }
    }

    /// Preset 5 emits sliders as Int (`slider:volume:50`), the shared blocks as Double
    /// (`slider:prefs:volume:50.0`). Scripts depend on both.
    func sliderWireValue(_ value: Double) -> String {
        switch dialect {
        case .item4Part: return "\(value)"
        case .step3Part: return "\(Int(value))"
        }
    }

    /// Preset 5 also writes the Int, not the Double, into its preferences plist.
    func commitSlider(_ fieldId: String, _ value: Double) {
        switch dialect {
        case .item4Part: onValueCommit?(fieldId, value)
        case .step3Part: onValueCommit?(fieldId, Int(value))
        }
    }

    /// Normalises a value for the line-oriented interaction log: every newline spelling becomes a literal `\n`.
    static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }

    /// What a text field puts on the interaction log. The log is a shared file in /tmp any local
    /// user can read, so a secure field says that it changed, never what it holds.
    static func loggedValue(_ value: String, secure: Bool) -> String {
        secure ? "<redacted>" : sanitize(value)
    }
}
