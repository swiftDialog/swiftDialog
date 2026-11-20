//
//  FooterRow.swift
//  dialog
//
//  The footer row: three slots on the band (brand, leading cluster, trailing cluster), the rail,
//  an optional fill and the band's rule. It seats; what a slot holds is the caller's.
//

import SwiftUI

/// Three slots on the band. The row is exactly `FooterBandM.band` tall whatever the slots hold;
/// the rule is paint and costs it nothing. The row adds no spacing of its own, so a slot that
/// needs air between its pieces owns it.
struct FooterRow<Brand: View, Leading: View, Trailing: View>: View {
    /// Post-scale.
    var rail: CGFloat = FooterBandM.rail
    var rule: FooterRulePlacement = .none
    /// The rule's ink; nil is `palette.hairline`. A surface the palette cannot answer for (a
    /// photograph under a scrim) passes its own.
    var ruleInk: Color?
    /// Optional fill behind the row.
    var fill: Color?
    /// The least air between the leading and trailing slots. nil is the system default; a row
    /// that centres something in the leading slot passes 0 so the centre is the span's centre.
    var gap: CGFloat?
    @ViewBuilder var brand: () -> Brand
    @ViewBuilder var leading: () -> Leading
    @ViewBuilder var trailing: () -> Trailing

    @Environment(\.palette) private var palette
    /// The flow's rail wins over the one a caller passes.
    @Environment(\.flowFooterRail) private var flowRail

    var body: some View {
        VStack(spacing: 0) {
            // Priority order: the actions are never squeezed, then the leading slot, then the
            // brand, which keeps only its minimum (a brand that must not truncate fixes its width).
            HStack(alignment: .center, spacing: 0) {
                brand()
                leading()
                    .layoutPriority(1)
                Spacer(minLength: gap)
                trailing()
                    .layoutPriority(2)
            }
            .padding(.horizontal, flowRail ?? rail)
            // Not scaled: the same band every construction reserves.
            .frame(height: FooterBandM.band)
            .background(fill)
            .footerBandRule(ruleInk ?? palette.hairline, enabled: rule == .over)
        }
    }
}
