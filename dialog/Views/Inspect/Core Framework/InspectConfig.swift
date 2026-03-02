//
//  InspectConfig.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 20/09/2025
//
//  Configuration structures for Inspect mode
//

import Foundation
import SwiftUI

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

// MARK: - Configuration

/// Configuration structure, this is matching the JSON format
/// Usage note: Due to the dynamic nature of the config, JSON must be used pre-loaded `export
/// DIALOG_INSPECT_CONFIG=/path/to/config.json`"$DIALOG_PATH" --inspect-mode
struct InspectConfig: Codable {
    let title: String?
    let message: String?
    let infobox: String?
    let icon: String?
    let iconsize: Int?
    let banner: String?        // Sets the Banner image used in some presets, ovrides icon
    let bannerHeight: Int?     // Banner height in pixels, default: 100 - the dialog width/height may need to be adjusted
    let bannerTitle: String?   // Banner "Title overlay"
    let width: Int?
    let height: Int?
    let size: String?  // Refactored into preset-specific sizing- we use "compact", "standard", or "large" -> see InspectSizes.swift
    let scanInterval: Int?
    let cachePaths: [String]?
    let sideMessage: [String]?
    let sideInterval: Int?
    let style: String?
    let liststyle: String?
    let preset: String
    let popupButton: String?
    let highlightColor: String?
    let secondaryColor: String?
    let backgroundColor: String?
    let backgroundImage: String?
    let backgroundOpacity: Double?
    let textOverlayColor: String?
    let gradientColors: [String]?
    let button1Text: String?
    let button1Disabled: Bool?
    let button2Text: String?
    let button2Visible: Bool?
    let autoEnableButton: Bool?
    let autoEnableButtonText: String?   // TODO: we may want to rename this, idea is this Text is used when a dialog run has finished and the button is enabled
    let finalButtonText: String?        // Optional text for final button when all items complete (overrides button1Text)
    let hideSystemDetails: Bool?
    let observeOnly: Bool?                  // Global observe-only mode - disables all user interactions (default: false/interactive)
    let autoAdvanceOnComplete: Bool?        // Preset6: Auto-navigate to next step after marking complete (default: true, set false for two-click flow)
    let colorThresholds: ColorThresholds?   // WIP: Configurable color thresholds for visualizations
    let plistSources: [PlistSourceConfig]?  // Array of plist configurations to monitor - used in compliance dashboards like preset5
    let categoryHelp: [CategoryHelp]?       // Optional help popovers for categories - used in compliance dashboards like preset5
    let uiLabels: UILabels?                 // Optional UI text customization (cross-preset status/progress/completion text)
    let complianceLabels: ComplianceLabels? // Optional compliance-specific text customization (Preset5)
    let pickerConfig: PickerConfig?         // Optional picker mode configuration (legacy presets, etc.)
    let instructionBanner: InstructionBannerConfig? // Optional instruction banner (all presets)
    let pickerLabels: PickerLabels?         // Optional picker mode text customization (legacy presets, etc.)

    let iconBasePath: String?                // Icon base path for relative loading icon paths
    let overlayicon: String?                  // Overlay icon for brand identity badges
    let rotatingImages: [String]?            // Array of image paths for image rotation
    let imageRotationInterval: Double?      // set interval for auto-rotation
    let imageShape: String?                  // rectangle, square, circle - used in preset6
    let imageSyncMode: String?              // "manual" | "sync" | "auto"
    let backButtonStyle: String?             // "inline" (inside scroll, default) | "footer" (in footer bar)
    let stepStyle: String?                  // "plain" | "colored" | "cards"
    let listIndicatorStyle: String?         // "letters" | "numbers" | "roman" - list indicator format
    let progressMode: String?                // "shared" (single bar, X of Y) | "perItem" (indeterminate per item) — Preset4 toast installer
    let progressBarConfig: ProgressBarConfig? // Optional progress bar visual configuration
    let logoConfig: LogoConfig?             // Optional logo overlay configuration (legacy presets)
    let detailOverlay: DetailOverlayConfig? // Optional detail flyout overlay configuration
    let helpButton: HelpButtonConfig?       // Optional help button configuration
    let actionPipe: String?                 // Optional FIFO path for instant script request delivery
    let triggerFile: String?                // Custom trigger file path (overrides dev/prod defaults)
    let skipPortal: Bool?                   // Skip portal phase entirely (Preset5) - go directly from intro to outro
    let debugMode: Bool?                    // Debug/testing mode - ignore completion flags, always start from step 1 (preserves form values)

    // MARK: - IPC (ignitecli Integration)
    let readinessFile: String?              // Path to write readiness signal JSON (default: "{triggerFile}.ready")
    let resultFile: String?                 // Path to write JSON result on exit (selections, form values, step statuses)
    let eventFile: String?                   // Path to write JSONL step events (step_started, step_completed)
    let deferralConfig: DeferralConfig?     // User-initiated deferral menu configuration

    // MARK: - Log Monitoring Configuration (Cross-Preset)
    let logMonitor: LogMonitorConfig?       // Single log monitor configuration
    let logMonitors: [LogMonitorConfig]?    // Multiple log monitor configurations

    // Note: Unified log monitoring (OSLogStore) is not supported because Apple
    // doesn't grant the com.apple.logging.local-store entitlement to third-party apps.
    // For custom installs, use a log file approach: the installer script writes progress
    // to a log file, then swiftDialog monitors that file using logMonitor config with a matching preset.

    // MARK: - Portal/WebView Configuration (Preset5)
    let portalConfig: PortalConfig?         // Self-service portal configuration (supports any authenticated web portal)
    let appConfigSource: AppConfigSource?   // MDM managed preference source for dynamic branding (overrides JSON values)
    let introSteps: [IntroStep]?            // Optional intro/outro screens before/after portal (Preset5)

    // MARK: - Preferences Output Configuration (Modular Architecture)
    let preferencesOutput: PreferencesOutputConfig? // Plist output for user preference collection (osquery/MDM labeling)

    // MARK: - Brand Selection (Multi-Brand Onboarding)
    let brands: [BrandConfig]?              // Available brand options for brand picker step
    let brandSelectionKey: String?          // Persistence key for selected brand (default: "selectedBrand")

    // MARK: - Localization (Intro Step Text)
    let localization: LocalizationConfig?   // Language sidecar files for translating intro step text

    // MARK: - Brand Palette (Cross-Preset Theming)
    let brandPalette: BrandPalette?         // Named color tokens and logo presets for consistent theming

    // MARK: - Footer Branding (Cross-Preset)
    // These fields extend existing branding (highlightColor, logoConfig) with footer-specific options
    let accentBorderColor: String?          // Top accent border color (defaults to highlightColor if nil)
    let showAccentBorder: Bool?             // Show top accent border ribbon (default: true)
    let footerBackgroundColor: String?      // Footer background color (hex)
    let footerTextColor: String?            // Footer text color (hex, for dark backgrounds)
    let footerText: String?                 // Text displayed in footer area
    let copyrightText: String?              // Optional copyright line in footer
    let supportText: String?                // Optional support contact text in footer

    // MARK: - Preset1/2 Multi-Screen Flow (Optional)
    let introScreen: PresetIntroScreen?     // Optional intro screen before items view (Preset1/2 only)
    let summaryScreen: PresetSummaryScreen? // Optional summary screen after items complete (Preset1/2 only)

    var items: [ItemConfig]

    // Progress bar configuration for status visualization
    struct ProgressBarConfig: Codable {
        let enableStatusColors: Bool?        // Enable status-based colors (default: false)
        let showCompletionState: Bool?       // Show green when all steps complete
        let showBlockingState: Bool?         // Show orange for blocking/required items
        let colors: ProgressBarColors?

        struct ProgressBarColors: Codable {
            let normal: String?      // Default: "#007AFF" (blue)
            let complete: String?    // Default: "#34C759" (green)
            let blocking: String?    // Default: "#FF9500" (orange)
            let error: String?       // Default: "#FF3B30" (red)
        }

        // Computed properties using existing Color(hex:) from Colour+Additions.swift
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

    // Logo overlay configuration for preset layouts
    struct LogoConfig: Codable {
        let imagePath: String                   // Path to logo image file (light mode / default)
        let imagePathDark: String?              // Dark mode variant (falls back to imagePath if nil)
        let position: String?                   // "topleft" | "topright" | "bottomleft" | "bottomright" (default: "topleft")
        let padding: Double?                    // Padding from edges in points (default: 20)
        let maxWidth: Double?                   // Maximum width in points (default: 80)
        let maxHeight: Double?                  // Maximum height in points (default: 80)
        let opacity: Double?                    // Logo opacity 0.0-1.0 (default: 0.6 for bottom, 1.0 for top)
        let backgroundColor: String?            // Background tint color in hex (default: nil/transparent)
        let backgroundOpacity: Double?          // Background opacity 0.0-1.0 (default: 0.2)
        let cornerRadius: Double?               // Corner radius for background (default: 8)
    }

    // User-initiated deferral configuration (shared across presets)
    // Integrates with ignitecli's deferral system: env vars, exit code 10, result file
    struct DeferralConfig: Codable {
        let enabled: Bool?                      // Show defer menu (default: false; also enabled if IGNITECLI_DEFER_ENABLED=true)
        let buttonText: String?                 // Menu button label (default: "Not Now")
        let options: [DeferOption]?             // Deferral options; falls back to IGNITECLI_DEFER_OPTIONS env var
        let exitCode: Int?                      // Exit code on deferral (default: 10, ignitecli standard)
    }

    struct DeferOption: Codable {
        let duration: String                    // ignitecli duration format: "3m", "20m", "1h", "4h", "1d", "tomorrow"
        let label: String?                      // Human-readable label override; auto-generated from duration if nil
    }

    /// Configuration for intro/outro full-screen layout styling
    /// Used with stepType: "intro" or "outro" to display welcome/completion pages
    struct IntroLayoutConfig: Codable {
        let heroImageShape: String?             // "circle" (default) | "roundedSquare" | "square"
        let heroImageSize: Double?              // Size in points (default: 200)
        let heroImagePadding: Double?           // Inset padding in points (nil = auto ~4%, 0 = none)
        let logoImage: String?                  // Bottom branding logo path
        let logoPosition: String?               // "bottomLeft" (default) | "bottomRight"
        let logoMaxWidth: Double?               // Maximum logo width in points (default: 120)
    }

    // MARK: - Preset1/2 Multi-Screen Flow

    /// Lightweight intro screen shown before the items view in Preset1/2
    /// Reuses GuidanceContentView for rich content rendering
    struct PresetIntroScreen: Codable {
        let title: String?                      // Main heading
        let subtitle: String?                   // Smaller text below title
        let heroImage: String?                  // Path, URL, or "sf=symbolname"
        let heroImageShape: String?             // "circle" | "roundedSquare" | "none" (default: "none")
        let heroImageSize: Double?              // Size in points (default: 200)
        let content: [GuidanceContent]?         // Rich content blocks (text, bullets, info, etc.)
        let buttonText: String?                 // Continue button label (default: "Get Started")
        let showBackButton: Bool?               // Show back button (default: false — it's the first screen)
    }

    /// Lightweight summary/bento screen shown after items complete in Preset1/2
    /// Supports both rich content and bento grid layouts
    struct PresetSummaryScreen: Codable {
        let title: String?                      // Main heading
        let subtitle: String?                   // Smaller text below title
        let heroImage: String?                  // Path, URL, or "sf=symbolname"
        let heroImageShape: String?             // "circle" | "roundedSquare" | "none" (default: "none")
        let heroImageSize: Double?              // Size in points (default: 120)
        let content: [GuidanceContent]?         // Rich content blocks
        let bentoLayout: String?                // "2x2" | "3x2" | "grid" (enables bento grid)
        let bentoCells: [GuidanceContent.BentoCellConfig]?  // Bento cell definitions
        let bentoColumns: Int?                  // Grid columns (default: 2)
        let bentoRowHeight: Double?             // Row height in points (default: 120)
        let bentoGap: Double?                   // Gap between cells (default: 12)
        let buttonText: String?                 // Final button label (default: "Close")
        let autoTransition: Bool?               // Auto-show when all items complete (default: true)
    }

    // MARK: - Shared Wallpaper Types

    /// Category of wallpapers for wallpaper picker (shared by GuidanceContent and IntroStep)
    struct WallpaperCategory: Codable {
        let title: String                           // Category title (e.g., "Full HD", "4K")
        let images: [WallpaperImage]                // Array of images in this category
    }

    /// Individual wallpaper image in a category
    struct WallpaperImage: Codable {
        let path: String                            // Full path to the wallpaper image
        let thumbnail: String?                      // Optional thumbnail path (uses path if nil)
        let title: String?                          // Optional display title
    }

    // MARK: - Preferences Output Configuration (Modular Architecture)

    /// Configuration for user preference collection and plist output
    /// Used for osquery integration, MDM device labeling, and profile assignment
    struct PreferencesOutputConfig: Codable {
        let plistPath: String                   // Path to write preferences plist (e.g., "/Library/Preferences/com.company.enrollment.plist")
        let writeOnStepComplete: Bool?          // Write after each step completes (default: true)
        let writeOnDialogExit: Bool?            // Write when dialog exits (default: true)
        let mergeWithExisting: Bool?            // Merge with existing plist values (default: true)
        let staticValues: [String: String]?     // Static key-value pairs to always include
    }

    // MARK: - Localization Config

    /// Configuration for language sidecar files that provide translated intro step text
    /// Language files are flat JSON with keys like "{stepId}.title", "{stepId}.content.0.content"
    struct LocalizationConfig: Codable {
        let languages: [String: String]   // langCode → relative file path, e.g. "de": "lang/de.json"
        let selectionKey: String?         // gridSelectionKey holding the choice (default: "preferredLanguage")
        let defaultLanguage: String?      // "auto" = system locale, "de" = hardcoded, nil = no default
        let languagePicker: Bool?         // true = show language selection page in legacy presets onboarding
    }

    // MARK: - Intro Steps Configuration (Preset5)

    /// Configuration for steps in preset5's linear step flow
    /// Supports branded setup assistant screens with portal as a step type
    struct IntroStep: Codable, Identifiable {
        let id: String
        let stepType: String?                   // "intro" | "processing" | "outro" | "portal" | "assistant" (default: "intro")

        // Hero Image Configuration
        let heroImage: String?                  // Path or "SF=symbolname" for SF Symbol
        let heroImageShape: String?             // "circle" | "roundedSquare" | "square" | "none"
        let heroImageSize: Double?              // Default: 200
        let heroImageSFSymbolColor: String?     // Hex color for SF Symbol (defaults to accentColor)
        let heroImageSFSymbolWeight: String?    // "regular" | "medium" | "bold" (default: "medium")
        let heroImagePadding: Double?           // Inset padding in points (nil = auto ~4%, 0 = none)

        // Content
        let title: String?
        let subtitle: String?                   // Smaller text below title
        let content: [GuidanceContent]?         // Rich content blocks (text, images, bullets, etc.)

        // Grid/Picker Content (for wallpaper-style selection screens)
        let gridItems: [GridItemConfig]?
        let gridColumns: Int?                   // Default: 3
        let gridSelectionMode: String?          // "single" | "multiple" | "none" (default: "single")
        let gridSelectionKey: String?           // Key to store selection in userValues
        let gridPreferenceKey: String?          // Key to write selection to preferences plist (for osquery/MDM labeling)

        // Wallpaper Picker (categorized horizontal-scroll picker with multi-monitor support)
        let wallpaperCategories: [WallpaperCategory]?  // Categories with images
        let wallpaperThumbnailHeight: Double?          // Thumbnail height (default: 120)
        let wallpaperSelectionKey: String?             // Key for selection output (internal storage)
        let wallpaperPreferenceKey: String?            // Key for preferences plist (for osquery/MDM)
        let wallpaperShowPath: Bool?                   // Show file path below title (default: false)
        let wallpaperConfirmButton: String?            // Confirm button text (nil = instant select)
        let wallpaperMultiSelect: Int?                 // Number of monitors for multi-select (default: 1)
        let wallpaperLayout: String?                   // Layout mode: "grid" (default), "row", or "categories"

        // Media Carousel (for instruction videos, GIFs, images with arrow navigation)
        let mediaItems: [MediaItemConfig]?      // Array of media items (images, GIFs, YouTube, Vimeo URLs)
        let mediaHeight: Double?                // Height of media carousel (default: 400)
        let mediaAutoplay: Bool?                // Autoplay videos (default: true)
        let mediaShowArrows: Bool?              // Show prev/next arrows (default: true)
        let mediaShowDots: Bool?                // Show dot indicators (default: true)

        // Progress Indicators
        let showProgressDots: Bool?             // Show step dots at bottom (default: false)
        let progressPosition: String?           // "bottom" | "top" (default: "bottom")

        // Button Configuration
        let actionButtonText: String?           // Custom button text during processing (e.g., "Processing…", "Installing…")
        let continueButtonText: String?         // Default: "Continue"
        let backButtonText: String?             // Default: "Back"
        let showBackButton: Bool?               // Default: true (except first step)
        let continueAction: String?             // "next" | "skip" | "portal" | custom script

        // Conditional Display
        let condition: String?                  // Script or expression to evaluate
        let skipIfComplete: Bool?               // Skip if already completed (via userValues)

        // MARK: - Installation Mode (Modular Architecture)
        // Transforms intro step into an installation progress display

        let installationMode: String?           // "progress" | "processing" | nil (default: nil/normal intro step)
        let installationLayout: String?         // "list" | "grid" | "cards" (default: "cards")
        let installationScale: CGFloat?         // Scale factor for installation cards (default: 0.75, use 1.0 for larger)
        let items: [ItemConfig]?                // Inline items for self-contained installation steps
        let autoAdvanceOnComplete: Bool?        // Auto-navigate to next step when all items complete (default: false)
        let processingMessage: String?          // Message shown during installation

        // Deployment Step Configuration (stepType: "deployment" — Preset1-style sidebar layout)
        let sideMessages: [String]?             // Rotating messages shown in content area (step-level, independent of global sideMessage)
        let sideMessageInterval: Int?           // Rotation interval in seconds (default: 8)
        let popupButtonText: String?            // Sidebar popup button text (e.g., "Install Details...")
        let autoEnableButton: Bool?             // Disable Continue until all items complete (default: true)
        let autoEnableButtonText: String?       // Continue button text when all complete (default: "Done")

        // Carousel Step Configuration (stepType: "carousel" — Preset2-style horizontal card carousel)
        let bannerHeight: Int?                  // Banner image height when heroImage is a file/URL (default: 100)
        let progressFormat: String?             // Progress text template: "{completed} of {total} completed"

        // Processing Step Type (countdown timer with visual feedback)
        let processingDuration: Int?            // Countdown duration in seconds (triggers processing step type)
        let processingMode: String?             // "simple" (auto-advance at 0) | "progressive" (wait for external trigger)

        // Override System (time-based escalation for stuck processing steps)
        let allowOverride: Bool?                // Enable override capability (default: false)
        let waitSmallOverrideTime: Int?         // Show small "Skip" link after X seconds (default: 30)
        let waitLargeOverrideTime: Int?         // Show large "Override" button after X seconds (default: 60)
        let overrideButtonText: String?         // Custom text for override button (default: "Skip")

        // Processing Result Configuration
        let autoAdvance: Bool?                  // Auto-navigate after completion (default: false - show result banner with continue button)
        let autoResult: String?                 // Force result: "success" (default) | "failure" - for demos
        let successMessage: String?             // Message shown on success (default: "Step Completed")
        let failureMessage: String?             // Message shown on failure (default: "Step Failed")
        let waitForExternalTrigger: Bool?       // If true, NEVER auto-complete - always wait for success:/failure: command (default: false)

        // Step Overlay (per-step help overlay like preset6's itemOverlay)
        let stepOverlay: DetailOverlayConfig?   // Rich help overlay for this step

        // Dynamic Updates - Plist monitoring for live content updates
        let plistMonitors: [PlistMonitor]?      // Array of plist monitors that auto-update content blocks
        let monitorRefreshInterval: Double?     // Global refresh interval in seconds (default: 1.0)
        let completionMode: String?             // "any" (default) | "all" — how multiple completionTriggers combine

        // Portal Step Configuration (for stepType: "portal")
        let portalConfig: PortalConfig?         // Per-step portal config (overrides global portalConfig)

        // Showcase Step Configuration (stepType: "showcase")
        let showcaseGradientColors: [String]?   // Hex colors for gradient background (fallback: highlightColor)
        let showcaseTextColor: String?          // Hex color for overlay text (fallback: white 90%)
        let showcaseImageHeight: Double?        // Image area height ratio 0.0-1.0 (default: 0.6)

        // Guide Step Configuration (stepType: "guide")
        let guideGradientColors: [String]?      // Hex colors for left panel gradient (fallback: highlightColor)
        let guideImageRatio: Double?            // Left panel width ratio 0.0-1.0 (default: 0.65)
        let guideCategoryIcon: String?          // Category icon for sidebar header (SF symbol name)
        let guideStepBadge: String?             // Badge text in sidebar header (e.g., "REQUIRED")
        let guideKeyPoints: String?             // Key points text block for sidebar
        let guideBulletPoints: [String]?        // Bullet point list for sidebar

        // Bento Step Configuration (stepType: "bento")
        let bentoLayout: String?                // "split" | "grid" (default: "grid")
        let bentoSidebarRatio: Double?          // 0.25-0.45 (default: 0.35), split mode only
        let bentoCells: [GuidanceContent.BentoCellConfig]?  // Cell definitions (step-level)
        let bentoColumns: Int?                  // Grid columns (default: 4)
        let bentoRowHeight: Double?             // Base row height in pts (default: 140)
        let bentoGap: Double?                   // Gap between cells in pts (default: 12)
        let bentoTintColor: String?             // Base hex for auto-tinting cells
        let bentoSidebarContent: [GuidanceContent]?  // Rich content for split sidebar

        // Assistant Step Configuration (stepType: "assistant" — Apple Setup Assistant style)
        let assistantImageHeight: Double?       // Hero image area ratio 0.0-1.0 (default: 0.4)
        let heroBackgroundColor: String?        // Hex color for hero image background area (e.g. "#05164D")
        let skipButtonText: String?             // Secondary button label left of Continue (e.g., "Set Up Later")
        let footerLink: String?                 // Centered privacy/info link text (e.g., "About Privacy...")

        // Monitoring fields (used by guide steps with filesystem validation)
        let paths: [String]?                    // Filesystem paths to check for existence
        let plistKey: String?                   // Plist key for condition checking
        let expectedValue: String?              // Expected plist value
        let evaluation: String?                 // "equals" | "boolean" | "exists" | "contains"

        // Picker mode (per-step flag — global pickerConfig controls mode)
        let selectable: Bool?                   // Whether this step participates in picker selection
    }

    // MARK: - Brand Config (Multi-Brand Onboarding)

    /// Brand definition for brand picker step
    /// Each brand can override branding fields (colors, logos, text) when selected
    struct BrandConfig: Codable, Identifiable {
        let id: String
        let displayName: String
        let subtitle: String?
        let logoPath: String?           // Card logo (shown on picker)
        let sfSymbol: String?           // Alternative to logoPath

        // Branding overrides (applied when selected)
        let highlightColor: String?
        let accentBorderColor: String?
        let footerBackgroundColor: String?
        let footerTextColor: String?
        let footerText: String?
        let logoConfigPath: String?     // Active logo (footer/sidebar, overrides logoConfig.imagePath)
        let button1Text: String?
        let button2Text: String?
        let introTitle: String?
        let outroTitle: String?
        let introButtonText: String?
        let outroButtonText: String?
    }

    /// Grid item for picker screens (wallpaper, theme selection, etc.)
    struct GridItemConfig: Codable, Identifiable {
        private let _id: String?                // Explicit ID from JSON
        let imagePath: String?
        let sfSymbol: String?
        let title: String?
        let subtitle: String?
        let description: String?                // Optional description shown below title
        let value: String?                      // Value to store when selected (defaults to _id)

        // Identifiable conformance: explicit id > value > imagePath > sfSymbol > UUID
        var id: String { _id ?? value ?? imagePath ?? sfSymbol ?? UUID().uuidString }

        enum CodingKeys: String, CodingKey {
            case _id = "id"
            case imagePath, sfSymbol, title, subtitle, description, value
        }
    }

    /// Media item for carousel (images, GIFs, YouTube, Vimeo, etc.)
    struct MediaItemConfig: Codable, Identifiable {
        var id: String { url ?? UUID().uuidString }
        let url: String?                        // URL or local path (images, GIFs, YouTube, Vimeo, etc.)
        let caption: String?                    // Optional caption text below media
        let title: String?                      // Optional title above media
    }

    struct ItemConfig: Codable {
        let id: String
        let displayName: String
        let subtitle: String?           // TODO: We need to simplify this - atm used as subtitle for preset6 checklist
        let guiIndex: Int
        let paths: [String]
        let icon: String?
        let status: String?             // Optional: status icon for list items (e.g., "shield", "checkmark.circle.fill") - supports dynamic updates via listitem: commands
        let banner: String?             // Optional: banner image path for preset cards
        let plistKey: String?           // Optional: plist key to check - used in compliance dashboards like preset5
        let expectedValue: String?      // Optional: expected value for the key - used in compliance dashboards like preset5
        let evaluation: String?         // Optional: evaluation type (equals, boolean, exists, contains, range) - used in compliance dashboards like preset5
        let plistRecheckInterval: Int?  // Optional: interval in seconds to recheck plist (0 = disabled, 1-3600, default: 0) - for real-time monitoring
        let useUserDefaults: Bool?      // Optional: use UserDefaults for instant notification-based monitoring instead of file polling (default: false) - 2025-11-08
        let category: String?           // Optional: custom category name - used in compliance dashboards like preset5
        let categoryIcon: String?       // Optional: custom category icon - used in compliance dashboards like preset5

        //  Guidance Support - Migration Assistant style step-by-step workflow
        let guidanceTitle: String?      // Main title for the step by step workflow
        let guidanceContent: [GuidanceContent]? // Rich content blocks for the step
        let stepType: String?           // "info" | "confirmation" | "processing" | "completion"
        let autoAdvanceOnComplete: Bool? // Per-item override: Auto-navigate to next step after marking complete (overrides global setting)
        let actionButtonText: String?   // Custom button text for this step's action (e.g., "Start", "Confirm", "Install")
        let continueButtonText: String? // Custom button text after step completes to navigate to next step (e.g., "Next", "Proceed")
        let finalButtonText: String?    // Custom button text when this step is complete (e.g., "Finish" for completion step)
        let processingDuration: Int?    // For processing steps: duration in seconds
        let processingMessage: String?  // Message shown during processing

        // Progress bar state flags
        let blocking: Bool?             // Mark item as blocking further progress
        let required: Bool?             // Mark item as required for completion
        let observeOnly: Bool?          // Per-item observe-only override (overrides global observeOnly)

        // Custom status text labels for this specific item (overrides global UILabels)
        let completedStatus: String?    // Custom text for completed state (overrides "Installed")
        let downloadingStatus: String?  // Custom text for downloading state (overrides "Installing...")
        let pendingStatus: String?      // Custom text for pending state (overrides "Waiting")

        // Bento box simple content
        let info: [String]?             // Simple bullet-point list for cards
        let bentoSize: String?          // Card size: "small", "medium", "large", "wide", "tall" (default: "medium")
        let cardLayout: String?         // Card layout: "vertical-image-below", "horizontal-image-left", "horizontal-image-right", "pattern", "gradient" (default: "vertical-image-below")
        let gradientColors: [String]?   // Custom gradient colors for this card (hex strings like ["#9AA5A4", "#66bb6a"])
        let verticalSpacing: String?    // Vertical spacing mode for guide layout: "compact" (150pt text, 32pt gap), "balanced" (200pt text, 60pt gap - default), "generous" (250pt text, 80pt gap)

        // Guide custom content
        let keyPointsText: String?      // Custom paragraph text for "Key Points" section in guide steps (appears above bullet points)
        let highlightColor: String?     // Per-item accent/highlight color (hex string like "#61BB46") - overrides global highlightColor

        // Preset6 success/failure handling (Option 3 - Hybrid approach)
        let successMessage: String?     // Message shown when step completes successfully
        let failureMessage: String?     // Message shown when step fails

        // Preset6 progressive override mechanism (for stuck workflows)
        let waitWarningTime: Int?       // Show warning after X seconds waiting (default: 120)
        let waitSmallOverrideTime: Int? // Show small override link after X seconds (default: 30)
        let waitLargeOverrideTime: Int? // Show large override button after X seconds (default: 60)
        let overrideButtonText: String? // Custom text for override button (default: "Override")
        let allowOverride: Bool?        // Enable override capability (default: true)
        let allowNavigationDuringProcessing: Bool? // Allow Continue/Back buttons while processing (default: true)

        // Preset6 processing modes
        let processingMode: String?     // "simple" (default - auto-complete) | "progressive" (wait for triggers)
        let autoAdvance: Bool?          // Auto-navigate after simple mode completes (default: false)
        let autoResult: String?         // Force result in simple mode: "success" (default) | "failure" - for banner demos
        let waitForExternalTrigger: Bool? // If true, NEVER auto-complete - always wait for success:/failure: command (default: false)

        // Multiple plist monitors for automatic status component updates
        let plistMonitors: [PlistMonitor]? // Array of plist monitors that auto-update guidance components
        let completionMode: String?        // "any" (default) | "all" — how multiple completionTriggers combine

        // Multiple JSON monitors for automatic status component updates
        let jsonMonitors: [JsonMonitor]? // Array of JSON monitors that auto-update guidance components

        // Per-item detail overlay override (overrides global detailOverlay for this item)
        let itemOverlay: DetailOverlayConfig? // Optional per-item detail overlay content

        // Validation target badge - auto-update a status-badge when plist/json validation runs
        let validationTargetBadge: ValidationTargetBadge? // Specifies which badge to update with validation result

        // Intro/outro layout configuration (for stepType: "intro" or "outro")
        let introLayoutConfig: IntroLayoutConfig? // Optional styling for full-screen welcome/completion pages

        // Bundle info display for installed apps
        let showBundleInfo: String? // Display bundle info when app is installed: "version" (CFBundleShortVersionString), "build" (CFBundleVersion), "identifier" (CFBundleIdentifier), "all" (version + build)

        // Target badge configuration for validation results (plistKey + evaluation)
        struct ValidationTargetBadge: Codable {
            let blockIndex: Int             // Index in guidanceContent array to update
            let successState: String?       // State when validation passes (default: "success")
            let failState: String?          // State when validation fails (default: "fail")
        }

        // MARK: - Convenience Initializer for Auto-Discovery
        /// Creates an ItemConfig with only the essential fields for auto-discovered items
        init(
            id: String,
            displayName: String,
            icon: String? = nil,
            paths: [String] = [],
            guiIndex: Int = 0,
            category: String? = nil,
            categoryIcon: String? = nil,
            plistKey: String? = nil,
            expectedValue: String? = nil,
            evaluation: String? = nil
        ) {
            self.id = id
            self.displayName = displayName
            self.subtitle = nil
            self.guiIndex = guiIndex
            self.paths = paths
            self.icon = icon
            self.status = nil
            self.banner = nil
            self.plistKey = plistKey
            self.expectedValue = expectedValue
            self.evaluation = evaluation
            self.plistRecheckInterval = nil
            self.useUserDefaults = nil
            self.category = category
            self.categoryIcon = categoryIcon
            self.guidanceTitle = nil
            self.guidanceContent = nil
            self.stepType = nil
            self.autoAdvanceOnComplete = nil
            self.actionButtonText = nil
            self.continueButtonText = nil
            self.finalButtonText = nil
            self.processingDuration = nil
            self.processingMessage = nil
            self.blocking = nil
            self.required = nil
            self.observeOnly = nil
            self.completedStatus = nil
            self.downloadingStatus = nil
            self.pendingStatus = nil
            self.info = nil
            self.bentoSize = nil
            self.cardLayout = nil
            self.gradientColors = nil
            self.verticalSpacing = nil
            self.keyPointsText = nil
            self.highlightColor = nil
            self.successMessage = nil
            self.failureMessage = nil
            self.waitWarningTime = nil
            self.waitSmallOverrideTime = nil
            self.waitLargeOverrideTime = nil
            self.overrideButtonText = nil
            self.allowOverride = nil
            self.allowNavigationDuringProcessing = nil
            self.processingMode = nil
            self.autoAdvance = nil
            self.autoResult = nil
            self.waitForExternalTrigger = nil
            self.plistMonitors = nil
            self.completionMode = nil
            self.jsonMonitors = nil
            self.itemOverlay = nil
            self.validationTargetBadge = nil
            self.introLayoutConfig = nil
            self.showBundleInfo = nil
        }

        // MARK: - Custom Decoder with Defaults
        /// Provides sensible defaults for commonly omitted fields:
        /// - guiIndex: Defaults to 0 (can be auto-assigned by parent if needed)
        /// - paths: Defaults to empty array (no file completion triggers)
        private enum CodingKeys: String, CodingKey {
            case id, displayName, subtitle, guiIndex, paths, icon, status, banner
            case plistKey, expectedValue, evaluation, plistRecheckInterval, useUserDefaults
            case category, categoryIcon
            case guidanceTitle, guidanceContent, stepType
            case autoAdvanceOnComplete, actionButtonText, continueButtonText, finalButtonText
            case processingDuration, processingMessage
            case blocking, required, observeOnly
            case completedStatus, downloadingStatus, pendingStatus
            case info, bentoSize, cardLayout, gradientColors, verticalSpacing
            case keyPointsText, highlightColor
            case successMessage, failureMessage
            case waitWarningTime, waitSmallOverrideTime, waitLargeOverrideTime
            case overrideButtonText, allowOverride, allowNavigationDuringProcessing
            case processingMode, autoAdvance, autoResult, waitForExternalTrigger
            case plistMonitors, completionMode, jsonMonitors, itemOverlay, validationTargetBadge, introLayoutConfig
            case showBundleInfo
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            // Required fields
            id = try container.decode(String.self, forKey: .id)
            displayName = try container.decode(String.self, forKey: .displayName)

            // Fields with sensible defaults (no longer required in JSON)
            guiIndex = try container.decodeIfPresent(Int.self, forKey: .guiIndex) ?? 0
            paths = try container.decodeIfPresent([String].self, forKey: .paths) ?? []

            // All optional fields
            subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
            icon = try container.decodeIfPresent(String.self, forKey: .icon)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            banner = try container.decodeIfPresent(String.self, forKey: .banner)
            plistKey = try container.decodeIfPresent(String.self, forKey: .plistKey)
            expectedValue = try container.decodeIfPresent(String.self, forKey: .expectedValue)
            evaluation = try container.decodeIfPresent(String.self, forKey: .evaluation)
            plistRecheckInterval = try container.decodeIfPresent(Int.self, forKey: .plistRecheckInterval)
            useUserDefaults = try container.decodeIfPresent(Bool.self, forKey: .useUserDefaults)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            categoryIcon = try container.decodeIfPresent(String.self, forKey: .categoryIcon)
            guidanceTitle = try container.decodeIfPresent(String.self, forKey: .guidanceTitle)
            guidanceContent = try container.decodeIfPresent([GuidanceContent].self, forKey: .guidanceContent)
            stepType = try container.decodeIfPresent(String.self, forKey: .stepType)
            autoAdvanceOnComplete = try container.decodeIfPresent(Bool.self, forKey: .autoAdvanceOnComplete)
            actionButtonText = try container.decodeIfPresent(String.self, forKey: .actionButtonText)
            continueButtonText = try container.decodeIfPresent(String.self, forKey: .continueButtonText)
            finalButtonText = try container.decodeIfPresent(String.self, forKey: .finalButtonText)
            processingDuration = try container.decodeIfPresent(Int.self, forKey: .processingDuration)
            processingMessage = try container.decodeIfPresent(String.self, forKey: .processingMessage)
            blocking = try container.decodeIfPresent(Bool.self, forKey: .blocking)
            required = try container.decodeIfPresent(Bool.self, forKey: .required)
            observeOnly = try container.decodeIfPresent(Bool.self, forKey: .observeOnly)
            completedStatus = try container.decodeIfPresent(String.self, forKey: .completedStatus)
            downloadingStatus = try container.decodeIfPresent(String.self, forKey: .downloadingStatus)
            pendingStatus = try container.decodeIfPresent(String.self, forKey: .pendingStatus)
            info = try container.decodeIfPresent([String].self, forKey: .info)
            bentoSize = try container.decodeIfPresent(String.self, forKey: .bentoSize)
            cardLayout = try container.decodeIfPresent(String.self, forKey: .cardLayout)
            gradientColors = try container.decodeIfPresent([String].self, forKey: .gradientColors)
            verticalSpacing = try container.decodeIfPresent(String.self, forKey: .verticalSpacing)
            keyPointsText = try container.decodeIfPresent(String.self, forKey: .keyPointsText)
            highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
            successMessage = try container.decodeIfPresent(String.self, forKey: .successMessage)
            failureMessage = try container.decodeIfPresent(String.self, forKey: .failureMessage)
            waitWarningTime = try container.decodeIfPresent(Int.self, forKey: .waitWarningTime)
            waitSmallOverrideTime = try container.decodeIfPresent(Int.self, forKey: .waitSmallOverrideTime)
            waitLargeOverrideTime = try container.decodeIfPresent(Int.self, forKey: .waitLargeOverrideTime)
            overrideButtonText = try container.decodeIfPresent(String.self, forKey: .overrideButtonText)
            allowOverride = try container.decodeIfPresent(Bool.self, forKey: .allowOverride)
            allowNavigationDuringProcessing = try container.decodeIfPresent(Bool.self, forKey: .allowNavigationDuringProcessing)
            processingMode = try container.decodeIfPresent(String.self, forKey: .processingMode)
            autoAdvance = try container.decodeIfPresent(Bool.self, forKey: .autoAdvance)
            autoResult = try container.decodeIfPresent(String.self, forKey: .autoResult)
            waitForExternalTrigger = try container.decodeIfPresent(Bool.self, forKey: .waitForExternalTrigger)
            plistMonitors = try container.decodeIfPresent([PlistMonitor].self, forKey: .plistMonitors)
            completionMode = try container.decodeIfPresent(String.self, forKey: .completionMode)
            jsonMonitors = try container.decodeIfPresent([JsonMonitor].self, forKey: .jsonMonitors)
            itemOverlay = try container.decodeIfPresent(DetailOverlayConfig.self, forKey: .itemOverlay)
            validationTargetBadge = try container.decodeIfPresent(ValidationTargetBadge.self, forKey: .validationTargetBadge)
            introLayoutConfig = try container.decodeIfPresent(IntroLayoutConfig.self, forKey: .introLayoutConfig)
            showBundleInfo = try container.decodeIfPresent(String.self, forKey: .showBundleInfo)
        }
    }

    // Completion trigger - defines automatic step completion when plist condition met
    struct CompletionTrigger: Codable {
        let condition: String           // "equals" | "notEquals" | "exists" | "match" | "greaterThan" | "lessThan"
        let value: String?              // Expected value for comparison (optional for "exists")
        let result: String              // "success" | "failure" - completion result type
        let message: String?            // Optional custom completion message
        let delay: Double?              // Optional delay before triggering (in seconds, default: 0)
    }

    // Plist monitor configuration - binds plist keys to guidance components
    struct PlistMonitor: Codable {
        let path: String                // Plist file path (supports glob patterns like "*.installinfo.plist")
        let key: String                 // Plist key to monitor (supports dot notation like "Settings.Network")
        let guidanceBlockIndex: Int     // Index of guidance component to update (0-based)
        let targetProperty: String      // Property to update: "state", "actual", "currentPhase", "progress", "label"
        let valueMap: [String: String]? // Optional value transformation (e.g., {"1": "enabled", "0": "disabled"})
        let recheckInterval: Int        // Polling interval in seconds (1-3600)
        let useUserDefaults: Bool?      // Use UserDefaults for faster reads (default: false)
        let evaluation: String?         // Optional evaluation: "equals", "boolean", "exists", "contains", "range"
        let completionTrigger: CompletionTrigger? // Optional auto-completion when condition met (Phase 1 MVP)
    }

    // JSON monitor configuration - binds JSON keys to guidance components
    struct JsonMonitor: Codable {
        let path: String                // JSON file path (supports glob patterns like "*.config.json")
        let key: String                 // JSON key path to monitor (supports dot notation like "deployment.status")
        let guidanceBlockIndex: Int     // Index of guidance component to update (0-based)
        let targetProperty: String      // Property to update: "state", "actual", "currentPhase", "progress", "label"
        let valueMap: [String: String]? // Optional value transformation (e.g., {"running": "enabled", "stopped": "disabled"})
        let recheckInterval: Int        // Polling interval in seconds (1-3600)
        let evaluation: String?         // Optional evaluation: "equals", "boolean", "exists", "contains", "range"
        let completionTrigger: CompletionTrigger? // Optional auto-completion when condition met
    }

    // MARK: - Log Monitor Configuration
    /// Configuration for monitoring log files and extracting status text via regex patterns
    /// Works across Presets 1-3 and 6+ for real-time status updates from Installomator, Jamf, Munki, etc.
    struct LogMonitorConfig: Codable {
        let path: String                         // Log file path (supports ~)
        let preset: String?                      // Named preset: "installomator" | "jamf" | "munki" | "shell" | "mdm-installer"
        let pattern: String?                     // Custom regex (overrides preset)
        let predicate: String?                   // Filter: only process lines containing this string (e.g., "com.example.installer")
        let captureGroup: Int?                   // Capture group index (default: 1)
        let itemId: String?                      // Single target item ID (simple case)
        let itemIds: [String]?                   // Multiple target item IDs (bundle case — routes to all)
        let autoMatch: Bool?                     // Auto-match status to items by displayName (default: true)
        let startFromEnd: Bool?                  // Start from EOF (default: true)
    }

    // Guidance content blocks for rich text display eg. used in Preset6
    struct GuidanceContent: Codable {
        let type: String                // "text" | "highlight" | "warning" | "info" | "success" | "bullets" | "arrow" | "image" | "image-carousel" | "video" | "webcontent" | "portal-webview" | "checkbox" | "dropdown" | "radio" | "toggle" | "slider" | "textfield" | "button" | "status-badge" | "comparison-table" | "phase-tracker" | "progress-bar" | "compliance-card" | "compliance-header" | "feature-table" | "bento-grid"
        var content: String?            // The actual text content (or button label for type="button") - optional for status monitoring types
        var items: [String]?            // Array of items - e.g. bullets
        let numbered: Bool?             // For bullets: use numbered circle icons (1.circle.fill, 2.circle.fill, ...) instead of a single icon
        let color: String?              // Optional color override (hex format)
        let bold: Bool?                 // Whether to display in bold
        let visible: Bool?              // Show/hide this block dynamically (default: true) - can be updated via plistMonitor or update_guidance command

        // Image-specific fields (for type="image")
        let imageShape: String?         // "rectangle" | "square" | "circle" - shape/clipping for the image
        let imageWidth: Double?         // Custom width in points (default: 400)
        let imageBorder: Bool?          // Show border/shadow around image (default: true)
        var caption: String?            // Caption text displayed below the image

        // Video-specific fields (for type="video")
        let autoplay: Bool?             // Auto-play video on load (default: false)
        let videoHeight: Double?        // Video player height in points (default: 300)

        // Webcontent-specific fields (for type="webcontent")
        let webHeight: Double?          // Web view height in points (default: 400)

        // Portal-webview fields (for type="portal-webview") - embedded authenticated portal in guidance blocks
        let portalURL: String?          // Override portal URL for this block (uses global portalConfig if nil)
        let portalPath: String?         // Path within portal (e.g., "/device/self-service")
        let portalHeight: Double?       // Height of embedded portal view in points (default: 400)
        let portalShowHeader: Bool?     // Show portal header bar with refetch button (default: true)
        let portalShowRefetch: Bool?    // Show refetch button in header (default: true)
        let portalOfflineMessage: String? // Custom message when portal is offline
        let portalUserAgent: String?    // Custom user agent for requests
        let portalBrandingKey: String?  // Branding key to send as header (uses global portalConfig if nil)
        let portalBrandingHeader: String? // Header name for branding key (default: X-Brand-ID)
        let portalCustomHeaders: [String: String]? // Additional custom headers to send

        // Interactive element fields (for type="checkbox" | "dropdown" | "radio" | "toggle" | "slider")
        let id: String?                 // Unique identifier for storing user input
        let required: Bool?             // Whether this input is required for step completion
        let options: [String]?          // Options for dropdown/radio selections
        var value: String?              // Default/current value (for checkbox, toggle, dropdown, radio) or numeric value as string for slider
        var helpText: String?           // Optional help text displayed in info popover (i icon)

        // Slider-specific fields (for type="slider")
        let min: Double?                // Minimum value for slider (default: 0)
        let max: Double?                // Maximum value for slider (default: 100)
        let step: Double?               // Step increment for slider (default: 1)
        let unit: String?               // Unit label to display (e.g., "%", "GB", "minutes")
        let discreteSteps: [SliderStep]? // Optional array of discrete step values with labels

        // Slider discrete step configuration
        struct SliderStep: Codable {
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

        // Button-specific fields (for type="button")
        let action: String?             // Button action: "url", "shell", "request", "custom" (triggers callback)
        let url: String?                // URL to open (for action="url")
        let shell: String?              // Shell command to execute (for action="shell")
        let shellTimeout: Int?          // Timeout in seconds for shell command (default: 30)
        let requestId: String?          // Abstract identifier for script callback (for action="request", e.g., "profiles-install")
        let targetBadge: TargetBadgeConfig?  // Badge to update with shell command result
        let buttonStyle: String?        // Button style: "bordered" (default), "borderedProminent", "plain"

        // Target badge configuration for shell commands
        struct TargetBadgeConfig: Codable {
            let blockIndex: Int             // Index in guidanceContent array to update
            let successState: String?       // State on exit 0 (default: "success")
            let failState: String?          // State on non-zero exit (default: "fail")
            let pendingState: String?       // State while running (default: "pending")
        }

        // Overlay trigger (for any content type)
        let opensOverlay: Bool?         // When true, clicking this content block opens the item's overlay (default: false)

        // Status monitoring fields (for type="status-badge" | "comparison-table" | "phase-tracker" | "progress-bar")
        var label: String?              // Display label for status components
        let state: String?              // Current state (e.g., "enabled", "disabled", "active", "enrolled")
        let icon: String?               // SF Symbol icon name for status-badge
        let autoColor: Bool?            // Auto-assign colors based on state (default: true)
        let expected: String?           // Expected value for comparison-table
        let actual: String?             // Actual value for comparison-table
        let expectedLabel: String?      // Custom label for expected column (default: "Expected")
        let actualLabel: String?        // Custom label for actual column (default: "Actual")
        let expectedIcon: String?       // SF Symbol icon for expected value (comparison-table columns mode)
        let actualIcon: String?         // SF Symbol icon for actual value (comparison-table columns mode)
        let comparisonStyle: String?    // Comparison layout: "stacked" (default) or "columns"
        let highlightCells: Bool?       // Enable bold/larger text and stronger tinted backgrounds for columns mode (default: false)
        let expectedColor: String?      // Custom color for expected column (hex: "#FF3B30"), overrides match-based coloring
        let actualColor: String?        // Custom color for actual column (hex: "#34C759"), overrides match-based coloring
        let category: String?           // Category name for grouping comparison-tables
        let currentPhase: Int?          // Current phase number (1-based) for phase-tracker
        let phases: [String]?           // Phase labels for phase-tracker
        let style: String?              // Display style: "stepper" (default), "progress", "checklist" for phase-tracker; "indeterminate" (default) or "determinate" for progress-bar
        let progress: Double?           // Progress value (0.0 to 1.0) for determinate progress-bar

        // Image carousel fields (for type="image-carousel")
        let images: [String]?           // Array of image paths for carousel
        let captions: [String]?         // Optional captions for each image (array must match images length)
        let imageHeight: Double?        // Custom height in points (default: 300)
        let showDots: Bool?             // Show dot page indicators (default: true)
        let showArrows: Bool?           // Show left/right arrow navigation buttons (default: true)
        let autoAdvance: Bool?          // Enable automatic slide advancement (default: false)
        let autoAdvanceDelay: Double?   // Seconds between auto-advances (default: 3.0)
        let transitionStyle: String?    // Transition animation: "slide" (default) | "fade"
        let currentIndex: Int?          // Current image index (0-based) for dynamic updates

        // Compliance card fields (for type="compliance-card", migrated from Preset5)
        let categoryName: String?       // Category name displayed in card header
        let passed: Int?                // Number of passed items in category
        let total: Int?                 // Total number of items in category
        let cardIcon: String?           // SF Symbol icon for category (displayed in header)
        let checkDetails: String?       // Optional compact bullet-point details to display inside card (newline-separated, supports Unicode symbols)

        // Feature table fields (for type="feature-table")
        let columns: [FeatureTableColumn]?  // Column definitions with labels and optional icons
        let rows: [FeatureTableRow]?        // Row definitions with feature text and boolean values per column

        struct FeatureTableColumn: Codable {
            let label: String               // Column header label (e.g., "Safari", "Chrome")
            let icon: String?               // Optional SF Symbol icon for column header
        }

        struct FeatureTableRow: Codable {
            let feature: String             // Feature description text
            let values: [Bool]              // Boolean values for each column (true = checkmark, false = X)
        }

        // Wallpaper picker fields (for type="wallpaper-picker")
        // Displays categorized image tiles for desktop wallpaper selection
        // Selection outputs full path for use with desktoppr CLI tool
        let wallpaperCategories: [WallpaperCategory]?  // Array of image categories
        let wallpaperColumns: Int?                      // Number of columns per row (default: 4)
        let wallpaperLayout: String?                    // "categories" (default) | "grid" | "row" - layout mode
        let wallpaperImageFit: String?                  // "fill" (default) | "fit" - how to display images
        let wallpaperThumbnailHeight: Double?           // Height of thumbnail images (default: 100)
        let wallpaperSelectionKey: String?              // Key for storing selection (default: "wallpaper")
        let wallpaperShowPath: Bool?                    // Show file path below selection (default: false)
        let wallpaperConfirmButton: String?             // Optional confirm button text (if set, shows button to confirm selection)
        let wallpaperMultiSelect: Int?                  // Number of monitors for multi-select (nil/0 = single select)

        // Install list fields (for type="install-list")
        // Traditional installation progress list with app icons and status indicators
        let installItems: [InstallItem]?                // Array of installable items

        // Install item definition for install-list type
        struct InstallItem: Codable {
            let title: String               // App/item name (e.g., "Microsoft Teams")
            let subtitle: String?           // Optional subtitle (e.g., "Installing...")
            let icon: String?               // Icon path or SF Symbol name
            let status: String?             // "pending" | "wait" | "success" | "fail" | "progress" (static fallback)
            let progress: Double?           // Progress value 0-100 (for status="progress")
            let itemId: String?             // Links to items[] entry for dynamic status from completedItems/downloadingItems
        }

        // Bento grid fields (for type="bento-grid")
        // CSS Grid-like layouts with variable cell sizes (1x1, 2x1, 1x2, 2x2)
        let bentoColumns: Int?              // Grid columns (default: 4)
        let bentoRowHeight: Double?         // Base row height in points (default: 140)
        let bentoGap: Double?               // Gap between cells in points (default: 12)
        let bentoTintColor: String?         // Base hex color for auto-tinting cells without explicit backgroundColor
        let bentoCells: [BentoCellConfig]?  // Cell definitions

        // Bento cell configuration for bento-grid type
        struct BentoCellConfig: Codable, Identifiable {
            let id: String                  // Unique cell identifier
            let column: Int                 // 0-based column position
            let row: Int                    // 0-based row position
            let columnSpan: Int?            // 1-4 (default: 1)
            let rowSpan: Int?               // 1-2 (default: 1)

            // Content type determines rendering mode
            let contentType: String         // "image" | "text" | "icon" | "mixed"

            // Image content (for contentType="image" or "mixed")
            let imagePath: String?          // Path to image file
            let imageFit: String?           // "fill" | "fit" (default: "fill")

            // Text content (for contentType="text" or "mixed")
            let title: String?              // Main title text
            let subtitle: String?           // Secondary text
            let textSize: String?           // "large" | "medium" | "small" (default: "medium")
            let textColor: String?          // Hex color for text

            // Icon content (for contentType="icon")
            let sfSymbol: String?           // SF Symbol name
            let iconSize: Double?           // Icon size in points (default: 48)
            let iconColor: String?          // Hex color for SF Symbol (overrides accentColor)
            let iconWeight: String?         // SF Symbol weight: "ultralight", "thin", "light", "regular", "medium", "semibold", "bold", "heavy", "black"

            // Cell styling
            let backgroundColor: String?    // Hex color for cell background
            let cornerRadius: Double?       // Corner radius (default: 12)

            // Category label — small-caps text above the title (e.g. "SECURITY", "APPS")
            let label: String?

            // Interaction - opens detail overlay when tapped
            let detailOverlay: DetailOverlayConfig?
        }
    }

    struct PlistSourceConfig: Codable {
        let path: String                    // Path to plist file
        let type: String                    // "compliance", "health", "licenses", "preferences", "custom"
        let displayName: String             // Human-readable name
        let icon: String?                   // SF Symbol icon name
        let keyMappings: [KeyMapping]?      // How to interpret plist keys
        let successValues: [String]?        // Values that indicate "success" (for booleans: ["true"])
        let criticalKeys: [String]?         // Keys that are considered critical
        let categoryPrefix: [String: String]? // Map prefixes to category names
        let categoryIcons: [String: String]? // Map category names to icon strings (e.g., "OS Security": "sf=shield.fill,colour1=#007AFF")
        let maxCheckDetails: Int?           // Max check items to display per category (default: 15)

        // MARK: - Auto-Discovery Options
        let autoDiscover: Bool?             // If true, auto-generate items from plist keys
        let findingKey: String?             // Subkey to check for findings (default: "finding")
        let expectedValue: String?          // Expected value for compliance (default: "false")
        let evaluation: String?             // Evaluation type: "boolean", "string", etc. (default: "boolean")
        let excludeKeys: [String]?          // Keys to exclude from auto-discovery
        let includePattern: String?         // Regex pattern to include keys (optional)
    }

    struct KeyMapping: Codable {
        let key: String                     // Original plist key
        let displayName: String?            // Human-readable name (optional)
        let category: String?               // Override category (optional)
        let isCritical: Bool?              // Override critical status (optional)
    }

    struct CategoryHelp: Codable {
        let category: String                // Category name to match
        let description: String             // Description of the category
        let recommendations: String?        // Recommendations if not compliant
        let icon: String?                   // Optional custom icon for the category
        let statusLabel: String?            // Optional custom label for "Compliance Status"
        let recommendationsLabel: String?   // Optional custom label for "Recommended Actions"
    }

    /// We try here a cross-preset approach fro UI text customization labels (currently > Presets 1-9)
    /// Use this for overriding default status text, progress formats, and completion messages
    /// Note: Primary UI config (title, message, button text) remains at top level
    struct UILabels: Codable {
        // Status text overrides for items
        let completedStatus: String?        // Label for completed items (default: "Completed")
        let downloadingStatus: String?      // Label for downloading items (default: "Installing...")
        let pendingStatus: String?          // Label for pending items (default: "Pending")
        let failedStatus: String?           // Label for validation failure (default: "Failed")

        // Progress bar text templates (use {completed}, {total}, {current} as placeholders)
        let progressFormat: String?         // Progress bar text (default: "{completed} of {total} completed")
        let stepCounterFormat: String?      // Step counter text (default: "Step {current} of {total}")

        // Completion celebration messages
        let completionMessage: String?      // Main completion message (default: "All Complete!")
        let completionSubtitle: String?     // Subtitle completion message (default: "Setup complete!")

        // Section headers (used in Preset1 and others)
        let sectionHeaderCompleted: String?  // Completed section header (default: "Completed")
        let sectionHeaderPending: String?    // Pending section header (default: "Pending Installation")
        let sectionHeaderFailed: String?     // Failed section header (default: "Installation Failed")

        // Step/Item workflow status labels (used in onboarding and multi-step flows)
        let statusConditionMet: String?     // Status when validation passes (default: "Condition Met")
        let statusConditionNotMet: String?  // Status when validation fails (default: "Condition Not Met")
        let statusChecking: String?         // Status during validation/download (default: "Checking...")
        let statusReadyToStart: String?     // Initial state status (default: "Ready to Start")
        let statusInProgress: String?       // Active step status (default: "In Progress")

        // MARK: - Guide Layout Labels
        // Welcome screen customization
        let welcomeTitle: String?           // Welcome page title (default: "Welcome")
        let welcomeBadge: String?           // Welcome badge text (default: "GETTING STARTED")
        let welcomeParagraph1: String?      // Main welcome paragraph
        let welcomeParagraph2: String?      // Secondary welcome paragraph

        // Sidebar and section labels
        let guideInformationLabel: String?  // Sidebar section header (default: "Guide Information")
        let sectionsLabel: String?          // Page counter label (default: "SECTIONS")
        let keyPointsLabel: String?         // Content card header (default: "Key Points")

        // Minimal layout (alternative welcome screen)
        let getStartedTitle: String?        // Minimal welcome title (default: "Get Started")
        let getStartedSubtitle: String?     // Minimal welcome subtitle (default: "Follow the steps to complete setup")

        // Fallback messages
        let imageNotAvailable: String?      // Image error message (default: "Image not available")

    }

    /// Compliance dashboard labels (Preset5 specific)
    /// These are specialized labels for security compliance and validation workflows
    struct ComplianceLabels: Codable {
        let complianceStatus: String?       // Label for "Compliance Status"
        let recommendedActions: String?     // Label for "Recommended Actions"
        let securityDetails: String?        // Label for "Security Details"
        let lastCheck: String?              // Label for "Last Check"
        let passed: String?                 // Label for "passed"
        let failed: String?                 // Label for "failed"
        let checksPassed: String?           // Format for "X of Y checks passed" (use {passed}, {total})
    }

    /// Picker configuration (Global - all presets with picker support)
    /// Enables presets to function as single or multi-select pickers
    /// Used by legacy presets, and future presets that support picker mode
    struct PickerConfig: Codable {
        let selectionMode: String?          // "single" | "multi" | "none" (default: "none" = standard mode)
        let returnSelections: Bool?         // Write selections to output plist (default: false)
        let outputPath: String?             // Custom output plist path (default: "/tmp/picker_selections.plist")
        let allowContinueWithoutSelection: Bool? // Allow finishing without selection (default: false for single/multi)
    }

    /// Instruction banner configuration (Global - all presets)
    /// Displays a dismissible instruction banner at the top of the view
    struct InstructionBannerConfig: Codable {
        let text: String?                   // Banner message text (required if config present)
        let icon: String?                   // Optional SF Symbol icon name
        let autoDismiss: Bool?              // Auto-hide after delay (default: true)
        let dismissDelay: Double?           // Seconds before auto-hide (default: 5.0)
        let showOnce: Bool?                 // Show only on first page/step (default: false)
    }

    /// Picker mode labels (Global - all presets with picker support)
    /// Used when a preset operates in single-select or multi-select picker mode
    /// This provides consistent picker UI text across legacy presets, and future presets
    struct PickerLabels: Codable {
        // Selection action buttons
        let selectButtonText: String?       // Selection button text (default: "Select This")
        let selectedButtonText: String?     // Selected state button text (default: "✓ Selected")
        let deselectButtonText: String?     // Deselect button text for multi-mode (default: "Deselect")

        // Navigation (picker-specific overrides for multi-page pickers)
        let continueButton: String?         // Continue to next page (default: "Continue")
        let finishButton: String?           // Complete picker action (default: "Finish")
        let backButton: String?             // Go to previous page (default: "Previous")
        let pageCounterFormat: String?      // Page indicator format (default: "{current} / {total}")

        // User feedback and guidance
        let selectionPrompt: String?        // Top-level prompt text (e.g., "Select your desktop background")
        let selectionRequired: String?      // Error message when selection required but not made
        let multiSelectHint: String?        // Hint for multi-select mode (default: "You can select multiple items")
    }

    /// Detail overlay configuration (Global - all presets)
    /// Provides a customizable flyout/sheet overlay for help, support info, or detailed content
    /// Can display rich content using GuidanceContent blocks, system info, and template variables
    ///
    /// **Gallery Presentation Mode:**
    /// Set `presentationMode: "gallery"` to display images in a carousel/grid format
    /// Perfect for visual step-by-step instructions, before/after comparisons, or screenshot guides
    struct DetailOverlayConfig: Codable {
        let enabled: Bool?                  // Enable overlay (default: true when config present)
        let size: String?                   // "small" | "medium" | "large" | "full" (default: "medium")
        let title: String?                  // Overlay title (default: "Help")
        let subtitle: String?               // Optional subtitle below title
        let icon: String?                   // SF Symbol or image path for header
        let overlayIcon: String?            // Overlay icon for header (badge style)
        let content: [GuidanceContent]?     // Rich content blocks (reuse existing GuidanceContent)
        let showSystemInfo: Bool?           // Include system info section (default: true)
        let showProgressInfo: Bool?         // Include progress/installation info (default: false)
        let closeButtonText: String?        // Close button text (default: "Close")
        let backgroundColor: String?        // Optional background color override (hex)
        let showDividers: Bool?             // Show section dividers (default: true)

        // Gallery presentation mode (for visual instructions)
        let presentationMode: String?       // "standard" (default) | "gallery" - switches between text and image-focused layouts
        let galleryImages: [String]?        // Array of image paths for gallery mode (required when presentationMode: "gallery")
        let galleryCaptions: [String]?      // Optional captions for each image (1:1 mapping with galleryImages)
        let galleryLayout: String?          // "carousel" (default) | "grid" | "sideBySide" - gallery display style
        let gallerySideContent: [GuidanceContent]?  // Content blocks shown on right side in sideBySide layout
        let showStepCounter: Bool?          // Show "Step 2 of 5" counter in gallery mode (default: true)
        let showNavigationArrows: Bool?     // Show prev/next arrow buttons in carousel mode (default: true)
        let showThumbnails: Bool?           // Show thumbnail strip below main image for quick navigation (default: true)
        let imageHeight: Double?            // Maximum height for gallery images in points (default: 400)
        let thumbnailSize: Double?          // Thumbnail dimensions in points (default: 60)
        let allowImageZoom: Bool?           // Allow clicking image to view fullscreen (default: false)
        let wide: Bool?                     // Use wider overlay dimensions (default: false)

        /// Manual initializer for creating configs programmatically (needed for item-specific overlays)
        init(
            enabled: Bool? = nil,
            size: String? = nil,
            title: String? = nil,
            subtitle: String? = nil,
            icon: String? = nil,
            overlayIcon: String? = nil,
            content: [GuidanceContent]? = nil,
            showSystemInfo: Bool? = nil,
            showProgressInfo: Bool? = nil,
            closeButtonText: String? = nil,
            backgroundColor: String? = nil,
            showDividers: Bool? = nil,
            presentationMode: String? = nil,
            galleryImages: [String]? = nil,
            galleryCaptions: [String]? = nil,
            galleryLayout: String? = nil,
            gallerySideContent: [GuidanceContent]? = nil,
            showStepCounter: Bool? = nil,
            showNavigationArrows: Bool? = nil,
            showThumbnails: Bool? = nil,
            imageHeight: Double? = nil,
            thumbnailSize: Double? = nil,
            allowImageZoom: Bool? = nil,
            wide: Bool? = nil
        ) {
            self.enabled = enabled
            self.size = size
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.overlayIcon = overlayIcon
            self.content = content
            self.showSystemInfo = showSystemInfo
            self.showProgressInfo = showProgressInfo
            self.closeButtonText = closeButtonText
            self.backgroundColor = backgroundColor
            self.showDividers = showDividers
            self.presentationMode = presentationMode
            self.galleryImages = galleryImages
            self.galleryCaptions = galleryCaptions
            self.galleryLayout = galleryLayout
            self.gallerySideContent = gallerySideContent
            self.showStepCounter = showStepCounter
            self.showNavigationArrows = showNavigationArrows
            self.showThumbnails = showThumbnails
            self.imageHeight = imageHeight
            self.thumbnailSize = thumbnailSize
            self.allowImageZoom = allowImageZoom
            self.wide = wide
        }
    }

    /// Help button configuration (Global - all presets)
    /// Displays a floating or inline help button that can trigger overlay, open URL, or custom action
    struct HelpButtonConfig: Codable {
        // Display properties
        let enabled: Bool?                  // Show help button (default: true when config present)
        let icon: String?                   // SF Symbol icon (default: "questionmark.circle")
        let label: String?                  // Optional button label text (e.g., "Help")
        let tooltip: String?                // Hover tooltip text (default: "Get Help")
        let style: String?                  // "floating" | "inline" | "toolbar" (default: "floating")

        // Action properties
        let action: String?                 // "overlay" (default) | "url" | "custom"
        let url: String?                    // URL to open (for action: "url")
        let customId: String?               // Custom identifier for interaction log (for action: "custom")

        // Position properties
        let position: String?               // "topRight" | "topLeft" | "bottomRight" | "bottomLeft" |
                                            // "sidebar" | "buttonBar" (default: "bottomRight")

        /// Memberwise initializer for programmatic creation
        init(enabled: Bool? = nil, icon: String? = nil, label: String? = nil,
             tooltip: String? = nil, style: String? = nil, action: String? = nil,
             url: String? = nil, customId: String? = nil, position: String? = nil) {
            self.enabled = enabled
            self.icon = icon
            self.label = label
            self.tooltip = tooltip
            self.style = style
            self.action = action
            self.url = url
            self.customId = customId
            self.position = position
        }
    }

    // MARK: - Portal/WebView Configuration (Preset5)

    /// Self-service portal configuration with authenticated WebView
    /// Enables embedding IT self-service portals with token-based authentication
    ///
    /// **Token Flow**:
    /// 1. Read authentication secret from `authSources` (file, keychain, or script)
    /// 2. POST to `portalURL + tokenEndpoint` to generate session token
    /// 3. Inject token as HTTP header in WKWebView requests
    /// 4. Auto-refresh before expiry (based on `tokenRefreshInterval`)
    struct PortalConfig: Codable {
        let provider: String?                   // Provider type for auth flow (default: "generic")
        let portalURL: String?                  // Base URL of the self-service portal (fallback if portalURLFile not found)
        let portalURLFile: String?              // Path to file containing portal URL (read at launch, overrides portalURL)
        let selfServicePath: String?            // Path within portal (default: "/")
        let tokenEndpoint: String?              // Token generation API endpoint
        let tokenRefreshInterval: Int?          // Refresh token X seconds before expiry (default: 300 = 5 min)
        let authSources: AuthSources?           // Where to find authentication credentials
        let offlineMode: String?                // "cache" | "fallback" | "error" (default: "fallback")
        let retryCount: Int?                    // Max retry attempts (default: 3)
        let retryDelay: Double?                 // Base delay between retries in seconds (default: 2.0)
        let fallbackMessage: String?            // Message shown when portal is unavailable
        let supportURL: String?                 // IT support portal URL
        let supportContact: String?             // Contact info shown when offline (phone, email, etc.)
        let cacheContentForOffline: Bool?       // Cache HTML for offline viewing (default: true)
        let cacheDuration: Int?                 // Cache validity in seconds (default: 86400 = 24 hours)
        let userAgent: String?                  // Custom User-Agent for web requests (e.g., "swiftdialog.self-service/1.0")
        let stateDomain: String?                // UserDefaults domain for state persistence (default: "com.swiftdialog.preset5")
        let selfServiceOnly: Bool?              // Skip outro screens, go directly to exit after portal (default: false)
        let brandingKey: String?                // Branding identifier value (e.g., "corporate", "division-a", "tenant-123")
        let brandingHeaderName: String?         // Header name for branding (default: "X-Brand-ID", or "X-Tenant-ID", "X-Org-ID", "X-Theme-ID", etc.)
        let customHeaders: [String: String]?    // Additional custom HTTP headers to send with all requests
        let clientCertSubject: String?          // Client certificate subject for mTLS
        let button1Text: String?                // Portal-specific primary button text (overrides global button1text)
        let button2Text: String?                // Portal-specific secondary button text (overrides global button2text)
        let ephemeralSession: Bool?             // Use non-persistent data store (default: false — persistent, backwards-compatible)
        let errorDetectionPhrases: [String]?    // DOM phrases that indicate an error page (opt-in, default: empty)
        let errorDetectionThreshold: Int?       // Number of phrase matches to trigger error state (default: 2)
        let openExternalLinksInBrowser: Bool?   // Open non-portal links in default browser (default: true)

        /// Authentication source configuration - where to find credentials
        struct AuthSources: Codable {
            // Static token (for Cloudflare, pre-configured bearer tokens, etc.)
            let staticToken: String?            // Direct bearer token value

            // File-based token sources
            let secretFile: String?             // Path to secret/token file

            // Keychain-based token sources
            let keychainService: String?        // Keychain service name
            let keychainAccount: String?        // Keychain account name

            // Script-based token generation
            let scriptPath: String?             // Custom script to generate token
            let scriptTimeout: Int?             // Script timeout in seconds (default: 30)

            // Header injection configuration
            let headerName: String?             // HTTP header name (default: "Authorization")
            let headerPrefix: String?           // Header value prefix (default: "Bearer ")

            // mTLS client certificate authentication
            let clientCertIdentity: String?     // Common name of client certificate in keychain
            let clientCertKeychain: String?     // Keychain name (default: login keychain)
        }
    }

    /// MDM AppConfig source configuration
    /// Specifies where to read managed preferences for dynamic branding
    ///
    /// **Pattern**: MDM (Jamf, Kandji, etc.) pushes managed preferences to device.
    /// Dialog reads these preferences at runtime to determine branding.
    ///
    /// **Priority**: MDM values always override JSON config values
    struct AppConfigSource: Codable {
        let domain: String?                     // Preference domain (e.g., "com.company.branding")

        // Maps MDM keys to existing InspectConfig fields
        let highlightColorKey: String?          // MDM key → highlightColor
        let accentBorderColorKey: String?       // MDM key → accentBorderColor
        let footerBackgroundColorKey: String?   // MDM key → footerBackgroundColor
        let footerTextColorKey: String?         // MDM key → footerTextColor
        let footerTextKey: String?              // MDM key → footerText
        let portalURLKey: String?               // MDM key → portalConfig.portalURL override
        let supportURLKey: String?              // MDM key → portalConfig.supportURL override
        let logoPathKey: String?                // MDM key → logoConfig.imagePath override

        // Button text mappings for localization
        let button1TextKey: String?             // MDM key → button1text (primary button)
        let button2TextKey: String?             // MDM key → button2text (secondary button)
        let introTitleKey: String?              // MDM key → intro screen title
        let introButtonTextKey: String?         // MDM key → intro continue button text
        let outroTitleKey: String?              // MDM key → outro screen title
        let outroButtonTextKey: String?         // MDM key → outro close button text

        let allowedBrandsKey: String?              // MDM key → array of allowed brand IDs (for brand picker filtering)

        let customKeys: [String: String]?       // Additional key mappings for extension
    }

    // MARK: - Brand Palette Configuration

    /// Brand color palette for theming with semantic color tokens and logo presets
    ///
    /// Defines named colors and logos that can be referenced throughout config using `$tokenName` syntax.
    /// Example: `"highlightColor": "$primary"` resolves to the palette's primary color.
    ///
    /// **Token Reference Syntax:**
    /// - `$primary`, `$success`, etc. → resolves to color hex value
    /// - `$logos.main` → resolves to logo path or SF Symbol string
    /// - `$custom.myColor` → resolves to custom token value
    ///
    /// **Deep Interpolation:**
    /// Tokens work inside strings: `"SF=icon,colour1=$primary"` → `"SF=icon,colour1=#6366F1"`
    struct BrandPalette: Codable {
        // Core semantic colors
        let primary: String?        // Main brand color (default: #6366F1 indigo-500)
        let secondary: String?      // Secondary accent (default: #8B5CF6 violet-500)
        let accent: String?         // Highlight/attention color (default: #F59E0B amber-500)

        // Status colors
        let success: String?        // Positive states (default: #22C55E green-500)
        let warning: String?        // Caution states (default: #F59E0B amber-500)
        let error: String?          // Error/failure states (default: #EF4444 red-500)
        let info: String?           // Informational states (default: #3B82F6 blue-500)

        // Surface colors
        let background: String?     // Main background (default: #0F172A slate-900)
        let surface: String?        // Card/panel background (default: #1E293B slate-800)
        let surfaceLight: String?   // Light mode surface (default: #F8FAFC slate-50)

        // Text colors
        let textPrimary: String?    // Primary text (default: #F8FAFC slate-50)
        let textSecondary: String?  // Muted/secondary text (default: #94A3B8 slate-400)

        // Logo presets (name → path or SF Symbol string)
        // Example: "main": "SF=building.2.fill,colour1=#17C9A5"
        let logos: [String: String]?

        // Arbitrary custom tokens for flexibility
        // Example: "brandTeal": "#17C9A5"
        let custom: [String: String]?

        /// Provides Tailwind-based defaults for any nil values
        func resolved() -> BrandPalette {
            BrandPalette(
                primary: primary ?? "#6366F1",       // indigo-500
                secondary: secondary ?? "#8B5CF6",   // violet-500
                accent: accent ?? "#F59E0B",         // amber-500
                success: success ?? "#22C55E",       // green-500
                warning: warning ?? "#F59E0B",       // amber-500
                error: error ?? "#EF4444",           // red-500
                info: info ?? "#3B82F6",             // blue-500
                background: background ?? "#0F172A", // slate-900
                surface: surface ?? "#1E293B",       // slate-800
                surfaceLight: surfaceLight ?? "#F8FAFC", // slate-50
                textPrimary: textPrimary ?? "#F8FAFC",   // slate-50
                textSecondary: textSecondary ?? "#94A3B8", // slate-400
                logos: logos,
                custom: custom
            )
        }

        /// Default Tailwind-based palette
        static let tailwindDefault = BrandPalette(
            primary: "#6366F1",       // indigo-500
            secondary: "#8B5CF6",     // violet-500
            accent: "#F59E0B",        // amber-500
            success: "#22C55E",       // green-500
            warning: "#F59E0B",       // amber-500
            error: "#EF4444",         // red-500
            info: "#3B82F6",          // blue-500
            background: "#0F172A",    // slate-900
            surface: "#1E293B",       // slate-800
            surfaceLight: "#F8FAFC",  // slate-50
            textPrimary: "#F8FAFC",   // slate-50
            textSecondary: "#94A3B8", // slate-400
            logos: nil,
            custom: nil
        )
    }

    // Generic color threshold system for all presets
    struct ColorThresholds: Codable {
        let excellent: Double              // Default: 90%+ = Green
        let good: Double                   // Default: 70%+ = Blue
        let warning: Double                // Default: 50%+ = Orange
        // Below warning = Red

        // Configurable labels for different use cases
        let excellentLabel: String?        // e.g., "Excellent", "Secure", "Complete"
        let goodLabel: String?             // e.g., "Good", "Safe", "In Progress"
        let warningLabel: String?          // e.g., "Warning", "At Risk", "Needs Attention"
        let criticalLabel: String?         // e.g., "Critical", "Unsafe", "Failed"

        // Configurable colors (hex strings)
        let excellentColor: String?        // Custom color for excellent range
        let goodColor: String?             // Custom color for good range
        let warningColor: String?          // Custom color for warning range
        let criticalColor: String?         // Custom color for critical range

        static let `default` = ColorThresholds(
            excellent: 0.9, good: 0.7, warning: 0.5,
            excellentLabel: nil, goodLabel: nil, warningLabel: nil, criticalLabel: nil,
            excellentColor: nil, goodColor: nil, warningColor: nil, criticalColor: nil
        )

        func getColor(for score: Double) -> Color {
            if score >= excellent {
                return excellentColor != nil ? Color(hex: excellentColor!) : .green
            } else if score >= good {
                return goodColor != nil ? Color(hex: goodColor!) : .blue
            } else if score >= warning {
                return warningColor != nil ? Color(hex: warningColor!) : .orange
            } else {
                return criticalColor != nil ? Color(hex: criticalColor!) : .red
            }
        }

        func getLabel(for score: Double) -> String {
            if score >= excellent {
                return excellentLabel ?? "Excellent"
            } else if score >= good {
                return goodLabel ?? "Good"
            } else if score >= warning {
                return warningLabel ?? "Warning"
            } else {
                return criticalLabel ?? "Critical"
            }
        }

        func getStatusIcon(for score: Double) -> String {
            if score >= excellent {
                return "checkmark.circle.fill"
            } else if score >= good {
                return "checkmark.circle"
            } else if score >= warning {
                return "exclamationmark.triangle.fill"
            } else {
                return "x.circle.fill"
            }
        }

        // Utility method for progress text
        func getProgressText(passed: Int, total: Int) -> String {
            let score = total > 0 ? Double(passed) / Double(total) : 0.0
            let percentage = Int(score * 100)
            return "\(passed)/\(total) (\(percentage)%)"
        }

        // Utility method for status badges
        func getStatusBadge(for score: Double) -> (color: Color, label: String, icon: String) {
            return (
                color: getColor(for: score),
                label: getLabel(for: score),
                icon: getStatusIcon(for: score)
            )
        }

        // Helper methods for flexible positive/negative color theming
        func getPositiveColor() -> Color {
            return excellentColor != nil ? Color(hex: excellentColor!) : .green
        }

        func getNegativeColor() -> Color {
            return criticalColor != nil ? Color(hex: criticalColor!) : .red
        }

        func getValidationColor(isValid: Bool) -> Color {
            return isValid ? getPositiveColor() : getNegativeColor()
        }
    }

    /// Custom encoder required because:
    /// 1. **Swift Limitation**: When implementing custom `init(from:)`, Swift requires matching `encode(to:)`
    /// 2. **Deprecated Field Exclusion**: Omits deprecated fields (button2Disabled, buttonStyle) from encoding
    ///
    /// Note: While InspectConfig is primarily used for *reading* JSON configs (not writing), Swift's
    /// Codable protocol requires both decoder and encoder when either is customized.
    ///
    /// Reference: https://www.hackingwithswift.com/books/ios-swiftui/adding-codable-conformance-for-published-properties
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encodeIfPresent(infobox, forKey: .infobox)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(iconsize, forKey: .iconsize)
        try container.encodeIfPresent(width, forKey: .width)
        try container.encodeIfPresent(height, forKey: .height)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(scanInterval, forKey: .scanInterval)
        try container.encodeIfPresent(cachePaths, forKey: .cachePaths)
        try container.encodeIfPresent(sideMessage, forKey: .sideMessage)
        try container.encodeIfPresent(sideInterval, forKey: .sideInterval)
        try container.encodeIfPresent(style, forKey: .style)
        try container.encodeIfPresent(liststyle, forKey: .liststyle)
        try container.encodeIfPresent(preset, forKey: .preset)
        try container.encodeIfPresent(popupButton, forKey: .popupButton)
        try container.encodeIfPresent(highlightColor, forKey: .highlightColor)
        try container.encodeIfPresent(secondaryColor, forKey: .secondaryColor)
        try container.encodeIfPresent(backgroundColor, forKey: .backgroundColor)
        try container.encodeIfPresent(backgroundImage, forKey: .backgroundImage)
        try container.encodeIfPresent(backgroundOpacity, forKey: .backgroundOpacity)
        try container.encodeIfPresent(textOverlayColor, forKey: .textOverlayColor)
        try container.encodeIfPresent(gradientColors, forKey: .gradientColors)
        try container.encodeIfPresent(button1Text, forKey: .button1Text)
        try container.encodeIfPresent(button1Disabled, forKey: .button1Disabled)
        try container.encodeIfPresent(button2Text, forKey: .button2Text)
        try container.encodeIfPresent(button2Visible, forKey: .button2Visible)
        try container.encodeIfPresent(autoEnableButton, forKey: .autoEnableButton)
        try container.encodeIfPresent(autoEnableButtonText, forKey: .autoEnableButtonText)
        try container.encodeIfPresent(hideSystemDetails, forKey: .hideSystemDetails)
        try container.encodeIfPresent(colorThresholds, forKey: .colorThresholds)
        try container.encodeIfPresent(plistSources, forKey: .plistSources)
        try container.encodeIfPresent(categoryHelp, forKey: .categoryHelp)
        try container.encodeIfPresent(uiLabels, forKey: .uiLabels)
        try container.encodeIfPresent(complianceLabels, forKey: .complianceLabels)
        try container.encodeIfPresent(pickerConfig, forKey: .pickerConfig)
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
        try container.encodeIfPresent(imageSyncMode, forKey: .imageSyncMode)
        try container.encodeIfPresent(backButtonStyle, forKey: .backButtonStyle)
        try container.encodeIfPresent(stepStyle, forKey: .stepStyle)
        try container.encodeIfPresent(listIndicatorStyle, forKey: .listIndicatorStyle)
        try container.encodeIfPresent(progressBarConfig, forKey: .progressBarConfig)
        try container.encodeIfPresent(logoConfig, forKey: .logoConfig)
        try container.encodeIfPresent(detailOverlay, forKey: .detailOverlay)
        try container.encodeIfPresent(helpButton, forKey: .helpButton)
        try container.encodeIfPresent(actionPipe, forKey: .actionPipe)
        // Log monitoring configuration
        try container.encodeIfPresent(logMonitor, forKey: .logMonitor)
        try container.encodeIfPresent(logMonitors, forKey: .logMonitors)
        // Portal/WebView configuration
        try container.encodeIfPresent(portalConfig, forKey: .portalConfig)
        try container.encodeIfPresent(appConfigSource, forKey: .appConfigSource)
        // Brand selection (multi-brand onboarding)
        try container.encodeIfPresent(brands, forKey: .brands)
        try container.encodeIfPresent(brandSelectionKey, forKey: .brandSelectionKey)
        // Brand palette configuration
        try container.encodeIfPresent(brandPalette, forKey: .brandPalette)
        // Footer branding
        try container.encodeIfPresent(accentBorderColor, forKey: .accentBorderColor)
        try container.encodeIfPresent(showAccentBorder, forKey: .showAccentBorder)
        try container.encodeIfPresent(footerBackgroundColor, forKey: .footerBackgroundColor)
        try container.encodeIfPresent(footerTextColor, forKey: .footerTextColor)
        try container.encodeIfPresent(footerText, forKey: .footerText)
        try container.encodeIfPresent(copyrightText, forKey: .copyrightText)
        try container.encodeIfPresent(supportText, forKey: .supportText)
        try container.encode(items, forKey: .items)
    }

    // MARK: - Custom Codable Implementation

    /// Custom decoder required for:
    /// 1. **Backward Compatibility**: Decode deprecated fields (button2Disabled, buttonStyle) but discard values
    /// 2. **Default Values**: Provide fallback for missing optional arrays (e.g., items defaults to [])
    ///
    /// Without this custom implementation, the synthesized decoder would:
    /// - Fail to decode configs with deprecated fields if those fields were removed from the struct
    /// - Require explicit handling of nil optionals throughout the codebase
    ///
    /// This enables safe JSON parsing of both legacy and modern config files.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decodeIfPresent(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        infobox = try container.decodeIfPresent(String.self, forKey: .infobox)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        iconsize = try container.decodeIfPresent(Int.self, forKey: .iconsize)
        width = try container.decodeIfPresent(Int.self, forKey: .width)
        height = try container.decodeIfPresent(Int.self, forKey: .height)
        size = try container.decodeIfPresent(String.self, forKey: .size)
        scanInterval = try container.decodeIfPresent(Int.self, forKey: .scanInterval)
        cachePaths = try container.decodeIfPresent([String].self, forKey: .cachePaths)
        sideMessage = try container.decodeIfPresent([String].self, forKey: .sideMessage)
        sideInterval = try container.decodeIfPresent(Int.self, forKey: .sideInterval)
        style = try container.decodeIfPresent(String.self, forKey: .style)
        liststyle = try container.decodeIfPresent(String.self, forKey: .liststyle)
        // Accept both "11" (string) and 11 (int) for preset
        if let stringValue = try? container.decode(String.self, forKey: .preset) {
            preset = stringValue
        } else {
            preset = String(try container.decode(Int.self, forKey: .preset))
        }
        popupButton = try container.decodeIfPresent(String.self, forKey: .popupButton)
        highlightColor = try container.decodeIfPresent(String.self, forKey: .highlightColor)
        secondaryColor = try container.decodeIfPresent(String.self, forKey: .secondaryColor)
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor)
        backgroundImage = try container.decodeIfPresent(String.self, forKey: .backgroundImage)
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
        textOverlayColor = try container.decodeIfPresent(String.self, forKey: .textOverlayColor)
        gradientColors = try container.decodeIfPresent([String].self, forKey: .gradientColors)
        button1Text = try container.decodeIfPresent(String.self, forKey: .button1Text)
        button1Disabled = try container.decodeIfPresent(Bool.self, forKey: .button1Disabled)
        finalButtonText = try container.decodeIfPresent(String.self, forKey: .finalButtonText)
        button2Text = try container.decodeIfPresent(String.self, forKey: .button2Text)

        // DEPRECATED: button2Disabled - Decode but ignore for backward compatibility
        // Buttons are always enabled when shown. Use button2Visible to control visibility.
        _ = try container.decodeIfPresent(Bool.self, forKey: .button2Disabled)

        button2Visible = try container.decodeIfPresent(Bool.self, forKey: .button2Visible)

        // DEPRECATED: buttonStyle - Decode but ignore for backward compatibility
        // Not used in Inspect mode. Each preset has its own fixed button styling.
        _ = try container.decodeIfPresent(String.self, forKey: .buttonStyle)
        autoEnableButton = try container.decodeIfPresent(Bool.self, forKey: .autoEnableButton)
        autoEnableButtonText = try container.decodeIfPresent(String.self, forKey: .autoEnableButtonText)
        hideSystemDetails = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDetails)
        observeOnly = try container.decodeIfPresent(Bool.self, forKey: .observeOnly)
        autoAdvanceOnComplete = try container.decodeIfPresent(Bool.self, forKey: .autoAdvanceOnComplete)
        colorThresholds = try container.decodeIfPresent(ColorThresholds.self, forKey: .colorThresholds)
        plistSources = try container.decodeIfPresent([PlistSourceConfig].self, forKey: .plistSources)
        categoryHelp = try container.decodeIfPresent([CategoryHelp].self, forKey: .categoryHelp)
        uiLabels = try container.decodeIfPresent(UILabels.self, forKey: .uiLabels)
        complianceLabels = try container.decodeIfPresent(ComplianceLabels.self, forKey: .complianceLabels)
        pickerConfig = try container.decodeIfPresent(PickerConfig.self, forKey: .pickerConfig)
        instructionBanner = try container.decodeIfPresent(InstructionBannerConfig.self, forKey: .instructionBanner)
        pickerLabels = try container.decodeIfPresent(PickerLabels.self, forKey: .pickerLabels)

        // Banner configuration
        banner = try container.decodeIfPresent(String.self, forKey: .banner)
        bannerHeight = try container.decodeIfPresent(Int.self, forKey: .bannerHeight)
        bannerTitle = try container.decodeIfPresent(String.self, forKey: .bannerTitle)

        // Preset6 specific properties
        iconBasePath = try container.decodeIfPresent(String.self, forKey: .iconBasePath)
        overlayicon = try container.decodeIfPresent(String.self, forKey: .overlayicon)
        rotatingImages = try container.decodeIfPresent([String].self, forKey: .rotatingImages)
        imageRotationInterval = try container.decodeIfPresent(Double.self, forKey: .imageRotationInterval)
        imageShape = try container.decodeIfPresent(String.self, forKey: .imageShape)
        imageSyncMode = try container.decodeIfPresent(String.self, forKey: .imageSyncMode)
        backButtonStyle = try container.decodeIfPresent(String.self, forKey: .backButtonStyle)
        stepStyle = try container.decodeIfPresent(String.self, forKey: .stepStyle)
        listIndicatorStyle = try container.decodeIfPresent(String.self, forKey: .listIndicatorStyle)
        progressMode = try container.decodeIfPresent(String.self, forKey: .progressMode)
        progressBarConfig = try container.decodeIfPresent(ProgressBarConfig.self, forKey: .progressBarConfig)
        logoConfig = try container.decodeIfPresent(LogoConfig.self, forKey: .logoConfig)
        detailOverlay = try container.decodeIfPresent(DetailOverlayConfig.self, forKey: .detailOverlay)
        helpButton = try container.decodeIfPresent(HelpButtonConfig.self, forKey: .helpButton)
        actionPipe = try container.decodeIfPresent(String.self, forKey: .actionPipe)
        triggerFile = try container.decodeIfPresent(String.self, forKey: .triggerFile)
        skipPortal = try container.decodeIfPresent(Bool.self, forKey: .skipPortal)
        debugMode = try container.decodeIfPresent(Bool.self, forKey: .debugMode)

        // IPC (ignitecli integration)
        readinessFile = try container.decodeIfPresent(String.self, forKey: .readinessFile)
        resultFile = try container.decodeIfPresent(String.self, forKey: .resultFile)
        eventFile = try container.decodeIfPresent(String.self, forKey: .eventFile)
        deferralConfig = try container.decodeIfPresent(DeferralConfig.self, forKey: .deferralConfig)

        // Log monitoring configuration
        logMonitor = try container.decodeIfPresent(LogMonitorConfig.self, forKey: .logMonitor)
        logMonitors = try container.decodeIfPresent([LogMonitorConfig].self, forKey: .logMonitors)

        // Portal/WebView configuration
        portalConfig = try container.decodeIfPresent(PortalConfig.self, forKey: .portalConfig)
        appConfigSource = try container.decodeIfPresent(AppConfigSource.self, forKey: .appConfigSource)

        // Preferences output configuration
        preferencesOutput = try container.decodeIfPresent(PreferencesOutputConfig.self, forKey: .preferencesOutput)

        // Brand selection (multi-brand onboarding)
        brands = try container.decodeIfPresent([BrandConfig].self, forKey: .brands)
        brandSelectionKey = try container.decodeIfPresent(String.self, forKey: .brandSelectionKey)

        // Localization (intro step text)
        localization = try container.decodeIfPresent(LocalizationConfig.self, forKey: .localization)

        // Brand palette configuration
        brandPalette = try container.decodeIfPresent(BrandPalette.self, forKey: .brandPalette)

        // Footer branding (cross-preset)
        accentBorderColor = try container.decodeIfPresent(String.self, forKey: .accentBorderColor)
        showAccentBorder = try container.decodeIfPresent(Bool.self, forKey: .showAccentBorder)
        footerBackgroundColor = try container.decodeIfPresent(String.self, forKey: .footerBackgroundColor)
        footerTextColor = try container.decodeIfPresent(String.self, forKey: .footerTextColor)
        footerText = try container.decodeIfPresent(String.self, forKey: .footerText)
        copyrightText = try container.decodeIfPresent(String.self, forKey: .copyrightText)
        supportText = try container.decodeIfPresent(String.self, forKey: .supportText)

        // Default to empty array if items not provided
        items = try container.decodeIfPresent([ItemConfig].self, forKey: .items) ?? []

        // Intro/outro screens (Preset5)
        introSteps = try container.decodeIfPresent([IntroStep].self, forKey: .introSteps)

        // Preset1/2 multi-screen flow
        introScreen = try container.decodeIfPresent(PresetIntroScreen.self, forKey: .introScreen)
        summaryScreen = try container.decodeIfPresent(PresetSummaryScreen.self, forKey: .summaryScreen)
    }

    private enum CodingKeys: String, CodingKey {
        case title, message, infobox, icon, iconsize, banner, bannerHeight, bannerTitle
        case width, height, size, scanInterval, cachePaths
        case sideMessage, sideInterval, style, liststyle, preset, popupButton
        case highlightColor, secondaryColor, backgroundColor, backgroundImage, backgroundOpacity
        case textOverlayColor, gradientColors
        case button1Text = "button1text"
        case button1Disabled = "button1disabled"
        case finalButtonText = "finalButtonText"
        case button2Text = "button2text"

        // DEPRECATED: button2Disabled - Buttons are always enabled when shown
        // Backward compatibility: Field is decoded but ignored
        // Removal timeline: v3.0.0 (post Presets 5-9 public release)
        case button2Disabled = "button2disabled"

        case button2Visible = "button2visible"

        // DEPRECATED: buttonStyle - Not used in Inspect mode
        // Backward compatibility: Field is decoded but ignored
        // Removal timeline: v3.0.0 (post Presets 5-9 public release)
        case buttonStyle
        case autoEnableButton, autoEnableButtonText, hideSystemDetails, observeOnly, autoAdvanceOnComplete, colorThresholds, plistSources, categoryHelp, uiLabels, complianceLabels, pickerConfig, instructionBanner, pickerLabels, items
        // Intro/outro screens
        case introSteps
        // Preset6 specific properties
        case iconBasePath, overlayicon, rotatingImages, imageRotationInterval, imageShape, imageSyncMode, backButtonStyle, stepStyle, listIndicatorStyle
        // Progress mode (Preset4 toast installer)
        case progressMode
        // Progress bar configuration
        case progressBarConfig
        // Logo overlay configuration
        case logoConfig
        // Detail overlay, help button, action pipe, trigger file, skip portal, and debug mode configuration
        case detailOverlay, helpButton, actionPipe, triggerFile, skipPortal, debugMode
        // IPC (ignitecli integration)
        case readinessFile, resultFile, eventFile, deferralConfig
        // Log monitoring configuration
        case logMonitor, logMonitors
        // Portal/WebView configuration
        case portalConfig, appConfigSource
        // Preferences output configuration
        case preferencesOutput
        // Brand selection (multi-brand onboarding)
        case brands, brandSelectionKey
        // Localization (intro step text)
        case localization
        // Brand palette configuration
        case brandPalette
        // Footer branding
        case accentBorderColor, showAccentBorder, footerBackgroundColor, footerTextColor, footerText, copyrightText, supportText
        // Preset1/2 multi-screen flow
        case introScreen, summaryScreen
    }
}
