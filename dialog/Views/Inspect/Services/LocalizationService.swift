//
//  LocalizationService.swift
//  dialog
//
//  Loads language sidecar JSON files and provides localized string lookups.
//  Not an ObservableObject — reactivity comes from Preset5's @State gridSelections.
//

import Foundation

class LocalizationService {
    private var dictionaries: [String: [String: Any]] = [:]

    /// Load all language files from a localization config.
    /// Paths in the config are relative to basePath (iconBasePath from the config directory).
    func loadLanguages(from config: InspectConfig.LocalizationConfig, basePath: String) {
        for (langCode, relativePath) in config.languages {
            let fullPath: String
            if relativePath.hasPrefix("/") {
                fullPath = relativePath
            } else {
                let base = basePath.hasSuffix("/") ? basePath : basePath + "/"
                fullPath = base + relativePath
            }

            guard FileManager.default.fileExists(atPath: fullPath),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                writeLog("LocalizationService: Failed to load \(langCode) from \(fullPath)", logLevel: .error)
                continue
            }

            dictionaries[langCode] = json
            writeLog("LocalizationService: Loaded \(langCode) (\(json.count) keys) from \(fullPath)", logLevel: .info)
        }
    }

    /// Look up a single string value for the given language and key.
    func string(forLanguage lang: String, key: String) -> String? {
        dictionaries[lang]?[key] as? String
    }

    /// Look up a string array value for the given language and key.
    func stringArray(forLanguage lang: String, key: String) -> [String]? {
        dictionaries[lang]?[key] as? [String]
    }

    /// Check if a language has been loaded.
    func hasLanguage(_ lang: String) -> Bool {
        dictionaries[lang] != nil
    }

    /// Resolve the default language from config. Returns a language code if available, nil otherwise.
    /// "auto" = detect from system locale, any other value = use as hardcoded language code.
    func resolveDefaultLanguage(from config: InspectConfig.LocalizationConfig) -> String? {
        guard let defaultLang = config.defaultLanguage else { return nil }
        if defaultLang == "auto" {
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            return hasLanguage(systemLang) ? systemLang : nil
        }
        return hasLanguage(defaultLang) ? defaultLang : nil
    }
}
