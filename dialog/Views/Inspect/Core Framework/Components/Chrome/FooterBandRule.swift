//
//  FooterBandRule.swift
//
//  The hairline along a footer band's top edge. Painted as an overlay so it costs the band no
//  height and the primary's air stays `FooterBandM.air()` everywhere.
//

import SwiftUI

/// A half-point rule in `ink`, the band's width.
struct FooterBandRule: View {
    var ink: Color

    var body: some View {
        Rectangle()
            .fill(ink)
            .frame(height: FooterBandM.ruleWidth)
    }
}

/// Where a band seats its rule. Only an overlay placement exists so the band's height never
/// depends on whether it draws one.
enum FooterRulePlacement: Equatable {
    /// No rule.
    case none
    /// An overlay on the band's top edge.
    case over
}

extension View {
    /// Paint the band's top rule over this view's top edge; `false` draws nothing.
    func footerBandRule(_ ink: Color, enabled: Bool = true) -> some View {
        overlay(alignment: .top) {
            if enabled { FooterBandRule(ink: ink) }
        }
    }
}
