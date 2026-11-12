//
//  FooterBand.swift
//
//  One footer band for every construction, and the rule that places the primary in it: 28 points
//  of air under the primary, centred on the primary itself rather than on the tallest control in
//  the row. CoreGraphics only; every construction reads these numbers rather than restating them.
//

import SwiftUI

/// The footer band, and where the primary sits in it. A construction that needs a different band
/// changes this type, never a local constant.
enum FooterBandM {

    /// The one band height every construction reserves (84 standard, `compact` 60, on a 40 rail).
    /// The shells' own `footerHeight` constants alias this.
    static let band: CGFloat = 84

    /// Where a body stops above the band's rule, so nothing that fills runs to the rule. Mirrors
    /// the band's own rule-to-primary air.
    static let bodyAir: CGFloat = 28

    /// The band's rail, for a footer with no body rail of its own.
    static let rail: CGFloat = 40

    /// The compact rung: a sheet's action row rather than a window footer.
    static let compact: CGFloat = 60

    /// The top rule's width wherever a band draws one.
    static let ruleWidth: CGFloat = 0.5

    /// The primary action's height, everywhere; the back doors match it.
    static let primaryHeight: CGFloat = 28

    /// The gap between the primary's bottom edge and the window's. `hairline` is the height a
    /// top rule consumes from the band (0 when it is painted over the band instead).
    static func air(hairline: CGFloat = 0) -> CGFloat {
        max(0, (band - hairline - primaryHeight) / 2)
    }

    /// The height the action cluster reports: always `primaryHeight`. A taller sibling overhangs
    /// the primary symmetrically instead of moving it; `tallestSibling` is deliberately unused.
    static func clusterHeight(tallestSibling: CGFloat) -> CGFloat {
        _ = tallestSibling
        return primaryHeight
    }
}

// MARK: - The flow's rail

/// The primary's distance from the window's trailing edge, one number per flow. `FooterRow` reads
/// it so the button does not move between a flow's screens; nil leaves each band on its own rail.
private struct FlowFooterRailKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var flowFooterRail: CGFloat? {
        get { self[FlowFooterRailKey.self] }
        set { self[FlowFooterRailKey.self] = newValue }
    }
}

extension FooterBandM {
    /// Every step flow's footer sits on the card edge; Presets 1–4 set no flow rail.
    static func flowRail(card: Bool) -> CGFloat {
        InspectMetrics.unit.cardEdge
    }
}

