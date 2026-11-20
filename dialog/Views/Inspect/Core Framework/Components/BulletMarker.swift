//
//  BulletMarker.swift
//  Dialog
//
//  What a bullet row draws in its marker column, and how wide that column is.
//

import SwiftUI

/// The marker a list row draws, with one column width for all markers so text starts at the same x.
enum BulletMarker: Equatable {
    /// The neutral marker. States that order does not matter.
    case bullet
    /// An ordered step; the numeral itself is the marker.
    case numbered(Int)
    /// An authored SF Symbol, drawn in the config accent.
    case icon(String)

    /// Which marker a row draws: numbered beats icon, icon beats bullet.
    /// `index` is 0-based; the numeral is 1-based.
    static func resolve(numbered: Bool, icon: String?, index: Int) -> BulletMarker {
        if numbered { return .numbered(index + 1) }
        // An empty icon name falls back to the bullet so every row has a mark.
        if let icon, !icon.isEmpty { return .icon(icon) }
        return .bullet
    }

    /// One column width for every marker. Scales with the glyph; 18pt fits a two-digit numeral.
    static func columnWidth(scaleFactor: CGFloat) -> CGFloat { 18 * scaleFactor }
}
