//
//  Config+Loading.swift
//  dialog
//
//  Config extension: loading from file, URL, environment or inline data, the managed-profile look
//  layered under a config, inline images, and the profile watch that reloads a running dialog.
//

import AppKit
import CryptoKit
import Foundation

extension Config {
    // MARK: - Inspect API
    
    /// Loads from `fromFile` (a path or http(s) URL), else the environment variable, else the demo config
    /// when the request allows it.
    func loadConfiguration(_ request: ConfigurationRequest = .default, fromFile: String = "") -> Result<ConfigurationResult, ConfigurationError> {
        if !fromFile.isEmpty {
            if fromFile.hasPrefix("http://") || fromFile.hasPrefix("https://") {
                writeLog("ConfigurationService: Using config from URL: \(fromFile)", logLevel: .info)
                return loadConfigurationFromURL(fromFile)
            }
            writeLog("ConfigurationService: Using config from provided file: \(fromFile)", logLevel: .info)
            return loadConfigurationFromFile(at: fromFile)
        }

        if let configPath = getConfigPath(from: request.environmentVariable) {
            if configPath.hasPrefix("http://") || configPath.hasPrefix("https://") {
                writeLog("ConfigurationService: Using config from URL (env): \(configPath)", logLevel: .info)
                return loadConfigurationFromURL(configPath)
            }
            writeLog("ConfigurationService: Using config from environment: \(configPath)", logLevel: .info)
            return loadConfigurationFromFile(at: configPath)
        }

        guard request.fallbackToTestData else {
            return .failure(.missingEnvironmentVariable(name: request.environmentVariable))
        }

        writeLog("ConfigurationService: No config path provided, using test data", logLevel: .info)
        return createTestConfiguration()
    }

    /// Loads a config over http(s), synchronously (callers run at startup). Relative resources resolve
    /// against `iconBasePath`, defaulting to the current directory.
    func loadConfigurationFromURL(_ urlString: String) -> Result<ConfigurationResult, ConfigurationError> {
        guard let url = URL(string: urlString) else {
            return .failure(.fileNotFound(path: urlString))
        }

        let semaphore = DispatchSemaphore(value: 0)
        let outcome = LockedValue<(data: Data?, error: (any Error)?)>((nil, nil))

        // Same 10 s bound as the wait below, so a slow host does not keep the task alive after we give up.
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            outcome.value = (data, error)
            semaphore.signal()
        }
        task.resume()

        let result = semaphore.wait(timeout: .now() + 10)
        if result == .timedOut {
            writeLog("ConfigurationService: URL request timed out: \(urlString)", logLevel: .error)
            return .failure(.fileNotFound(path: urlString))
        }

        let (downloadedData, downloadError) = outcome.value
        guard let data = downloadedData, downloadError == nil else {
            writeLog("ConfigurationService: Failed to download config from URL: \(downloadError?.localizedDescription ?? "unknown error")", logLevel: .error)
            return .failure(.fileNotFound(path: urlString))
        }

        do {
            var jsonData = data
            var remapNotes: [String] = []
            if var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                if jsonObject["iconBasePath"] == nil {
                    let currentDirectory = FileManager.default.currentDirectoryPath
                    jsonObject["iconBasePath"] = currentDirectory
                    writeLog("ConfigurationService: Remote config - auto-set iconBasePath to: \(currentDirectory)", logLevel: .info)
                }

                if let brandPalette = jsonObject["brandPalette"] as? [String: Any] {
                    writeLog("🎨 CONFIG: Found brandPalette with \(brandPalette.count) keys: \(Array(brandPalette.keys))", logLevel: .debug)
                    jsonObject = resolveBrandTokens(in: jsonObject, palette: brandPalette)
                    writeLog("🎨 CONFIG: Token resolution completed", logLevel: .debug)
                    writeLog("ConfigurationService: Resolved brand palette tokens", logLevel: .info)
                } else {
                    writeLog("🎨 CONFIG: No brandPalette found in config", logLevel: .debug)
                }

                // 3.1.1 keys, as `validateInspectSchema` does for the file and inline loaders.
                let remap = InspectLegacyRemap.apply(jsonObject)
                jsonObject = remap.object
                remapNotes = remap.notes
                InspectLegacyRemap.log(remap.notes)

                if let coerced = InspectConfigCoercion.coerceScalars(in: jsonObject) as? [String: Any] {
                    jsonObject = coerced
                }
                if let expanded = GradientPresets.expandReferences(in: jsonObject) as? [String: Any] {
                    jsonObject = expanded
                }

                if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                    jsonData = modifiedData
                }
            }

            let decoder = JSONDecoder()
            InspectConfig.unknownKeyWarnings = remapNotes
            let config = try decoder.decode(InspectConfig.self, from: jsonData)
            let keyWarnings = InspectConfig.unknownKeyWarnings
            InspectConfig.unknownKeyWarnings = []

            let processedConfig = applyConfigurationDefaults(to: config)
            var warnings = validateConfiguration(processedConfig)
            warnings.append(contentsOf: keyWarnings)

            writeLog("ConfigurationService: Successfully loaded configuration from URL: \(urlString)", logLevel: .info)
            writeLog("ConfigurationService: Loaded \(config.items.count) items", logLevel: .info)

            return .success(ConfigurationResult(
                config: processedConfig,
                source: .file(path: urlString),
                warnings: warnings
            ))

        } catch let error {
            let jsonString = String(data: data, encoding: .utf8)
            let detailedError = ConfigurationError.formatJSONError(error, jsonString: jsonString)
            writeLog("ConfigurationService: Configuration loading failed from URL \(urlString):\n\(detailedError)", logLevel: .error)
            return .failure(.invalidJSON(path: urlString, error: error))
        }
    }
    
    /// The one decode surface: layers the profile look, resolves tokens and gradient presets, validates
    /// and decodes. Used by the file loader and inline `--jsonstring`; `source` names where the bytes came from.
    func loadConfiguration(fromData data: Data, source: ConfigurationSource = .file(path: "<data>")) -> Result<ConfigurationResult, ConfigurationError> {
        InspectConfig.unknownKeyWarnings = []

        // Token resolution is idempotent, so a caller that already resolved is fine.
        var resolvedData = data
        if var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let effective = Self.effectiveObject(jsonObject)
            jsonObject = effective.object
            writeLog("ConfigurationService: config source: \(effective.source) · \(source)", logLevel: .info)
            if let brandPalette = jsonObject["brandPalette"] as? [String: Any] {
                jsonObject = resolveBrandTokens(in: jsonObject, palette: brandPalette)
                writeLog("ConfigurationService: Resolved brand palette tokens (fromData)", logLevel: .info)
            }
            if let expanded = GradientPresets.expandReferences(in: jsonObject) as? [String: Any] {
                jsonObject = expanded
            }
            if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                resolvedData = modifiedData
            }
        }

        let validation = validateInspectSchema(resolvedData)
        // Once each: a profile fallback check above runs the same schema pass, legacy notes included.
        var seenWarnings = Set<String>()
        let keyWarnings = InspectConfig.unknownKeyWarnings.filter { seenWarnings.insert($0).inserted }
        InspectConfig.unknownKeyWarnings = []

        switch validation {
        case .valid(let config):
            let processedConfig = applyConfigurationDefaults(to: config)
            var warnings = validateConfiguration(processedConfig)
            warnings.append(contentsOf: keyWarnings)

            return .success(ConfigurationResult(
                config: processedConfig,
                source: source,
                warnings: warnings
            ))
        case .notInspect:
            return .failure(.invalidFormat(reason: "No inspect content found (expected preset, introSteps, or items). If you meant a standard dialog, drop --inspect-mode."))
        case .malformed(let reason):
            return .failure(.invalidFormat(reason: "Inspect config is malformed: \(reason)"))
        }
    }

    // MARK: - Profile look and inline images

    /// The config a run uses, layered lowest first: the profile's brand keys, then the flow it names
    /// (or `neutralLook` while no profile is installed), then the config. A config with inspect content
    /// of its own takes the brand only. Inline images become cached files.
    ///
    /// A profile layer that does not decode is left out so one bad profile value cannot stop every
    /// dialog; the config alone is the last resort. Gate A, window sizing and the loader all read this.
    static func effectiveObject(_ object: [String: Any]) -> (object: [String: Any], source: String) {
        let profile = profileDomain()
        let flow = flowKey(of: object)
        let setup = flow.flatMap { profile?[$0] as? [String: Any] }
        let brand = (profile ?? [:]).filter { brandKeys.contains($0.key) }

        func compose(brand useBrand: Bool, flow useFlow: Bool, dropped: String?) -> ([String: Any], String) {
            var out = object
            var sources = ["the config"]
            if let flow {
                if useFlow, let setup {
                    out = layered(profile: setup, over: object)
                    sources.insert("the profile's \(flow) (\(managedConfigDomain), \(setup.count) keys)", at: 0)
                } else {
                    out = layered(profile: neutralLook, over: object)
                    sources.insert(setup == nil ? "the neutral look (no \(flow) yet)" : "the neutral look", at: 0)
                }
            }
            if useBrand, !brand.isEmpty {
                out = layered(profile: brand, over: out)
                sources.insert("the brand (\(brand.keys.sorted().joined(separator: ", ")))", at: 0)
            }
            if let dropped { sources.append("left out, does not decode: \(dropped)") }
            return (materializingInlineImages(out) as? [String: Any] ?? out, sources.joined(separator: " → "))
        }

        let full = compose(brand: true, flow: true, dropped: nil)
        guard !brand.isEmpty || setup != nil, !decodes(full.0) else { return full }
        var fallbacks: [(Bool, Bool, String)] = []
        if !brand.isEmpty { fallbacks.append((false, true, "the brand")) }
        if setup != nil, let flow {
            fallbacks.append((true, false, "the profile's \(flow)"))
            if !brand.isEmpty { fallbacks.append((false, false, "the brand and the profile's \(flow)")) }
        }
        for (useBrand, useFlow, dropped) in fallbacks {
            let tried = compose(brand: useBrand, flow: useFlow, dropped: dropped)
            if decodes(tried.0) {
                writeLog("Config: \(dropped) left out — its values do not decode", logLevel: .error)
                return tried
            }
        }
        return full   // the config itself does not decode; the loader reports it
    }

    /// The profile dictionary a config without inspect content runs: the one `profileLook` names, or
    /// `setupExperience` for a run with a log monitor. nil for a self-contained config.
    static func flowKey(of object: [String: Any]) -> String? {
        guard !hasInspectContent(object) else { return nil }
        if let named = object["profileLook"] as? String { return named }
        return object["logMonitor"] != nil || object["logMonitors"] != nil ? managedConfigKey : nil
    }

    /// Whether a composed config decodes, by the same check Gate A applies.
    private static func decodes(_ object: [String: Any]) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return false }
        if case .malformed = validateInspectSchema(data) { return false }
        return true
    }

    /// Keys that style a dialog without shaping it (no preset, steps or rows), so they can sit under any config.
    static let brandKeys: Set<String> = [
        "logoConfig", "icon", "brandPalette", "highlightColor", "secondaryColor", "appearance",
        "buttonShape", "glow", "phaseBackground", "phaseBackgroundPalette", "phaseBackgroundPaletteDark"
    ]

    /// `effectiveObject` for raw bytes; non-JSON input is returned unchanged.
    static func effectiveData(_ data: Data) -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let out = try? JSONSerialization.data(withJSONObject: effectiveObject(object).object) else { return data }
        return out
    }

    static func hasInspectContent(_ object: [String: Any]) -> Bool {
        ["preset", "introSteps", "items", "steps"].contains { object[$0] != nil }
    }

    /// The look shown until a profile lands: preset 5 (so the switch need not resize the window), one
    /// installation step, no rows; the log monitor fills the rows live.
    static let neutralLook: [String: Any] = [
        "preset": "5",
        "title": "Setting up your Mac",
        "introSteps": [["id": "install", "stepType": "installation", "title": "Setting up your Mac",
                        "subtitle": "Your Mac is being configured by your organization.", "items": [Any]()]]
    ]

    /// The managed domain the look is delivered under; its top-level brand keys style every inspect
    /// dialog and its `setupExperience` dictionary is the flow for a look-less run.
    static let managedConfigDomain = dialogManagedLookDomain
    static let managedConfigKey = "setupExperience"
    /// Where profiles land; tests override it before anything loads.
    nonisolated(unsafe) static var managedPreferencesBase = "/Library/Managed Preferences"

    /// The profile domain as JSON values: `<data>` becomes `base64=…`, `<date>` ISO 8601 text.
    /// nil when no profile is installed.
    static func profileDomain() -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: "\(managedPreferencesBase)/\(managedConfigDomain).plist"),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return jsonCompatible(plist) as? [String: Any]
    }

    /// The brand keys plus the `flow` dictionary, as canonical bytes; only a change to these bytes is a
    /// new look for this dialog. nil when no profile is installed.
    static func profileLook(flow: String? = managedConfigKey) -> Data? {
        guard let profile = profileDomain() else { return nil }
        let look = profile.filter { brandKeys.contains($0.key) || $0.key == flow }
        return try? JSONSerialization.data(withJSONObject: look, options: .sortedKeys)
    }

    static func jsonCompatible(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]: return dict.mapValues(jsonCompatible)
        case let array as [Any]: return array.map(jsonCompatible)
        case let data as Data: return "base64=" + data.base64EncodedString()
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        default: return value
        }
    }

    /// Profile underneath, config on top; a top-level key the config sets wins whole.
    static func layered(profile: [String: Any], over file: [String: Any]) -> [String: Any] {
        profile.merging(file) { _, fromFile in fromFile }
    }

    /// Where inline images are written, named by content hash. The system temporary folder cleans
    /// unused files itself; nothing here deletes, and a missing file is written again on the next load.
    nonisolated(unsafe) static var inlineImageCache: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("swiftDialog-InlineImages", isDirectory: true)

    static func materializingInlineImages(_ value: Any) -> Any {
        switch value {
        case let dict as [String: Any]: return dict.mapValues(materializingInlineImages)
        case let array as [Any]: return array.map(materializingInlineImages)
        case let text as String: return inlineImagePath(text) ?? text
        default: return value
        }
    }

    /// `base64=<data>` (classic's spelling) or `data:image/<type>;base64,<data>` to a cached file path;
    /// nil for anything that does not decode to an image.
    static func inlineImagePath(_ text: String) -> String? {
        let payload: Substring
        if text.hasPrefix("base64=") {
            payload = text.dropFirst(7)
        } else if text.hasPrefix("data:image/"), let comma = text.firstIndex(of: ","), text[..<comma].hasSuffix(";base64") {
            payload = text[text.index(after: comma)...]
        } else {
            return nil
        }
        guard let data = Data(base64Encoded: String(payload), options: .ignoreUnknownCharacters), NSImage(data: data) != nil
        else { return nil }
        let name = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined().prefix(32)
        let url = inlineImageCache.appendingPathComponent("\(name).png")   // .png: path-vs-symbol checks read the name
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: inlineImageCache, withIntermediateDirectories: true)
            guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        }
        return url.path
    }

    /// Loads a config file; `iconBasePath` defaults to the file's directory.
    func loadConfigurationFromFile(at path: String) -> Result<ConfigurationResult, ConfigurationError> {
        writeLog("🔧 CONFIG: loadConfigurationFromFile called with path: \(path)", logLevel: .debug)

        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))

            // Path-dependent pre-processing happens here; the shared decode surface only sees bytes.
            var jsonData = data
            if var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                if jsonObject["iconBasePath"] == nil {
                    let configDirectory = (path as NSString).deletingLastPathComponent
                    jsonObject["iconBasePath"] = configDirectory
                    writeLog("ConfigurationService: Auto-set iconBasePath to: \(configDirectory)", logLevel: .info)
                }

                if let brandPalette = jsonObject["brandPalette"] as? [String: Any] {
                    writeLog("🎨 CONFIG: Found brandPalette with \(brandPalette.count) keys: \(Array(brandPalette.keys))", logLevel: .debug)
                    jsonObject = resolveBrandTokens(in: jsonObject, palette: brandPalette)
                    writeLog("🎨 CONFIG: Token resolution completed", logLevel: .debug)
                    writeLog("ConfigurationService: Resolved brand palette tokens", logLevel: .info)
                } else {
                    writeLog("🎨 CONFIG: No brandPalette found in config", logLevel: .debug)
                }

                if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                    jsonData = modifiedData
                }
            }

            let result = loadConfiguration(fromData: jsonData, source: .file(path: path))

            switch result {
            case .success(let configResult):
                writeLog("ConfigurationService: Successfully loaded configuration from \(path)", logLevel: .info)
                writeLog("ConfigurationService: Loaded \(configResult.config.items.count) items", logLevel: .info)
            case .failure(let error):
                writeLog("ConfigurationService: Configuration loading failed for \(path):\n\(error.localizedDescription)", logLevel: .error)
            }
            return result

        } catch let error {
            let jsonString = try? String(contentsOfFile: path, encoding: .utf8)
            let detailedError = ConfigurationError.formatJSONError(error, jsonString: jsonString)
            writeLog("ConfigurationService: Configuration loading failed for \(path):\n\(detailedError)", logLevel: .error)
            return .failure(.invalidJSON(path: path, error: error))
        }
    }
    
    /// The built-in demo config (`inspectDemoConfigJSON`), used when no config is given.
    func createTestConfiguration() -> Result<ConfigurationResult, ConfigurationError> {
        let testConfigJSON = inspectDemoConfigJSON
        
        do {
            guard let jsonData = testConfigJSON.data(using: .utf8) else {
                throw NSError(domain: "TestDataError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create JSON data"])
            }
            
            let config = try JSONDecoder().decode(InspectConfig.self, from: jsonData)
            let processedConfig = applyConfigurationDefaults(to: config)
            
            writeLog("ConfigurationService: Created test configuration with \(config.items.count) items", logLevel: .info)
            
            return .success(ConfigurationResult(
                config: processedConfig,
                source: .testData,
                warnings: []
            ))
            
        } catch let error {
            return .failure(.testDataCreationFailed(error: error))
        }
    }
    
}

/// The built-in demo: a three-step preset 5 flow (intro, bento, deployment). Also the sample
/// `--inspect-mode` writes for authors to copy.
let inspectDemoConfigJSON = """
    {
        "preset": "5",
        "width": 1000,
        "height": 650,
        "highlightColor": "#007AFF",
        "showAccentBorder": false,
        "introSteps": [
            {
                "id": "welcome",
                "stepType": "intro",
                "title": "swiftDialog — Inspect Mode",
                "subtitle": "A sample configuration to get you started.",
                "heroImage": "computer",
                "heroImageSize": 180,
                "content": [
                    {
                        "type": "text",
                        "content": "This is a Preset 5 workflow. Each step uses a different layout — intro, bento grid, and deployment — to demonstrate what's possible."
                    }
                ],
                "continueButtonText": "Explore",
                "showBackButton": false
            },
            {
                "id": "presets-overview",
                "stepType": "bento",
                "bentoLayout": "grid",
                "title": "6 Preset Layouts",
                "subtitle": "Click a card to learn more",
                "bentoColumns": 3,
                "bentoRowHeight": 140,
                "bentoGap": 12,
                "bentoCells": [
                    {
                        "id": "preset1",
                        "column": 0, "row": 0, "columnSpan": 1, "rowSpan": 1,
                        "contentType": "icon",
                        "backgroundStyle": "gradient",
                        "gradientStyle": "ethereal",
                        "gradientPalette": ["#0A84FF", "#64D2FF", "#5E5CE6"],
                        "sfSymbol": "sidebar.leading",
                        "iconSize": 36,
                        "iconColor": "#FFFFFF",
                        "textColor": "#FFFFFF",
                        "title": "Preset 1",
                        "label": "DEPLOYMENT",
                        "cornerRadius": 16,
                        "detailOverlay": {
                            "title": "Preset 1 — Deployment",
                            "subtitle": "Sidebar + scrollable item list",
                            "icon": "sidebar.leading",
                            "content": [
                                { "type": "text", "content": "The classic deployment layout. A sidebar shows a hero icon and overall progress, while the main area lists items with real-time status updates." },
                                { "type": "bullets", "items": ["Sidebar with hero icon and progress bar", "Scrollable item list with status indicators", "File-system monitoring via paths array", "Rotating status messages"] },
                                { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "1", "buttonStyle": "borderedProminent" }
                            ]
                        }
                    },
                    {
                        "id": "preset2",
                        "column": 1, "row": 0, "columnSpan": 1, "rowSpan": 1,
                        "contentType": "icon",
                        "backgroundStyle": "gradient",
                        "gradientStyle": "vivid",
                        "gradientPalette": ["#30D158", "#63E6BE", "#00C7BE"],
                        "sfSymbol": "rectangle.split.3x1",
                        "iconSize": 36,
                        "iconColor": "#FFFFFF",
                        "textColor": "#FFFFFF",
                        "title": "Preset 2",
                        "label": "CARDS",
                        "cornerRadius": 16,
                        "detailOverlay": {
                            "title": "Preset 2 — Cards",
                            "subtitle": "Horizontal card carousel",
                            "icon": "rectangle.split.3x1",
                            "content": [
                                { "type": "text", "content": "Items displayed as cards in a horizontal carousel. Great for visual app catalogs where each card shows an icon, name, and install status." },
                                { "type": "bullets", "items": ["Horizontal scrolling card layout", "Large app icons with status badges", "Progress bar across the top", "Auto-advances on completion"] },
                                { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "2", "buttonStyle": "borderedProminent" }
                            ]
                        }
                    },
                    {
                        "id": "preset3",
                        "column": 2, "row": 0, "columnSpan": 1, "rowSpan": 1,
                        "contentType": "icon",
                        "backgroundStyle": "gradient",
                        "gradientStyle": "ethereal",
                        "gradientPalette": ["#BF5AF2", "#5E5CE6", "#FF6EC7"],
                        "sfSymbol": "list.bullet.rectangle",
                        "iconSize": 36,
                        "iconColor": "#FFFFFF",
                        "textColor": "#FFFFFF",
                        "title": "Preset 3",
                        "label": "COMPACT",
                        "cornerRadius": 16,
                        "detailOverlay": {
                            "title": "Preset 3 — Compact",
                            "subtitle": "Compact list with gradient background",
                            "icon": "list.bullet.rectangle",
                            "content": [
                                { "type": "text", "content": "A space-efficient list layout with a gradient background. Ideal for quick installations where you want minimal screen footprint." },
                                { "type": "bullets", "items": ["Compact item rows", "Gradient background from brand colors", "Small window footprint", "Clean, minimal design"] },
                                { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "3", "buttonStyle": "borderedProminent" }
                            ]
                        }
                    },
                    {
                        "id": "preset4",
                        "column": 0, "row": 1, "columnSpan": 1, "rowSpan": 1,
                        "contentType": "icon",
                        "backgroundStyle": "gradient",
                        "gradientStyle": "ethereal",
                        "gradientPalette": ["#FF9F0A", "#FF375F", "#FFD60A"],
                        "sfSymbol": "bell.badge",
                        "iconSize": 36,
                        "iconColor": "#FFFFFF",
                        "textColor": "#FFFFFF",
                        "title": "Preset 4",
                        "label": "TOAST",
                        "cornerRadius": 16,
                        "detailOverlay": {
                            "title": "Preset 4 — Toast Installer",
                            "subtitle": "Compact notification-style installer",
                            "icon": "bell.badge",
                            "content": [
                                { "type": "text", "content": "A small, unobtrusive toast notification that tracks installations in the corner of the screen. Stays out of the user's way." },
                                { "type": "bullets", "items": ["Notification-sized window", "Corner-anchored positioning", "Three progress modes: shared bar, per-item, or report list", "Non-intrusive for background installs"] },
                                { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "4", "buttonStyle": "borderedProminent" }
                            ]
                        }
                    },
                    {
                        "id": "preset5",
                        "column": 1, "row": 1, "columnSpan": 1, "rowSpan": 1,
                        "contentType": "icon",
                        "backgroundStyle": "gradient",
                        "gradientStyle": "vivid",
                        "gradientPalette": ["#5E5CE6", "#BF5AF2", "#0A84FF"],
                        "sfSymbol": "macwindow.on.rectangle",
                        "iconSize": 36,
                        "iconColor": "#FFFFFF",
                        "textColor": "#FFFFFF",
                        "title": "Preset 5",
                        "label": "UNIFIED",
                        "cornerRadius": 16,
                        "detailOverlay": {
                            "title": "Preset 5 — Unified Portal",
                            "subtitle": "The most flexible preset (this sample)",
                            "icon": "macwindow.on.rectangle",
                            "content": [
                                { "type": "text", "content": "A multi-step flow. Combine intro screens, bento grids, deployment tracking, cadence carousels, guides, brand pickers, and more in a single workflow." },
                                { "type": "bullets", "items": ["12 step types: intro, bento, deployment, cadence, carousel, guide, showcase, portal, processing, brandPicker, assistant, outro", "Linear navigation with back/continue", "55+ content block types", "Branding, forms, compliance checks"] },
                                { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "5", "buttonStyle": "borderedProminent" }
                            ]
                        }
                    },
                    {
                        "id": "preset6",
                        "column": 2, "row": 1, "columnSpan": 1, "rowSpan": 1,
                        "contentType": "icon",
                        "backgroundStyle": "gradient",
                        "gradientStyle": "ethereal",
                        "gradientPalette": ["#FF375F", "#FF6482", "#AC8E68"],
                        "sfSymbol": "sidebar.squares.leading",
                        "iconSize": 36,
                        "iconColor": "#FFFFFF",
                        "textColor": "#FFFFFF",
                        "title": "Preset 6",
                        "label": "GUIDANCE",
                        "cornerRadius": 16,
                        "detailOverlay": {
                            "title": "Preset 6 — Modern Sidebar",
                            "subtitle": "Sidebar navigation with guided content",
                            "icon": "sidebar.squares.leading",
                            "content": [
                                { "type": "text", "content": "A modern sidebar navigation layout. Users can jump between sections freely rather than following a linear path." },
                                { "type": "bullets", "items": ["Sidebar with section navigation", "Non-linear — jump to any section", "Rich guidance content per section", "Great for self-service portals"] },
                                { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "6", "buttonStyle": "borderedProminent" }
                            ]
                        }
                    }
                ],
                "continueButtonText": "Continue",
                "backButtonText": "Back"
            },
            {
                "id": "apps",
                "stepType": "deployment",
                "title": "App Installation",
                "subtitle": "Simulated deployment step with progress tracking.",
                "heroImage": "SF=arrow.down.app.fill",
                "items": [
                    { "id": "safari", "displayName": "Safari", "guiIndex": 0, "icon": "/Applications/Safari.app", "paths": ["/Applications/Safari.app"], "showBundleInfo": "all" },
                    { "id": "mail", "displayName": "Mail", "guiIndex": 1, "icon": "/System/Applications/Mail.app", "paths": ["/System/Applications/Mail.app"], "showBundleInfo": "all" },
                    { "id": "keynote", "displayName": "Keynote", "guiIndex": 2, "icon": "/Applications/Keynote.app", "paths": ["/Applications/Keynote.app"], "showBundleInfo": "all" },
                    { "id": "textedit", "displayName": "TextEdit", "guiIndex": 3, "icon": "/System/Applications/TextEdit.app", "paths": ["/System/Applications/TextEdit.app"], "showBundleInfo": "all" },
                    { "id": "calculator", "displayName": "Calculator", "guiIndex": 4, "icon": "/System/Applications/Calculator.app", "paths": ["/System/Applications/Calculator.app"], "showBundleInfo": "all" }
                ],
                "autoEnableButton": false,
                "allowOverride": true,
                "continueButtonText": "Finish",
                "showBackButton": true
            }
        ]
    }
    """

/// The profile's look, changed only once a change holds: macOS rewrites the managed-preferences file
/// as other profiles install, and it can briefly read as absent. A new look counts after 2 s of
/// reading the same; a removed profile after 10 s.
struct SettledLook {
    private(set) var current: Data?
    private var candidate: (look: Data?, since: TimeInterval)?

    init(_ current: Data?) { self.current = current }

    /// A different look is being watched until it holds or goes back.
    var isSettling: Bool { candidate != nil }

    /// The look to switch to once it has held; nil while nothing changed or it is still settling.
    /// `now` is system uptime, which clock changes during setup do not move.
    mutating func observe(_ look: Data?, at now: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Data?? {
        guard look != current else { candidate = nil; return nil }
        guard let seen = candidate, seen.look == look else { candidate = (look, now); return nil }
        guard now - seen.since >= (look == nil ? 10 : 2) else { return nil }
        candidate = nil
        current = look
        return .some(look)
    }
}

/// Watches the look's profile off the main thread: a file-date check every 2 s, then parse
/// (`Config.profileLook`), hold (`SettledLook`) and reload on its own queue. Only the finished config
/// reaches the main thread through `apply`.
final class ProfileLookWatch: @unchecked Sendable {
    private let queue = DispatchQueue(label: "swiftdialog.profile-look", qos: .utility)
    private var timer: DispatchSourceTimer?
    // Confined to `queue`.
    private var look: SettledLook
    private var fileDate: Date?
    private let flow: String?
    private let uptime: () -> TimeInterval
    private let load: () -> Result<ConfigurationResult, ConfigurationError>?
    private let apply: @MainActor (InspectConfig) -> Void

    /// - Parameters:
    ///   - look: the look before the config loaded (`Config.profileLook(flow:)`).
    ///   - flow: the profile dictionary the dialog runs (`Config.flowKey`); nil means the brand only.
    ///   - load: reloads the config, profile included; runs on the watch's queue.
    ///   - apply: receives the reloaded config on the main thread.
    init(from look: Data?, flow: String?,
         uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         load: @escaping () -> Result<ConfigurationResult, ConfigurationError>?,
         apply: @escaping @MainActor (InspectConfig) -> Void) {
        self.look = SettledLook(look)
        self.flow = flow
        self.uptime = uptime
        self.load = load
        self.apply = apply
    }

    func start(every interval: TimeInterval = 2) {
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() { timer?.cancel(); timer = nil }

    /// One check of the profile, on the watch's queue; tests call it directly.
    func tick() {
        let path = "\(Config.managedPreferencesBase)/\(Config.managedConfigDomain).plist"
        let date = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        guard date != fileDate || look.isSettling else { return }
        fileDate = date
        guard let settled = look.observe(Config.profileLook(flow: flow), at: uptime()) else { return }
        writeLog("InspectState: the look's profile \(settled == nil ? "was removed" : "changed") — reloading", logLevel: .info)
        switch load() {
        case .success(let loaded):
            let config = loaded.config, apply = self.apply
            DispatchQueue.main.async { MainActor.assumeIsolated { apply(config) } }
        case .failure(let error):
            writeLog("InspectState: kept the current look — \(error)", logLevel: .info)
        case nil:
            break
        }
    }
}
