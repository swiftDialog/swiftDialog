//
//  BlockSemantics.swift
//  Dialog
//
//  The one truth table for what mark and hue a block state earns, kept out of the views so every
//  block agrees. A pass earns no mark (the value beside it already says so); tint is severity
//  only, plus the accent for an active phase.
//

import SwiftUI

enum BlockSemantics {

    enum State: String {
        case pass, fail, pending, active, inactive, disabled, warning
    }

    /// The SF Symbol a state earns, or nil. Only `fail` earns one; `warning` is a quantity (a
    /// deadline), not an alert glyph.
    static func mark(for state: State) -> String? {
        switch state {
        case .fail:
            return "xmark.circle.fill"
        case .pass, .pending, .active, .inactive, .disabled, .warning:
            return nil
        }
    }

    /// The hue a state earns, or nil for ordinary text colour.
    static func tint(for state: State, palette: ResolvedPalette) -> Color? {
        switch state {
        case .fail:
            return palette.error
        case .warning:
            return palette.warning
        case .active:
            return palette.accent
        case .pass, .pending, .inactive, .disabled:
            return nil
        }
    }
}
