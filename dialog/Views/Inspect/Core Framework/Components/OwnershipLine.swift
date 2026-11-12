//
//  OwnershipLine.swift
//
//  The footer's ownership claim ("Managed by your IT"), the same on every screen of a flow.
//  Which words and what an empty value means are resolved upstream; this draws the type.
//

import SwiftUI

/// The flow's sign-off at `BrandSlotMetrics.claimFontSize`, wrapping to `claimLineLimit` lines
/// rather than shrinking. The ink is a parameter because the seats that draw it use different
/// tokens on different grounds; generic over `ShapeStyle` so hierarchical styles need no wrapper.
struct OwnershipLine<Ink: ShapeStyle>: View {
    let text: String
    let ink: Ink

    var body: some View {
        Text(text)
            .font(.system(size: BrandSlotMetrics.claimFontSize))
            .foregroundStyle(ink)
            .lineLimit(BrandSlotMetrics.claimLineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }
}
