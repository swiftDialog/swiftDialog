//
//  BrandSlot.swift
//  dialog
//
//  Where the brand mark and claim sit, as one vocabulary every reader of `logoConfig.position`
//  resolves through, so the key cannot mean two placements to two readers.
//

import SwiftUI

// MARK: - What an author may write

/// The three values `logoConfig.position` accepts. Names intent; the construction maps it to
/// geometry.
enum BrandPosition: Equatable {
    /// The construction's own closing band (default): rail foot where a rail exists, else the
    /// action bar's leading seat.
    case footer
    /// Opposite the title, at the top of the window.
    case header
    /// Suppressed: no mark and no claim.
    case none

    /// Case-insensitive and fail-open to `.footer`. Older corner spellings still resolve: anything
    /// containing "bottom" is `.footer`, "header" or anything containing "top" is `.header`.
    init(authored: String?) {
        let raw = (authored ?? "").lowercased()
        if raw.isEmpty {
            self = .footer
        } else if raw == "none" {
            self = .none
        } else if raw.contains("bottom") {
            self = .footer
        } else if raw == "header" || raw.contains("top") {
            self = .header
        } else {
            self = .footer
        }
    }
}

// MARK: - Where the mark sits

/// The brand seats. Only the card seats are wired; the rest complete the vocabulary.
enum BrandSlot: Equatable {
    /// Mark over claim in the sidebar column's foot.
    case railFoot
    /// Mark as the sidebar column's head block, in place of the per-step icon and flow title.
    case railHead
    /// Mark over claim at the action bar's leading end, capped at 220pt.
    case actionLeading
    /// Brand line centred above the action bar.
    case actionCentered
    /// Mark opposite the title at the top; the claim closes the window from the footer.
    case header
    /// The brand is the payload; terminal screens only.
    case payload
    /// Suppressed.
    case none

    /// Resolves the authored `logoConfig.position` through `BrandPosition`; `.footer` maps to
    /// `.actionLeading`, the only footer seat reachable from an authored value.
    init(position: String?) {
        switch BrandPosition(authored: position) {
        case .header: self = .header
        case .none:   self = .none
        case .footer: self = .actionLeading
        }
    }
}

// MARK: - Slot geometry and the claim's type

/// Brand slot sizes and the claim's type. Slots are fixed boxes the mark scales into, so a wide
/// wordmark never moves what follows it.
enum BrandSlotMetrics {
    /// Inside the 250pt sidebar column.
    static let columnSlot = CGSize(width: 176, height: 20)
    /// On the 76pt action bar.
    static let actionSlot = CGSize(width: 220, height: 22)

    /// The claim is the quietest text on screen: muted, sentence case, never bold.
    static let claimFontSize: CGFloat = 11.5
    /// The claim wraps rather than truncating; two lines is the limit.
    static let claimLineLimit = 2
}
