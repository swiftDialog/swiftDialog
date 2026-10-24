//
//  InspectConfig+GuidanceContent.swift
//  dialog
//
//  `GuidanceContent`, the content-block model shared by all presets, plus `CardStepBlocks` folds.
//

import Foundation
import SwiftUI

extension InspectConfig {
    /// An array that drops elements it cannot decode instead of failing the whole container,
    /// so one malformed phase does not discard the block.
    struct LossyArray<Element: Codable & Equatable>: Codable, Equatable, RandomAccessCollection {
        let elements: [Element]

        var startIndex: Int { elements.startIndex }
        var endIndex: Int { elements.endIndex }
        subscript(position: Int) -> Element { elements[position] }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var out: [Element] = []
            while !container.isAtEnd {
                if let value = try? container.decode(Element.self) {
                    out.append(value)
                } else {
                    // Consume the element so the cursor advances.
                    _ = try? container.decode(AnyIgnored.self)
                }
            }
            self.elements = out
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            for element in elements { try container.encode(element) }
        }

        private struct AnyIgnored: Decodable {
            init(from decoder: Decoder) throws { _ = try? decoder.singleValueContainer() }
        }
    }

    /// One phase of a `phase-tracker`. Decodes from a bare label string or an object with time,
    /// detail and state; both shapes can mix in one array.
    struct PhaseSpec: Codable, Equatable, Sendable {
        let label: String
        /// Free text such as "09:12", "now · 62%" or "~25 min"; never computed.
        let time: String?
        /// The sentence the vertical variant shows under the label.
        let detail: String?
        /// Authored state; absent derives it from `currentPhase`.
        let state: PhaseState?
        /// Relative segment width: a coarse bucket rather than a parsed duration, since `time` is free text.
        /// Absent means `regular`, so unsized tracks stay equal.
        let chunkSize: ChunkSize?

        /// Failure is a state of a real phase; there is no separate error phase, so the track length is fixed.
        enum PhaseState: String, Codable, Equatable, Sendable {
            case done, current, pending, blocked, failed
        }

        /// Coarse share of the track; the smallest still fits a word.
        enum ChunkSize: String, Codable, Equatable, Sendable {
            case nano, mini, regular, long

            var weight: Double {
                switch self {
                case .nano:    return 1
                case .mini:    return 2
                case .regular: return 4
                case .long:    return 7
                }
            }
        }

        init(label: String, time: String? = nil, detail: String? = nil,
             state: PhaseState? = nil, chunkSize: ChunkSize? = nil) {
            self.label = label; self.time = time; self.detail = detail
            self.state = state; self.chunkSize = chunkSize
        }

        private enum CodingKeys: String, CodingKey { case label, time, detail, state, chunkSize }

        init(from decoder: Decoder) throws {
            // A bare label is a phase with nothing else.
            if let single = try? decoder.singleValueContainer(),
               let label = try? single.decode(String.self) {
                self.label = label
                self.time = nil; self.detail = nil; self.state = nil; self.chunkSize = nil
                return
            }
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.label = try c.decode(String.self, forKey: .label)
            self.time = try? c.decode(String.self, forKey: .time)
            self.detail = try? c.decode(String.self, forKey: .detail)
            // An unknown state is ignored and derived from currentPhase.
            self.state = (try? c.decode(String.self, forKey: .state)).flatMap(PhaseState.init(rawValue:))
            self.chunkSize = (try? c.decode(String.self, forKey: .chunkSize)).flatMap(ChunkSize.init(rawValue:))
        }
    }

    struct GuidanceContent: Codable, Sendable {
        let type: String                // "text" | "highlight" | "warning" | "info" | "success" | "bullets" | "arrow" | "image" | "image-carousel" | "video" | "webcontent" | "portal-webview" | "checkbox" | "dropdown" | "radio" | "toggle" | "slider" | "textfield" | "button" | "status-badge" | "comparison-table" | "phase-tracker" | "progress-bar" | "compliance-card" | "compliance-header" | "feature-table" | "bento-grid" | "stat-row" | "checklist"
        var content: String?            // The actual text content (or button label for type="button") - optional for status monitoring types

        /// Alias for `content` (configs write `{"type": "paragraph", "text": "…"}`). Only `normalized` reads
        /// it; `content` is canonical.
        var text: String?
        var items: [String]?            // Array of items - e.g. bullets

        /// Folds accepted synonyms into the canonical fields once, before blocks reach a renderer.
        static func normalized(_ block: GuidanceContent) -> GuidanceContent {
            guard block.content == nil, let text = block.text, !text.isEmpty else { return block }
            var out = block
            out.content = text
            return out
        }
        /// Turns a callout (`warning` | `info` | `success`) into a card with an icon tile and this heading.
        /// Absent, the block renders as the plain callout.
        var title: String?
        let numbered: Bool?             // For bullets: use numbered circle icons (1.circle.fill, 2.circle.fill, ...) instead of a single icon

        // Stat-row fields (type="stat-row"): figure and caption tiles. Values are authored or measured tokens;
        // Preset 5 also resolves {cadenceCount} / {cadenceDuration} / {cadenceTimeouts}.
        var stats: [StatCell]?          // Tiles, left to right
        // Checklist fields (type="checklist"): marker lines, numbered on intros, check/info/warn on outros.
        var checklist: [ChecklistLine]? // Lines, top to bottom
        var color: String?              // Optional color override (hex format)
        var bold: Bool?                 // Whether to display in bold
        var visible: Bool?              // Show/hide this block dynamically (default: true) - can be updated via plistMonitor or update_guidance command
        /// Shows the block only when a recorded value matches (a pick, a script's `select:`, or an outcome such as
        /// `items.done`). Same rule as a step's `showWhen`, on every surface that draws blocks.
        var showWhen: InspectConfig.ShowWhenConfig?

        // Prose fields (type="prose"): text written over IPC while open (`content=` replaces, `append=` adds,
        // `stream=end` closes).
        /// Keep the newest line in view as content arrives (default: true). Stream state travels in `state`
        /// ("streaming" / "ended"), set only over IPC; see `GuidanceProseBlock.streaming(from:)`.
        var follow: Bool?

        // Image-specific fields (for type="image")
        let imageShape: String?         // "rectangle" | "square" | "circle" - shape/clipping for the image
        let imageWidth: Double?         // Custom width in points (default: 400)
        let imageBorder: Bool?          // Show border/shadow around image (default: true)
        var caption: String?            // Caption text displayed below the image
        /// How media occupies the payload band: "fill" | "split" | "inline" (default).
        let mediaLayout: String?

        // Video-specific fields (for type="video")
        let autoplay: Bool?             // Auto-play video on load (default: false)
        let videoHeight: Double?        // Video player height in points (default: 300)
        let videoLoop: Bool?            // Seamless ambient loop with hidden controls (AVPlayerLooper) — default: false

        // Webcontent-specific fields (for type="webcontent")
        let webHeight: Double?          // Web view height in points (default: 400)

        // Portal-webview fields (type="portal-webview"): an embedded authenticated portal.
        let portalURL: String?          // Override portal URL for this block (uses global portalConfig if nil)
        let portalPath: String?         // Path within portal (e.g., "/device/self-service")
        let portalHeight: Double?       // Height of embedded portal view in points (default: 400)
        // No header or refetch toggles: `EmbeddedWebFrame` always shows the source strip, and retry appears only on
        // failure.

        // Interactive element fields (for type="checkbox" | "dropdown" | "radio" | "toggle" | "slider")
        let id: String?                 // Unique identifier for storing user input
        let required: Bool?             // Whether this input is required for step completion
        let options: [String]?          // Options for dropdown/radio selections
        /// Per-option second line, parallel to `options`; may be shorter than `options`.
        let optionDetails: [String]?
        /// Per-option leading icon, parallel to `options`: "SF=name", a bare SF Symbol name, or an image path
        /// (absolute or relative to `iconBasePath`). If any option has one, every row reserves the slot.
        let optionIcons: [String]?
        /// Right-hand annotation on a `form-section` heading, e.g. "optional".
        let note: String?
        /// Per-option trailing button label on `action-rows`, parallel to `options`; empty means no button.
        let optionActions: [String]?
        /// URL each row's action opens (System Settings deep links included), parallel to `optionActions`.
        let optionURLs: [String]?
        /// Options in a `select-list`/`select-grid` that cannot be unchecked; always counted as selected.
        let requiredOptions: [String]?
        var value: String?              // Default/current value (for checkbox, toggle, dropdown, radio) or numeric value as string for slider
        var helpText: String?           // Optional help text displayed in info popover (i icon)

        // Slot-picker fields (type="slot-picker"): a continuous time window up to a marked deadline.
        let windowHours: Int?                 // length of the strip from "now"
        let granularityMinutes: Int?          // handle snaps to this
        let deadline: String?                 // ISO-8601 with offset; the marked tick
        let deadlineNote: String?
        let defaultAt: String?                // ISO-8601, or "now" / "deadline"
        let quickPicks: [InspectConfig.SlotQuickPick]?
        let facts: [InspectConfig.SlotFact]?
        let continueFormat: String?           // "Schedule for {time}"
        let continueAtNow: String?            // "Install now"
        let secondaryAtLater: String?         // "Install now instead"

        // Slider-specific fields (for type="slider")
        let min: Double?                // Minimum value for slider (default: 0)
        let max: Double?                // Maximum value for slider (default: 100)
        let step: Double?               // Step increment for slider (default: 1)
        let unit: String?               // Unit label to display (e.g., "%", "GB", "minutes")
        let discreteSteps: [SliderStep]? // Optional array of discrete step values with labels

        struct SliderStep: Codable, Sendable {
            let value: Double           // Numeric value for this step
            let label: String           // Display label (e.g., "1 minute", "30 minutes", "1 hour")
        }

        // Textfield-specific fields (for type="textfield")
        var placeholder: String?        // Placeholder text when empty
        let secure: Bool?               // Password mode (hide characters)
        let inherit: String?            // Value source: "plist:path:key", "defaults:domain:key", "env:NAME", "field:itemId.fieldId"
        let regex: String?              // Validation pattern (regex)
        let regexError: String?         // Error message when regex fails
        let maxLength: Int?             // Maximum character limit
        // Preset 6 only; Preset 5 renders plain text fields.
        let textfieldMode: String?      // "date" | "file" | "editor" | "confirm" (nil = plain field)
        /// `drop-zone`: collect several dropped files rather than replace one.
        var multiple: Bool?
        /// `drop-zone` with `multiple`: the most files kept (the first dropped stay).
        var limit: Int?
        let fileType: String?           // mode="file": space-separated tokens — "folder", "image", "movie"/"video", "audio", or filename extensions (classic --textfield grammar)
        let initialPath: String?        // mode="file": directory the open panel starts in (default: user home)
        let editorHeight: Double?       // mode="editor": editor height in points (default: 120)

        // Button-specific fields (for type="button")
        var action: String?             // Button action: "url", "shell", "request", "custom" (triggers callback). `var`: canonicalization infers it from the payload when absent.
        let url: String?                // URL to open (for action="url")
        let shell: String?              // Shell command to execute (for action="shell")
        let requestId: String?          // Abstract identifier for script callback (for action="request", e.g., "profiles-install")
        let targetBadge: TargetBadgeConfig?  // Badge the request callback names
        let buttonStyle: String?        // Button style: "bordered" (default), "borderedProminent", "plain"

        // The badge a `request` action names in its callback (`request:<id>:<item>:<badgeIndex>`); the script
        // that answers sets its state over IPC.
        struct TargetBadgeConfig: Codable, Sendable {
            let blockIndex: Int             // Index in guidanceContent array to update
        }

        // Overlay trigger (for any content type)
        let opensOverlay: Bool?         // When true, clicking this content block opens the item's overlay (default: false)

        // Specimen framing (any block): names the component and what to author for it. Absent, no frame.
        var specimen: String?           // the component's authored name, e.g. "handoff-list"
        var specimenNote: String?       // one line of when-to-use, shown beneath the frame

        // Status monitoring fields (for type="status-badge" | "comparison-table" | "phase-tracker" | "progress-bar")
        var label: String?              // Display label for status components
        var state: String?              // Current state (e.g., "enabled", "disabled", "active", "enrolled")
        var icon: String?               // SF Symbol icon name for status-badge
        var autoColor: Bool?            // Auto-assign colors based on state (default: true)
        var expected: String?           // Expected value for comparison-table
        var actual: String?             // Actual value for comparison-table
        var expectedLabel: String?      // Custom label for expected column (default: "Expected")
        var actualLabel: String?        // Custom label for actual column (default: "Actual")
        var expectedIcon: String?       // SF Symbol icon for expected value (comparison-table columns mode)
        var actualIcon: String?         // SF Symbol icon for actual value (comparison-table columns mode)
        var highlightCells: Bool?       // Enable bold/larger text and stronger tinted backgrounds for columns mode (default: false)
        var expectedColor: String?      // Custom color for expected column (hex: "#FF3B30"), overrides match-based coloring
        var actualColor: String?        // Custom color for actual column (hex: "#34C759"), overrides match-based coloring
        var category: String?           // Category name for grouping comparison-tables
                                        // A merged table carries the category as its `label`.
        var currentPhase: Int?          // Current phase number (1-based) for phase-tracker
        /// Phase-tracker phases: bare label strings or objects with time, detail and state (`PhaseSpec`).
        typealias PhaseSpec = InspectConfig.PhaseSpec

        let phases: LossyArray<PhaseSpec>?
        var style: String?              // Display style: "stepper" (default), "progress", "checklist" for phase-tracker; "indeterminate" (default) or "determinate" for progress-bar
        var progress: Double?           // Progress value (0.0 to 1.0) for determinate progress-bar

        // Image carousel fields (type="image-carousel")
        /// How each slide fills its frame: "fill" (crop, default) | "fit" (whole picture).
        let imageFit: String?           // "fill" (default, crops) | "fit" (shows the whole picture)
        let images: [String]?           // Array of image paths for carousel
        let captions: [String]?         // Optional captions for each image (array must match images length)
        let imageHeight: Double?        // Custom height in points (default: 300)
        let showDots: Bool?             // Show dot page indicators (default: true)
        let showArrows: Bool?           // Show left/right arrow navigation buttons (default: true)
        let autoAdvance: Bool?          // Enable automatic slide advancement (default: false)
        let autoAdvanceDelay: Double?   // Seconds between auto-advances (default: 3.0)
        let transitionStyle: String?    // Transition animation: "slide" (default) | "fade"
        var currentIndex: Int?          // Current image index (0-based) for dynamic updates

        // Compliance card fields (type="compliance-card")
        var categoryName: String?       // Category name displayed in card header
        var passed: Int?                // Number of passed items in category
        var total: Int?                 // Total number of items in category
        var cardIcon: String?           // SF Symbol icon for category (displayed in header)
        var checkDetails: String?       // Optional compact bullet-point details to display inside card (newline-separated, supports Unicode symbols)

        // Feature table fields (for type="feature-table")
        let columns: [FeatureTableColumn]?  // Column definitions with labels and optional icons
        let rows: [FeatureTableRow]?        // Row definitions with feature text and boolean values per column
        /// Multi-row comparison table with headers drawn once. `var` because `foldComparisonChecks`
        /// (in `canonicalizeBlocks`) folds single-row blocks into it at decode.
        var checks: [ComparisonCheck]?

        // MARK: - Advisory

        /// Advisory rows. `detail`, `deadline` and `duration` are separate fields so each can be read on its own.
        let findings: [AdvisoryFinding]?
        /// Small caps heading above the rows, e.g. "2 things to fix", "What changed".
        let sectionLabel: String?
        /// The line under the rows: provenance, reassurance, or what happens next.
        let footnote: String?

        struct AdvisoryFinding: Codable, Sendable {
            /// An `.app` bundle, image path or SF Symbol name. Absent, the row shows only its state glyph.
            let icon: String?
            /// "error" | "warning" | "success": the glyph and the row's only colour.
            let state: String?
            /// Named in the user's terms ("macOS is three versions behind"), not a policy label.
            let title: String
            /// Why it matters, in one sentence.
            let detail: String?
            /// When it is due, e.g. "overdue 3 days" or "due Fri 9 Aug".
            let deadline: String?
            /// What it costs the user, e.g. "~25 min · 1 restart".
            let duration: String?
        }

        struct FeatureTableColumn: Codable, Sendable {
            let label: String               // Column header label (e.g., "Safari", "Chrome")
            let icon: String?               // Optional SF Symbol icon for column header
        }

        struct FeatureTableRow: Codable, Sendable {
            let feature: String             // Feature description text
            let values: [Bool]              // Boolean values for each column (true = checkmark, false = X)
            /// A qualifier under the feature name, e.g. "bundled" or "v16.9 or later".
            let detail: String?
        }

        /// One row of a comparison table; the table owns the column headers.
        struct ComparisonCheck: Codable, Sendable {
            let check: String               // What is being checked
            let required: String            // The requirement
            let found: String               // What was actually found
            /// `true` means pass. Absent, derived from `required == found`.
            let pass: Bool?
            /// Expands this row in place with `note` and an optional action; use it for the row the user can act on.
            let expanded: Bool?
            let note: String?               // Sentence shown when expanded
            let actionLabel: String?        // Button label, e.g. "Update now"
            let actionURL: String?          // Opened via NSWorkspace
        }

        // Wallpaper picker fields (type="wallpaper-picker"): categorized tiles; the selection is a full path.
        // The members `WallpaperPayload` carries are `var` because `canonicalizeBlocks` folds the grouped
        // `wallpaper` container onto them; the rest stay `let`.
        var wallpaperCategories: [WallpaperCategory]?  // Array of image categories
        let wallpaperColumns: Int?                      // Number of columns per row (default: 4) — block-only, no step counterpart
        var wallpaperLayout: String?                    // "categories" (default) | "grid" | "row" - layout mode
        let wallpaperImageFit: String?                  // "fill" (default) | "fit" — block-only, no step counterpart
        var wallpaperThumbnailHeight: Double?           // Height of thumbnail images (default: 100)
        var wallpaperSelectionKey: String?              // Key for storing selection (default: "wallpaper")
        /// Decodes, folds and validates, but is not read at block level (`WallpaperPicker` takes no
        /// `preferenceKey`). Only the step-level `wallpaperPreferenceKey` is applied.
        var wallpaperPreferenceKey: String?             // preferences plist key (osquery/MDM)
        var wallpaperShowPath: Bool?                    // Show file path below selection (default: false)
        var wallpaperConfirmButton: String?             // Optional confirm button text (if set, shows button to confirm selection)
        /// The number of monitors (0 or 1 = single select), not a boolean, unlike `optionMultiSelect`.
        var wallpaperMultiSelect: Int?                  // Number of monitors for multi-select (nil/0 = single select)

        // Option picker fields (type="option-picker"): generic choice cards. `var` because the grouped `option`
        // container folds onto them. `optionKey` matches the step-level spelling.
        var optionKey: String?                          // selection storage/emit key
        var optionCards: [OptionCard]?                      // option cards
        var optionMultiSelect: Bool?                    // allow multiple (default: false)
        var optionLayout: String?                       // "cards" | "grid" | "rows" (default)
        var optionConfirmButton: String?                // confirm text (nil = instant select)
        /// Passed to `OptionPickerView.preferenceKey`, which does not use it. Only the step-level
        /// `optionPreferenceKey` is applied.
        var optionPreferenceKey: String?  // preferences plist key; not read at block level

        /// Grouped authoring forms, folded onto the flat keys by `canonicalizeBlocks` and then cleared, as at
        /// step level. The step's payload types are reused so members stay in sync.
        var option: InspectConfig.IntroStep.OptionPayload?
        var wallpaper: InspectConfig.IntroStep.WallpaperPayload?

        // Dock picker fields (type="dock-picker"). `var` because canonicalizeBlocks folds the grouped `dock`
        // container onto them.
        var dockMode: String?                           // "flavors" (default) | "build"
        var dockFlavors: [DockFlavor]?                  // flavors mode: preset docks
        var dockItems: [DockItem]?                      // build mode: candidate apps
        /// "narrow": the 560 pt measure (`DockPicker.contentMaxWidth`), the only schema value.
        var dockLayout: String?                         // "narrow" (560pt outro measure)
        var dockSelectionKey: String?                   // selection storage/emit key
        /// Decodes, folds and validates, but is not read at block level (`DockPicker` takes no `preferenceKey`).
        /// Only the step-level `dockPreferenceKey` is applied.
        var dockPreferenceKey: String?  // preferences plist key; not read at block level
        var dockConfirmButton: String?                  // confirm text (nil = instant)
        var dockShowUnavailable: Bool?                  // show install-greyed items (default: false — every render site reads `?? false`)
        var dockApplyMode: String?                      // "additive" (default) | "replace"
        /// The "Keep my Dock as it is" card, so a dock-picker block can offer a decline too.
        var dockDecline: InspectConfig.DeclineOption?
        /// The grouped authoring form, folded onto the flat `dock*` keys by `canonicalizeBlocks` and then cleared.
        var dock: InspectConfig.IntroStep.DockPayload?

        // Install list fields (type="install-list"): installation progress rows with icons and status.
        let installItems: [InstallItem]?                // Array of installable items

        struct InstallItem: Codable, Sendable {
            let title: String               // App/item name (e.g., "Microsoft Teams")
            let subtitle: String?           // Optional subtitle (e.g., "Installing...")
            let icon: String?               // Icon path or SF Symbol name
            let status: String?             // "pending" | "wait" | "success" | "fail" | "progress" (static fallback)
            let progress: Double?           // Progress value 0-100 (for status="progress")
            let itemId: String?             // Links to items[] entry for dynamic status from completedItems/downloadingItems
            /// The state in words (Queued, Downloaded, Installed, Verified, Removed, Skipped, Failed).
            /// Absent, derived from `status`.
            let stateLabel: String?
            /// Shown under a failed row, with a retry scoped to that item.
            let failureNote: String?
            let retryLabel: String?
            let retryURL: String?

            // Catalogue row fields (type="detail-rows"). All optional; ignored by install-list.
            let subtitleSymbol: String?     // SF Symbol shown after the subtitle (e.g. "safari" beside "Website")
            let detail: String?             // Multi-line description paragraph shown below the title row
            let actionLabel: String?        // Trailing action button label (e.g. "Open"); nil = no button
            let action: String?             // "url" | "request" | "custom" (see handleRowAction)
            let url: String?                // URL for action="url"
            let requestId: String?          // requestId for action="request"

            // Bento row fields (for BentoCellConfig.rows). Optional; ignored elsewhere.

            /// Whether the item is already present: nil | "installed" | "pending" | "unavailable", as in
            /// `OptionCard.state`. Distinct from `status`, which describes an install run. Config-authored.
            let state: String?

            /// A short trailing fact chip, e.g. "1.2 GB". Never a status.
            let badge: String?

            // Carousel facts reachable from a block: `claim`, `size` and `identifier`, the fields
            // `CarouselCardView` and `CarouselManifestRow` draw.

            /// One line on why this app is included.
            let claim: String?
            /// Download size, e.g. "1.2 GB"; falls back to `badge`.
            let size: String?
            /// Bundle identifier, truncated from the left (`CarouselM.truncatedIdentifier`) so the distinctive end
            /// stays.
            let identifier: String?
        }

        // Bento grid fields (type="bento-grid"): grid layouts with 1x1, 2x1, 1x2 and 2x2 cells.
        let bentoColumns: Int?              // Grid columns (default: 2)
        let bentoRowHeight: Double?         // Base row height in points (default: 140)
        let bentoGap: Double?               // Gap between cells in points (default: 12)
        let bentoTintColor: String?         // Base hex color for auto-tinting cells without explicit backgroundColor
        let bentoCells: [BentoCellConfig]?  // Cell definitions
        /// "hero" | "summary" render `BentoModule` with that arrangement, as the step-level `bentoLayout` does.
        /// "grid", any other value or absence render `BentoGridView`. "split" is a step-only value.
        let bentoLayout: String?

        /// Per-block portal configuration for `portal-webview`, same meaning as `IntroStep.portalConfig`.
        /// Resolution is block, then config, so several portals on one screen are possible.
        let portalConfig: PortalConfig?

        /// Entries for `handoff-list`, the software step's handoff layout as a block. Entries with `detail`
        /// render as cards, the rest as rows. Row status comes from the block's `ProgressContext`
        /// (`completedItems` / `downloadingItems`).
        let handoffs: [SoftwareHandoff]?

        /// Which design `install-list` draws: "rows" (default) is the vertical list; "cards" and "manifest"
        /// are the two carousel designs.
        let installLayout: String?

        // MARK: Software catalogue rows
        // `bundle-list` and `bundle-detail` rows arrive already resolved by the software arm (status and the
        // `SoftwareRowRule.action` fields), since a block can only see three of the five states.
        // The handoff layout uses `handoff-list` as is.

        /// One `bundle-list` row: a bundle as an icon strip with its counted state and action.
        struct BundleRowPayload: Codable, Sendable {
            /// Also the itemId named by `request` actions and detail navigation.
            let bundleId: String
            let title: String
            let summary: String?
            /// Authored download size ("6.8 GB"), never computed.
            let size: String?
            /// One entry per member app, in bundle order.
            let icons: [BundleMemberIcon]?
            /// Counted from live detection (`BundleTally`). Used only when `icons` is empty; `icons` wins when both
            /// exist.
            let installedCount: Int?
            let totalCount: Int?
            /// Whether a `bundle-detail` step exists for this bundle (`hasSoftwareDetail`).
            let hasDetail: Bool
            let actionLabel: String?
            let action: String?
            let actionURL: String?
            let requestId: String?

            enum CodingKeys: String, CodingKey {
                case bundleId = "id", title, summary, size, icons, installedCount, totalCount,
                     hasDetail, actionLabel, action, actionURL, requestId
            }
        }

        /// One member icon in a bundle row's strip: the `AppIconView` inputs plus its resolved status.
        struct BundleMemberIcon: Codable, Sendable {
            let icon: String?
            let appBundleId: String?
            let paths: [String]?
            /// `StepStatus` raw value ("pending" | "active" | "completed" | "failed" | "skipped").
            let status: String?
        }

        /// One `bundle-detail` row: installed, installing, missing and failed each render distinctly.
        struct DetailRowPayload: Codable, Sendable {
            /// The step's `items[]` entry this row resolved from.
            let itemId: String
            let displayName: String
            let icon: String?
            let appBundleId: String?
            let paths: [String]?
            /// `StepStatus` raw value, resolved by the arm; sets the icon ring and status text.
            let status: String?
            /// Version text from the installed bundle; nil when the app is not present.
            let detail: String?
            let actionLabel: String?
            let action: String?
            let actionURL: String?
            let requestId: String?
        }

        /// `bundle-list` rows (`BundleRowPayload`).
        let bundleRows: [BundleRowPayload]?
        /// `bundle-detail` rows (`DetailRowPayload`).
        let detailRows: [DetailRowPayload]?

        /// The command `bundle-detail` shows verbatim in a code frame, and the note under it. Separate keys
        /// from `content` / `note` so a shell command is never read as prose.
        let bundleCommand: String?
        let bundleCommandNote: String?

        // MARK: Media carousel (type = "media-carousel")

        /// A carousel of mixed media (images, GIFs, video files, YouTube/Vimeo embeds), rendered per
        /// `IntroMediaType.detect`. Separate from `image-carousel`, which takes parallel string arrays.
        /// The media step's `mediaStage`, viewer layout and `mediaSide` / `mediaRatio` split are step-only.
        let mediaItems: [MediaItemConfig]?
        /// Carousel height in points (default 400).
        let mediaHeight: Double?
        /// Autoplay video items (default true).
        let mediaAutoplay: Bool?
        /// Show previous/next arrows (default true).
        let mediaShowArrows: Bool?
        /// Show page dots (default true).
        let mediaShowDots: Bool?
        /// "fill" crops each image to its box; "fit" (default) shows the whole image. Same as the step's `mediaFit`.
        let mediaFit: String?

        // MARK: Grid picker (type = "grid-picker")

        /// The grid picker as a block. The selection is stored in `userValues` under `gridSelectionKey`
        /// (default "grid"), comma-joined, and emitted as `select:<key>:<values>` via `SelectionEmission.shouldEmit`.
        /// `gridPreferenceKey` is step-level only.
        let gridItems: [GridItemConfig]?
        /// Grid columns (default 3, as `IntroGridPicker`).
        let gridColumns: Int?
        /// "single" | "multiple" | "none" (default "single").
        let gridSelectionMode: String?
        /// Where the selection is stored and emitted (default "grid").
        let gridSelectionKey: String?

        /// One `stat-row` tile: a figure and caption, authored or from measured tokens.
        struct StatCell: Codable, Sendable {
            var value: String               // Big figure ("{cadenceCount}", "ca. 12 Min.", "2,4 GB")
            var label: String               // Caption below it ("Apps to install")
            /// Optional semantic tint: `ok` | `warning` | `error` | `info` (as `status-badge`). Resolved through the
            /// palette, not a raw colour. Absent, the tile is neutral.
            var state: String?
        }

        /// One checklist line: text, marker style and an optional hint and watch.
        /// Field order matters: the memberwise init is used by tests, so `context` stays last.
        struct ChecklistLine: Codable, Sendable {
            var text: String                // The line
            var marker: String?             // "number" (default: 1-based position) | "check" | "info" | "warn"
            /// Secondary line under `text`: where to look or what to tick.
            var hint: String?
            /// Per-line watch, independent of the step's `paths`/`plistKey`. A line without one is `.unwatched` and
            /// renders as authored; use that for settings that cannot be verified on device.
            var paths: [String]?
            var plistKey: String?
            var expectedValue: String?
            var evaluation: String?
            /// Trailing muted label naming where the setting lives ("General"); `hint` says what to do.
            var context: String?
        }

        // Bento cell configuration for bento-grid.
        struct BentoCellConfig: Codable, Identifiable, Sendable {
            let id: String                  // Unique cell identifier
            let column: Int                 // 0-based column position
            let row: Int                    // 0-based row position
            let columnSpan: Int?            // 1-4 (default: 1)
            let rowSpan: Int?               // 1-2 (default: 1)

            /// Rows in the tile's middle zone, one button each, reusing `InstallItem` as `detail-rows` does.
            /// Tile height follows the count (`BentoRowM.rowsZoneHeight(count:)`).
            let rows: [InstallItem]?

            let contentType: String         // "image" | "text" | "icon" | "mixed"

            let imagePath: String?          // Path to image file
            let imageFit: String?           // "fill" | "fit" (default: "fill")

            let title: String?              // Main title text
            let subtitle: String?           // Secondary text
            /// Title/subtitle size: "small" (14 pt title), "medium" (20 pt, default), "large" (32 pt).
            let textSize: String?
            let textColor: String?          // Hex color for text
            /// Tinted surface: "accent" | "cool" | "warm" | "neutral". Omitted, surfaces rotate. The surface also
            /// sets the text colour.
            let surface: String?
            /// How the detail opens: "sheet", "popover" or "inline" (expands over a dimmed grid). Omitted, the
            /// grid's setting decides, else the sheet (`BentoDetailRoute`).
            let detailPresentation: String?

            let sfSymbol: String?           // SF Symbol name
            let iconSize: Double?           // Icon size in points (default: 48)
            let iconColor: String?          // Hex color for SF Symbol (overrides accentColor)
            let iconWeight: String?         // SF Symbol weight: "ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"

            let backgroundColor: String?    // Hex color for cell background
            let cornerRadius: Double?       // Corner radius (default: 12)

            // Procedural gradient background, replacing the flat backgroundColor when set.
            let backgroundStyle: String?    // nil (flat color) | "gradient" | "mesh"
            let gradientStyle: String?      // "ethereal" | "vivid" | "subtle" (default: "ethereal")
            let gradientPalette: [String]?  // Array of hex colors for gradient palette

            // Small-caps category label above the title, e.g. "Security".
            let label: String?

            /// The pill beside the title ("Beta"); `label` renders above the title.
            var badge: String?

            /// Trailing fine print, e.g. "1.4 GB".
            var meta: String?

            /// Cell-level action, using the same four fields as `InstallItem` and routed through `handleRowAction`.
            /// `var … = nil` keeps them out of the memberwise init used by BentoGridView.
            var actionLabel: String?
            var action: String?
            var url: String?
            var requestId: String?

            // Opens the detail overlay when tapped.
            let detailOverlay: DetailOverlayConfig?

            // If `id` matches a key in ComplianceAggregatorService, the subtitle and icon colour follow the live
            // finding and a click shows a detail popover.
        }

        /// Applies IPC property overrides (from update_guidance / batch_update) to a copy of this block.
        /// Shared by Presets 5 and 6; copy-and-set avoids the type checker's time limit. `content` is left to callers.
        func applyingDynamicProperties(_ props: [String: String]) -> GuidanceContent {
            var b = self
            if let v = props["color"] { b.color = v }
            if let v = props["bold"].flatMap(Bool.init) { b.bold = v }
            if let v = props["visible"].flatMap(Bool.init) { b.visible = v }
            // `stream=end` closes a prose stream; any other value opens it (the router also opens it on
            // `append=`/`line=`).
            if let v = props["stream"] { b.state = v.lowercased() == "end" ? "ended" : "streaming" }
            if let v = props["label"] { b.label = v }
            if let v = props["state"] { b.state = v }
            if let v = props["icon"] { b.icon = v }
            if let v = props["autoColor"].flatMap(Bool.init) { b.autoColor = v }
            if let v = props["expected"] { b.expected = v }
            if let v = props["actual"] { b.actual = v }
            if let v = props["expectedLabel"] { b.expectedLabel = v }
            if let v = props["actualLabel"] { b.actualLabel = v }
            if let v = props["expectedIcon"] { b.expectedIcon = v }
            if let v = props["actualIcon"] { b.actualIcon = v }
            if let v = props["highlightCells"].flatMap(Bool.init) { b.highlightCells = v }
            if let v = props["expectedColor"] { b.expectedColor = v }
            if let v = props["actualColor"] { b.actualColor = v }
            if let v = props["currentPhase"].flatMap(Int.init) { b.currentPhase = v }
            if let v = props["style"] { b.style = v }
            if let v = props["progress"].flatMap(Double.init) { b.progress = v }
            if let v = props["currentIndex"].flatMap(Int.init) { b.currentIndex = v }
            if let v = props["categoryName"] { b.categoryName = v }
            if let v = props["passed"].flatMap(Int.init) { b.passed = v }
            if let v = props["total"].flatMap(Int.init) { b.total = v }
            if let v = props["cardIcon"] { b.cardIcon = v }
            if let v = props["checkDetails"] { b.checkDetails = v }
            return b
        }

        /// Resolves a block identifier, either a numeric string ("2") or a block id, to an index.
        static func resolveBlockIndex(_ identifier: String, in content: [GuidanceContent]) -> Int? {
            if let index = Int(identifier), index >= 0, index < content.count {
                return index
            }
            return content.firstIndex { $0.id == identifier }
        }

        /// Block types that need more than the default text column (see `InspectMetrics.wideContentMaxW`).
        /// Add multi-column renderers here.
        static let wideLayoutTypes: Set<String> = ["bento-grid", "compliance-summary", "findings-list"]
    }

}

// MARK: - Step-level stats on the card layout

/// Folds step-level keys (stats, media, grid items) into blocks for the card arms, which read only
/// blocks. Applied once in `cardBlocks`, shared by all card arms.
enum CardStepBlocks {

    /// Which half of a tile a `resolve` call is for, so the caller can look up `<stepId>.stats.<i>.value|label`.
    enum StatField { case value, label }

    /// Prepends a `stat-row` when the step has stats and no authored one. `resolve` localizes and
    /// substitutes tokens, injected so the fold stays pure.
    static func fold(content: [InspectConfig.GuidanceContent],
                     stats: [InspectConfig.PresetIntroScreen.OverviewStat]?,
                     resolve: (Int, StatField, String) -> String = { _, _, text in text })
    -> [InspectConfig.GuidanceContent] {
        guard let stats, !stats.isEmpty else { return content }
        // An authored block wins, so stats are never drawn twice.
        guard !content.contains(where: { $0.type == "stat-row" }) else { return content }
        guard let block = statRow(from: stats, resolve: resolve) else { return content }
        // Prepended: the strip sits directly under the subtitle.
        return [block] + content
    }

    /// Built by decoding its wire shape (no memberwise init), the same path as an authored block.
    private static func statRow(from stats: [InspectConfig.PresetIntroScreen.OverviewStat],
                               resolve: (Int, StatField, String) -> String)
    -> InspectConfig.GuidanceContent? {
        let payload: [String: Any] = [
            "type": "stat-row",
            "stats": stats.enumerated().map { index, stat in
                ["value": resolve(index, .value, stat.value),
                 "label": resolve(index, .label, stat.label)]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return try? JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: data)
    }

    /// Appends a `media-carousel` when the step has `mediaItems` and no authored one. Appended, since
    /// content comes first. Unset options stay absent so the renderer's defaults apply.
    static func foldMedia(content: [InspectConfig.GuidanceContent],
                          items: [InspectConfig.MediaItemConfig]?,
                          height: Double? = nil, autoplay: Bool? = nil,
                          showArrows: Bool? = nil, showDots: Bool? = nil, fit: String? = nil)
    -> [InspectConfig.GuidanceContent] {
        guard let items, !items.isEmpty else { return content }
        // An authored block wins, so the carousel is never drawn twice.
        guard !content.contains(where: { $0.type == "media-carousel" }) else { return content }
        var payload: [String: Any] = [
            "type": "media-carousel",
            "mediaItems": items.map { item -> [String: Any] in
                var out: [String: Any] = [:]
                if let url = item.url { out["url"] = url }
                if let caption = item.caption { out["caption"] = caption }
                if let title = item.title { out["title"] = title }
                return out
            }
        ]
        if let height { payload["mediaHeight"] = height }
        if let autoplay { payload["mediaAutoplay"] = autoplay }
        if let showArrows { payload["mediaShowArrows"] = showArrows }
        if let showDots { payload["mediaShowDots"] = showDots }
        if let fit { payload["mediaFit"] = fit }
        guard let block = decodeBlock(payload) else { return content }
        return content + [block]
    }

    /// Appends a `grid-picker` when the step has `gridItems` and no authored one. `id` uses each item's
    /// resolved identity so selections match. On the card layout the answer goes to `userValues`, not
    /// Preset 5's `gridSelections`.
    static func foldGrid(content: [InspectConfig.GuidanceContent],
                         items: [InspectConfig.GridItemConfig]?,
                         columns: Int?, selectionMode: String?, selectionKey: String?)
    -> [InspectConfig.GuidanceContent] {
        guard let items, !items.isEmpty else { return content }
        guard !content.contains(where: { $0.type == "grid-picker" }) else { return content }
        var payload: [String: Any] = [
            "type": "grid-picker",
            "gridItems": items.map { item -> [String: Any] in
                var out: [String: Any] = ["id": item.id]
                if let imagePath = item.imagePath { out["imagePath"] = imagePath }
                if let sfSymbol = item.sfSymbol { out["sfSymbol"] = sfSymbol }
                if let title = item.title { out["title"] = title }
                if let subtitle = item.subtitle { out["subtitle"] = subtitle }
                if let description = item.description { out["description"] = description }
                if let value = item.value { out["value"] = value }
                return out
            }
        ]
        if let columns { payload["gridColumns"] = columns }
        if let selectionMode { payload["gridSelectionMode"] = selectionMode }
        if let selectionKey { payload["gridSelectionKey"] = selectionKey }
        guard let block = decodeBlock(payload) else { return content }
        return content + [block]
    }

    /// Decodes a synthesized block from its wire shape (no memberwise init). Internal so
    /// `foldCatalogue` (GuidanceCatalogueBlocks.swift) can share it.
    static func decodeBlock(_ payload: [String: Any]) -> InspectConfig.GuidanceContent? {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        return try? JSONDecoder().decode(InspectConfig.GuidanceContent.self, from: data)
    }
}

// `Sendable` must be declared in the type's own file; conditional on the element.
extension InspectConfig.LossyArray: Sendable where Element: Sendable {}
