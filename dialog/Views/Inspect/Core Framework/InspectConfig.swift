//
//  InspectConfig.swift
//  dialog
//
//  The root inspect config: the JSON shape every preset decodes, with unknown-key advisories
//  and canonicalization at the decode site.
//

import Foundation
import SwiftUI

/// Dynamic coding key for ad-hoc JSON key lookups (e.g. the "title" fallback for "displayName").
struct RawCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
}


// MARK: - Generic option values

/// A JSON scalar in the `options` passthrough map: general dialog options whose values are
/// booleans (e.g. `moveable`) or strings (e.g. `windowbuttons: "min,max"`).
enum OptionValue: Codable, Equatable {
    case bool(Bool)
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // Bool before Int before String keeps each value on its native type.
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Option value must be a boolean, integer, or string")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }

    /// The value as a boolean, accepting common string/int spellings; nil when it is not one.
    var boolValue: Bool? {
        switch self {
        case .bool(let value):
            return value
        case .int(let value):
            return value != 0
        case .string(let value):
            switch value.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
    }

    /// The value as a string, for options that take a string argument.
    var stringValue: String {
        switch self {
        case .bool(let value): return value ? "true" : "false"
        case .int(let value): return String(value)
        case .string(let value): return value
        }
    }
}

// MARK: - Configuration

/// The root config, matching the JSON format. Loaded from the file named by
/// `DIALOG_INSPECT_CONFIG` when the dialog runs with `--inspect-mode`.
struct InspectConfig: Codable, Sendable {
    /// Unknown-key warnings from the most recent decode pass. Cleared before decode and
    /// harvested after by the loading paths in Config.swift.
    static var unknownKeyWarnings: [String] {
        get { unknownKeyWarningStore.value }
        set { unknownKeyWarningStore.value = newValue }
    }
    private static let unknownKeyWarningStore = LockedValue<[String]>([])

    let title: String?
    let message: String?
    let infobox: String?
    let icon: String?
    let iconsize: Int?
    let banner: String?        // Banner image used in some presets; overrides icon
    let bannerHeight: Int?     // Pixels (default: 100)
    let bannerTitle: String?   // Title overlaid on the banner
    let width: Int?
    let height: Int?
    let size: String?  // "compact" | "standard" | "large"; see InspectSizes
    let density: String?  // "standard" | "comfortable"; moves type only, see InspectDensity
    let options: [String: OptionValue]?  // General dialog options (moveable, ontop, windowbuttons, resizable)
    let scanInterval: Int?
    let cachePaths: [String]?
    let cacheExtensions: [String]?
    let sideMessage: [String]?
    let sideInterval: Int?
    let style: String?
    let liststyle: String?
    /// Authored only; nil means the author said nothing. What renders is answered by the derived
    /// `construction` in InspectSizes, and nothing writes this key back.
    let chrome: String?      // "plain" | "sidebar" | "card" | "rail" | "fixture" — see Construction

    /// Opt-in: this flow's steps are migration screens, read through `usesMigrationBodies`.
    /// Intent has to be authored; block roles alone cannot tell a migration body from a
    /// catalogue page. The migration chrome implies it; absent elsewhere means no step is captured.
    let migrationBodies: Bool?
    /// Which end of the card states the step count: "header" (default) or "footer".
    /// See `CardStepCounterPlacement`.
    let stepCounterPlacement: String?
    /// List order for the item-list presets: "completedFirst" (default) | "activeFirst" | "guiIndex".
    let itemSortOrder: String?
    /// Button flavour for the whole flow: "pill" | "rounded"; see InspectButtonShape. Text-only
    /// affordances (Back, Later) are untouched.
    let buttonShape: String?
    /// Accent glow strength: "full" (default) | "soft" | "subtle" | "none" (`InspectGlow`).
    let glow: String?
    let preset: String
    let popupButton: String?
    let highlightColor: String?
    let secondaryColor: String?
    let backgroundColor: String?
    let backgroundImage: String?
    let backgroundOpacity: Double?
    let textOverlayColor: String?
    let gradientColors: [String]?
    let gradientPalette: [String]?  // Hex colors for the procedural gradient banner
    let gradientStyle: String?      // "ethereal" (default) | "vivid" | "subtle"
    let button1Text: String?
    let button1Disabled: Bool?
    let button1Symbol: String?      // SF Symbol for button1, classic --button1symbol grammar
    let button2Text: String?
    let button2Symbol: String?      // SF Symbol for button2, same grammar as button1Symbol
    let enableOnTimer: Double?      // Seconds after launch to enable a disabled button1 (one-shot)
    let receiptsBasePath: String?   // Base dir for `receipt` requirements (default /var/db/receipts)
    /// Where the detection log goes (`DetectionLog`). `DIALOG_DETECTION_LOG` overrides it, but an
    /// env var never reaches a dialog that launchd starts; this key travels with the config.
    let detectionLog: String?
    /// Count receipts instead of naming them (`ReceiptCensus`): every receipt that appears in
    /// `receiptsBasePath` after launch completes the next pending row. Off unless authored.
    let receiptCensus: Bool?
    let button2Visible: Bool?
    let autoEnableButton: Bool?
    let autoEnableButtonText: String?   // Button label once the run has finished and the button is enabled
    let finalButtonText: String?        // Final button text when all items complete (overrides button1Text)
    let hideSystemDetails: Bool?
    let observeOnly: Bool?                  // Disables all user interaction (default: false)
    let autoAdvanceOnComplete: Bool?        // Preset6: go to the next step after marking complete (default: true)
    let autoAdvanceDelay: Double?           // Seconds before auto-advancing (default: 0.5)
    let colorThresholds: ColorThresholds?   // Color thresholds for visualizations
    let plistSources: [PlistSourceConfig]?  // Plists to monitor (compliance dashboards)
    let labels: UnifiedLabels?              // One flat key-value map for all UI text + optional translations
    let uiLabels: UILabels?                 // Legacy: use `labels`
    let complianceLabels: ComplianceLabels? // Legacy: use `labels`
    let instructionBanner: InstructionBannerConfig? // Instruction banner (all presets)
    let pickerLabels: PickerLabels?         // Legacy: use `labels`

    let iconBasePath: String?                // Base path for relative icon paths
    let overlayicon: String?                  // Overlay icon for brand identity badges
    let rotatingImages: [String]?            // Image paths for image rotation
    let imageRotationInterval: Double?      // Seconds between rotations
    let imageShape: String?                  // rectangle | square | circle (preset6)
    let backButtonStyle: String?             // "inline" (inside scroll, default) | "footer" (in footer bar)
    let stepStyle: String?                  // "plain" | "colored" | "cards"
    let listIndicatorStyle: String?         // "letters" | "numbers" | "roman"
    let progressMode: String?                // Preset4: "shared" (one bar, X of Y) | "perItem" | "report" (check list)
    let messageStyle: String?                // Preset4: "info" — each item as a single-answer card, one at a time
    let progressBarConfig: ProgressBarConfig?
    let appearance: String?                 // Force window appearance: "dark" | "light"; nil/"auto" = follow OS
    let logoConfig: LogoConfig?             // Logo overlay (legacy presets)
    let topBand: TopBandConfig?             // Flow-level top border: device | claim | logo
    let successColor: String?               // Hex for success bars/ticks; absent → the design green
    let detailOverlay: DetailOverlayConfig? // Detail flyout overlay
    let helpButton: HelpButtonConfig?
    let actionPipe: String?                 // FIFO path for instant script request delivery
    let triggerFile: String?                // Trigger file path (overrides dev/prod defaults)
    let skipPortal: Bool?                   // Preset5: go directly from intro to outro
    let debugMode: Bool?                    // Ignore completion flags, always start from step 1
    let resumable: Bool?                    // Save progress and resume on relaunch (default: false)
    let showProfilesRow: Bool?              // Log monitor: the "Configuration profiles" row (default true)
    let dateStyle: String?                  // "relative" | "short" | "medium" (default) | "long" | "iso8601"
    let windowPosition: String?             // Anchor at launch: "topright"|"topleft"|"bottomright"|… (Preset4 toast)
    let windowPositionOffset: Double?       // Edge offset in points for windowPosition (default 48)
    /// What a button that would exit does instead: "exit" (default) or "minimize", which sends the
    /// window to the Dock. A button that navigates keeps navigating. See `ButtonExit`.
    let button1Action: String?
    let button2Action: String?
    let greetingNameSource: ManagedValueRef? // Preset3: managed-pref domain+key holding the user's display name
    let completedTitle: String?             // Preset3: main-phase title once all items complete (supports {userName})
    /// Accepted so configs that author it keep validating; no preset draws a top progress strip.
    let showStepProgress: Bool?
    /// Content orientation every step inherits unless it sets its own. P5/P6/P7 default to
    /// top-left; `"center"` restores the centred look for a whole flow. See `ContentStance`.
    let contentAnchor: String?              // "top" | "center"     (vertical)
    let contentAlign: String?               // "leading" | "center" (horizontal)
    let phaseBackground: String?            // Backdrop shared by intro/main/outro: "plain" (default) | "gradient" |
                                            // a ProceduralGradientStyle | "splash"; "banded" is read by the
                                            // setup-assistant journey seat only, others treat it as plain
    let phaseBackgroundSource: ManagedValueRef?     // Managed-pref override for the backdrop style
                                                    // (palette keys: "<key>Palette", "<key>PaletteDark")
    let phaseBackgroundPalette: [String]?           // Brand palette (hex) tinting the backdrop at atmosphere strength
    let phaseBackgroundPaletteDark: [String]?       // Dark-scheme palette (defaults to the light palette)

    // MARK: - IPC (ignitecli Integration)
    let readinessFile: String?              // Readiness signal JSON (default: "{triggerFile}.ready")
    let resultFile: String?                 // JSON result on exit (selections, form values, step statuses)
    let eventFile: String?                   // JSONL step events (step_started, step_completed)
    let deferralConfig: DeferralConfig?

    // MARK: - Log Monitoring (Cross-Preset)
    let logMonitor: LogMonitorConfig?
    let logMonitors: [LogMonitorConfig]?

    // MARK: - Portal/WebView (Preset5)
    let portalConfig: PortalConfig?         // Self-service portal (any authenticated web portal)
    let appConfigSource: AppConfigSource?   // MDM managed preference source for dynamic branding
    let introSteps: [IntroStep]?            // Intro/outro screens before/after the portal (Preset5)
    /// Preset 6's step list. Its root `items[]` were always walked as steps, so they decode here
    /// whether the key is spelled `steps` or `items` (the compat window).
    let steps: [IntroStep]?

    // MARK: - Preferences Output
    let preferencesOutput: PreferencesOutputConfig? // Plist output for user preference collection

    // MARK: - Brand Selection
    let brands: [BrandConfig]?              // Options for the brand picker step
    let brandSelectionKey: String?          // Persistence key for the selected brand (default: "selectedBrand")

    // MARK: - Localization
    let localization: LocalizationConfig?   // Language sidecar files for intro step text

    // MARK: - Brand Palette (Cross-Preset Theming)
    let brandPalette: BrandPalette?         // Named color tokens and logo presets
    /// The whole brand palette from a managed preference domain, light and dark. The profile
    /// wins; the inline `brandPalette` is the fallback. The ref's `key` holds a dictionary of
    /// role → hex and `darkKey` the dark set; a partial dictionary fills only the roles it names.
    let brandPaletteRef: ManagedValueRef?
    /// Show the opt-in debug panel. `DIALOG_INSPECT_DEBUG` or this turns it on.
    let debugPanel: Bool?
    /// Reload the config file whenever it is saved, staying on the current step. An invalid save
    /// keeps the last good version on screen and says why.
    let watch: Bool?
    /// The palette slots for the dark appearance, optional per key; unset slots keep the light
    /// value. `ResolvedPalette(from:dark:scheme:)` is the only place the choice is made.
    let brandPaletteDark: BrandPalette?

    // MARK: - Footer Branding (Cross-Preset)
    let accentBorderColor: String?          // Defaults to highlightColor
    let showAccentBorder: Bool?             // Opt-in 1pt accent ribbon on the window's bottom edge
    let footerBackgroundColor: String?      // Hex
    let footerTextColor: String?            // Hex, for dark backgrounds
    let footerText: String?
    let copyrightText: String?
    let supportText: String?

    // MARK: - Preset1/2 Multi-Screen Flow
    let introScreen: PresetIntroScreen?     // Intro screen before the items view (Preset1/2 only)
    let summaryScreen: PresetSummaryScreen? // Summary screen after items complete (Preset1/2 only)

    /// Rich content blocks for plain-branded's content column. Root-level because that
    /// construction has no step machine. Every authored block is kept; one outside
    /// `plainBrandedPermits(_:)` earns an advisory at the decode site.
    let guidanceContent: [GuidanceContent]?

    /// Block types judged to fit plain-branded's 500pt column, in both appearances. Advisory
    /// only: a type outside the set still renders and earns a warning at the decode site. Not a
    /// schema enum, because the schema file never runs at runtime and an enum there would reject
    /// working configs unseen.
    static let plainBrandedAllowedBlockTypes: Set<String> = [
        // Text, images and controls.
        "text", "paragraph", "bullets", "image", "image-carousel", "button", "stepper",
        // Callouts.
        "status-badge", "advisory", "warning", "success", "highlight", "explainer",
        // Lists.
        "checklist", "install-list", "handoff-list", "label-value", "stat-row",
        // Tables.
        "comparison-table", "feature-table",
        // Status. `compliance-header` draws a second, larger header pair and is out;
        // `compliance-summary` and `findings-list` are unjudged and render anyway.
        "compliance-card",
        // Form.
        "form-section", "textfield", "dropdown", "radio", "checkbox", "slider", "toggle",
        // Pickers.
        "segmented", "search", "multi-select",
        // Choosers. `option-picker` and `dock-picker` are out: they draw their selection in the
        // flow's accent and overflow the column.
        "grid-picker", "slot-picker",
        // Select.
        "select-list", "select-grid",
        // Web. `portal-webview` reads `block.portalConfig ?? config.portalConfig`.
        "portal-webview", "webcontent",
        // Handoff.
        "action-rows",
        // Identity.
        "identity", "signature-preview"
        // `bento-grid` is out: its grid arm leaves most of the column empty and drops the cell
        // button; its `BentoModule` arms are unjudged.
    ]

    /// True iff `block` renders inside plain-branded's allowlist. `info` is judged on its
    /// resolved form through `GuidanceCalloutBlock.resolveForm`: `.chip` and `.card` are admitted,
    /// `.flat` is not.
    static func plainBrandedPermits(_ block: GuidanceContent) -> Bool {
        return plainBrandedAllowedBlockTypes.contains(block.type)
    }

    var items: [ItemConfig]

    /// Cache file extensions with a dot prefix; defaults to [".download", ".pkg", ".dmg"].
    var resolvedCacheExtensions: [String] {
        let extensions = cacheExtensions ?? ["download", "pkg", "dmg"]
        return extensions.map { ext in
            ext.hasPrefix(".") ? ext.lowercased() : ".\(ext.lowercased())"
        }
    }

    // MARK: - Custom Codable Implementation

    /// Custom decoder: unknown-key advisories for the root and nested surfaces, lenient shapes
    /// (`preset` as string or int, `items` defaulting to [], preset 6's `items[]` as `steps`,
    /// `introSteps` falling back to `steps`), canonicalization of steps, blocks and the summary
    /// screen, loud rejections (reserved bookend ids, `items[]` beside `introSteps[]`), and
    /// deprecated fields decoded and discarded.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let dynamicContainer = try decoder.container(keyedBy: RawCodingKey.self)
        let allJSONKeys = Set(dynamicContainer.allKeys.map(\.stringValue))
        let unknownRootKeys = InspectConfig.unknownKeys(in: allJSONKeys, against: InspectConfig.knownRootKeys)
        for key in unknownRootKeys {
            InspectConfig.unknownKeyWarnings.append(InspectConfig.unknownRootKeyWarning(key))
        }
        // Steps, blocks, summaryScreen and introScreen are scopes the root pass cannot see.
        InspectConfig.auditStepAndBlockKeys(root: dynamicContainer)
        InspectConfig.auditSummaryScreenKeys(root: dynamicContainer)
        InspectConfig.auditIntroScreenKeys(root: dynamicContainer)

        title = try container.decodeIfPresent(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        infobox = try container.decodeIfPresent(String.self, forKey: .infobox)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        iconsize = try container.decodeIfPresent(Int.self, forKey: .iconsize)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        density = try container.decodeIfPresent(String.self, forKey: .density)
        options = try container.decodeIfPresent([String: OptionValue].self, forKey: .options)
        scanInterval = try container.decodeIfPresent(Int.self, forKey: .scanInterval)
        cachePaths = try container.decodeIfPresent([String].self, forKey: .cachePaths)
        cacheExtensions = try container.decodeIfPresent([String].self, forKey: .cacheExtensions)
        // The schema allows a plain string as well as a list.
        if let single = try? container.decodeIfPresent(String.self, forKey: .sideMessage) {
            sideMessage = [single]
        } else {
            sideMessage = try container.decodeIfPresent([String].self, forKey: .sideMessage)
        }
        sideInterval = try container.decodeIfPresent(Int.self, forKey: .sideInterval)
        style = try container.decodeIfPresent(String.self, forKey: .style)
        liststyle = try container.decodeIfPresent(String.self, forKey: .liststyle)
        chrome = try container.decodeIfPresent(String.self, forKey: .chrome)
        migrationBodies = try container.decodeIfPresent(Bool.self, forKey: .migrationBodies)
        stepCounterPlacement = try container.decodeIfPresent(String.self, forKey: .stepCounterPlacement)
        itemSortOrder = try container.decodeIfPresent(String.self, forKey: .itemSortOrder)
        buttonShape = try container.decodeIfPresent(String.self, forKey: .buttonShape)
        glow = try container.decodeIfPresent(String.self, forKey: .glow)
        // `preset` may be a string or an int.
        if let stringValue = try? container.decode(String.self, forKey: .preset) {
            preset = stringValue
        } else {
            preset = String(try container.decode(Int.self, forKey: .preset))
        }
        popupButton = try container.decodeIfPresent(String.self, forKey: .popupButton)
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
        secondaryColor = try container.decodeIfPresent(String.self, forKey: .secondaryColor)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        appearance = try container.decodeIfPresent(String.self, forKey: .appearance)
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
        textOverlayColor = try container.decodeIfPresent(String.self, forKey: .textOverlayColor)
        gradientColors = try container.decodeIfPresent([String].self, forKey: .gradientColors)
        gradientPalette = try container.decodeIfPresent([String].self, forKey: .gradientPalette)
        gradientStyle = try container.decodeIfPresent(String.self, forKey: .gradientStyle)
        button1Text = try container.decodeIfPresent(String.self, forKey: .button1Text)
        button1Disabled = try container.decodeIfPresent(Bool.self, forKey: .button1Disabled)
        button1Symbol = try container.decodeIfPresent(String.self, forKey: .button1Symbol)
        finalButtonText = try container.decodeIfPresent(String.self, forKey: .finalButtonText)
        button2Text = try container.decodeIfPresent(String.self, forKey: .button2Text)
        button2Symbol = try container.decodeIfPresent(String.self, forKey: .button2Symbol)
        enableOnTimer = try container.decodeIfPresent(Double.self, forKey: .enableOnTimer)
        receiptsBasePath = try container.decodeIfPresent(String.self, forKey: .receiptsBasePath)
        detectionLog = try container.decodeIfPresent(String.self, forKey: .detectionLog)
        receiptCensus = try container.decodeIfPresent(Bool.self, forKey: .receiptCensus)

        // Deprecated; decoded and ignored so older configs keep validating.
        _ = try container.decodeIfPresent(Bool.self, forKey: .button2Disabled)

        button2Visible = try container.decodeIfPresent(Bool.self, forKey: .button2Visible)

        // Deprecated; decoded and ignored so older configs keep validating.
        _ = try container.decodeIfPresent(String.self, forKey: .buttonStyle)
        autoEnableButton = try container.decodeIfPresent(Bool.self, forKey: .autoEnableButton)
        autoEnableButtonText = try container.decodeIfPresent(String.self, forKey: .autoEnableButtonText)
        hideSystemDetails = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDetails)
        observeOnly = try container.decodeIfPresent(Bool.self, forKey: .observeOnly)
        autoAdvanceOnComplete = try container.decodeIfPresent(Bool.self, forKey: .autoAdvanceOnComplete)
        autoAdvanceDelay = try container.decodeIfPresent(Double.self, forKey: .autoAdvanceDelay)
        colorThresholds = try container.decodeIfPresent(ColorThresholds.self, forKey: .colorThresholds)
        plistSources = try container.decodeIfPresent([PlistSourceConfig].self, forKey: .plistSources)
        labels = try container.decodeIfPresent(UnifiedLabels.self, forKey: .labels)
        uiLabels = try container.decodeIfPresent(UILabels.self, forKey: .uiLabels)
        complianceLabels = try container.decodeIfPresent(ComplianceLabels.self, forKey: .complianceLabels)
        instructionBanner = try container.decodeIfPresent(InstructionBannerConfig.self, forKey: .instructionBanner)
        pickerLabels = try container.decodeIfPresent(PickerLabels.self, forKey: .pickerLabels)

        banner = try container.decodeIfPresent(String.self, forKey: .banner)
        bannerHeight = try container.decodeIfPresent(Int.self, forKey: .bannerHeight)
        bannerTitle = try container.decodeIfPresent(String.self, forKey: .bannerTitle)

        iconBasePath = try container.decodeIfPresent(String.self, forKey: .iconBasePath)
        overlayicon = try container.decodeIfPresent(String.self, forKey: .overlayicon)
        rotatingImages = try container.decodeIfPresent([String].self, forKey: .rotatingImages)
        imageRotationInterval = try container.decodeIfPresent(Double.self, forKey: .imageRotationInterval)
        imageShape = try container.decodeIfPresent(String.self, forKey: .imageShape)
        backButtonStyle = try container.decodeIfPresent(String.self, forKey: .backButtonStyle)
        stepStyle = try container.decodeIfPresent(String.self, forKey: .stepStyle)
        listIndicatorStyle = try container.decodeIfPresent(String.self, forKey: .listIndicatorStyle)
        progressMode = try container.decodeIfPresent(String.self, forKey: .progressMode)
        messageStyle = try container.decodeIfPresent(String.self, forKey: .messageStyle)
        progressBarConfig = try container.decodeIfPresent(ProgressBarConfig.self, forKey: .progressBarConfig)
        logoConfig = try container.decodeIfPresent(LogoConfig.self, forKey: .logoConfig)
        topBand = try container.decodeIfPresent(TopBandConfig.self, forKey: .topBand)
        successColor = try container.decodeIfPresent(String.self, forKey: .successColor)
        detailOverlay = try container.decodeIfPresent(DetailOverlayConfig.self, forKey: .detailOverlay)
        helpButton = try container.decodeIfPresent(HelpButtonConfig.self, forKey: .helpButton)
        actionPipe = try container.decodeIfPresent(String.self, forKey: .actionPipe)
        triggerFile = try container.decodeIfPresent(String.self, forKey: .triggerFile)
        skipPortal = try container.decodeIfPresent(Bool.self, forKey: .skipPortal)
        debugMode = try container.decodeIfPresent(Bool.self, forKey: .debugMode)
        resumable = try container.decodeIfPresent(Bool.self, forKey: .resumable)
        showProfilesRow = try container.decodeIfPresent(Bool.self, forKey: .showProfilesRow)
        dateStyle = try container.decodeIfPresent(String.self, forKey: .dateStyle)
        windowPosition = try container.decodeIfPresent(String.self, forKey: .windowPosition)
        windowPositionOffset = try container.decodeIfPresent(Double.self, forKey: .windowPositionOffset)
        button1Action = try container.decodeIfPresent(String.self, forKey: .button1Action)
        button2Action = try container.decodeIfPresent(String.self, forKey: .button2Action)
        greetingNameSource = try container.decodeIfPresent(ManagedValueRef.self, forKey: .greetingNameSource)
        completedTitle = try container.decodeIfPresent(String.self, forKey: .completedTitle)
        showStepProgress = try container.decodeIfPresent(Bool.self, forKey: .showStepProgress)
        contentAnchor = try container.decodeIfPresent(String.self, forKey: .contentAnchor)
        contentAlign = try container.decodeIfPresent(String.self, forKey: .contentAlign)
        phaseBackground = try container.decodeIfPresent(String.self, forKey: .phaseBackground)
        phaseBackgroundSource = try container.decodeIfPresent(ManagedValueRef.self, forKey: .phaseBackgroundSource)
        phaseBackgroundPalette = try container.decodeIfPresent([String].self, forKey: .phaseBackgroundPalette)
        phaseBackgroundPaletteDark = try container.decodeIfPresent([String].self, forKey: .phaseBackgroundPaletteDark)

        readinessFile = try container.decodeIfPresent(String.self, forKey: .readinessFile)
        resultFile = try container.decodeIfPresent(String.self, forKey: .resultFile)
        eventFile = try container.decodeIfPresent(String.self, forKey: .eventFile)
        deferralConfig = try container.decodeIfPresent(DeferralConfig.self, forKey: .deferralConfig)

        logMonitor = try container.decodeIfPresent(LogMonitorConfig.self, forKey: .logMonitor)
        logMonitors = try container.decodeIfPresent([LogMonitorConfig].self, forKey: .logMonitors)

        portalConfig = try container.decodeIfPresent(PortalConfig.self, forKey: .portalConfig)
        appConfigSource = try container.decodeIfPresent(AppConfigSource.self, forKey: .appConfigSource)

        preferencesOutput = try container.decodeIfPresent(PreferencesOutputConfig.self, forKey: .preferencesOutput)

        brands = try container.decodeIfPresent([BrandConfig].self, forKey: .brands)
        brandSelectionKey = try container.decodeIfPresent(String.self, forKey: .brandSelectionKey)

        localization = try container.decodeIfPresent(LocalizationConfig.self, forKey: .localization)

        brandPalette = try container.decodeIfPresent(BrandPalette.self, forKey: .brandPalette)
        brandPaletteRef = try container.decodeIfPresent(ManagedValueRef.self, forKey: .brandPaletteRef)
        debugPanel = try container.decodeIfPresent(Bool.self, forKey: .debugPanel)
        watch = try container.decodeIfPresent(Bool.self, forKey: .watch)
        brandPaletteDark = try container.decodeIfPresent(BrandPalette.self, forKey: .brandPaletteDark)

        accentBorderColor = try container.decodeIfPresent(String.self, forKey: .accentBorderColor)
        showAccentBorder = try container.decodeIfPresent(Bool.self, forKey: .showAccentBorder)
        footerBackgroundColor = try container.decodeIfPresent(String.self, forKey: .footerBackgroundColor)
        footerTextColor = try container.decodeIfPresent(String.self, forKey: .footerTextColor)
        footerText = try container.decodeIfPresent(String.self, forKey: .footerText)
        copyrightText = try container.decodeIfPresent(String.self, forKey: .copyrightText)
        supportText = try container.decodeIfPresent(String.self, forKey: .supportText)

        items = try container.decodeIfPresent([ItemConfig].self, forKey: .items) ?? []

        // Steps are canonicalized at the door so every consumer sees explicit types; the
        // step_add/step_replace path calls the same function.
        let decodedIntroSteps = InspectConfig.canonicalizeSteps(
            try container.decodeIfPresent([IntroStep].self, forKey: .introSteps))

        // Preset 6's `items[]` is its step list and decodes as steps for preset 6 only; for
        // presets 1-4 `items[]` is a row list and stays ItemConfig.
        if let authored = try container.decodeIfPresent([IntroStep].self, forKey: .steps) {
            steps = InspectConfig.canonicalizeSteps(authored)
        } else if InspectPresetName.normalizePreset(preset) == "preset6",
                  let asSteps = try? container.decodeIfPresent([IntroStep].self, forKey: .items) {
            steps = InspectConfig.canonicalizeSteps(asSteps)
        } else {
            steps = nil
        }

        // `steps[]` is accepted on every preset but only preset 6 reads `config.steps`; the
        // others read `introSteps`, so it falls back to `steps`. `introSteps` wins when both are
        // authored.
        let decodedSteps = decodedIntroSteps ?? steps

        // The bookend projection owns `_intro`/`_outro`; a config claiming one is rejected.
        if let claimed = decodedSteps?.first(where: { InspectConfig.reservedBookendIds.contains($0.id) }) {
            throw DecodingError.dataCorrupted(.init(
                codingPath: [CodingKeys.introSteps],
                debugDescription: """
                    Step id '\(claimed.id)' is reserved for the bookend projection \
                    (introScreen -> '\(InspectConfig.reservedIntroStepId)', \
                    summaryScreen -> '\(InspectConfig.reservedOutroStepId)'). Rename the step.
                    """))
        }
        introSteps = decodedSteps

        introScreen = try container.decodeIfPresent(PresetIntroScreen.self, forKey: .introScreen)
        // The outro's grouped `dock: { … }` folds onto its flat `dock*` keys here; the screen is
        // decoded once from a root key, so `canonicalizeBlocks` never sees it.
        if let decodedSummary = try container.decodeIfPresent(PresetSummaryScreen.self,
                                                              forKey: .summaryScreen) {
            var summaryAdvisories: [String] = []
            summaryScreen = InspectConfig.canonicalizeSummaryScreen(decodedSummary,
                                                                    advisories: &summaryAdvisories)
            // Logged, not appended to `unknownKeyWarnings`: a both-spellings conflict is a
            // canonicalization advisory, not an unknown key.
            for line in summaryAdvisories {
                writeLog("InspectConfig: \(line)", logLevel: .info)
            }
        } else {
            summaryScreen = nil
        }

        // Root-level blocks go through the same `canonicalizeBlocks` seam as step and item
        // blocks; the key folds only fill holes, so canonical spellings decode unchanged.
        var decodedGuidanceContent = try container.decodeIfPresent([GuidanceContent].self, forKey: .guidanceContent)
        var guidanceBlockAdvisories: [String] = []
        InspectConfig.canonicalizeBlocks(&decodedGuidanceContent,
                                         id: "guidanceContent",
                                         advisories: &guidanceBlockAdvisories)
        InspectConfig.unknownKeyWarnings.append(contentsOf: guidanceBlockAdvisories)

        guidanceContent = decodedGuidanceContent

        // `items[]` beside `introSteps[]` would render a blank panel; fail loudly instead.
        let hasItems = container.contains(.items)
        let hasIntroSteps = container.contains(.introSteps)
        if hasItems && hasIntroSteps {
            throw DecodingError.dataCorruptedError(
                forKey: .items,
                in: container,
                debugDescription: """
                Conflicting root shape: config has both `items[]` (Preset 6 shape) and `introSteps[]` (Preset 5 shape). \
                Preset 5 uses `introSteps[]`; Preset 6 uses `items[]`. Remove whichever does not match your target preset.
                """
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case title, message, infobox, icon, iconsize, banner, bannerHeight, bannerTitle
        case width, height, size, density, options, scanInterval, cachePaths, cacheExtensions
        case sideMessage, sideInterval, style, liststyle, preset, popupButton, chrome, migrationBodies, stepCounterPlacement, itemSortOrder, buttonShape, glow
        case highlightColor, secondaryColor, backgroundColor, backgroundImage, backgroundOpacity, appearance
        case textOverlayColor, gradientColors, gradientPalette, gradientStyle
        case button1Text = "button1text"
        case button1Disabled = "button1disabled"
        case button1Symbol = "button1symbol"
        case finalButtonText = "finalButtonText"
        case button2Text = "button2text"
        case button2Symbol = "button2symbol"
        case enableOnTimer
        case receiptsBasePath
        case detectionLog
        case receiptCensus

        // Deprecated: decoded and ignored.
        case button2Disabled = "button2disabled"

        case button2Visible = "button2visible"

        // Deprecated: decoded and ignored.
        case buttonStyle
        case autoEnableButton, autoEnableButtonText, hideSystemDetails, observeOnly, autoAdvanceOnComplete, autoAdvanceDelay, colorThresholds, plistSources, labels, uiLabels, complianceLabels, instructionBanner, pickerLabels, items
        case introSteps
        case steps
        case iconBasePath, overlayicon, rotatingImages, imageRotationInterval, imageShape, backButtonStyle, stepStyle, listIndicatorStyle
        case progressMode
        case messageStyle
        case progressBarConfig
        case logoConfig
        case topBand
        case successColor
        case detailOverlay, helpButton, actionPipe, triggerFile, skipPortal, debugMode, resumable, showProfilesRow, dateStyle
        case windowPosition, windowPositionOffset, button1Action, button2Action, greetingNameSource, completedTitle, phaseBackground
        case showStepProgress
        case contentAnchor, contentAlign
        case phaseBackgroundSource, phaseBackgroundPalette, phaseBackgroundPaletteDark
        case readinessFile, resultFile, eventFile, deferralConfig
        case logMonitor, logMonitors
        case portalConfig, appConfigSource
        case preferencesOutput
        case brands, brandSelectionKey
        case localization
        case brandPalette
        case brandPaletteRef
        case debugPanel
        case watch
        case brandPaletteDark
        case accentBorderColor, showAccentBorder, footerBackgroundColor, footerTextColor, footerText, copyrightText, supportText
        case introScreen, summaryScreen
        case guidanceContent
    }
}

// MARK: - Encoding (same file as the private CodingKeys it requires)
extension InspectConfig {
    /// Required beside the custom `init(from:)`; omits the deprecated fields.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(migrationBodies, forKey: .migrationBodies)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(infobox, forKey: .infobox)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(iconsize, forKey: .iconsize)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(density, forKey: .density)
        try container.encodeIfPresent(options, forKey: .options)
        try container.encodeIfPresent(scanInterval, forKey: .scanInterval)
        try container.encodeIfPresent(cachePaths, forKey: .cachePaths)
        try container.encodeIfPresent(cacheExtensions, forKey: .cacheExtensions)
        try container.encodeIfPresent(sideMessage, forKey: .sideMessage)
        try container.encodeIfPresent(sideInterval, forKey: .sideInterval)
        try container.encodeIfPresent(style, forKey: .style)
        try container.encodeIfPresent(liststyle, forKey: .liststyle)
        try container.encodeIfPresent(preset, forKey: .preset)
        try container.encodeIfPresent(popupButton, forKey: .popupButton)
        try container.encodeIfPresent(highlightColor, forKey: .highlightColor)
        try container.encodeIfPresent(secondaryColor, forKey: .secondaryColor)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(appearance, forKey: .appearance)
        try container.encodeIfPresent(backgroundImage, forKey: .backgroundImage)
        try container.encodeIfPresent(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encodeIfPresent(textOverlayColor, forKey: .textOverlayColor)
        try container.encodeIfPresent(gradientColors, forKey: .gradientColors)
        try container.encodeIfPresent(button1Text, forKey: .button1Text)
        try container.encodeIfPresent(button1Disabled, forKey: .button1Disabled)
        try container.encodeIfPresent(button1Symbol, forKey: .button1Symbol)
        try container.encodeIfPresent(button2Text, forKey: .button2Text)
        try container.encodeIfPresent(button2Symbol, forKey: .button2Symbol)
        try container.encodeIfPresent(enableOnTimer, forKey: .enableOnTimer)
        try container.encodeIfPresent(receiptsBasePath, forKey: .receiptsBasePath)
        try container.encodeIfPresent(detectionLog, forKey: .detectionLog)
        try container.encodeIfPresent(receiptCensus, forKey: .receiptCensus)
        try container.encodeIfPresent(button2Visible, forKey: .button2Visible)
        try container.encodeIfPresent(autoEnableButton, forKey: .autoEnableButton)
        try container.encodeIfPresent(autoEnableButtonText, forKey: .autoEnableButtonText)
        try container.encodeIfPresent(hideSystemDetails, forKey: .hideSystemDetails)
        try container.encodeIfPresent(colorThresholds, forKey: .colorThresholds)
        try container.encodeIfPresent(plistSources, forKey: .plistSources)
        try container.encodeIfPresent(uiLabels, forKey: .uiLabels)
        try container.encodeIfPresent(complianceLabels, forKey: .complianceLabels)
        try container.encodeIfPresent(instructionBanner, forKey: .instructionBanner)
        try container.encodeIfPresent(pickerLabels, forKey: .pickerLabels)
        try container.encodeIfPresent(banner, forKey: .banner)
        try container.encodeIfPresent(bannerHeight, forKey: .bannerHeight)
        try container.encodeIfPresent(bannerTitle, forKey: .bannerTitle)
        try container.encodeIfPresent(iconBasePath, forKey: .iconBasePath)
        try container.encodeIfPresent(overlayicon, forKey: .overlayicon)
        try container.encodeIfPresent(rotatingImages, forKey: .rotatingImages)
        try container.encodeIfPresent(imageRotationInterval, forKey: .imageRotationInterval)
        try container.encodeIfPresent(imageShape, forKey: .imageShape)
        try container.encodeIfPresent(backButtonStyle, forKey: .backButtonStyle)
        try container.encodeIfPresent(stepStyle, forKey: .stepStyle)
        try container.encodeIfPresent(listIndicatorStyle, forKey: .listIndicatorStyle)
        try container.encodeIfPresent(progressBarConfig, forKey: .progressBarConfig)
        try container.encodeIfPresent(logoConfig, forKey: .logoConfig)
        try container.encodeIfPresent(topBand, forKey: .topBand)
        try container.encodeIfPresent(detailOverlay, forKey: .detailOverlay)
        try container.encodeIfPresent(helpButton, forKey: .helpButton)
        try container.encodeIfPresent(actionPipe, forKey: .actionPipe)
        try container.encodeIfPresent(logMonitor, forKey: .logMonitor)
        try container.encodeIfPresent(logMonitors, forKey: .logMonitors)
        try container.encodeIfPresent(portalConfig, forKey: .portalConfig)
        try container.encodeIfPresent(appConfigSource, forKey: .appConfigSource)
        try container.encodeIfPresent(brands, forKey: .brands)
        try container.encodeIfPresent(brandSelectionKey, forKey: .brandSelectionKey)
        try container.encodeIfPresent(brandPalette, forKey: .brandPalette)
        try container.encodeIfPresent(brandPaletteRef, forKey: .brandPaletteRef)
        try container.encodeIfPresent(debugPanel, forKey: .debugPanel)
        try container.encodeIfPresent(watch, forKey: .watch)
        try container.encodeIfPresent(brandPaletteDark, forKey: .brandPaletteDark)
        try container.encodeIfPresent(accentBorderColor, forKey: .accentBorderColor)
        try container.encodeIfPresent(showAccentBorder, forKey: .showAccentBorder)
        try container.encodeIfPresent(footerBackgroundColor, forKey: .footerBackgroundColor)
        try container.encodeIfPresent(footerTextColor, forKey: .footerTextColor)
        try container.encodeIfPresent(footerText, forKey: .footerText)
        try container.encodeIfPresent(copyrightText, forKey: .copyrightText)
        try container.encodeIfPresent(supportText, forKey: .supportText)
        try container.encodeIfPresent(guidanceContent, forKey: .guidanceContent)
        try container.encode(items, forKey: .items)
    }
}

extension InspectConfig {
    /// Window options live under `options`, not at the root; a root-level copy's warning says
    /// where it goes.
    static let windowOptionKeys: Set<String> = ["moveable", "movable", "ontop", "resizable", "windowbuttons"]

    static func unknownRootKeyWarning(_ key: String) -> String {
        if windowOptionKeys.contains(key.lowercased()) {
            return "Unknown key '\(key)' in root config — window options go under \"options\": {\"\(key)\": true}"
        }
        return "Unknown key '\(key)' in root config"
    }
}

// The status enums the current preset views read.
// MARK: - Unified Status Enum

/// Unified status enum for all Inspect mode items
enum InspectItemStatus: Equatable {
    case pending
    case downloading
    case completed
    case failed(String)

    /// Handler for simple status without associated values for basic comparisons
    var simpleStatus: SimpleItemStatus {
        switch self {
        case .pending: return .pending
        case .downloading: return .downloading
        case .completed: return .completed
        case .failed: return .failed
        }
    }
}

/// Simple download status enum
///
/// **EXTERNAL API**: This enum is maintained for backward compatibility with external scripts
/// that may rely on parsing Dialog's state output.
///
/// **Internal Usage**: Prefer `InspectItemStatus` with Swift pattern matching:
/// ```swift
/// // Preferred internal approach:
/// if case .failed = itemStatus {
///     // Handle failure
/// }
///
/// // Avoid in internal code:
/// if itemStatus.simpleStatus == .failed {
///     // Less type-safe
/// }
/// ```
///
/// **Note**: `InspectItemStatus` provides richer information via associated values
/// (e.g., `.failed(String)` includes error message), while `SimpleItemStatus` only
/// indicates state without context.
enum SimpleItemStatus {
    case pending
    case downloading
    case completed
    case failed
}
