//
//  InspectConfig+LabelsAndOverlays.swift
//  dialog
//
//  Plist sources, label systems (unified/UI/compliance/picker), detail overlay, help button.
//

import Foundation
import SwiftUI

extension InspectConfig {
    struct PlistSourceConfig: Codable, Sendable {
        let path: String                    // Path to plist file
        let type: String                    // "compliance", "health", "licenses", "preferences", "custom"
        let displayName: String             // Human-readable name
        let icon: String?                   // SF Symbol icon name
        let keyMappings: [KeyMapping]?      // How to interpret plist keys
        let successValues: [String]?        // Values that indicate "success" (for booleans: ["true"])
        let criticalKeys: [String]?         // Keys that are considered critical
        let categoryPrefix: [String: String]? // Map prefixes to category names
        let categoryIcons: [String: String]? // Category name → icon string
        /// Command that re-runs the checks; unset, the detail button only re-reads the plist.
        /// Either way a `rescan:requested` line goes to the interaction log.
        let rescanCommand: String?
        let timestampKey: String?           // Last-check timestamp key (default tries the common spellings)

        // MARK: - Auto-discovery
        let autoDiscover: Bool?             // If true, auto-generate items from plist keys
        let findingKey: String?             // Subkey to check for findings (default: "finding")
        let expectedValue: String?          // Expected value for compliance (default: "false")
        let evaluation: String?             // Evaluation type: "boolean", "string", etc. (default: "boolean")
        let excludeKeys: [String]?          // Keys to exclude from auto-discovery
        let includePattern: String?         // Regex pattern to include keys (optional)

        // MARK: - Display labels
        let healthyLabel: String?           // Passing-check label (default "Healthy")
        let attentionLabel: String?         // Failing-check label (default "Needs Attention")
    }

    struct KeyMapping: Codable, Sendable {
        let key: String                     // Original plist key
        let displayName: String?            // Human-readable name (optional)
        let category: String?               // Override category (optional)
        let isCritical: Bool?              // Override critical status (optional)
        // Remediation content; plist sibling values override these.
        let severity: String?               // "healthy" | "warning" | "failure" (config-only)
        let explanation: String?            // User-facing reason for the check
        let remediation: String?            // Steps the user can take to resolve a failure
        let actionButtonText: String?       // Label for the optional remediation button
        let actionURL: String?              // URL the action button opens (e.g. x-apple.systempreferences:...)
        // Drill-down values an admin can state up front; `found`/`lastPassed` come from the plist.
        let expected: String?               // Value the baseline requires, e.g. "expire_after ≥ 90"
        let reference: String?              // Baseline reference, e.g. "CIS 3.4"
    }

    // MARK: - Unified labels

    /// One flat key → text map for all UI labels, plus per-language `translations`.
    /// Resolution order: translations[lang][key] → labels[key] → legacy label structs → default.
    struct UnifiedLabels: Codable, Sendable {
        private let values: [String: String]
        let translations: [String: [String: String]]?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            var vals: [String: String] = [:]
            var trans: [String: [String: String]]?

            for key in container.allKeys {
                if key.stringValue == "translations" {
                    trans = try container.decodeIfPresent([String: [String: String]].self, forKey: key)
                } else {
                    if let stringValue = try? container.decode(String.self, forKey: key) {
                        vals[key.stringValue] = stringValue
                    }
                }
            }
            self.values = vals
            self.translations = trans
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in values {
                try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
            }
            if let trans = translations {
                try container.encode(trans, forKey: DynamicCodingKey(stringValue: "translations"))
            }
        }

        /// Resolves a label, preferring the requested language's translation.
        func resolve(_ key: String, language: String? = nil) -> String? {
            if let lang = language, let translated = translations?[lang]?[key] {
                return translated
            }
            return values[key]
        }

        private struct DynamicCodingKey: CodingKey {
            var stringValue: String
            var intValue: Int?
            init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
            init?(intValue: Int) { self.stringValue = "\(intValue)"; self.intValue = intValue }
        }
    }

    /// Cross-preset status text, progress formats and completion messages. Title, message and
    /// button text stay at the top level of the config.
    struct UILabels: Codable, Sendable {
        let completedStatus: String?        // Label for completed items (default: "Completed")
        let downloadingStatus: String?      // Label for downloading items (default: "Installing...")
        let pendingStatus: String?          // Label for pending items (default: "Pending")
        let failedStatus: String?           // Label for validation failure (default: "Failed")
        let skippedStatus: String?          // Label for items not attempted (default: "Skipped")
        let removedStatus: String?          // Completed item that later disappeared (default: "Removed")

        // Placeholders: {completed}, {total}, {current}
        let progressFormat: String?         // Progress bar text (default: "{completed} of {total} completed")
        let stepCounterFormat: String?      // Step counter text (default: "Step {current} of {total}")

        let completionMessage: String?      // Main completion message (default: "All Complete!")
        let completionSubtitle: String?     // Subtitle completion message (default: "Setup complete!")

        let sectionHeaderCompleted: String?  // Completed section header (default: "Completed")
        let sectionHeaderPending: String?    // Pending section header (default: "Pending Installation")
        let sectionHeaderFailed: String?     // Failed section header (default: "Installation Failed")

        let statusConditionMet: String?     // Status when validation passes (default: "Condition Met")
        let statusConditionNotMet: String?  // Status when validation fails (default: "Condition Not Met")
        let statusChecking: String?         // Status during validation/download (default: "Checking...")
        let statusReadyToStart: String?     // Initial state status (default: "Ready to Start")
        let statusInProgress: String?       // Active step status (default: "In Progress")

        // MARK: - Guide layout labels
        let welcomeTitle: String?           // Welcome page title (default: "Welcome")
        let welcomeBadge: String?           // Welcome badge text (default: "GETTING STARTED")
        let welcomeParagraph1: String?      // Main welcome paragraph
        let welcomeParagraph2: String?      // Secondary welcome paragraph

        let guideInformationLabel: String?  // Sidebar section header (default: "Guide Information")
        let sectionsLabel: String?          // Page counter label (default: "SECTIONS")
        let keyPointsLabel: String?         // Content card header (default: "Key Points")

        let getStartedTitle: String?        // Minimal welcome title (default: "Get Started")
        let getStartedSubtitle: String?     // Minimal welcome subtitle (default: "Follow the steps to complete setup")

        let imageNotAvailable: String?      // Image error message (default: "Image not available")

    }

    /// Compliance dashboard labels.
    struct ComplianceLabels: Codable, Sendable {
        let complianceStatus: String?       // Label for "Compliance Status"
        let recommendedActions: String?     // Label for "Recommended Actions"
        let securityDetails: String?        // Label for "Security Details"
        let lastCheck: String?              // Label for "Last Check"
        let passed: String?                 // Label for "passed"
        let failed: String?                 // Label for "failed"
        let checksPassed: String?           // Format for "X of Y checks passed" (use {passed}, {total})
    }

    /// Dismissible instruction banner at the top of the view.
    struct InstructionBannerConfig: Codable, Sendable {
        let text: String?                   // Banner message text (required if config present)
        let icon: String?                   // Optional SF Symbol icon name
        let autoDismiss: Bool?              // Auto-hide after delay (default: true)
        let dismissDelay: Double?           // Seconds before auto-hide (default: 5.0)
    }

    /// 3.1.1 guide picker mode: `selectable` steps are chosen, and Finish writes the selections plist.
    struct PickerConfig: Codable, Sendable {
        let selectionMode: String?                  // "single" | "multi" | "none" (default)
        let returnSelections: Bool?                 // Write the selections plist (default: false)
        let outputPath: String?                     // Default: /tmp/preset5_guide_selections.plist
        let allowContinueWithoutSelection: Bool?    // Finish with nothing selected (default: false)
    }

    /// Labels for single- and multi-select picker mode.
    struct PickerLabels: Codable, Sendable {
        let selectButtonText: String?       // Selection button text (default: "Select This")
        let selectedButtonText: String?     // Selected state button text (default: "✓ Selected")
        let deselectButtonText: String?     // Deselect button text for multi-mode (default: "Deselect")

        let continueButton: String?         // Continue to next page (default: "Continue")
        let finishButton: String?           // Complete picker action (default: "Finish")
        let backButton: String?             // Go to previous page (default: "Previous")
        let pageCounterFormat: String?      // Page indicator format (default: "{current} / {total}")

        let selectionPrompt: String?        // Top-level prompt text (e.g., "Select your desktop background")
        let selectionRequired: String?      // Error message when selection required but not made
        let multiSelectHint: String?        // Hint for multi-select mode (default: "You can select multiple items")
    }

    /// Help/detail overlay shown from any preset: `GuidanceContent` blocks, system info and
    /// template variables, or an image gallery when `presentationMode` is "gallery".
    struct DetailOverlayConfig: Codable, Sendable {
        let enabled: Bool?                  // Enable overlay (default: true when config present)

        /// A present config is the opt-in; only `enabled: false` hides it. Every caller must use this.
        var isShown: Bool { enabled ?? true }
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

        let presentationMode: String?       // "standard" (default) | "gallery"
        let galleryImages: [String]?        // Image paths; required in gallery mode
        let galleryCaptions: [String]?      // One caption per gallery image
        let galleryLayout: String?          // "carousel" (default) | "grid" | "sideBySide"
        let gallerySideContent: [GuidanceContent]?  // Right-side blocks in sideBySide layout
        let showStepCounter: Bool?          // "Step 2 of 5" counter in gallery mode (default: true)
        let showNavigationArrows: Bool?     // Prev/next arrows in carousel mode (default: true)
        let showThumbnails: Bool?           // Thumbnail strip below the main image (default: true)
        let imageHeight: Double?            // Max gallery image height in points (default: 400)
        let thumbnailSize: Double?          // Thumbnail dimensions in points (default: 60)
        let allowImageZoom: Bool?           // Allow clicking image to view fullscreen (default: false)
        let wide: Bool?                     // Use wider overlay dimensions (default: false)
        let detailMedia: String?            // Media path for the inline detail panel (falls back to cell imagePath)
        let detailMediaFit: String?         // "fill" (default) | "fit"

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
            wide: Bool? = nil,
            detailMedia: String? = nil,
            detailMediaFit: String? = nil
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
            self.detailMedia = detailMedia
            self.detailMediaFit = detailMediaFit
        }
    }

    /// Floating or inline help button that opens the overlay, a URL, or logs a custom action.
    struct HelpButtonConfig: Codable, Sendable {
        let enabled: Bool?                  // Show help button (default: true when config present)

        /// A present config is the opt-in; only `enabled: false` hides it.
        var isShown: Bool { enabled ?? true }
        let icon: String?                   // SF Symbol icon (default: "questionmark.circle")
        let label: String?                  // Optional button label text (e.g., "Help")
        let tooltip: String?                // Hover tooltip text (default: "Get Help")
        let style: String?                  // "floating" | "inline" | "toolbar" (default: "floating")

        let action: String?                 // "overlay" (default) | "url" | "custom"
        let url: String?                    // URL to open (for action: "url")
        let customId: String?               // Custom identifier for interaction log (for action: "custom")

        let position: String?               // "topRight" | "topLeft" | "bottomRight" | "bottomLeft" |
                                            // "sidebar" | "buttonBar" (default: "bottomRight")

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

}
