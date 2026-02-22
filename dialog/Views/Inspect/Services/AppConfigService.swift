//
//  AppConfigService.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 17/01/2026
//
//  Service for reading MDM managed preferences and applying as overrides
//  Implements the "single binary, multiple configurations" model for multi-brand deployments
//

import Foundation
import SwiftUI

/// MDM override values for branding fields
/// These values take precedence over JSON config when present
struct MDMBrandingOverrides {
    var highlightColor: String?
    var accentBorderColor: String?
    var footerBackgroundColor: String?
    var footerTextColor: String?
    var footerText: String?
    var portalURL: String?
    var supportURL: String?
    var logoPath: String?

    // Button text for localization
    var button1Text: String?
    var button2Text: String?
    var introTitle: String?
    var introButtonText: String?
    var outroTitle: String?
    var outroButtonText: String?

    var hasAnyValue: Bool {
        return highlightColor != nil ||
               accentBorderColor != nil ||
               footerBackgroundColor != nil ||
               footerTextColor != nil ||
               footerText != nil ||
               portalURL != nil ||
               supportURL != nil ||
               logoPath != nil ||
               button1Text != nil ||
               button2Text != nil ||
               introTitle != nil ||
               introButtonText != nil ||
               outroTitle != nil ||
               outroButtonText != nil
    }
}

/// Service for reading MDM AppConfig managed preferences
/// Used to dynamically apply branding based on MDM configuration
class AppConfigService: ObservableObject {

    // MARK: - Published State

    @Published var mdmOverrides: MDMBrandingOverrides?
    @Published var isLoading: Bool = false

    // MARK: - Singleton

    static let shared = AppConfigService()

    private init() {}

    // MARK: - Configuration Loading

    /// Load branding overrides from MDM managed preferences
    /// - Parameter source: AppConfigSource specifying which MDM keys map to which fields
    /// - Returns: MDMBrandingOverrides if any MDM values found, nil otherwise
    func loadMDMOverrides(source: InspectConfig.AppConfigSource?) -> MDMBrandingOverrides? {
        guard let source = source else { return nil }

        let domain = source.domain ?? Bundle.main.bundleIdentifier ?? "com.dialog.branding"

        var overrides = MDMBrandingOverrides()

        // Read each configured key from managed preferences
        if let key = source.highlightColorKey {
            overrides.highlightColor = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.accentBorderColorKey {
            overrides.accentBorderColor = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.footerBackgroundColorKey {
            overrides.footerBackgroundColor = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.footerTextColorKey {
            overrides.footerTextColor = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.footerTextKey {
            overrides.footerText = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.portalURLKey {
            overrides.portalURL = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.supportURLKey {
            overrides.supportURL = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.logoPathKey {
            overrides.logoPath = readManagedPreference(domain: domain, key: key)
        }

        // Button text for localization
        if let key = source.button1TextKey {
            overrides.button1Text = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.button2TextKey {
            overrides.button2Text = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.introTitleKey {
            overrides.introTitle = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.introButtonTextKey {
            overrides.introButtonText = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.outroTitleKey {
            overrides.outroTitle = readManagedPreference(domain: domain, key: key)
        }

        if let key = source.outroButtonTextKey {
            overrides.outroButtonText = readManagedPreference(domain: domain, key: key)
        }

        // Only return if at least one value was found
        guard overrides.hasAnyValue else {
            writeLog("AppConfig: No MDM branding overrides found", logLevel: .debug)
            return nil
        }

        writeLog("AppConfig: Loaded MDM overrides - highlightColor: \(overrides.highlightColor ?? "nil"), footerText: \(overrides.footerText ?? "nil")", logLevel: .info)

        self.mdmOverrides = overrides
        return overrides
    }

    // MARK: - Value Resolution (MDM > JSON)

    /// Get effective highlight color (MDM override or JSON config value)
    func effectiveHighlightColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.highlightColor ?? jsonValue
    }

    /// Get effective accent border color (MDM override or JSON config value)
    func effectiveAccentBorderColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.accentBorderColor ?? jsonValue
    }

    /// Get effective footer background color
    func effectiveFooterBackgroundColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.footerBackgroundColor ?? jsonValue
    }

    /// Get effective footer text color
    func effectiveFooterTextColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.footerTextColor ?? jsonValue
    }

    /// Get effective footer text
    func effectiveFooterText(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.footerText ?? jsonValue
    }

    /// Get effective portal URL
    func effectivePortalURL(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.portalURL ?? jsonValue
    }

    /// Get effective support URL
    func effectiveSupportURL(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.supportURL ?? jsonValue
    }

    /// Get effective logo path
    func effectiveLogoPath(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.logoPath ?? jsonValue
    }

    // MARK: - Array Preference Reading (Brand Picker)

    /// Read a managed array preference (checks MDM forced, then falls back to simple)
    func readManagedArrayPreference(domain: String, key: String) -> [String]? {
        if UserDefaults.standard.objectIsForced(forKey: key, inDomain: domain) {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString),
               let array = value as? [String] {
                return array
            }
        }
        return readSimpleArrayPreference(domain: domain, key: key)
    }

    /// Read an array preference without checking if managed (for testing/debugging)
    func readSimpleArrayPreference(domain: String, key: String) -> [String]? {
        if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString),
           let array = value as? [String] {
            return array
        }
        return nil
    }

    /// Load allowed brand IDs from MDM managed preferences
    func loadAllowedBrandIds(source: InspectConfig.AppConfigSource?) -> [String]? {
        guard let source = source, let key = source.allowedBrandsKey else { return nil }
        let domain = source.domain ?? Bundle.main.bundleIdentifier ?? "com.dialog.branding"
        return readManagedArrayPreference(domain: domain, key: key)
    }

    // MARK: - Private Helpers

    /// Read a managed preference value using CFPreferences (reads from /Library/Managed Preferences/)
    /// - Parameters:
    ///   - domain: Preference domain
    ///   - key: Preference key
    /// - Returns: Value as String if found and managed, nil otherwise
    private func readManagedPreference(domain: String, key: String) -> String? {
        // Check if the key is managed (forced by MDM)
        guard UserDefaults.standard.objectIsForced(forKey: key, inDomain: domain) else {
            // Fall back to reading unmanaged preference (for demo/testing)
            return readSimplePreference(domain: domain, key: key)
        }

        // Read using CFPreferences which correctly reads from /Library/Managed Preferences/
        if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) {
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            }
        }

        return nil
    }

    /// Read a preference without checking if managed (for testing/debugging)
    /// Also reads from /Library/Managed Preferences/ via CFPreferences
    func readSimplePreference(domain: String, key: String) -> String? {
        // Use CFPreferences to read from all preference sources including managed
        if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) {
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            }
        }
        return nil
    }
}
