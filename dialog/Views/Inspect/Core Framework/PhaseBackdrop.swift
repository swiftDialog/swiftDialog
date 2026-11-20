//
//  PhaseBackdrop.swift
//  dialog
//
//  The phase backdrop: which ground a phase screen draws, resolved from the config and the managed look.
//

import SwiftUI

// MARK: - Phase backdrop

/// Default managed-pref domain for the dialog-managed look; `phaseBackgroundSource` can point
/// elsewhere.
let dialogManagedLookDomain = "au.csiro.dialog.setup"
let dialogManagedLookStyleKey = "PhaseBackground"

/// Managed pref (`<key>`, `<key>Palette`, `<key>PaletteDark`) beats `config.phaseBackground`
/// beats plain. Invalid values fall through rather than blanking the window.
@MainActor
func resolvePhaseBackdrop(config: InspectConfig?) -> PhaseBackdropSpec {
    let domain = config?.phaseBackgroundSource?.domain ?? dialogManagedLookDomain
    let styleKey = config?.phaseBackgroundSource?.key ?? dialogManagedLookStyleKey
    let managed = CadenceMonitorService.managedPrefDict(domain: domain)

    var spec = PhaseBackdropSpec()
    let validStyles = ["plain", "gradient", "splash"] + ProceduralGradientStyle.allCases.map(\.rawValue)
    if let value = managed?[styleKey] as? String, validStyles.contains(value) {
        spec.style = value
    } else if let value = config?.phaseBackground, validStyles.contains(value) {
        spec.style = value
    }

    let managedPalette = managed?["\(styleKey)Palette"] as? [String] ?? []
    let managedDark = managed?["\(styleKey)PaletteDark"] as? [String] ?? []
    // A profile can name a gradient preset ("preset:g09"); the config's palette is expanded
    // at decode.
    spec.palette = GradientPresets.expand(
        !managedPalette.isEmpty ? managedPalette : (config?.phaseBackgroundPalette ?? []), dark: false)
    spec.darkPalette = GradientPresets.expand(
        !managedDark.isEmpty ? managedDark : (config?.phaseBackgroundPaletteDark ?? []), dark: true)
    return spec
}

/// Resolved backdrop after the managed, config, default ladder.
struct PhaseBackdropSpec: Equatable {
    var style: String = "plain"
    var palette: [String] = []       // hex strings, light scheme
    var darkPalette: [String] = []   // hex strings, dark scheme (falls back to palette)
}
