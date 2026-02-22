//
//  BrandingResolver.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 11/02/2026
//
//  Unified MDM-aware branding resolver shared across presets.
//  Delegates to AppConfigService for MDM override resolution (MDM > JSON).
//

import SwiftUI

/// Resolves branding values with MDM override support and optional brand selection.
/// Usage: `BrandingResolver(config: inspectConfig, mdmOverrides: overrides, selectedBrand: brand)`
///
/// Priority: MDM managed preference → selected brand → JSON config value → nil
struct BrandingResolver {
    let config: InspectConfig?
    let mdmOverrides: MDMBrandingOverrides?
    let selectedBrand: InspectConfig.BrandConfig?

    private var service: AppConfigService { AppConfigService.shared }

    init(config: InspectConfig?, mdmOverrides: MDMBrandingOverrides?,
         selectedBrand: InspectConfig.BrandConfig? = nil) {
        self.config = config
        self.mdmOverrides = mdmOverrides
        self.selectedBrand = selectedBrand
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

    var primaryColor: Color {
        if let hex = effectiveHighlightColor {
            return Color(hex: hex)
        }
        return .accentColor
    }

    var accentColor: Color {
        if let hex = effectiveHighlightColor ?? effectiveAccentBorderColor {
            return Color(hex: hex)
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
