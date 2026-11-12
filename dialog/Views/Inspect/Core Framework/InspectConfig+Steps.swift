//
//  InspectConfig+Steps.swift
//  dialog
//
//  IntroStep, the step model for presets 5 and 7. Its canonicalization, bookend projection and
//  ListItem rows live in the InspectConfig+StepCanonicalization, +Bookends and +ListItem files.
//

import Foundation
import SwiftUI

extension InspectConfig {
    /// One destination in the splash chooser (chrome "splash").
    struct SplashEnvironmentConfig: Codable, Sendable {
        /// Reported as `selection: <environmentKey> = <id>`; nil reports the title instead.
        let id: String?
        let title: String
        let subtitle: String?

        var value: String { id ?? title }
    }

    /// Shows a step only when an earlier pick matches. The pick may hold several comma-joined
    /// values: `anyOf` needs one of them listed, `noneOf` needs none. With `anyOf`, an unanswered
    /// key hides the step; with only `noneOf`, it excludes nothing.
    struct ShowWhenConfig: Codable, Sendable, Equatable {
        let key: String
        var anyOf: [String]?
        var noneOf: [String]?

        func matches(_ values: [String: String]) -> Bool {
            let picked = Set((values[key] ?? "").split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
            if let anyOf, !anyOf.isEmpty, picked.isDisjoint(with: anyOf) { return false }
            if let noneOf, !picked.isDisjoint(with: noneOf) { return false }
            return true
        }
    }

    /// The acknowledgement a review step asks for when its plan removes something for good.
    struct ReviewAcknowledge: Codable, Sendable {
        let label: String
        let subtitle: String?
    }

    struct IntroStep: Codable, Identifiable, Sendable {
        let id: String

        // Two independent axes: `stepType` is the renderer, `phase` is the step's role in the
        // flow. `canonicalizeStep` fills both at decode.
        var stepType: String?                   // renderer, e.g. "options" | "installation" | "processing"
        var phase: String?                      // "intro" | "main" | "outro" (nil = main)

        /// The one definition of the renderer; every consumer reads this, never `stepType`.
        /// The stored property stays optional because synthesized Codable would otherwise require the key.
        var resolvedStepType: String {
            stepType ?? "standard"
        }

        /// The one definition of the phase. The `stepType` fallback covers a step that skipped
        /// canonicalization.
        var resolvedPhase: String {
            if let phase { return phase }
            if let stepType, InspectConfig.stepPhaseValues.contains(stepType) { return stepType }
            return "main"
        }

        var heroImage: String?                  // Path or "SF=symbolname"
        let heroImageShape: String?             // "circle" | "roundedSquare" | "square" | "none"
        let heroImageSize: Double?              // Default: 200
        let heroImageSFSymbolColor: String?     // Hex color for SF Symbol (defaults to accentColor)
        let heroImageSFSymbolWeight: String?    // "regular" | "medium" | "bold" (default: "medium")
        let heroImagePadding: Double?           // Inset padding in points (nil = auto ~4%, 0 = none)

        var title: String?
        let subtitle: String?
        /// Short chip above the title; the screen's own, not the flow's.
        let eyebrow: String?
        var content: [GuidanceContent]?

        /// Cadence steps only: title/claim shown when the run finishes. Localized via the step
        /// sidecar like `title`; absent, the running copy stays.
        let completedTitle: String?
        let completedMessage: String?

        /// Headline when a run stops; same contract as `completedTitle`.
        let failedTitle: String?

        // ItemConfig aliases, folded into title/content by `canonicalizeStep` and cleared there so a
        // canonical step has one spelling per fact; the secure-field exclusion set only sees `content`.
        var guidanceTitle: String?
        var guidanceContent: [GuidanceContent]?

        // The rest of the preset 6 item vocabulary, so `items[]` decodes as steps. `icon` folds
        // into `heroImage` and `itemOverlay` into `stepOverlay`; `displayName` and
        // `completedStatus` are not aliases and stay.
        /// Short flow label for the rail and step list; not a synonym of `title`.
        let displayName: String?
        var icon: String?
        var itemOverlay: DetailOverlayConfig?
        let completedStatus: String?
        /// Per-step override of config.observeOnly.
        let observeOnly: Bool?
        /// Whether Continue/Back stay live while this step processes (default true).
        let allowNavigationDuringProcessing: Bool?
        /// Consecutive steps sharing a group render under one rail heading; nil means ungrouped.
        let group: String?
        /// Opt-in: the preset 6 header draws `heroImage` as a rounded tile beside the heading.
        let headerIconTile: Bool?

        // Grid picker
        let gridItems: [GridItemConfig]?
        let gridColumns: Int?                   // Default 3 (journey grid: 4)
        let gridSelectionMode: String?          // "single" (default) | "multiple" | "none"
        let gridSelectionKey: String?           // userValues key
        let gridPreferenceKey: String?          // Preferences plist key

        // Wallpaper picker
        var wallpaperCategories: [WallpaperCategory]?
        var wallpaperThumbnailHeight: Double?          // Default 120
        var wallpaperSelectionKey: String?
        var wallpaperPreferenceKey: String?            // Preferences plist key
        var wallpaperShowPath: Bool?                   // Default false
        var wallpaperConfirmButton: String?            // nil = instant select
        var wallpaperMultiSelect: Int?                 // Number of monitors (default 1)
        var wallpaperLayout: String?                   // "grid" (default) | "row" | "categories"

        // Option picker
        var optionKey: String?                         // Selection key (falls back to step.id)
        var optionCards: [OptionCard]?
        var optionMultiSelect: Bool?                   // Default false
        var optionLayout: String?                      // "cards" | "grid" | "rows" (default)
        var optionConfirmButton: String?               // nil = instant select
        var optionPreferenceKey: String?               // Preferences plist key

        // Dock picker
        var dockMode: String?                          // "flavors" (default) | "build"
        var dockFlavors: [DockFlavor]?                 // flavors mode
        var dockItems: [DockItem]?                     // build mode
        var dockLayout: String?                        // "narrow" (560pt outro measure), the only value
        var dockSelectionKey: String?                  // Selection key (falls back to step.id)
        var dockPreferenceKey: String?                 // Preferences plist key
        var dockConfirmButton: String?                 // nil = instant
        var dockShowUnavailable: Bool?                 // Default false
        var dockApplyMode: String?                     // "additive" (default) | "replace"
        /// Optional "keep my Dock" card; absent offers no decline.
        var dockDecline: DeclineOption?

        // Media carousel
        var mediaItems: [MediaItemConfig]?
        var mediaHeight: Double?                // Default 400
        var mediaAutoplay: Bool?                // Default true
        var mediaShowArrows: Bool?              // Default true
        var mediaShowDots: Bool?                // Default true

        /// Authored facts for the vignette; only `{itemCount}` is resolved from live state.
        let stats: [PresetIntroScreen.OverviewStat]?

        /// Outro receipt rows. `stepId` must name an existing step (resume is index-based); the
        /// answer is read from live selections at render time.
        let receipt: [ReceiptRow]?

        struct ReceiptRow: Codable, Sendable {
            let stepId: String                      // Step to return to on Change
            let label: String
            let selectionKey: String?               // Defaults to `stepId`
            let fallbackValue: String?              // Shown when the value has no friendlier form
        }
        let showProgressDots: Bool?             // Default false

        let actionButtonText: String?           // Button text during processing
        /// Splash chooser destinations; two or more turn the mark into a picker button.
        let environments: [SplashEnvironmentConfig]?
        let environmentLabel: String?
        /// Key the splash pick is reported under (default "environment") on stdout `selection:`,
        /// the event file's `formValues` and the result file.
        let environmentKey: String?
        /// Shown only when an earlier pick matches; otherwise skipped like a satisfied `skipIfComplete`.
        let showWhen: ShowWhenConfig?
        /// Multi-select options: "switch" draws a trailing switch per row; absent draws a checkbox.
        let optionControl: String?
        /// A cadence step runs only the entries in this multi-select step's resolved plan (`OptionPlan`).
        let cadenceSelectionKey: String?
        /// Timeout for each derived entry, in seconds (default 600).
        let cadenceTimeout: Double?
        /// A review step shows this multi-select step's resolved plan.
        let reviewSelectionKey: String?
        /// Asked on the review step when the plan holds an option with `exposure`; Continue waits for it.
        let reviewAcknowledge: ReviewAcknowledge?
        let learnMoreText: String?
        /// Shown inside the splash by its link (page, video, image or local path); without it the link is not drawn.
        let learnMoreURL: String?
        let continueButtonText: String?         // Default "Continue"
        let backButtonText: String?             // Default "Back"
        /// Provisioning shell only: "text" or "chevron".
        let backButtonKind: String?
        let showBackButton: Bool?               // Default true (except first step)
        let continueAction: String?             // "next" | "skip" | "portal" | custom script

        let condition: String?                  // Script or expression to evaluate
        let skipIfComplete: Bool?               // Skip when the selection key already has a value
        let revisitable: Bool?                  // Never auto-skip, even when satisfied

        // Window reposition when this step appears
        let windowPosition: String?             // "left" | "right" | "center" | "topleft" …
        let windowPositionOffset: Double?       // Edge offset in points

        let substeps: [SubStep]?                // stepType "substeps": gated in-page mini-wizard

        // MARK: - Installation mode
        let installationMode: String?           // "progress" | "processing" | nil
        let installationLayout: String?         // "grid"; anything else renders the list
        var items: [ListItem]?                  // Rows, not steps: never counted on the rail; `listitem: add` appends
        let autoAdvanceOnComplete: Bool?        // Default false
        let processingMessage: String?

        // Deployment step (stepType "deployment")
        let sideMessages: [String]?             // Step-level rotating messages
        let sideMessageInterval: Int?           // Seconds (default 8)
        let popupButtonText: String?
        let autoEnableButton: Bool?             // Hold Continue until all items complete (default true)
        let autoEnableButtonText: String?       // Default "Done"

        // Carousel step (stepType "carousel")
        let bannerHeight: Int?                  // Points (default 100)
        let progressFormat: String?             // "{completed} of {total} completed"

        // Processing step
        let processingDuration: Int?            // Countdown seconds; presence selects the processing type
        let processingMode: String?             // "simple" (auto-advance at 0) | "progressive" (wait for trigger)

        let allowOverride: Bool?                // Default false
        let waitSmallOverrideTime: Int?         // Seconds before the small "Skip" link (default 30)
        let waitLargeOverrideTime: Int?         // Seconds before the large override button (default 60)
        let overrideButtonText: String?         // Default "Skip"

        let autoAdvance: Bool?                  // Default false: show the result banner and wait
        let autoResult: String?                 // "success" (default) | "failure"
        let successMessage: String?             // Default "Step Completed"
        let failureMessage: String?             // Default "Step Failed"
        let waitForExternalTrigger: Bool?       // Never auto-complete; wait for a success:/failure: command
        let requireManualConfirm: Bool?        // success:/failure: update state but do not advance
        let selectable: Bool?                  // Guide picker: this step can be selected (`pickerConfig`)

        var stepOverlay: DetailOverlayConfig?   // Per-step help overlay

        // Card chrome ("chrome": "card")
        let cardPanel: CardPanel?               // Layout inferred from field presence
        /// Per-step footer line (Markdown); on the outro it replaces the step dots.
        /// `InspectConfig.footerText` is the flow-wide line.
        let footerNote: String?

        let plistMonitors: [PlistMonitor]?
        let monitorRefreshInterval: Double?     // Seconds (default 1.0)
        let completionMode: String?             // "any" (default) | "all" — how completionTriggers combine

        // Cadence: side messages advance as monitored attributes are satisfied.
        /// Decodes from a bare entries array or a grouped object; see `CadencePayload`.
        var cadence: CadencePayload?
        var cadenceStyle: String?               // "manifest" (default) | "spotlight" | "bento"
        /// Continue while the cadence or card installation runs: "confirm" (default, live) | "hidden" | "disabled".
        /// On completion or halt Continue is live regardless. `confirmIncomplete` decides what
        /// pressing it does. Unknown values resolve to confirm (`CadenceContinueVisibility.resolve`).
        var continueWhileRunning: String?
        /// Whole-cadence estimate in seconds; split across entries without their own `timeEstimate`.
        var totalTimeEstimate: Double?
        /// Visible final-screen countdown in seconds; the dialog then closes itself via the
        /// result-file path with exit 4.
        var autoCloseAfter: Double?
        /// Ask before Continue skips unfinished work. Default on for cadence and card-installation steps.
        var confirmIncomplete: Bool?
        /// Plain-styled secondary beside the primary. Card arms only.
        var secondaryButtonText: String?
        /// "back" (default) | "next".
        var secondaryAction: String?

        /// Carousel form: "cards" (default) or "manifest". Unknown values render cards.
        var carouselStyle: String?
        var cadenceInterval: Double?            // Native poll seconds (default: monitorRefreshInterval, then 0.6)
        var cadenceMinDwell: Double?            // Default minimum seconds per entry (0.6); per-entry minDwell overrides
        var cadenceRef: ManagedValueRef?        // Read the entries from a managed preference

        /// The entries, whichever shape they were authored in.
        var cadenceEntries: [CadenceEntry]? {
            cadence?.entries
        }
        let brandColorRef: ManagedValueRef?     // Cadence tint color from a managed preference
        let showCadenceRecap: Bool?             // Outro: tile row and summary line, only if the cadence completed
        let heroBadge: String?                  // "check": completion badge on the hero
        let contentAnchor: String?              // "center" | "top" (default on P5/P6/P7); pairs with contentAlign
        let contentAlign: String?               // "leading" (default on P5/P6/P7) | "center"; see ContentStance

        // MARK: - Software bundles (stepType "software")
        /// How the step type is composed; for "software": bundles | detail | handoff.
        let layout: String?
        /// Per-step state words merged over the defaults, e.g. `{"done": "Processed"}`.
        /// Keys: done, active, queued, failed, blocked, removed (`ProvisioningVocabulary.merged`).
        let stateWords: [String: String]?
        /// Journey grid cards are the step's `cadence` entries, each pacing an equal share of the
        /// items; off, one card per item.
        let divisionMode: Bool?
        /// Division mode: shares become whole and this message shows on the last card until every
        /// item is processed, which also gates the primary button.
        let finalMessage: String?
        /// Division mode: "disabled" | "hidden" | "none" decouple the primary button from
        /// `finalMessage`. See `JourneyDivision.resolve`.
        let holdPrimary: String?
        /// `layout: "grid"`: accent progress bar under the cards.
        let gridProgress: Bool?
        /// Grid header "N / M" counter (default true).
        let showGridCounter: Bool?
        /// Footer "N of M <word>" line (default true); false falls back to `footerNote`.
        let showProgressLine: Bool?
        /// `layout: "grid"`: "tile" (default) | "glass".
        let gridStyle: String?
        var bundles: [SoftwareBundle]?          // layout "bundles" and "detail"
        let handoffs: [SoftwareHandoff]?        // layout "handoff"
        let bundleId: String?                   // layout "detail": which bundle this screen shows
        let backLabel: String?                  // detail breadcrumb
        var softwareNote: String?
        /// Agent identity line; rendered only when supplied.
        var agentLabel: String?

        var portalConfig: PortalConfig?         // Overrides the global portalConfig

        // Showcase step
        var showcaseGradientColors: [String]?   // Hex (fallback: highlightColor)
        var showcaseTextColor: String?          // Hex (fallback: white 90%)
        var showcaseImageHeight: Double?        // Ratio 0.0-1.0 (default 0.6)

        /// Guide step copy; `canonicalizeStep` folds it into `content` as a text block.
        var guideText: String?

        // Bento step
        var bentoLayout: String?                // "split" | "grid" (default)
        var bentoSidebarRatio: Double?          // 0.25-0.45 (default 0.35), split only
        var bentoCells: [GuidanceContent.BentoCellConfig]?
        var bentoColumns: Int?                  // Default 2
        var bentoRowHeight: Double?             // Points (default 140)
        var bentoGap: Double?                   // Points (default 12)
        /// Review aid: prints each cell's authored slot on it. Off by default.
        var bentoShowSlots: Bool?
        var bentoTintColor: String?             // Base hex for auto-tinted cells
        var bentoSidebarContent: [GuidanceContent]?

        // Assistant step
        var assistantImageHeight: Double?       // Ratio 0.0-1.0 (default 0.4)
        let heroBackgroundColor: String?        // Hex
        let skipButtonText: String?             // Secondary button left of Continue

        // Media step
        var mediaSide: String?                  // "left" | "right" (default)
        /// "viewer" (default for multi-item steps) | "split".
        var mediaLayout: String?
        /// Viewer stage: "light" (default) | "surface" | "#RRGGBB".
        var mediaStage: String?
        var mediaRatio: Double?                 // Panel width ratio 0.2-0.8 (default 0.5)
        /// "fill" crops; "fit" and absence show the whole image (`MediaFit`).
        var mediaFit: String?

        // Guide-step monitoring
        let paths: [String]?
        let plistKey: String?
        let expectedValue: String?
        let evaluation: String?                 // "equals" | "boolean" | "exists" | "contains"


        // Grouped spellings; stored properties so the parity test and unknown-key detector see them.
        var wallpaper: WallpaperPayload?
        var option: OptionPayload?
        var dock: DockPayload?
        var media: MediaPayload?
        var bento: BentoPayload?
        var showcase: ShowcasePayload?
        var assistant: AssistantPayload?
        /// One screen of a step that pages through several (`screens`); the step keeps one
        /// position in the flow. Card chrome only. Distinct from the `substeps` wizard.
        struct CardScreen: Codable, Sendable {
            let id: String?
            let title: String?                  // nil → the step's own title
            let subtitle: String?
            let content: [GuidanceContent]?
            let cardPanel: CardPanel?
            let continueButtonText: String?
            let continueAction: String?
        }
        var screens: [CardScreen]?

        var software: SoftwarePayload?
        var portal: PortalConfig?               // Grouped spelling of `portalConfig`

        /// Export step: writes the selection to files. Nothing is written until a button is
        /// pressed. Has no flat twins, so `canonicalizeStep` leaves it alone.
        struct ExportPayload: Codable, Sendable {
            let items: [ExportItem]?            // Copied in list order
            let destination: String?            // Directory ("~" expands); created on write, same names replaced
            let editors: [String]?              // editor bundle ids, preferred first; only installed ones offered
            let revealButtonText: String?       // Default "Reveal in Finder"; both actions write first
        }
        struct ExportItem: Codable, Sendable {
            let source: String                  // Absolute or ~ path
            let name: String?                   // Default: last path component
            let note: String?                   // e.g. "6 icons"
        }
        var export: ExportPayload?

        // MARK: - Per-type payload containers
        // Grouped spelling of the flat keys (`wallpaper: { categories: [...] }`); each member is
        // its flat key minus the family prefix. `canonicalizeStep` folds grouped onto flat, grouped
        // wins with an advisory.

        /// Decodes from a bare entries array (`"cadence": [...]`) or a grouped object.
        struct CadencePayload: Codable, Sendable {
            let entries: [CadenceEntry]?
            let style: String?
            let interval: Double?
            let minDwell: Double?
            let ref: ManagedValueRef?

            private enum CodingKeys: String, CodingKey {
                case entries, style, interval, minDwell, ref
            }

            init(from decoder: Decoder) throws {
                if let bare = try? decoder.singleValueContainer().decode([CadenceEntry].self) {
                    entries = bare
                    style = nil; interval = nil; minDwell = nil; ref = nil
                    return
                }
                let c = try decoder.container(keyedBy: CodingKeys.self)
                entries = try c.decodeIfPresent([CadenceEntry].self, forKey: .entries)
                style = try c.decodeIfPresent(String.self, forKey: .style)
                interval = try c.decodeIfPresent(Double.self, forKey: .interval)
                minDwell = try c.decodeIfPresent(Double.self, forKey: .minDwell)
                ref = try c.decodeIfPresent(ManagedValueRef.self, forKey: .ref)
            }
        }

        struct WallpaperPayload: Codable, Sendable {
            let categories: [WallpaperCategory]?
            let confirmButton: String?
            let layout: String?
            let multiSelect: Int?
            let preferenceKey: String?
            let selectionKey: String?
            let showPath: Bool?
            let thumbnailHeight: Double?
        }

        struct OptionPayload: Codable, Sendable {
            let cards: [OptionCard]?
            let confirmButton: String?
            let key: String?
            let layout: String?
            let multiSelect: Bool?
            let preferenceKey: String?
        }

        struct DockPayload: Codable, Sendable {
            let applyMode: String?
            let confirmButton: String?
            let decline: DeclineOption?
            let flavors: [DockFlavor]?
            let items: [DockItem]?
            let layout: String?
            let mode: String?
            let preferenceKey: String?
            let selectionKey: String?
            let showUnavailable: Bool?
        }

        struct MediaPayload: Codable, Sendable {
            let autoplay: Bool?
            let fit: String?
            let height: Double?
            let items: [MediaItemConfig]?
            let layout: String?                 // "split" | "viewer"
            let stage: String?                  // "light" (default) | "surface" | "#RRGGBB"
            let ratio: Double?
            let showArrows: Bool?
            let showDots: Bool?
            let side: String?
        }

        struct BentoPayload: Codable, Sendable {
            let cells: [GuidanceContent.BentoCellConfig]?
            let columns: Int?
            let gap: Double?
            let layout: String?
            let rowHeight: Double?
            let showSlots: Bool?
            let sidebarContent: [GuidanceContent]?
            let sidebarRatio: Double?
            let tintColor: String?
        }

        struct ShowcasePayload: Codable, Sendable {
            let gradientColors: [String]?
            let imageHeight: Double?
            let textColor: String?
        }

        struct AssistantPayload: Codable, Sendable {
            let agentLabel: String?
            let imageHeight: Double?
        }

        struct SoftwarePayload: Codable, Sendable {
            let bundles: [SoftwareBundle]?
            let note: String?
            /// Canonical home of `agentLabel`; `AssistantPayload` keeps a legacy spelling and
            /// `software` wins when both are authored.
            let agentLabel: String?
        }
    }

    // MARK: - Card panel

    /// Right-hand panel of a card step. Shape follows presence: `image` → screenshot frame,
    /// `paragraphs` → text card, otherwise `stat`/`pairs` → facts card.
    struct CardPanel: Codable, Sendable {
        let caption: String?            // Uppercase caption ("TAKES ABOUT")
        let stat: String?               // Hero stat ("2 minutes")
        let pairs: [CardPanelPair]?     // Label/value rows
        let image: String?
        let video: String?              // Looping clip; overrides image
        let imageTitle: String?         // Chrome-strip label
        let paragraphs: [String]?
        let layout: String?             // "max": the player fills the column
    }

    struct CardPanelPair: Codable, Sendable {
        let label: String
        let value: String
    }

    // MARK: - Brand config

    /// One brand in the brand picker; its fields override the branding when selected.
    struct BrandConfig: Codable, Identifiable, Sendable {
        let id: String
        let displayName: String
        let subtitle: String?
        let logoPath: String?           // Picker card logo
        let sfSymbol: String?           // Alternative to logoPath

        let highlightColor: String?
        let accentBorderColor: String?
        let footerBackgroundColor: String?
        let footerTextColor: String?
        let footerText: String?
        let logoConfigPath: String?     // Overrides logoConfig.imagePath
        let button1Text: String?
        let button2Text: String?
        let introTitle: String?
        let outroTitle: String?
        let introButtonText: String?
        let outroButtonText: String?
    }

    /// One item of a grid picker.
    struct GridItemConfig: Codable, Identifiable, Sendable {
        private let _id: String?
        let imagePath: String?
        let sfSymbol: String?
        let title: String?
        let subtitle: String?
        let description: String?
        let value: String?                      // Stored when selected (defaults to _id)

        /// Must be stable across accesses (SwiftUI identity and selection go by it), so the
        /// chain ends in a fixed string, never `UUID()`.
        var id: String {
            _id ?? value ?? imagePath ?? sfSymbol ?? title ?? subtitle ?? description ?? "grid-item"
        }

        enum CodingKeys: String, CodingKey {
            case _id = "id"
            case imagePath, sfSymbol, title, subtitle, description, value
        }
    }

    /// One carousel item: image, GIF or video URL.
    struct MediaItemConfig: Codable, Identifiable, Sendable {
        /// Stable across accesses, as `GridItemConfig.id`.
        var id: String { url ?? title ?? caption ?? "media-item" }
        let url: String?                        // URL or local path
        let caption: String?                    // Below the media
        let title: String?                      // Above the media
    }

}
