//
//  GuidanceBlockSpacing.swift
//  dialog
//
//  The gap between two guidance blocks, decided by the roles on either side: an 8-unit scale
//  (16 / 24 / 32 / 48), with the big gap above a heading and a tight one below it.

import SwiftUI

/// What a block is for spacing purposes, so spacing is decided per role rather than per block type.
enum GuidanceBlockRole {
    /// A section heading: binds down to its content, separates up from the previous section.
    case label
    /// Running prose: the lede, a warning, an explanatory note.
    case prose
    /// A block of figures: a table, a card, a row of stats.
    case data
    /// An enumerated run: bullets, a checklist.
    case list
    /// Progress state: a tracker, a progress bar, a status badge.
    case state
    /// A picture or a movie.
    case media

    init(blockType: String) {
        switch blockType {
        case "compliance-header":
            self = .label
        case "comparison-table", "feature-table", "compliance-card", "stat-row", "bento-grid":
            self = .data
        case "bullets", "checklist", "handoff-list":
            self = .list
        case "phase-tracker", "progress-bar", "status-badge":
            self = .state
        case "image", "image-carousel", "video", "webcontent", "portal-webview":
            self = .media
        default:
            // text, highlight, warning, info, success, arrow, and every input control.
            self = .prose
        }
    }
}

enum GuidanceBlockSpacing {
    /// The scale; nothing outside it may be returned.
    static let tight: CGFloat = 16
    static let base: CGFloat = 24
    static let section: CGFloat = 32
    static let wide: CGFloat = 48

    /// The gap below `above` and above `below`. Cases are checked in order.
    static func gap(below above: GuidanceBlockRole, above below: GuidanceBlockRole) -> CGFloat {
        // A heading opens a section, so the air goes above it.
        if below == .label { return section }

        // ...and binds tightly to what it labels.
        if above == .label { return tight }

        // The state line sits apart from the content above it.
        if below == .state { return wide }

        // A track hangs off the state line it belongs to.
        if above == .state { return tight }

        // Prose into figures, or figures into prose, is a change of register.
        if above != below { return section }

        // Two of a kind run on.
        return base
    }

    /// Convenience for a whole run: the gap that precedes each block after the first.
    static func gaps(for blocks: [InspectConfig.GuidanceContent]) -> [CGFloat] {
        guard blocks.count > 1 else { return [] }
        return zip(blocks, blocks.dropFirst()).map { above, below in
            gap(below: GuidanceBlockRole(blockType: above.type),
                above: GuidanceBlockRole(blockType: below.type))
        }
    }
}
