//
//  BrandingResolver.swift
//  dialog
//
//  Branding resolver shared across presets. MDM overrides arrive as `MDMBrandingOverrides`.
//

import SwiftUI

/// Resolves branding values. Priority: MDM managed preference → selected brand → JSON config → nil.
struct BrandingResolver {
    let config: InspectConfig?
    let mdmOverrides: MDMBrandingOverrides?
    let selectedBrand: InspectConfig.BrandConfig?
    let colorScheme: ColorScheme

    init(config: InspectConfig?, mdmOverrides: MDMBrandingOverrides?,
         selectedBrand: InspectConfig.BrandConfig? = nil,
         colorScheme: ColorScheme = .light) {
        self.config = config
        self.mdmOverrides = mdmOverrides
        self.selectedBrand = selectedBrand
        self.colorScheme = colorScheme
    }

    // MARK: - Color Hex Strings (MDM > Brand > JSON)

    var effectiveHighlightColor: String? {
        mdmOverrides?.highlightColor ?? selectedBrand?.highlightColor ?? config?.highlightColor
    }

    var effectiveAccentBorderColor: String? {
        mdmOverrides?.accentBorderColor ?? selectedBrand?.accentBorderColor ?? config?.accentBorderColor
    }

    var effectiveFooterBackgroundColor: String? {
        mdmOverrides?.footerBackgroundColor ?? selectedBrand?.footerBackgroundColor ?? config?.footerBackgroundColor
    }

    var effectiveFooterTextColor: String? {
        mdmOverrides?.footerTextColor ?? selectedBrand?.footerTextColor ?? config?.footerTextColor
    }

    // MARK: - Resolved SwiftUI Colors

    /// The raw brand color without dark mode adaptation
    var rawPrimaryColor: Color {
        if let hex = effectiveHighlightColor {
            return Color(hex: hex)
        }
        return .accentColor
    }

    /// Primary color adapted for the color scheme: dark brand colors are lightened in dark mode.
    var primaryColor: Color {
        let color = rawPrimaryColor
        return colorScheme == .dark ? color.darkModeAdapted : color
    }

    var accentColor: Color {
        if let hex = effectiveHighlightColor ?? effectiveAccentBorderColor {
            let color = Color(hex: hex)
            return colorScheme == .dark ? color.darkModeAdapted : color
        }
        return Color.accentColor
    }

    var footerBackgroundColor: Color {
        if let hex = effectiveFooterBackgroundColor {
            return Color(hex: hex)
        }
        return Color(NSColor.windowBackgroundColor)
    }

    var footerTextColor: Color {
        if let hex = effectiveFooterTextColor {
            return Color(hex: hex)
        }
        return .primary
    }

    // MARK: - Content Strings (MDM > Brand > JSON)

    var footerText: String? {
        mdmOverrides?.footerText ?? selectedBrand?.footerText ?? config?.footerText
    }

    var logoPath: String? {
        mdmOverrides?.logoPath ?? selectedBrand?.logoConfigPath ?? config?.logoConfig?.imagePath
    }

    var button1Text: String? {
        mdmOverrides?.button1Text ?? selectedBrand?.button1Text ?? config?.button1Text
    }

    var button2Text: String? {
        mdmOverrides?.button2Text ?? selectedBrand?.button2Text ?? config?.button2Text
    }

    var introTitle: String? {
        mdmOverrides?.introTitle ?? selectedBrand?.introTitle
    }

    var outroTitle: String? {
        mdmOverrides?.outroTitle ?? selectedBrand?.outroTitle
    }

    var introButtonText: String? {
        mdmOverrides?.introButtonText ?? selectedBrand?.introButtonText
    }

    var outroButtonText: String? {
        mdmOverrides?.outroButtonText ?? selectedBrand?.outroButtonText
    }
}
