//
//  InspectConfig+PortalAndBranding.swift
//  dialog
//
//  Portal/WebView config, MDM app-config source, brand palette, color thresholds.
//

import Foundation
import SwiftUI

extension InspectConfig {
    /// A self-service portal shown in a WKWebView. The URL resolves from `portalURLFile`, then
    /// the MDM override, then `portalURL`, with `selfServicePath` appended.
    struct PortalConfig: Codable, Sendable {
        let portalURL: String?                  // Base URL of the self-service portal (fallback if portalURLFile not found)
        let portalURLFile: String?              // Path to file containing portal URL (read at launch, overrides portalURL)
        let selfServicePath: String?            // Path within portal (default: "/")
        let fallbackMessage: String?            // Message shown when portal is unavailable
        let supportURL: String?                 // IT support portal URL
        let supportContact: String?             // Contact info shown when offline (phone, email, etc.)
        let stateDomain: String?                // UserDefaults domain (default "com.swiftdialog.preset5")
        let selfServiceOnly: Bool?              // Exit after the portal, skipping outro (default false)
        let button1Text: String?                // Portal-specific primary button text (overrides global button1text)
        let button2Text: String?                // Portal-specific secondary button text (overrides global button2text)
        let openExternalLinksInBrowser: Bool?   // Non-portal links open in the browser (default true)
    }
}

extension InspectConfig.PortalConfig {
    static let knownKeys: Set<String> = [
        "portalURL", "portalURLFile", "selfServicePath", "fallbackMessage", "supportURL", "supportContact",
        "stateDomain", "selfServiceOnly", "button1Text", "button2Text", "openExternalLinksInBrowser"
    ]

    /// Sign-in, request and offline keys of earlier versions. Portal pages load without credentials or
    /// custom requests, so lint names these on their own rather than as typos.
    static let noLongerReadKeys: Set<String> = [
        "provider", "tokenEndpoint", "tokenRefreshInterval", "authSources", "clientCertSubject",
        "offlineMode", "retryCount", "retryDelay", "cacheContentForOffline", "cacheDuration",
        "userAgent", "brandingKey", "brandingHeaderName", "customHeaders",
        "ephemeralSession", "errorDetectionPhrases", "errorDetectionThreshold"
    ]

    /// Decodes the fields, and reports any other key the way root, step and item keys are reported.
    /// Root, step (and its `portal` alias) and block `portalConfig` all decode through here.
    init(from decoder: Decoder) throws {
        let raw = try decoder.container(keyedBy: RawCodingKey.self)
        let authored = Set(raw.allKeys.map(\.stringValue))
        for key in InspectConfig.unknownKeys(in: authored, against: Self.knownKeys) {
            InspectConfig.unknownKeyWarnings.append(Self.noLongerReadKeys.contains(key)
                ? "'\(key)' in portalConfig is no longer read: portal pages load without sign-in or custom requests"
                : "Unknown key '\(key)' in portalConfig")
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        portalURL = try container.decodeIfPresent(String.self, forKey: .portalURL)
        portalURLFile = try container.decodeIfPresent(String.self, forKey: .portalURLFile)
        selfServicePath = try container.decodeIfPresent(String.self, forKey: .selfServicePath)
        fallbackMessage = try container.decodeIfPresent(String.self, forKey: .fallbackMessage)
        supportURL = try container.decodeIfPresent(String.self, forKey: .supportURL)
        supportContact = try container.decodeIfPresent(String.self, forKey: .supportContact)
        stateDomain = try container.decodeIfPresent(String.self, forKey: .stateDomain)
        selfServiceOnly = try container.decodeIfPresent(Bool.self, forKey: .selfServiceOnly)
        button1Text = try container.decodeIfPresent(String.self, forKey: .button1Text)
        button2Text = try container.decodeIfPresent(String.self, forKey: .button2Text)
        openExternalLinksInBrowser = try container.decodeIfPresent(Bool.self, forKey: .openExternalLinksInBrowser)
    }
}

extension InspectConfig {

    /// Where to read MDM-managed preferences for branding. Each `*Key` names the preference key
    /// that overrides the matching config field; managed values always win over the JSON.
    struct AppConfigSource: Codable, Sendable {
        let domain: String?                     // Preference domain

        let highlightColorKey: String?          // MDM key → highlightColor
        let accentBorderColorKey: String?       // MDM key → accentBorderColor
        let footerBackgroundColorKey: String?   // MDM key → footerBackgroundColor
        let footerTextColorKey: String?         // MDM key → footerTextColor
        let footerTextKey: String?              // MDM key → footerText
        let portalURLKey: String?               // MDM key → portalConfig.portalURL override
        let supportURLKey: String?              // MDM key → portalConfig.supportURL override
        let logoPathKey: String?                // MDM key → logoConfig.imagePath override

        let button1TextKey: String?             // MDM key → button1text (primary button)
        let button2TextKey: String?             // MDM key → button2text (secondary button)
        let introTitleKey: String?              // MDM key → intro screen title
        let introButtonTextKey: String?         // MDM key → intro continue button text
        let outroTitleKey: String?              // MDM key → outro screen title
        let outroButtonTextKey: String?         // MDM key → outro close button text

        let allowedBrandsKey: String?              // MDM key → allowed brand IDs for the brand picker

    }

    // MARK: - Brand Palette Configuration

    /// Named brand colors and logos referenced elsewhere in the config as `$primary`, `$logos.main`
    /// or `$custom.name`; tokens also interpolate inside strings such as `"SF=icon,colour1=$primary"`.
    struct BrandPalette: Codable, Sendable {
        let primary: String?        // Main brand color (default: #6366F1 indigo-500)
        let secondary: String?      // Secondary accent (default: #8B5CF6 violet-500)
        let accent: String?         // Highlight/attention color (default: #F59E0B amber-500)

        let success: String?        // Positive states (default: #22C55E green-500)
        let warning: String?        // Caution states (default: #F59E0B amber-500)
        let error: String?          // Error/failure states (default: #EF4444 red-500)
        let info: String?           // Informational states (default: #3B82F6 blue-500)
        let notice: String?         // Temporary notices (default #724913 light / #e0b378 dark)

        let background: String?     // Main background (default: #0F172A slate-900)
        let surface: String?        // Card/panel background (default: #1E293B slate-800)
        let surfaceLight: String?   // Light mode surface (default: #F8FAFC slate-50)

        let textPrimary: String?    // Primary text (default: #F8FAFC slate-50)
        let textSecondary: String?  // Muted/secondary text (default: #94A3B8 slate-400)

        // Name → image path or SF Symbol string.
        let logos: [String: String]?

        // Free-form tokens, referenced as `$custom.name`.
        let custom: [String: String]?

        /// Fills nil colors with Tailwind defaults. `notice` stays nil so `ResolvedPalette` can supply
        /// its light/dark pair.
        func resolved() -> BrandPalette {
            BrandPalette(
                primary: primary ?? "#6366F1",       // indigo-500
                secondary: secondary ?? "#8B5CF6",   // violet-500
                accent: accent ?? "#F59E0B",         // amber-500
                success: success ?? "#22C55E",       // green-500
                warning: warning ?? "#F59E0B",       // amber-500
                error: error ?? "#EF4444",           // red-500
                info: info ?? "#3B82F6",             // blue-500
                notice: notice,
                background: background ?? "#0F172A", // slate-900
                surface: surface ?? "#1E293B",       // slate-800
                surfaceLight: surfaceLight ?? "#F8FAFC", // slate-50
                textPrimary: textPrimary ?? "#F8FAFC",   // slate-50
                textSecondary: textSecondary ?? "#94A3B8", // slate-400
                logos: logos,
                custom: custom
            )
        }

        /// Default Tailwind palette; `notice` stays nil for the same reason as in `resolved()`.
        static let tailwindDefault = BrandPalette(
            primary: "#6366F1",       // indigo-500
            secondary: "#8B5CF6",     // violet-500
            accent: "#F59E0B",        // amber-500
            success: "#22C55E",       // green-500
            warning: "#F59E0B",       // amber-500
            error: "#EF4444",         // red-500
            info: "#3B82F6",          // blue-500
            notice: nil,
            background: "#0F172A",    // slate-900
            surface: "#1E293B",       // slate-800
            surfaceLight: "#F8FAFC",  // slate-50
            textPrimary: "#F8FAFC",   // slate-50
            textSecondary: "#94A3B8", // slate-400
            logos: nil,
            custom: nil
        )
    }

    /// Score bands (0–1) shared by all presets; below `warning` is critical.
    struct ColorThresholds: Codable, Sendable {
        let excellent: Double              // Default 0.9
        let good: Double                   // Default 0.7
        let warning: Double                // Default 0.5

        let excellentLabel: String?
        let goodLabel: String?
        let warningLabel: String?
        let criticalLabel: String?

        // Hex strings; nil falls back to the palette.
        let excellentColor: String?
        let goodColor: String?
        let warningColor: String?
        let criticalColor: String?

        static let `default` = ColorThresholds(
            excellent: 0.9, good: 0.7, warning: 0.5,
            excellentLabel: nil, goodLabel: nil, warningLabel: nil, criticalLabel: nil,
            excellentColor: nil, goodColor: nil, warningColor: nil, criticalColor: nil
        )

        /// Color for a score: an authored threshold color wins, otherwise the palette's semantic color.
        func getColor(for score: Double, palette: ResolvedPalette) -> Color {
            if score >= excellent {
                return excellentColor.map { Color(hex: $0) } ?? palette.success
            } else if score >= good {
                return goodColor.map { Color(hex: $0) } ?? palette.info
            } else if score >= warning {
                return warningColor.map { Color(hex: $0) } ?? palette.warning
            } else {
                return criticalColor.map { Color(hex: $0) } ?? palette.error
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

        func getProgressText(passed: Int, total: Int) -> String {
            let score = total > 0 ? Double(passed) / Double(total) : 0.0
            let percentage = Int(score * 100)
            return "\(passed)/\(total) (\(percentage)%)"
        }

        // Same rule as `getColor`: authored threshold color wins, palette otherwise.
        func getPositiveColor(palette: ResolvedPalette) -> Color {
            excellentColor.map { Color(hex: $0) } ?? palette.success
        }

        func getNegativeColor(palette: ResolvedPalette) -> Color {
            criticalColor.map { Color(hex: $0) } ?? palette.error
        }

        func getValidationColor(isValid: Bool, palette: ResolvedPalette) -> Color {
            isValid ? getPositiveColor(palette: palette) : getNegativeColor(palette: palette)
        }
    }

}
