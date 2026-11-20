//
//  ContentStance.swift
//  dialog
//
//  Where a step's content sits, vertically (`contentAnchor`) and horizontally (`contentAlign`),
//  resolved once. The alignment partners hang off the stance so no call site can take half of
//  an alignment.
//

import SwiftUI

/// Where a step's content group sits: vertically (`anchor`) and horizontally (`align`). Two axes
/// because all four combinations are real.
struct ContentStance: Equatable {
    /// Consumed by `AnchoredStepContent`.
    let anchor: StepAnchor
    /// Consumed by everything that lays content across the width.
    let align: HorizontalAlignment

    /// Content starts under the step label and runs flush left.
    static let topLeading = ContentStance(anchor: .top, align: .leading)
    /// Group centred in the viewport, text centred in the content column.
    static let centered = ContentStance(anchor: .center, align: .center)

    // MARK: - Partners, computed from `align` so they cannot disagree with it

    /// `.multilineTextAlignment` partner; a leading frame holding centred text is a real and
    /// confusing combination.
    var textAlignment: TextAlignment { align == .center ? .center : .leading }

    /// `.frame(alignment:)` partner: where a view that does not fill its width comes to rest.
    var frameAlignment: Alignment { Alignment(horizontal: align, vertical: .center) }

    var isLeading: Bool { align != .center }

    /// The measure for a block of content. Centred keeps the content column; leading goes
    /// full-bleed so grids and tiles get the width.
    func maxWidth(_ metrics: InspectMetrics) -> CGFloat {
        align == .center ? metrics.contentMaxW : .infinity
    }

    /// The measure for prose: leading prose caps at `proseMaxW` and stays flush left.
    func proseMaxWidth(_ metrics: InspectMetrics) -> CGFloat {
        align == .center ? metrics.contentMaxW : metrics.proseMaxW
    }
}

/// Resolves the pair from config along the step → config → preset default ladder. A top-level
/// `"contentAlign": "center"` restores the centred look for a whole config.
enum ContentStanceResolver {
    /// Unknown strings fall back rather than disabling the feature; "left" maps to leading.
    static func align(_ configValue: String?, default fallback: HorizontalAlignment) -> HorizontalAlignment {
        switch configValue?.lowercased() {
        case "leading", "left":  return .leading
        case "center", "centre", "centered", "centred": return .center
        default: return fallback
        }
    }

    /// Step types drawn as bands: a fixed header for the hero and title, the chooser centred in
    /// what remains. Headers with real mass only; a bare title strands itself from its payload.
    static let bandedStepTypes: Set<String> = ["options", "dock", "brandPicker"]

    /// Step types that centre their group whole: a bare-title header, a split text-beside-media
    /// layout, or payloads that vary in height, where bands would open holes.
    static let centeredStepTypes: Set<String> = ["substeps", "assistant", "cadence"]

    /// The stance a step type is designed around, before anything the config says. A default
    /// only: `resolve` lets an authored `contentAnchor` outrank it. Only the vertical half moves
    /// for banded types.
    static func presetDefault(forStepType stepType: String?, preset: ContentStance) -> ContentStance {
        guard let stepType else { return preset }
        if bandedStepTypes.contains(stepType) {
            return ContentStance(anchor: .bands, align: preset.align)
        }
        if centeredStepTypes.contains(stepType) {
            // Both directions: vertically centred with a flush-left edge reads as a mistake.
            return .centered
        }
        return preset
    }

    static func anchor(_ configValue: String?, default fallback: StepAnchor) -> StepAnchor {
        guard let raw = configValue?.lowercased(), let parsed = StepAnchor(rawValue: raw) else {
            return fallback
        }
        return parsed
    }

    /// Per-step keys outrank the config's top-level defaults, which outrank the preset.
    static func resolve(stepAnchor: String?, stepAlign: String?,
                        configAnchor: String?, configAlign: String?,
                        preset: ContentStance) -> ContentStance {
        ContentStance(
            anchor: anchor(stepAnchor, default: anchor(configAnchor, default: preset.anchor)),
            align: align(stepAlign, default: align(configAlign, default: preset.align))
        )
    }
}
