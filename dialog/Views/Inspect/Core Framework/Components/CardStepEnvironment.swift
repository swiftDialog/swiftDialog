//
//  CardStepEnvironment.swift
//  dialog
//
//  The card shell's metrics and the environment keys the shell and its pieces share: step counter placement, brand slot, greeting name, footer claim, auto-close and top band.
//

import SwiftUI

// MARK: - Brand-mark placement

// The `cardBrandSlot` environment value: a `BrandSlot` resolved once from `logoConfig.position`
// (`BrandPosition(authored:)`): `bottom*` → `.actionLeading`, `header` or other `top*` → `.header`,
// `none` suppresses, anything else → `.actionLeading`. `.actionCentered` is chrome-selected only.

/// Card shell numbers that are not layout.
enum CardStepShellM {
    /// The content slot's bottom fade, about one line of body text.
    static let bodyFadeHeight: CGFloat = 28
}

/// Where the card's step counter is stated (root key `stepCounterPlacement`). Moves the counter, never
/// duplicates it; dots are unaffected. Unknown values fall back to `.header`.
enum CardStepCounterPlacement: Equatable {
    case header
    case footer
    /// Stated nowhere, for screens that are not a sequence. Dots are unaffected.
    case none

    init(_ authored: String?) {
        switch (authored ?? "").lowercased() {
        case "footer": self = .footer
        case "none":   self = .none
        // Unknown values fall back to the standard header, as `BrandSlot(position:)` does.
        default:       self = .header
        }
    }
}

private struct CardStepCounterPlacementKey: EnvironmentKey {
    static let defaultValue: CardStepCounterPlacement = .header
}

private struct CardBrandSlotKey: EnvironmentKey {
    static let defaultValue: BrandSlot = .actionLeading
}

private struct CardGreetingNameKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    /// Injected at the preset root from `config.logoConfig.position`; read by the card shell.
    var cardBrandSlot: BrandSlot {
        get { self[CardBrandSlotKey.self] }
        set { self[CardBrandSlotKey.self] = newValue }
    }

    /// Injected at the preset root from `config.stepCounterPlacement`; read by the card shell.
    var cardStepCounterPlacement: CardStepCounterPlacement {
        get { self[CardStepCounterPlacementKey.self] }
        set { self[CardStepCounterPlacementKey.self] = newValue }
    }

    /// The resolved first name for `{userName}` in card titles; nil leaves the token untouched.
    var cardGreetingName: String? {
        get { self[CardGreetingNameKey.self] }
        set { self[CardGreetingNameKey.self] = newValue }
    }
}

// MARK: - Top band

/// The brand claim shows only when authored: unset or empty draws no line.
enum CardFooterClaim {
    static func resolve(authored: String?) -> String? {
        authored?.isEmpty == false ? authored : nil
    }
}

/// The brand claim in the card's action bar, the same sign-off `IntroFooterView` seats. Injected at the
/// Preset 5 and 6 dispatch rather than threaded through each `CardFooterModel`.
private struct CardFooterClaimKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var cardFooterClaim: String? {
        get { self[CardFooterClaimKey.self] }
        set { self[CardFooterClaimKey.self] = newValue }
    }
}

private struct CardAutoCloseKey: EnvironmentKey {
    // Computed: the model holds a closure and is not `Sendable`.
    static var defaultValue: CardAutoCloseModel? { nil }
}

extension EnvironmentValues {
    /// The bounded final-screen hold, injected per step at the Preset 5 dispatch.
    var cardAutoClose: CardAutoCloseModel? {
        get { self[CardAutoCloseKey.self] }
        set { self[CardAutoCloseKey.self] = newValue }
    }
}

private struct CardTopBandKey: EnvironmentKey {
    static let defaultValue: InspectConfig.TopBandConfig? = nil
}

extension EnvironmentValues {
    /// The flow-level top band, injected with arm legality applied; the shell renders what it receives.
    var cardTopBand: InspectConfig.TopBandConfig? {
        get { self[CardTopBandKey.self] }
        set { self[CardTopBandKey.self] = newValue }
    }
}
