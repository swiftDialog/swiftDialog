//
//  InspectConfig+CommonTypes.swift
//  dialog
//
//  Config types shared across presets: progress bar, logo, deferral, intro/summary screens,
//  wallpaper, option/dock cards, substeps, preferences output, localization.
//

import Foundation
import SwiftUI

extension InspectConfig {
    struct ProgressBarConfig: Codable, Sendable {
        let enableStatusColors: Bool?        // Enable status-based colors (default: false)
        let showCompletionState: Bool?       // Show green when all steps complete
        let showBlockingState: Bool?         // Show orange for blocking/required items
        let colors: ProgressBarColors?

        struct ProgressBarColors: Codable, Sendable {
            let normal: String?      // Default: "#007AFF" (blue)
            let complete: String?    // Default: "#34C759" (green)
            let blocking: String?    // Default: "#FF9500" (orange)
            let error: String?       // Default: "#FF3B30" (red)
        }

        var normalColor: Color {
            Color(hex: colors?.normal ?? "#007AFF")
        }

        var completeColor: Color {
            Color(hex: colors?.complete ?? "#34C759")
        }

        var blockingColor: Color {
            Color(hex: colors?.blocking ?? "#FF9500")
        }

        var errorColor: Color {
            Color(hex: colors?.error ?? "#FF3B30")
        }
    }

    /// Logo overlay for preset layouts.
    struct LogoConfig: Codable, Sendable {
        /// Which brands the footer carries: "vendor" (default) | "both". The customer half comes
        /// from the selected `BrandConfig`.
        let lockup: String?
        let imagePath: String                   // Logo image path (light mode / default)
        let imagePathDark: String?              // Dark mode variant (falls back to imagePath)
        let position: String?                   // "footer" (default) | "header" | "none"; legacy corner
                                                 // spellings still map forward, case-insensitively
        let padding: Double?                    // Points from the edges (default: 20)
        let maxWidth: Double?                   // Points (default: 80)
        let maxHeight: Double?                  // Points (default: 80)
        let opacity: Double?                    // 0.0-1.0 (default: 0.6 for bottom, 1.0 for top)
        let backgroundColor: String?            // Background tint hex (default: transparent)
        let backgroundOpacity: Double?          // 0.0-1.0 (default: 0.2)
        let cornerRadius: Double?               // Background corner radius (default: 8)
        let verticalOffset: Double?             // Points: negative=up, positive=down (default: 0)
        let introVerticalOffset: Double?        // Intro phase nudge (falls back to verticalOffset)
        let outroVerticalOffset: Double?        // Outro phase nudge (falls back to verticalOffset)
        let introScale: Double?                 // Intro screen scale (default: 1.5)
        let outroScale: Double?                 // Outro/summary screen scale (default: 1.0)
        let scale: Double?                      // Main phase scale (default: 1.0)
        let showOnIntro: Bool?                  // Default: true
        let showOnMain: Bool?                   // Default: true
        let showOnSummary: Bool?                // Default: true
        /// Fraction of the mark's height kept as margin around it; 0 (default) fills the box,
        /// ~0.1–0.15 suits a wide wordmark. Marks are sized by their trimmed visible ink, so this
        /// is the only margin they get. Draw sites clamp it to 0…0.6.
        let logoClearSpace: Double?

        /// `logoClearSpace` for the renderers: absent = 0, unclamped. Every seat reads this
        /// rather than spelling the fallback itself.
        var clearSpace: CGFloat { CGFloat(logoClearSpace ?? 0) }

        /// `position` parsed to the authored vocabulary. Every reader goes through this.
        var resolvedPosition: BrandPosition { BrandPosition(authored: position) }

        /// The bottom-footer logo for an appearance: nil unless `resolvedPosition == .footer`.
        func footerPath(isDark: Bool) -> String? {
            guard resolvedPosition == .footer else { return nil }
            return resolvedPath(isDark: isDark)
        }

        /// The appearance-resolved mark with no position gate, for chromes that seat it themselves.
        func resolvedPath(isDark: Bool) -> String? {
            if isDark, let dark = imagePathDark { return dark }
            return imagePath
        }
    }

    /// Flow-level top band: a device render, a claim, or the brand mark. Per-flow so the
    /// payload's top edge does not move between steps. Absent → no band.
    struct TopBandConfig: Codable, Sendable {
        let flavor: String                  // "claim" (absorbs the header) | "device" | "logo"
        let height: Double?                 // override; claim clamps 100–220 (default h/3),
                                            // device/logo clamp 100–118 (default 118)
        let image: String?                  // device: the render; logo: overrides logoConfig
        let ground: String?                 // "wash" (default; clamped 0.16) | "image"
                                            // (claim always paints full-strength gradient)
        let groundPalette: [String]?        // gradient colors; nil → gradientPalette → design fallback
        let groundImage: String?            // ground "image": cover-filled, wash fallback
    }

    /// User-initiated deferral, shared across presets. Integrates with ignitecli's deferral
    /// system: env vars, exit code 10, result file.
    struct DeferralConfig: Codable, Sendable {
        let enabled: Bool?                      // Default: false; also on when IGNITECLI_DEFER_ENABLED=true
        let buttonText: String?                 // Menu button label (default: "Not Now")
        let options: [DeferOption]?             // Falls back to the IGNITECLI_DEFER_OPTIONS env var
        let exitCode: Int?                      // Exit code on deferral (default: 10)
    }

    struct DeferOption: Codable, Sendable {
        let duration: String                    // ignitecli duration: "3m", "20m", "1h", "4h", "1d", "tomorrow"
        let label: String?                      // Label override; generated from duration if nil
    }

    // MARK: - Preset1/2 Multi-Screen Flow

    /// Intro screen shown before the items view in Preset1/2.
    struct PresetIntroScreen: Codable, Sendable {
        let title: String?                      // Main heading
        let subtitle: String?                   // Smaller text below title
        let heroImage: String?                  // Path, URL, or "sf=symbolname"
        let heroImageShape: String?             // "circle" | "roundedSquare" | "none" (default: "none")
        let heroImageSize: Double?              // Size in points (default: 200)
        /// Rich content blocks. Every layout renders them after its composed body, never
        /// replacing it.
        let content: [GuidanceContent]?
        let buttonText: String?                 // Continue button label (default: "Get Started")
        let showBackButton: Bool?               // Default: false (it is the first screen)

        // Layouts. "overview": greeting under a hero band, stat tiles, footnote and app-list
        // link. "welcome": centered greeting, app-icon strip, numbered steps. "explainer":
        // three illustrated Step 1-2-3 cards.
        let layout: String?                     // nil/"centered" (default) | "overview" | "welcome" | "explainer"
        let userBadge: String?                  // Identity chip text (e.g. enrollment email); initials derived
        let userBadgePosition: String?          // "bandLeading" (default) | "bandTrailing" | "footerLeading"
                                                // | "footerLeading"; read by the overview intro only
        let stats: [OverviewStat]?              // Stat tiles; "{itemCount}" in value → live item count.
                                                // Values are authored; the UI never invents figures.
        let footnote: String?                   // "overview": small policy/ownership line, bottom-left
        let linkText: String?                   // "overview"/"welcome": accent app-list link → item-list popover
        let steps: [String]?                    // "welcome": numbered what-to-expect lines ({userName} substituted)
        let showAppIcons: Bool?                 // "welcome": icon strip from the real item list (default: true)
        let explainerSteps: [ExplainerStep]?    // "explainer": the three Step-N cards
        let explainerStepLabel: String?         // "explainer": eyebrow format, {n} = 1-based index (default "Step {n}")

        struct OverviewStat: Codable, Sendable {
            let value: String                   // Big figure ("{itemCount}", "~12 min", "2.4 GB")
            let label: String                   // Caption below it ("apps to install")
        }

        /// One "explainer" card. Built-in vignettes ("start" | "install" | "launch") draw with the
        /// configured item icons; `image` overrides with a custom picture.
        struct ExplainerStep: Codable, Sendable {
            let title: String                   // "Start" / "Install" / "Launch"
            let body: String                    // One-sentence expectation
            let art: String?                    // Built-in vignette (default by position)
            let image: String?                  // Custom illustration path (overrides art)
        }
    }

    /// Summary/bento screen shown after items complete in Preset1/2.
    struct PresetSummaryScreen: Codable, Sendable {
        let title: String?                      // Main heading
        let subtitle: String?                   // Smaller text below title
        let heroImage: String?                  // Path, URL, or "sf=symbolname"
        let heroImageShape: String?             // "circle" | "roundedSquare" | "none" (default: "none")
        let heroImageSize: Double?              // Size in points (default: 120)
        /// Rich content blocks, same contract as `PresetIntroScreen.content`: rendered after the
        /// layout's composed body, never replacing it.
        let content: [GuidanceContent]?
        /// Decoded and in the schema but read by nothing on this surface; `bentoCells` is what
        /// enables the grid. Kept so configs that author it keep validating.
        let bentoLayout: String?                // "grid" — accepted, inert on this surface
        let bentoCells: [GuidanceContent.BentoCellConfig]?  // Bento cell definitions
        let bentoColumns: Int?                  // Grid columns (default: 2)
        let bentoRowHeight: Double?             // Row height in points (default: 120)
        let bentoGap: Double?                   // Gap between cells (default: 12)
        let buttonText: String?                 // Final button label (default: "Close")
        let autoTransition: Bool?               // Auto-show when all items complete (default: true)
        let itemStrip: String?                  // Preset 4 finish page's per-item strip:
                                                // "always" (default) | "never" | "auto" (while it fits)

        // Outro layouts. Strings support {userName}, {managed:domain:key|fallback}, and
        // live-count tokens {itemCount} / {completedCount} / {failedCount} / {skippedCount}.
        let layout: String?                     // nil/"centered" | "dock" | "receipt" | "nextsteps"
        let caption: String?                    // "dock": line under the picker (default explains additive apply)
        let infoNote: String?                   // "receipt": info banner above the footer
        let footnote: String?                   // "nextsteps": footer-left line ("Something missing? …")
        let linkText: String?                   // Footer-left accent link → per-item status popover
        let sectionTitle: String?               // "nextsteps": section header (default "Suggested next")
        let nextSteps: [NextStep]?              // "nextsteps": suggested action rows
        // The dock keys mirror `DockPayload`. They are `var` because `InspectConfig.init(from:)`
        // folds the grouped `dock` container onto them after decoding; the type stays
        // synthesized-Codable so its JSON keys are its stored property names.
        var dockFlavors: [DockFlavor]?          // "dock": prebuilt dock presets to pick from;
                                                // the picker lays out up to 3 columns and wraps
        var dockApplyMode: String?              // "additive" (default) | "replace"
        var dockConfirmButton: String?          // confirm text (nil = instant)
        var dockDecline: DeclineOption?         // the "Keep my Dock as it is" card
        var dockItems: [DockItem]?              // build mode: candidate apps
        /// The picker's measure. "narrow" is the 560pt outro arrangement, the only value the
        /// schema, the model and the renderer share. Not a mode; `dockMode` is.
        var dockLayout: String?                 // "narrow" (560pt outro measure)
        var dockMode: String?                   // "flavors" | "build" (default: flavors when dockFlavors is set)
        /// Inert on this surface: the outro dock picker has no preferences write-through.
        var dockPreferenceKey: String?          // preferences plist key — inert on this surface
        var dockSelectionKey: String?           // selection storage/emit key
        var dockShowUnavailable: Bool?          // show install-greyed items
        /// The grouped authoring form, folded onto the flat keys above at decode and then nil'd.
        var dock: InspectConfig.IntroStep.DockPayload?

        /// One "nextsteps" action row. `action` is a path or URL handed to NSWorkspace when
        /// Open is clicked; nil hides the button.
        struct NextStep: Codable, Sendable {
            let title: String                   // "Sign in to Slack"
            let subtitle: String?               // "Your team workspace is acme.slack.com"
            let icon: String?                   // Icon path/SF (default: matching item icon by title, else app.fill)
            let action: String?                 // App path or URL to open
            let buttonText: String?             // Row button label (default "Open")
        }
    }

    // MARK: - Shared Wallpaper Types

    /// A wallpaper category for the wallpaper picker (shared by GuidanceContent and IntroStep).
    struct WallpaperCategory: Codable, Sendable {
        let title: String                           // e.g. "Full HD", "4K"
        let images: [WallpaperImage]
        let featured: Bool?                         // Surface first with a ★
    }

    struct WallpaperImage: Codable, Sendable {
        let path: String                            // Full path to the wallpaper image
        let thumbnail: String?                      // Uses path if nil
        let title: String?
    }

    // MARK: - Shared Option-Picker + Dock Types

    /// A selectable option card, the "pick one from a set" primitive for browser / email /
    /// PDF-viewer / appearance / dock-flavor choices. Shared by GuidanceContent
    /// (`option-picker` block) and IntroStep (`options` step).
    struct OptionCard: Codable, Identifiable, Sendable {
        var id: String { cardId }
        let cardId: String                          // decoded from "id"
        let label: String                           // primary label
        let subtitle: String?                       // secondary description
        let sfSymbol: String?                       // SF Symbol glyph for the card
        let iconPath: String?                       // image/app-icon path (overrides sfSymbol)
        let value: String?                          // value emitted on select (defaults to id)
        let dockPreview: [DockItem]?                // optional embedded Dock preview (dock-flavor cards)

        /// Whether this option can be chosen: `nil` (selectable, default), `"installed"`,
        /// `"pending"`, or `"unavailable"` (rendered disabled). Authored by the orchestrator,
        /// which knows the inventory; put the reason in `subtitle`.
        let state: String?

        /// Built-in tile artwork: `light` · `dark` · `auto` (miniature desktops for the appearance
        /// choice). Precedence: `iconPath`, then `preview`, then `sfSymbol`; an unknown name falls
        /// through to the icon.
        let preview: String?

        /// What choosing this costs the user ("~25 min · 1 restart"). Effort only; `exposure`
        /// carries the risk.
        let effort: String?

        /// What not choosing it costs ("3 days unpatched"). The only field that takes the
        /// warning tint.
        let exposure: String?

        /// Marks the recommended option: badge and pre-selection. Only the first is honoured;
        /// ignored on an `unavailable` card.
        let recommended: Bool?

        /// Why it is recommended, in the user's terms ("back soonest", "no restart").
        let recommendReason: String?

        /// Fired on commit, after the `select:` emit, through the PresetActions "url" path, so
        /// custom schemes work unchanged.
        let action: String?
        let url: String?

        /// Right-aligned measurable ("12 GB", "—"). Rendered only in `layout: "rows"`; the
        /// column is dropped when no card has one.
        let differentiator: String?

        /// Cards sharing a category render under one labelled band with a count. Absent on
        /// every card = ungrouped. Grid/cards layouts only.
        let category: String?

        enum CodingKeys: String, CodingKey {
            case cardId = "id", label, subtitle, sfSymbol, iconPath, value, dockPreview, state, preview
            case effort, exposure, recommended, recommendReason, action, url, differentiator, category
            case includes, cancels, runOrder, runMessage
        }

        /// Multi-select steps: options this one includes when picked. Included options show on
        /// and fixed, and run without being picked themselves.
        var includes: [String]?
        /// Options this one cancels when it runs. Cancelled options show off and fixed, and do
        /// not run even if picked. A cancel beats an include.
        var cancels: [String]?
        /// Run position when a progress step derives its entries from the cards: ascending,
        /// ties in card order, absent = 0.
        var runOrder: Int?
        /// The progress line while this option runs; absent, "<label>…".
        var runMessage: String?

        /// An `unavailable` card is shown with its reason but cannot be picked.
        var isSelectable: Bool { state != "unavailable" }
    }

    /// A named jump point on a slot-picker strip ("Now", "Last slot").
    struct SlotQuickPick: Codable, Sendable {
        let label: String
        let at: String        // ISO-8601 instant, or "now" / "deadline"
    }

    /// One label/value fact row on a slot-picker card ("Duration" / "About 25 minutes, one restart").
    struct SlotFact: Codable, Sendable {
        let label: String
        let value: String
    }

    /// A single dock item (app): label + absolute path, optional SF Symbol for the preview tile.
    struct DockItem: Codable, Sendable {
        let label: String
        let path: String                            // e.g. /Applications/Foo.app
        let sfSymbol: String?                       // glyph when no icon is available
    }

    /// An explicit "change nothing" choice for a picker. It is a real option in the grid, not a
    /// hidden skip, and picker-neutral (dock and wallpaper share it).
    struct DeclineOption: Codable, Sendable {
        let label: String                           // "Keep my Dock as it is"
        let subtitle: String?                       // "Nothing added. You can pick a layout later…"
        /// Value emitted when declining (default "none"), so a consumer can tell an explicit
        /// decline from an unanswered step.
        let value: String?
    }

    /// A named group of software: a view over the step's `items` by item id, so monitoring,
    /// install progress and `recheck:` keep working per item. Carries only what a group needs
    /// and an item cannot know.
    struct SoftwareBundle: Codable, Identifiable, Sendable {
        var id: String { bundleId }
        let bundleId: String                        // decoded from "id"
        let title: String
        let summary: String?                        // "Design tools, fonts"
        /// Download size as authored text ("6.8 GB"). Never computed; omit rather than estimate.
        let size: String?
        let itemIds: [String]                       // members, in display order
        /// The command that will run, shown verbatim. Authored, because only the admin knows it.
        let command: String?
        let commandNote: String?                    // e.g. "No admin password needed"
        /// Group action. `{missing}` / `{total}` / `{installed}` in `label` resolve from live
        /// detection.
        let action: BundleAction?

        struct BundleAction: Codable, Sendable {
            let label: String                       // supports {missing}/{installed}/{total}
            let action: String?                     // request (default) | app | url | custom
            let url: String?                        // app: bundle id or path · url: the URL
            let requestId: String?                  // request: id the orchestrator dispatches on
        }

        enum CodingKeys: String, CodingKey {
            case bundleId = "id", title, summary, size, itemIds, command, commandNote, action
        }
    }

    /// One handoff row: a place to go, or something to launch. Each row names its target so a
    /// launch that does nothing is diagnosable.
    struct SoftwareHandoff: Codable, Identifiable, Sendable {
        var id: String { handoffId }
        let handoffId: String                       // decoded from "id"
        let title: String
        let subtitle: String?                       // "62 apps · updated daily"
        let detail: String?                         // the longer sentence under a card
        /// What the row launches, printed next to it: a URL scheme or an app path.
        let target: String?
        let targetNote: String?                     // "opens the desktop app"
        let buttonLabel: String?                    // "Launch" / "Open Self Service"
        let action: String?                         // app | url | custom | request
        let url: String?
        let requestId: String?
        let icon: String?
        /// Item whose install state gates the row; not yet installed shows as unavailable with
        /// the reason.
        let itemId: String?

        enum CodingKeys: String, CodingKey {
            case handoffId = "id", title, subtitle, detail, target, targetNote,
                 buttonLabel, action, url, requestId, icon, itemId
        }
    }

    /// A named preset dock ("flavor") — a curated ordered set of dock items.
    struct DockFlavor: Codable, Identifiable, Sendable {
        var id: String { flavorId }
        let flavorId: String                        // decoded from "id"
        let name: String
        let summary: String?
        let sfSymbol: String?                       // card glyph
        let items: [DockItem]
        /// The pre-selection, as `OptionCard.recommended`, so Continue is live on open.
        let recommended: Bool?

        enum CodingKeys: String, CodingKey {
            case flavorId = "id", name, summary, sfSymbol, items, recommended
        }
    }

    /// One gated substep inside a `substeps` step: icon + title + text, optional media
    /// (image/video), optional action.
    struct SubStep: Codable, Identifiable, Sendable {
        /// Stable identity; a computed `UUID()` is never correct for an `Identifiable`.
        var id: String { subId ?? title ?? sfSymbol ?? text ?? "substep" }
        let subId: String?                          // decoded from "id"
        let title: String?
        let text: String?
        let sfSymbol: String?                       // glyph above the title
        let iconPath: String?                       // image/app-icon path (overrides sfSymbol)
        let media: String?                          // image or video path shown as a card
        let mediaLoop: Bool?                        // seamless-loop a video media (default: false)
        /// How the picture occupies the band: `inline` (default) | `split` | `fill`, resolved by
        /// `MediaLayout` with the same words guidance blocks use.
        let mediaLayout: String?
        let action: String?                         // "url" | "request" | app path | "none"
        let url: String?                            // URL for action:"url" (or x-apple.systempreferences:)
        let requestId: String?                      // request id for action:"request"
        let actionButtonText: String?              // label for the per-substep action button

        enum CodingKeys: String, CodingKey {
            case subId = "id", title, text, sfSymbol, iconPath, media, mediaLoop, mediaLayout,
                 action, url, requestId, actionButtonText
        }
    }

    // MARK: - Preferences Output

    /// User preference collection written to a plist, for osquery, MDM device labeling and
    /// profile assignment.
    struct PreferencesOutputConfig: Codable, Sendable {
        let plistPath: String                   // Plist to write, under /Library/Preferences for example
        let writeOnStepComplete: Bool?          // Default: true
        let writeOnDialogExit: Bool?            // Default: true
        let mergeWithExisting: Bool?            // Merge with existing plist values (default: true)
        let staticValues: [String: String]?     // Key-value pairs always included
    }

    // MARK: - Localization Config

    /// Language sidecar files with translated intro step text: flat JSON keyed like
    /// "{stepId}.title", "{stepId}.content.0.content".
    struct LocalizationConfig: Codable, Sendable {
        let languages: [String: String]   // langCode → relative file path, e.g. "de": "lang/de.json"
        let selectionKey: String?         // gridSelectionKey holding the choice (default: "preferredLanguage")
        let defaultLanguage: String?      // "auto" = system locale, "de" = fixed, nil = no default
    }

    // MARK: - Intro Steps (Preset5)

    /// `IntroStep`, the steps of preset5's linear flow, lives in InspectConfig+Steps.swift.
}

// MARK: - Density

/// The authored reading-comfort tier. It writes to `typeScale` only, through
/// `InspectLayoutProtocol`; `measureScale` never sees it, so strings grow and layout does not.
/// An unknown tier renders at `standard` and the resolver says why.
enum InspectDensity: String, Equatable, CaseIterable {
    /// The unmarked default.
    case standard
    /// 10% larger type in the same window.
    case comfortable

    /// Fonts and icon point sizes only; never reaches `measureScale` or a raw `scaleFactor:` parameter.
    var typeScale: CGFloat {
        switch self {
        case .standard: return 1.0
        case .comfortable: return 1.1
        }
    }

    /// A resolved tier plus one advisory line when the authored value was overruled or is only
    /// partly honoured. Nil in the normal cases.
    struct Resolved: Equatable {
        let tier: InspectDensity
        let advisory: String?
    }

    /// Presets whose step bodies read type through the metrics seam. `BookendScreenView` reads
    /// it for every preset, so density always reaches intro/outro screens; step bodies only on
    /// these. A test re-derives this set from the sources, so it moves with the code.
    static let stepBodySeamPresets: Set<String> = ["preset5"]

    /// The one resolver. An unknown tier and Preset 4 both overrule the authored value and say so.
    /// - Parameters:
    ///   - authored: the raw `density` value as written in the config, if any.
    ///   - preset: the config's preset, in any spelling the size table accepts.
    static func resolve(authored: String?, preset: String) -> Resolved {
        guard let authored else { return Resolved(tier: .standard, advisory: nil) }

        guard let tier = InspectDensity(rawValue: authored.lowercased()) else {
            let known = InspectDensity.allCases.map(\.rawValue).joined(separator: "|")
            return Resolved(tier: .standard,
                            advisory: "unknown density '\(authored)' — rendering at 'standard'. "
                                    + "Known tiers: \(known)")
        }

        let canonical = InspectPresetName.normalizePreset(preset)

        // The 550x110 toast cannot grow with its type; larger type there is a clipping bug.
        if tier != .standard, canonical == "preset4" {
            return Resolved(tier: .standard,
                            advisory: "density '\(authored)' ignored on preset4 — the toast idiom "
                                    + "pins 'standard' because its window cannot grow with the type")
        }

        // Partial coverage, stated rather than discovered. See stepBodySeamPresets.
        if tier != .standard, !stepBodySeamPresets.contains(canonical) {
            return Resolved(tier: tier,
                            advisory: "density '\(authored)' applies to this config's intro/outro "
                                    + "screens only — \(canonical) step content still reads the "
                                    + "legacy one-knob scale and renders at 'standard' until its "
                                    + "type sites move onto the metrics seam")
        }

        return Resolved(tier: tier, advisory: nil)
    }
}
