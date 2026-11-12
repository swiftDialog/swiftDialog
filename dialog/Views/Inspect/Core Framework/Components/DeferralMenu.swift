//
//  DeferralMenu.swift
//
//  When the footer offers a deferral menu. Shared by every preset that draws `DeferralMenuView`.
//

import SwiftUI

enum DeferralMenu {
    /// Deferral is an entry decision: the menu is offered until the first `processing` step and
    /// never after. A flow with no processing step defers from anywhere.
    ///
    /// Reads `resolvedStepType`, so an untyped step (`standard`) never ends the offer. Written
    /// without the nil-coalescing operator because a source-level test greps for it.
    /// `isDeferralEnabled(config:)` (does the flow defer at all) and the rail's `showLaterAndBack`
    /// (does this seat draw a way out) are separate gates.
    static func isOffered(steps: [InspectConfig.IntroStep], currentIndex: Int) -> Bool {
        guard let firstProcessing = steps.firstIndex(where: { $0.resolvedStepType == "processing" })
        else { return true }
        return currentIndex < firstProcessing
    }
}
