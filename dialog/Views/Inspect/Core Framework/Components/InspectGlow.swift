//
//  InspectGlow.swift
//  dialog
//
//  How much accent glow a flow draws. Root key `glow`: "full" (default), "soft", "subtle",
//  "none". Injected once above the preset switch, so one setting reaches every preset.
//

import SwiftUI

enum InspectGlow: String, Equatable {
    case full, soft, subtle, none

    /// Absent or unknown keeps the designed look.
    init(_ raw: String?) {
        self = raw.flatMap { InspectGlow(rawValue: $0.lowercased()) } ?? .full
    }

    /// The share of the designed glow that is drawn.
    var factor: Double {
        switch self {
        case .full: return 1
        case .soft: return 0.6
        case .subtle: return 0.3
        case .none: return 0
        }
    }
}

private struct InspectGlowKey: EnvironmentKey {
    static let defaultValue: InspectGlow = .full
}

extension EnvironmentValues {
    var inspectGlow: InspectGlow {
        get { self[InspectGlowKey.self] }
        set { self[InspectGlowKey.self] = newValue }
    }
}

/// An accent shadow scaled by the flow's `glow`: opacity by its factor, spread shrinking with it,
/// nothing at all at "none".
private struct GlowShadow: ViewModifier {
    @Environment(\.inspectGlow) private var glow
    let color: Color
    let opacity: Double
    let radius: CGFloat
    let y: CGFloat
    let active: Bool

    func body(content: Content) -> some View {
        let f = glow.factor
        content.shadow(color: active && f > 0 ? color.opacity(opacity * f) : .clear,
                       radius: radius * (0.4 + 0.6 * f), y: y * f)
    }
}

extension View {
    /// `.shadow(color: color.opacity(opacity), radius:, y:)` when active, scaled by `glow`.
    func glowShadow(_ color: Color, opacity: Double, radius: CGFloat, y: CGFloat = 0, active: Bool = true) -> some View {
        modifier(GlowShadow(color: color, opacity: opacity, radius: radius, y: y, active: active))
    }
}
