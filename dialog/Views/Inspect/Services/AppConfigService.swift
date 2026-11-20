//
//  AppConfigService.swift
//  dialog
//
//  Reads MDM managed preferences and exposes them as branding overrides that win over JSON config.
//

import Foundation
import SwiftUI

/// Branding values read from MDM; a non-nil value takes precedence over the JSON config.
struct MDMBrandingOverrides {
    var highlightColor: String?
    var accentBorderColor: String?
    var footerBackgroundColor: String?
    var footerTextColor: String?
    var footerText: String?
    var portalURL: String?
    var supportURL: String?
    var logoPath: String?

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

/// Reads MDM AppConfig managed preferences for branding; main-actor singleton.
@MainActor
class AppConfigService: ObservableObject {

    // MARK: - Published State

    @Published var mdmOverrides: MDMBrandingOverrides?
    @Published var isLoading: Bool = false

    // MARK: - Singleton

    static let shared = AppConfigService()

    private init() {}

    // MARK: - Configuration Loading

    /// Reads the keys named by `source`; returns nil when no key has a value.
    func loadMDMOverrides(source: InspectConfig.AppConfigSource?) -> MDMBrandingOverrides? {
        guard let source = source else { return nil }

        let domain = source.domain ?? Bundle.main.bundleIdentifier ?? "com.dialog.branding"

        var overrides = MDMBrandingOverrides()

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

        guard overrides.hasAnyValue else {
            writeLog("AppConfig: No MDM branding overrides found", logLevel: .debug)
            return nil
        }

        writeLog("AppConfig: Loaded MDM overrides - highlightColor: \(overrides.highlightColor ?? "nil"), footerText: \(overrides.footerText ?? "nil")", logLevel: .info)

        self.mdmOverrides = overrides
        return overrides
    }

    // MARK: - Value Resolution (MDM > JSON)

    func effectiveHighlightColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.highlightColor ?? jsonValue
    }

    func effectiveAccentBorderColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.accentBorderColor ?? jsonValue
    }

    func effectiveFooterBackgroundColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.footerBackgroundColor ?? jsonValue
    }

    func effectiveFooterTextColor(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.footerTextColor ?? jsonValue
    }

    func effectiveLogoPath(jsonValue: String?, mdm: MDMBrandingOverrides?) -> String? {
        return mdm?.logoPath ?? jsonValue
    }

    // MARK: - Array Preference Reading (Brand Picker)

    /// The forced (managed) array when there is one, otherwise any unmanaged value.
    func readManagedArrayPreference(domain: String, key: String) -> [String]? {
        if UserDefaults.standard.objectIsForced(forKey: key, inDomain: domain) {
            if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString),
               let array = value as? [String] {
                return array
            }
        }
        return readSimpleArrayPreference(domain: domain, key: key)
    }

    /// Reads the array from any preference source, managed or not.
    func readSimpleArrayPreference(domain: String, key: String) -> [String]? {
        if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString),
           let array = value as? [String] {
            return array
        }
        return nil
    }

    /// Brand IDs the brand picker may offer, from the `allowedBrandsKey` preference.
    func loadAllowedBrandIds(source: InspectConfig.AppConfigSource?) -> [String]? {
        guard let source = source, let key = source.allowedBrandsKey else { return nil }
        let domain = source.domain ?? Bundle.main.bundleIdentifier ?? "com.dialog.branding"
        return readManagedArrayPreference(domain: domain, key: key)
    }

    // MARK: - Private Helpers

    /// The forced (managed) value as a String, else any unmanaged value, else nil. Numbers are stringified.
    private func readManagedPreference(domain: String, key: String) -> String? {
        guard UserDefaults.standard.objectIsForced(forKey: key, inDomain: domain) else {
            return readSimplePreference(domain: domain, key: key)
        }

        // CFPreferences is what reads /Library/Managed Preferences/.
        if let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) {
            if let stringValue = value as? String {
                return stringValue
            } else if let numberValue = value as? NSNumber {
                return numberValue.stringValue
            }
        }

        return nil
    }

    /// Reads the value from any preference source, managed or not; numbers are stringified.
    func readSimplePreference(domain: String, key: String) -> String? {
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
