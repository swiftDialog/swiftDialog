//
//  UIConfiguration.swift
//  dialog
//
//  The resolved window, background and button configuration the config services hand to the state.
//

import SwiftUI

struct ButtonConfiguration {
    var button1Text: String = ""
    var button1Disabled: Bool = false
    var button1Symbol: String?               // Classic --button1symbol grammar (InspectButtonSymbolSpec)
    var button2Text: String = ""
    var button2Symbol: String?               // Same grammar as button1Symbol
    var button2Visible: Bool = false          // Shown when complete; always enabled
    var autoEnableButton: Bool = true
}

struct BackgroundConfiguration {
    var backgroundColor: String?
    var backgroundImage: String?
    var backgroundOpacity: Double = 1.0
    var textOverlayColor: String?
    var gradientColors: [String] = []
}

// MARK: - Configuration Structs for Grouped State

struct UIConfiguration {
    var windowTitle: String = "System Inspection"
    var statusMessage: String = "Checking items…"
    var iconPath: String?
    var iconBasePath: String?
    var overlayIcon: String?
    var sideMessages: [String] = []
    var currentSideMessageIndex: Int = 0
    var popupButtonText: String = "Install details..."
    var preset: String = "preset1"
    /// Empty when the config gives no brand colour; `palette.accent` then falls back to the system
    /// accent. Readers use `.nilIfEmpty`.
    var highlightColor: String = ""
    var secondaryColor: String = "#A0A0A0"
    var iconSize: Int = 120
    var subtitleMessage: String?

    // Window sizing, raw as authored; InspectDensity and InspectSizes resolve them.
    var width: Int?
    var height: Int?
    var size: String?              // "compact", "standard" or "large"
    var density: String?
    var chrome: String?            // e.g. "card"

    // Banner; nil keeps the logo.
    var bannerImage: String?
    var bannerHeight: Int = 100
    var bannerTitle: String?

    // Preset 6
    var rotatingImages: [String] = []
    var imageRotationInterval: Double = 4.0
    var imageFormat: String = "square"     // "square" | "rectangle" | "round"
    var stepStyle: String = "plain"        // "plain" | "colored" | "cards"
    var listIndicatorStyle: String = "numbers"  // "letters" | "numbers" | "roman"
}
