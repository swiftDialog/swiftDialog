//
//  SplashPick.swift
//  dialog
//
//  What a splash step offers to pick, resolved from its payload.
//

import SwiftUI

/// The splash pick's key and default value.
enum SplashPick {
    static let defaultKey = "environment"

    /// The `splash` backdrop's pools, dark palette first; empty for any other backdrop style.
    @MainActor
    static func groundPools(config: InspectConfig?) -> [Color] {
        let spec = resolvePhaseBackdrop(config: config)
        guard spec.style == "splash" else { return [] }
        return (spec.darkPalette.isEmpty ? spec.palette : spec.darkPalette).map { Color(hex: $0) }
    }

    static func key(for step: InspectConfig.IntroStep) -> String {
        guard let key = step.environmentKey, !key.isEmpty else { return defaultKey }
        return key
    }

    /// The first destination's value, or nil when the step is not a chooser.
    static func defaultValue(for step: InspectConfig.IntroStep) -> String? {
        guard let environments = step.environments, environments.count > 1 else { return nil }
        return environments[0].value
    }
}
