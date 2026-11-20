//
//  FooterBrandSeat.swift
//
//  The brand seat at the leading end of a footer band: mark, hairline, gap.
//

import SwiftUI

/// A brand mark clamped by `BrandMarkBox.fit` so a wide wordmark cannot move the row, followed
/// by a hairline separator and the gap to whatever comes next.
struct FooterBrandSeat: View {
    let path: String
    /// Authored mark height, pre-scale; capped at 28 × scale.
    var height: CGFloat = 22
    var clearSpace: CGFloat = 0
    var scale: CGFloat = 1
    /// Air between the separator and the leading slot.
    var gap: CGFloat = 12

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: gap) {
            BrandMark(path: path,
                      box: BrandMarkBox.fit(authored: Double(height * scale),
                                            default: height * scale,
                                            cap: 28 * scale),
                      clearSpace: clearSpace)
                .accessibilityHidden(true)
            Rectangle()
                .fill(palette.text.opacity(0.14))
                .frame(width: 0.5, height: 18 * scale)
        }
        .padding(.trailing, gap)
    }
}
