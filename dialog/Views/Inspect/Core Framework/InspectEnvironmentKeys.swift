//
//  InspectEnvironmentKeys.swift
//  Dialog
//
//  Shared SwiftUI `EnvironmentKey`s that let inspect views reach services and layout facts owned
//  by the preset root without threading them through every initializer.
//

import SwiftUI

// MARK: - Compliance Aggregator

/// The preset's `ComplianceAggregatorService`, injected at the preset root. `nil` when a preset
/// owns no aggregator (Presets 2–4): plist-driven blocks then skip rendering and bento cells skip
/// the auto-binding.
private struct ComplianceAggregatorKey: EnvironmentKey {
    static let defaultValue: ComplianceAggregatorService? = nil
}

extension EnvironmentValues {
    var complianceAggregator: ComplianceAggregatorService? {
        get { self[ComplianceAggregatorKey.self] }
        set { self[ComplianceAggregatorKey.self] = newValue }
    }
}

// MARK: - Host size

/// The size of the preset root's content area, published so a `.sheet` (which cannot measure its
/// host) can clamp against it. `.zero` means not measured yet; clamping is skipped.
private struct InspectHostSizeKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    var inspectHostSize: CGSize {
        get { self[InspectHostSizeKey.self] }
        set { self[InspectHostSizeKey.self] = newValue }
    }
}

/// The body band between a shell's header and footer rule. A payload whose authored height could
/// outgrow it (`webcontent`'s `webHeight`) stays inside. `.zero` leaves the authored size alone.
private struct InspectBodyBandKey: EnvironmentKey {
    static let defaultValue: CGSize = .zero
}

extension EnvironmentValues {
    var inspectBodyBand: CGSize {
        get { self[InspectBodyBandKey.self] }
        set { self[InspectBodyBandKey.self] = newValue }
    }
}

// MARK: - Localization

/// Resolves a fixed-UI string: `(key, englishFallback) -> String`. A closure because resolution
/// also needs the preset's selected language, which lives in preset state. The default returns the
/// fallback, so renderers under presets without localization (1–4) read English.
typealias InspectLocalizer = (_ key: String, _ fallback: String) -> String

private struct InspectLocalizationKey: EnvironmentKey {
    // Computed: a closure is not `Sendable`, and a computed default is not shared state.
    static var defaultValue: InspectLocalizer { { _, fallback in fallback } }
}

extension EnvironmentValues {
    var inspectLocalization: InspectLocalizer {
        get { self[InspectLocalizationKey.self] }
        set { self[InspectLocalizationKey.self] = newValue }
    }
}

// MARK: - Branded control primitives

/// Whether a construction wants the hand-drawn control primitives (`BrandPicker`) in place of
/// AppKit's. False by default so constructions that have not adopted render unchanged; carried in
/// the environment because the block that honours it sits several `@ViewBuilder` hops away.
private struct BrandedControlsKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var brandedControls: Bool {
        get { self[BrandedControlsKey.self] }
        set { self[BrandedControlsKey.self] = newValue }
    }
}

// MARK: - Card header help seat

/// The help control a card header seats at the trailing end of its eyebrow row, after the step
/// counter (a corner disc would collide with the counter). `nil` by default: no help control drawn.
struct CardHeaderHelp: Sendable {
    let icon: String
    let tooltip: String
    /// Main-actor and `@Sendable` so the type is `Sendable`; only ever called from a button.
    let action: @MainActor @Sendable () -> Void
}

private struct CardHeaderHelpKey: EnvironmentKey {
    static let defaultValue: CardHeaderHelp? = nil
}

extension EnvironmentValues {
    var cardHeaderHelp: CardHeaderHelp? {
        get { self[CardHeaderHelpKey.self] }
        set { self[CardHeaderHelpKey.self] = newValue }
    }
}

/// True when a card drew its brand mark (`CardBrandMark`). The preset stands its window-corner
/// mark down on this report, not on the construction, so the logo draws once.
struct CardBrandSeatedKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// True when a card header drew the help control. The preset stands its corner glyph
/// (`cornerHelpButton`) down on this answer; a screen that reports nothing keeps the corner glyph.
struct CardHeaderHelpSeatedKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Applies the authored flavour, or nothing at all when none is authored.
    @ViewBuilder
    func inspectButtonShape(_ shape: InspectButtonShape?) -> some View {
        switch shape {
        case .pill:    self.buttonBorderShape(.capsule)
        case .rounded: self.buttonBorderShape(.roundedRectangle(radius: 8))
        case nil:      self
        }
    }
}

extension EnvironmentValues {
    /// Injected at each preset root, so the flavour belongs to the flow, not to one bar.
    var inspectButtonShape: InspectButtonShape? {
        get { self[InspectButtonShapeKey.self] }
        set { self[InspectButtonShapeKey.self] = newValue }
    }
}

private struct InspectButtonShapeKey: EnvironmentKey {
    static let defaultValue: InspectButtonShape? = nil
}

// MARK: - Button flavours

/// The shape a config asks its buttons to take (root key `buttonShape`): `pill` or `rounded`.
/// Text-only affordances are untouched. Absent or unknown resolves to nil and applies no modifier.
enum InspectButtonShape: String {
    case pill
    case rounded

    init?(_ raw: String?) {
        guard let raw, !raw.isEmpty,
              let shape = InspectButtonShape(rawValue: raw.lowercased()) else { return nil }
        self = shape
    }
}
