//
//  InspectSizes.swift
//  dialog
//
//  Window sizes for the inspect presets: the construction table, the `chrome` resolver and the
//  one window-size ladder used at launch and at runtime.
//

import Foundation
import CoreGraphics

/// Centralized sizing definitions for all Inspect Mode presets
public enum InspectSizes {

    // MARK: - Constructions

    /// One entry per chrome shell. A shell's size belongs to the construction, not to the preset
    /// drawing it. Selected with the `chrome` config key; presets 2 and 3 have no construction and
    /// use the per-preset arms in `getSize`.
    public enum Construction: String, CaseIterable {
        // The pre-card shell; Preset 1's default, reachable on the P5 engine only via `chrome: "plain"`.
        case plain
        // Three bands (back chevron, body, footer), centred title, one 560pt media column.
        case plainSimple = "plain-simple"
        // Centred stack: hero tile, title, body. Hyphenated raw value, so it is explicit.
        case plainCentered = "plain-centered"
        // Left-aligned 500pt column (`PlainBrandedM.columnWidth`), no top band, floating action pill.
        case plainBranded = "plain-branded"
        case sidebar    // the only construction with a 250pt sidebar
        case card       // the migration card: the card IS the window
        case rail       // the sidebar's 920 × 620, HStack shell with a left rail
        /// Header, one row list, one status band, footer. The only elastic construction: opens at
        /// 820 × 600 and holds at the 800 × 600 minimum. `chrome: "fixture"` still decodes and
        /// resolves to the engine's default.
        case provisioning
        /// The migration bodies (receipt, media split, task list) on the provisioning shell.
        /// Opt-in at the flow via `chrome: "migration"` or `migrationBodies: true`
        /// (`usesMigrationBodies`); never inferred from a step's contents.
        case migration
        /// Media owns the frame; text sits on the picture in a bottom scrim. State α (full-bleed)
        /// or β (framed card) follows how the media is authored; see `setupAssistantStepView`.
        case setupAssistant = "setup-assistant"
        /// Splash / chooser in front of a flow: brand mark on a dark ground, stacked doors, and a
        /// destination picker when the flow has several. Same 820 × 600 as `setupAssistant`.
        case splash
        case toast      // Preset 4's own idiom (documented exception)

        /// `plain-fruitcorp` is an older spelling of `plain-branded`; configs that still author it decode.
        public init?(rawValue: String) {
            let name = rawValue == "plain-fruitcorp" ? "plain-branded" : rawValue
            guard let match = Self.allCases.first(where: { $0.rawValue == name }) else { return nil }
            self = match
        }

        /// The one window size this construction is designed for. A bigger window is asked for
        /// with explicit `width`/`height`, never with a size mode.
        public var size: CGSize {
            switch self {
            case .plain:       return CGSize(width: 820, height: 600)   // one number with the card
            // 800 × 600: `PlainSimpleM.cardMaxHeight` and `MigrationM.fitsNarrowSplit` derive from it.
            case .plainSimple: return CGSize(width: 800, height: 600)
            case .plainCentered: return CGSize(width: 800, height: 688)
            case .plainBranded: return CGSize(width: 800, height: 600)
            // A 250pt column costs width; the rail and the sidebar both have one.
            case .sidebar, .rail: return CGSize(width: 920, height: 620)
            case .card:        return CGSize(width: 820, height: 600)   // one number with plain
            // 820 × 600 (`ProvisioningM.recommended`), shared with card and migration so one flow
            // can mix shells without the window jumping.
            case .provisioning: return CGSize(width: 820, height: 600)
            case .migration:      return CGSize(width: 820, height: 600)
            case .setupAssistant: return CGSize(width: 820, height: 600)
            case .splash:      return CGSize(width: 820, height: 600)
            case .toast:       return CGSize(width: 550, height: 110)
            }
        }

        /// Which engines have an adapter for this shell. Keyed on normalized engine names
        /// (preset 7 reaches the preset5 row through `normalizePreset`). A case missing from its
        /// row resolves to the engine's default with no symptom, so every case needs a row.
        var engines: Set<String> {
            switch self {
            // Preset 6 keeps `card` on purpose: its default sidebar is navigation, the card is a
            // content shell with no column, and an authored `chrome: "card"` takes it to 820×600.
            case .card:    return ["preset5", "preset6"]
            case .rail:    return ["preset6"]
            // Preset 5 owns the provisioning step vocabulary (cadence, carousel, brandPicker).
            case .provisioning: return ["preset5"]
            case .migration:      return ["preset5"]
            case .setupAssistant: return ["preset5"]
            case .splash:      return ["preset5"]
            case .plain:   return ["preset1", "preset5"]
            case .sidebar: return ["preset6"]
            // Preset 1's phase model (intro → main → summary) is these shells' flow.
            case .plainSimple: return ["preset1"]
            case .plainCentered: return ["preset1"]
            case .plainBranded: return ["preset1"]
            case .toast:   return ["preset4"]   // documented exception; not in the schema enum
            }
        }

        /// Each engine's default construction for an unauthored `chrome`. Presets 2 and 3 return
        /// nil and fall to the legacy size table.
        static func defaultConstruction(forEngine engine: String) -> Construction? {
            switch engine {
            case "preset1": return .plain
            case "preset4": return .toast
            case "preset5": return .card
            case "preset6": return .sidebar
            default:        return nil
            }
        }

        /// The one resolver both the window size and the renderers consult:
        ///   1. authored `chrome`, if this engine has the adapter
        ///   2. the engine's default construction
        ///   3. nil — the caller falls to the legacy size table (presets 2/3)
        /// An unknown or unsupported value resolves like absence, so a typo never selects a
        /// different shell or resizes the window (a card request must not resize the toast).
        static func resolve(preset: String, authoredChrome: String?) -> Construction? {
            let engine = InspectSizes.normalizePreset(preset)   // maps preset7 onto the preset5 engine
            if let authoredChrome,
               let authored = Construction(rawValue: authoredChrome),
               authored.engines.contains(engine) {
                return authored
            }
            return defaultConstruction(forEngine: engine)
        }
    }

    /// Normalize a preset name to its engine form, e.g. "6" → "preset6". Every preset 7 spelling
    /// (`"7"`, `"preset7"`, `"guided-setup"`, `"guided"`) resolves to the preset5 engine.
    static func normalizePreset(_ preset: String) -> String {
        InspectPresetName.normalizePreset(preset)
    }

    /// Window size for a preset. Size modes never change the window: a construction has one
    /// footprint, and a bigger window is asked for with explicit `width`/`height`. An unknown
    /// `mode` falls through to the preset's size so older configs keep working.
    public static func getSize(preset: String, mode: String) -> (CGFloat, CGFloat) {
        let normalizedPreset = normalizePreset(preset)

        if let construction = Construction.resolve(preset: normalizedPreset, authoredChrome: nil) {
            return (construction.size.width, construction.size.height)
        }

        // Presets 2 and 3 have no construction; each is one size.
        switch normalizedPreset {
        case "preset2":
            // 860 seats four 168pt cards at 14pt spacing with room for the paging arrows.
            return (860, 600)

        case "preset3":
            // Height is a cap; the itemCount-aware overload adapts it to tile rows.
            return (760, 820)

        default:
            return (1000, 600)
        }
    }

    /// Preset 3's item layout: `chrome: "grid"` opts in to the tile grid; absent or anything else
    /// is the list, the 3.1.1 look. One reader for the view and the window size.
    public static func preset3UsesGrid(chrome: String?) -> Bool {
        chrome?.trimmingCharacters(in: .whitespaces).lowercased() == "grid"
    }

    /// Content-adaptive variant. Preset 3 sizes its height to the number of items, capped at the
    /// preset's standard height. Other presets ignore `itemCount`.
    /// - Parameter itemCount: number of list items (0 ⇒ unknown ⇒ fixed size).
    public static func getSize(preset: String, mode: String, itemCount: Int,
                               chrome: String? = nil) -> (CGFloat, CGFloat) {
        let (width, height) = getSize(preset: preset, mode: mode)
        guard normalizePreset(preset) == "preset3", itemCount > 0 else { return (width, height) }
        let base: CGFloat = 330        // header + progress zone + footer + paddings
        let adaptive: CGFloat
        if preset3UsesGrid(chrome: chrome) {
            // 5 tiles per row; one tile row incl. group label + spacing.
            adaptive = base + CGFloat(Int((Double(itemCount) / 5).rounded(.up))) * 155
        } else {
            // One row per item: 44pt row + 8pt spacing.
            adaptive = base + CGFloat(itemCount) * 52
        }
        return (width, min(max(adaptive, 460), height))   // clamp: never taller than the fixed max
    }

    /// Default size when no preset is specified.
    public static var defaultSize: (CGFloat, CGFloat) {
        return (1000, 600)
    }

    // MARK: - Window resolver

    /// The one window-size ladder, shared by launch-time sizing and `InspectLayoutProtocol.windowSize`:
    /// explicit width/height → construction → preset table (itemCount-aware) → `defaultSize`.
    /// `origin` wording is read by log tooling; keep it stable.
    public static func windowSize(width: Int?, height: Int?, preset: String,
                                  mode: String?, itemCount: Int,
                                  chrome: String? = nil,
                                  bandGrowth: CGFloat = 0) -> (size: CGSize, origin: String) {
        if let width, let height {
            return (CGSize(width: CGFloat(width), height: CGFloat(height)),
                    "Custom size \(width)×\(height)")
        }
        let sizeMode = mode ?? "standard"
        if let construction = Construction.resolve(preset: preset, authoredChrome: chrome) {
            var size = construction.size
            if construction == .card, bandGrowth > 0 {
                size.height += bandGrowth
                return (size, "card chrome + band (\(Int(size.width))×\(Int(size.height)))")
            }
            // Chrome phrasing only when the author asked for this construction, else preset phrasing.
            if let chrome, Construction(rawValue: chrome) == construction {
                return (size, "\(chrome) chrome (\(Int(size.width))×\(Int(size.height)))")
            }
            return (size, "\(preset) \(sizeMode) (\(Int(size.width))×\(Int(size.height)))")
        }
        if !preset.isEmpty {
            let (w, h) = getSize(preset: preset, mode: sizeMode, itemCount: itemCount, chrome: chrome)
            return (CGSize(width: w, height: h),
                    "\(preset) \(sizeMode) (\(Int(w))×\(Int(h)))")
        }
        let (w, h) = defaultSize
        return (CGSize(width: w, height: h),
                "Using default size (\(Int(w))×\(Int(h)))")
    }

    /// Extra card-window height for an additive top band: bandHeight − 38, where 38 is what the
    /// banded layout's vertical compression reclaims, so the payload budget stays exactly the
    /// bandless one. The claim flavour absorbs the header and grows nothing. Decided at launch
    /// from the authored steps; runtime step_add never resizes the window.
    static func cardBandGrowth(config: InspectConfig?) -> CGFloat {
        guard let config, config.construction == .card,
              let band = config.topBand,
              band.flavor.lowercased() != "claim",
              topBandBlockingStep(in: config.introSteps ?? [], claim: false) == nil
        else { return 0 }
        let compressionSavings: CGFloat = 38   // (38−20) + (46−26), the cardBand* metrics
        return max(0, cardTopBandResolvedHeight(flavor: band.flavor,
                                                 override: band.height) - compressionSavings)
    }

    /// Content scale for a size-mode name; `InspectLayoutProtocol.scaleFactor` delegates here.
    /// Every mode name is retired and scales at 1.0: type size is the `density` knob, window size
    /// is explicit `width`/`height`.
    public static func scale(mode: String?) -> CGFloat {
        1.0
    }

    /// Bento-grid layout constants, used instead of literals at call sites.
    public enum Bento {
        /// Width of the compact plist-bound detail sheet (BentoPlistDetailSheet)
        static let plistDetailWidth: CGFloat = 460
        /// Frame for the inline BentoInlineDetailView when `inlineExpansion` is on
        static let inlineDetailSize = CGSize(width: 720, height: 540)
        /// Default icon size for `contentType: "icon"` bento cells
        static let defaultIconSize: CGFloat = 48
        /// Default icon size for `contentType: "mixed"` cells; smaller to leave room for title + subtitle
        static let mixedIconSize: CGFloat = 40
    }
}

/// The resolved construction. Derived, never stored, so `chrome` stays the author's own words.
extension InspectConfig {
    var construction: InspectSizes.Construction? {
        InspectSizes.Construction.resolve(preset: preset, authoredChrome: chrome)
    }

    /// Whether this flow's steps may be drawn as migration bodies. Two spellings: `chrome:
    /// "migration"` (shell and bodies) or `migrationBodies: true` (bodies inside a host's own shell).
    var usesMigrationBodies: Bool {
        migrationBodies == true || construction == .migration
    }
}

/// Band heights. Claim: window/3 = 200 (override clamped 100–220), inside the 600 window. Device and
/// logo: 118 (override clamped 100–118), growing the window to 820×680 (`InspectSizes.cardBandGrowth`).
func cardTopBandResolvedHeight(flavor: String, override: Double?) -> CGFloat {
    if flavor.lowercased() == "claim" {
        if let h = override { return CGFloat(min(max(h, 100), 220)) }
        return (CardM.card.height / 3).rounded()
    }
    if let h = override { return CGFloat(min(max(h, 100), 118)) }
    return 118
}
