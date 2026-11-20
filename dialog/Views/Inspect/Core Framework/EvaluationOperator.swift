//
//  EvaluationOperator.swift
//  dialog
//
//  The evaluation operators a plist or JSON check can name, and how each is derived when unnamed.
//

import SwiftUI

/// The comparison a requirement applies. Every engine resolves the `evaluation` key here, so a
/// requirement means the same comparison whichever engine reads it. Names match
/// case-insensitively; an unknown name is nil, and every caller fails closed on nil.
enum EvaluationOperator: String, CaseIterable {
    case exists
    case boolean
    case equals
    case contains
    case range
    /// Change against a baseline recorded on first check. Only the installation-detection
    /// poller keeps a baseline; other engines fail closed.
    case changed
    /// The value is a date within `expectedValue` seconds of now. Only `Validation` implements it.
    case withinSeconds = "withinseconds"

    /// Other authored spellings of an existing operator.
    private static let aliases: [String: EvaluationOperator] = [
        "within_seconds": .withinSeconds,
        "recentseconds": .withinSeconds,
        "recent": .withinSeconds
    ]

    /// Parses an authored operator name; nil for anything unrecognised.
    init?(authored: String) {
        let folded = authored.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let direct = EvaluationOperator(rawValue: folded) {
            self = direct
        } else if let alias = EvaluationOperator.aliases[folded] {
            self = alias
        } else {
            return nil
        }
    }

    /// `contains`, read off the value's shape: a string is a case-folded substring match, an array
    /// is exact membership (elements string-coerced), a scalar matches on its string form, and
    /// null or a missing expected value is false. Takes `Any` because a stringified array cannot
    /// be told from a string.
    static func containsMatch(value: Any, expected: String?) -> Bool {
        guard let expected, !expected.isEmpty else { return false }
        if value is NSNull { return false }

        if let array = value as? [Any] {
            return array.contains { element in
                if element is NSNull { return false }
                if let string = element as? String { return string == expected }
                return String(describing: element) == expected
            }
        }

        let string = (value as? String) ?? String(describing: value)
        return string.localizedCaseInsensitiveContains(expected)
    }

    /// The default for an absent `evaluation` key: `equals` when an `expectedValue` is authored,
    /// else `exists`. Returns nil only when `evaluation` is authored and names nothing.
    static func resolve(evaluation: String?, expectedValue: String?) -> EvaluationOperator? {
        guard let authored = evaluation,
              !authored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return expectedValue != nil ? .equals : .exists
        }
        return EvaluationOperator(authored: authored)
    }

    /// A log/advisory line explaining a derived default; nil when `evaluation` is authored.
    static func derivationNote(evaluation: String?, expectedValue: String?) -> String? {
        guard evaluation == nil || evaluation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
        else { return nil }
        return expectedValue != nil
            ? "no 'evaluation' authored and an 'expectedValue' is present — comparing with 'equals'"
            : "no 'evaluation' authored and no 'expectedValue' — checking with 'exists'"
    }
}
