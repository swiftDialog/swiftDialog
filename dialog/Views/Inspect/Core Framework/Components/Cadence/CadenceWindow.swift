//
//  CadenceWindow.swift
//  dialog
//
//  Window arithmetic for the cadence row: the bento board shows a few steps at a time, sliding
//  with the active entry.
//

import Foundation

enum CadenceM {
    /// `4 × 168 + 3 × 20 = 732`: four seats fill the column with no remainder.
    static let cardGap: CGFloat = 20
    /// 820 window minus the card chrome's 44pt rail.
    static let rowContentWidth: CGFloat = 732
    /// Minimum seat width; decides how many seats fit, never the width a seat is drawn at.
    static let cardWidth: CGFloat = 144

    /// How many seats fit across `viewport` at the given minimum and the fixed gap.
    static func cardsPerRow(viewport: CGFloat, minCard: CGFloat = cardWidth) -> Int {
        max(1, Int((viewport + cardGap) / (minCard + cardGap)))
    }

    /// The indices in view: as many as fit, sliding so the active entry stays visible, clamped
    /// at both ends rather than re-centred.
    static func visibleWindow(count: Int, active: Int, viewport: CGFloat,
                              minCard: CGFloat = cardWidth) -> [Int] {
        let per = cardsPerRow(viewport: viewport, minCard: minCard)
        guard count > per else { return Array(0..<count) }
        let start = min(max(0, active - per + 1), count - per)
        return Array(start..<(start + per))
    }
}
