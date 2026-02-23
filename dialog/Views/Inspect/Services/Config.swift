//
//  Config.swift
//  dialog
//
//  Created by Henry Stamerjohann, Declarative IT GmbH, 25/07/2025
//  Business logic service used for configuration loading and processing
//

import Foundation

// MARK: - Configuration Models

struct ConfigurationRequest {
    let environmentVariable: String
    let fallbackToTestData: Bool
    
    static let `default` = ConfigurationRequest(
        environmentVariable: "DIALOG_INSPECT_CONFIG",
        fallbackToTestData: true
    )
}

struct ConfigurationResult {
    let config: InspectConfig
    let source: ConfigurationSource
    let warnings: [String]
}


enum ConfigurationError: Error, LocalizedError {
    case fileNotFound(path: String)
    case invalidJSON(path: String, error: Error)
    case missingEnvironmentVariable(name: String)
    case testDataCreationFailed(error: Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Configuration file not found at: \(path)"
        case .invalidJSON(let path, let error):
            // Read JSON file to provide snippet context in error
            let jsonString = try? String(contentsOfFile: path, encoding: .utf8)
            return "Invalid JSON in configuration file \(path): \(Self.formatJSONError(error, jsonString: jsonString))"
        case .missingEnvironmentVariable(let name):
            return "Environment variable '\(name)' not set and no fallback available"
        case .testDataCreationFailed(let error):
            return "Failed to create test configuration: \(error.localizedDescription)"
        }
    }

    /// Format JSON decoding errors with helpful details including line/column for syntax errors
    static func formatJSONError(_ error: Error, jsonString: String? = nil) -> String {
        if let decodingError = error as? DecodingError {
            switch decodingError {
            case .keyNotFound(let key, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                let location = path.isEmpty ? "root" : "'\(path)'"
                var message = "Missing required field '\(key.stringValue)' at \(location)"

                // Try to show the JSON section where error occurred
                if let json = jsonString, !path.isEmpty {
                    let result = extractJSONSnippet(json: json, path: path)
                    if let lineNum = result.lineNumber {
                        message += " (line \(lineNum))"
                    }
                    if let snippet = result.snippet {
                        message += "\n\n📍 Error location:\n\(snippet)"
                    }
                }

                // Add helpful hint for common missing fields
                if let hint = fieldHint(for: key.stringValue) {
                    message += "\n\n💡 Hint: \(hint)"
                }
                return message

            case .typeMismatch(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                var message = "Type mismatch at '\(path)': expected \(type)"

                if let json = jsonString, !path.isEmpty {
                    let result = extractJSONSnippet(json: json, path: path)
                    if let lineNum = result.lineNumber {
                        message += " (line \(lineNum))"
                    }
                    if let snippet = result.snippet {
                        message += "\n\n📍 Error location:\n\(snippet)"
                    }
                }

                // Add type hint for common fields
                if let hint = typeHint(for: path, expectedType: type) {
                    message += "\n\n💡 Hint: \(hint)"
                }
                return message

            case .valueNotFound(let type, let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                var message = "Missing value at '\(path)': expected \(type)"

                if let json = jsonString, !path.isEmpty {
                    let result = extractJSONSnippet(json: json, path: path)
                    if let lineNum = result.lineNumber {
                        message += " (line \(lineNum))"
                    }
                }
                return message

            case .dataCorrupted(let context):
                let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
                let location = path.isEmpty ? "document" : "'\(path)'"
                return "Data corrupted at \(location): \(context.debugDescription)"

            @unknown default:
                return error.localizedDescription
            }
        }

        // For NSError from JSONSerialization (syntax errors)
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain || nsError.domain == "NSCocoaErrorDomain" {
            // Try to extract line/column from userInfo if available
            if let debugDesc = nsError.userInfo[NSDebugDescriptionErrorKey] as? String {
                // Format: "... around line X, column Y"
                var message = "JSON syntax error (line "

                // Try to extract line number and show context
                if let json = jsonString,
                   let range = debugDesc.range(of: "line \\d+", options: .regularExpression),
                   let lineNum = Int(debugDesc[range].dropFirst(5)) {
                    message += "\(lineNum)): \(debugDesc)"
                    let lines = json.components(separatedBy: "\n")
                    if lineNum > 0 && lineNum <= lines.count {
                        let startLine = max(0, lineNum - 3)
                        let endLine = min(lines.count, lineNum + 2)
                        var snippet = "\n\n📍 Around line \(lineNum):\n"
                        for i in startLine..<endLine {
                            let marker = (i + 1 == lineNum) ? "→ " : "  "
                            snippet += "\(marker)\(i + 1): \(lines[i])\n"
                        }
                        message += snippet
                    }
                } else {
                    message = "JSON syntax error: \(debugDesc)"
                }
                return message
            }
        }

        return error.localizedDescription
    }

    /// Extract JSON snippet around a coding path for error context
    /// Returns tuple with optional line number and optional snippet string
    private static func extractJSONSnippet(json: String, path: String) -> (lineNumber: Int?, snippet: String?) {
        // Parse path to find the item index and field name
        // e.g., "items.Index 0.guidanceContent.Index 0.state" -> items[0].guidanceContent[0], field: state
        let components = path.split(separator: ".")

        var arrayKey = ""
        var itemIndex = 0
        var fieldName: String?

        for component in components {
            let comp = String(component)
            if comp.hasPrefix("Index ") {
                if let idx = Int(comp.dropFirst(6)) {
                    itemIndex = idx
                }
            } else {
                // Track nested arrays (items, guidanceContent, etc.)
                if ["items", "guidanceContent", "plistSources"].contains(comp) {
                    arrayKey = comp
                    itemIndex = 0  // Reset for nested array
                } else {
                    // Last non-index component is the field name (for typeMismatch)
                    fieldName = comp
                }
            }
        }

        let lines = json.components(separatedBy: "\n")
        var foundKeyLine = -1
        var braceCount = 0
        var inTargetArray = false
        var currentItemIndex = -1
        var itemStartLine = -1
        var itemEndLine = -1

        // First pass: find the item block
        for (lineIdx, line) in lines.enumerated() {
            if line.contains("\"\(arrayKey)\"") && line.contains("[") {
                inTargetArray = true
                braceCount = 0
            }

            if inTargetArray {
                for char in line {
                    if char == "{" {
                        if braceCount == 0 {
                            currentItemIndex += 1
                            if currentItemIndex == itemIndex {
                                itemStartLine = lineIdx
                            }
                        }
                        braceCount += 1
                        if currentItemIndex == itemIndex && braceCount == 1 {
                            foundKeyLine = lineIdx
                        }
                    } else if char == "}" {
                        braceCount -= 1
                        if braceCount == 0 && currentItemIndex == itemIndex {
                            itemEndLine = lineIdx
                        }
                    }
                }

                if line.contains("]") && braceCount <= 0 {
                    inTargetArray = false
                }
            }

            if foundKeyLine >= 0 && braceCount == 0 {
                break
            }
        }

        // If we have a specific field name, search within the item block for it
        if let field = fieldName, itemStartLine >= 0 {
            let searchEnd = itemEndLine >= 0 ? itemEndLine : min(lines.count, itemStartLine + 20)
            for i in itemStartLine...searchEnd where lines[i].contains("\"\(field)\"") {
                foundKeyLine = i
                break
            }
        }

        if foundKeyLine >= 0 {
            let startLine = max(0, foundKeyLine - 2)
            let endLine = min(lines.count, foundKeyLine + 6)
            var snippet = ""
            for i in startLine..<endLine {
                let marker = (i == foundKeyLine) ? "→ " : "  "
                snippet += "\(marker)\(i + 1): \(lines[i])\n"
            }
            return (foundKeyLine + 1, snippet)
        }

        return (nil, nil)
    }

    /// Provide helpful hints for common missing fields
    private static func fieldHint(for fieldName: String) -> String? {
        switch fieldName {
        case "paths":
            return "Add \"paths\": [] to each item. This array lists file paths to monitor for completion."
        case "id":
            return "Add \"id\": \"unique-identifier\" to each item. This must be unique across all items."
        case "displayName":
            return "Add \"displayName\": \"Name\" to each item. This is shown in the UI."
        case "guiIndex":
            return "Add \"guiIndex\": 0 to each item. This determines the display order (0 = first)."
        case "preset":
            return "Add \"preset\": \"preset1\" at the root level. Valid: preset1-6, or named: deployment, cards, compact, toast, portal, self-service, guidance."
        case "items":
            return "Add \"items\": [] at the root level. This array contains the items to display."
        case "title":
            return "Add \"title\": \"Your Title\" at the root level."
        case "guidanceContent":
            return "Add \"guidanceContent\": [] to items that need guidance panels. Array of content blocks."
        case "type":
            return "Add \"type\": \"text\" to guidance content blocks. Types: text, badge, button, spacer, divider, etc."
        case "content":
            return "Add \"content\": \"...\" to guidance content blocks for the display text."
        case "state":
            return "Add \"state\": \"pending\" to badge blocks. States: pending, success, fail, info, etc."
        default:
            return nil
        }
    }

    /// Provide helpful hints for type mismatch errors
    private static func typeHint(for path: String, expectedType: Any.Type) -> String? {
        let fieldName = path.split(separator: ".").last.map(String.init) ?? ""

        switch fieldName {
        case "guiIndex":
            return "\"guiIndex\" must be a number without quotes. Use guiIndex: 0, not guiIndex: \"0\""
        case "state":
            return "\"state\" must be a string. Use state: \"pending\", not state: 0"
        case "paths":
            return "\"paths\" must be an array. Use paths: [\"/path/to/file\"], not paths: \"/path\""
        case "items":
            return "\"items\" must be an array of objects. Use items: [{...}], not items: {...}"
        case "guidanceContent":
            return "\"guidanceContent\" must be an array. Use guidanceContent: [{...}], not guidanceContent: {...}"
        default:
            // Generic type hints
            let typeStr = String(describing: expectedType)
            if typeStr.contains("Int") {
                return "This field expects a number without quotes."
            } else if typeStr.contains("Bool") {
                return "This field expects true or false without quotes."
            } else if typeStr.contains("String") {
                return "This field expects a string value in quotes."
            } else if typeStr.contains("Array") {
                return "This field expects an array using square brackets []."
            }
            return nil
        }
    }
}

// MARK: - Configuration Service

class Config {
    
    // MARK: - Inspect API
    
    /// Load configuration from explicit file path via commandline --inspect-config arg (see https://github.com/swiftDialog/swiftDialog/commit/e884ee60f8925c7e47a3096ec6d89f5d92b72d5b#diff-c3b51bf2b51dc1dab1f2d5e8d90baaefa239d674a20f4cf22d67903bef14cb45, else use environment variable,, or fallback to test data
    /// - Parameters:
    ///   - request: Configuration request with environment variable and fallback settings
    ///   - fromFile: Optional explicit file path to load configuration from (takes precedence over environment)
    /// - Returns: Result containing configuration or error
    func loadConfiguration(_ request: ConfigurationRequest = .default, fromFile: String = "") -> Result<ConfigurationResult, ConfigurationError> {
        // Priority 1: Use explicit file path if provided
        if !fromFile.isEmpty {
            // Check if it's a URL
            if fromFile.hasPrefix("http://") || fromFile.hasPrefix("https://") {
                writeLog("ConfigurationService: Using config from URL: \(fromFile)", logLevel: .info)
                return loadConfigurationFromURL(fromFile)
            }
            writeLog("ConfigurationService: Using config from provided file: \(fromFile)", logLevel: .info)
            return loadConfigurationFromFile(at: fromFile)
        }

        // Priority 2: Get config path from environment
        if let configPath = getConfigPath(from: request.environmentVariable) {
            // Check if it's a URL
            if configPath.hasPrefix("http://") || configPath.hasPrefix("https://") {
                writeLog("ConfigurationService: Using config from URL (env): \(configPath)", logLevel: .info)
                return loadConfigurationFromURL(configPath)
            }
            writeLog("ConfigurationService: Using config from environment: \(configPath)", logLevel: .info)
            return loadConfigurationFromFile(at: configPath)
        }

        // Priority 3: Check if fallback is allowed
        guard request.fallbackToTestData else {
            return .failure(.missingEnvironmentVariable(name: request.environmentVariable))
        }

        writeLog("ConfigurationService: No config path provided, using test data", logLevel: .info)
        return createTestConfiguration()
    }

    /// Load configuration from a remote URL
    /// Resources (images, icons) are resolved from iconBasePath (local) or current directory
    func loadConfigurationFromURL(_ urlString: String) -> Result<ConfigurationResult, ConfigurationError> {
        guard let url = URL(string: urlString) else {
            return .failure(.fileNotFound(path: urlString))
        }

        // Synchronous download for simplicity (config loading happens at startup)
        let semaphore = DispatchSemaphore(value: 0)
        var downloadedData: Data?
        var downloadError: Error?

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            downloadedData = data
            downloadError = error
            semaphore.signal()
        }
        task.resume()

        // Wait with timeout (10 seconds)
        let result = semaphore.wait(timeout: .now() + 10)
        if result == .timedOut {
            writeLog("ConfigurationService: URL request timed out: \(urlString)", logLevel: .error)
            return .failure(.fileNotFound(path: urlString))
        }

        guard let data = downloadedData, downloadError == nil else {
            writeLog("ConfigurationService: Failed to download config from URL: \(downloadError?.localizedDescription ?? "unknown error")", logLevel: .error)
            return .failure(.fileNotFound(path: urlString))
        }

        do {
            // Parse JSON for pre-processing
            var jsonData = data
            if var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // If iconBasePath is nil or missing, use current working directory
                if jsonObject["iconBasePath"] == nil {
                    let currentDirectory = FileManager.default.currentDirectoryPath
                    jsonObject["iconBasePath"] = currentDirectory
                    writeLog("ConfigurationService: Remote config - auto-set iconBasePath to: \(currentDirectory)", logLevel: .info)
                }

                // Resolve brand palette tokens BEFORE decoding
                if let brandPalette = jsonObject["brandPalette"] as? [String: Any] {
                    print("🎨 CONFIG: Found brandPalette with \(brandPalette.count) keys: \(Array(brandPalette.keys))")
                    jsonObject = resolveBrandTokens(in: jsonObject, palette: brandPalette)
                    print("🎨 CONFIG: Token resolution completed")
                    writeLog("ConfigurationService: Resolved brand palette tokens", logLevel: .info)
                } else {
                    print("🎨 CONFIG: No brandPalette found in config")
                }

                if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                    jsonData = modifiedData
                }
            }

            let decoder = JSONDecoder()
            let config = try decoder.decode(InspectConfig.self, from: jsonData)

            let processedConfig = applyConfigurationDefaults(to: config)
            let warnings = validateConfiguration(processedConfig)

            writeLog("ConfigurationService: Successfully loaded configuration from URL: \(urlString)", logLevel: .info)
            writeLog("ConfigurationService: Loaded \(config.items.count) items", logLevel: .info)

            return .success(ConfigurationResult(
                config: processedConfig,
                source: .file(path: urlString),  // Track as URL source
                warnings: warnings
            ))

        } catch let error {
            let jsonString = String(data: data, encoding: .utf8)
            let detailedError = ConfigurationError.formatJSONError(error, jsonString: jsonString)
            writeLog("ConfigurationService: Configuration loading failed from URL \(urlString):\n\(detailedError)", logLevel: .error)
            return .failure(.invalidJSON(path: urlString, error: error))
        }
    }
    
    /// Fallback: Load configuration from specific file path
    /// TODO: Reevaluate as this has been brittle - loading from file system to late to initialize UI accordingly
    func loadConfigurationFromFile(at path: String) -> Result<ConfigurationResult, ConfigurationError> {
        print("🔧 CONFIG: loadConfigurationFromFile called with path: \(path)")

        // Check if file exists
        guard FileManager.default.fileExists(atPath: path) else {
            return .failure(.fileNotFound(path: path))
        }

        do {
            // Load and parse JSON
            let data = try Data(contentsOf: URL(fileURLWithPath: path))

            // Parse JSON to dictionary for pre-processing
            var jsonData = data
            if var jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                // If iconBasePath is nil or missing, auto-set to config directory
                if jsonObject["iconBasePath"] == nil {
                    let configDirectory = (path as NSString).deletingLastPathComponent
                    jsonObject["iconBasePath"] = configDirectory
                    writeLog("ConfigurationService: Auto-set iconBasePath to: \(configDirectory)", logLevel: .info)
                }

                // Resolve brand palette tokens BEFORE decoding
                if let brandPalette = jsonObject["brandPalette"] as? [String: Any] {
                    print("🎨 CONFIG: Found brandPalette with \(brandPalette.count) keys: \(Array(brandPalette.keys))")
                    jsonObject = resolveBrandTokens(in: jsonObject, palette: brandPalette)
                    print("🎨 CONFIG: Token resolution completed")
                    writeLog("ConfigurationService: Resolved brand palette tokens", logLevel: .info)
                } else {
                    print("🎨 CONFIG: No brandPalette found in config")
                }

                // Re-serialize modified JSON
                if let modifiedData = try? JSONSerialization.data(withJSONObject: jsonObject, options: []) {
                    jsonData = modifiedData
                }
            }

            let decoder = JSONDecoder()
            let config = try decoder.decode(InspectConfig.self, from: jsonData)

            // Validate and apply defaults
            let processedConfig = applyConfigurationDefaults(to: config)
            let warnings = validateConfiguration(processedConfig)
            
            writeLog("ConfigurationService: Successfully loaded configuration from \(path)", logLevel: .info)
            writeLog("ConfigurationService: Loaded \(config.items.count) items", logLevel: .info)
            
            return .success(ConfigurationResult(
                config: processedConfig,
                source: .file(path: path),
                warnings: warnings
            ))
            
        } catch let error {
            // Get original JSON string for enhanced error reporting
            let jsonString = try? String(contentsOfFile: path, encoding: .utf8)
            let detailedError = ConfigurationError.formatJSONError(error, jsonString: jsonString)
            writeLog("ConfigurationService: Configuration loading failed for \(path):\n\(detailedError)", logLevel: .error)
            return .failure(.invalidJSON(path: path, error: error))
        }
    }
    
    /// Fallback for Demo: Create test configuration for development/fallback
    /// Shows a 3-step Preset 5 workflow: intro → bento grid (6 preset cards with Generate Starter) → deployment demo
    func createTestConfiguration() -> Result<ConfigurationResult, ConfigurationError> {
        let testConfigJSON = """
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
                    "heroImage": "SF=macbook.gen2",
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
                    "subtitle": "Tap any card to learn more",
                    "bentoColumns": 3,
                    "bentoRowHeight": 140,
                    "bentoGap": 12,
                    "bentoCells": [
                        {
                            "id": "preset1",
                            "column": 0, "row": 0, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "sidebar.leading",
                            "iconSize": 36,
                            "title": "Preset 1",
                            "label": "DEPLOYMENT",
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
                            "sfSymbol": "rectangle.split.3x1",
                            "iconSize": 36,
                            "title": "Preset 2",
                            "label": "CARDS",
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
                            "sfSymbol": "list.bullet.rectangle",
                            "iconSize": 36,
                            "title": "Preset 3",
                            "label": "COMPACT",
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
                            "sfSymbol": "bell.badge",
                            "iconSize": 36,
                            "title": "Preset 4",
                            "label": "TOAST",
                            "detailOverlay": {
                                "title": "Preset 4 — Toast Installer",
                                "subtitle": "Compact notification-style installer",
                                "icon": "bell.badge",
                                "content": [
                                    { "type": "text", "content": "A small, unobtrusive toast notification that tracks installations in the corner of the screen. Stays out of the user's way." },
                                    { "type": "bullets", "items": ["Notification-sized window", "Corner-anchored positioning", "Progress tracking with minimal UI", "Non-intrusive for background installs"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "4", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset5",
                            "column": 1, "row": 1, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "macwindow.on.rectangle",
                            "iconSize": 36,
                            "title": "Preset 5",
                            "label": "UNIFIED",
                            "detailOverlay": {
                                "title": "Preset 5 — Unified Portal",
                                "subtitle": "The most flexible preset (this sample)",
                                "icon": "macwindow.on.rectangle",
                                "content": [
                                    { "type": "text", "content": "A multi-step wizard with 9 step types. Combine intro screens, bento grids, deployment tracking, carousels, guides, and more in a single workflow." },
                                    { "type": "bullets", "items": ["9 step types: intro, bento, deployment, carousel, guide, showcase, portal, processing, outro", "Linear navigation with back/continue", "55+ content block types", "Branding, forms, compliance checks"] },
                                    { "type": "button", "content": "Generate Starter", "icon": "arrow.down.doc.fill", "action": "generate", "requestId": "5", "buttonStyle": "borderedProminent" }
                                ]
                            }
                        },
                        {
                            "id": "preset6",
                            "column": 2, "row": 1, "columnSpan": 1, "rowSpan": 1,
                            "contentType": "icon",
                            "sfSymbol": "sidebar.squares.leading",
                            "iconSize": 36,
                            "title": "Preset 6",
                            "label": "GUIDANCE",
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
                        { "id": "word", "displayName": "Microsoft Word", "guiIndex": 0, "icon": "/Applications/Microsoft Word.app", "paths": ["/Applications/Microsoft Word.app"], "showBundleInfo": "all" },
                        { "id": "excel", "displayName": "Microsoft Excel", "guiIndex": 1, "icon": "/Applications/Microsoft Excel.app", "paths": ["/Applications/Microsoft Excel.app"], "showBundleInfo": "all" },
                        { "id": "1password", "displayName": "1Password", "guiIndex": 2, "icon": "/Applications/1Password.app", "paths": ["/Applications/1Password.app"], "showBundleInfo": "all" },
                        { "id": "slack", "displayName": "Slack", "guiIndex": 3, "icon": "/Applications/Slack.app", "paths": ["/Applications/Slack.app"], "showBundleInfo": "all" },
                        { "id": "chrome", "displayName": "Google Chrome", "guiIndex": 4, "icon": "/Applications/Google Chrome.app", "paths": ["/Applications/Google Chrome.app"], "showBundleInfo": "all" }
                    ],
                    "autoEnableButton": false,
                    "continueButtonText": "Finish",
                    "showBackButton": true
                }
            ]
        }
        """
        
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
    
    // MARK: - Internal Helper Methods
    
    private func getConfigPath(from environmentVariable: String) -> String? {
        guard let path = ProcessInfo.processInfo.environment[environmentVariable] else {
            return nil
        }
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func applyConfigurationDefaults(to config: InspectConfig) -> InspectConfig {
        var processedConfig = config

        // Process auto-discovery from plistSources
        if let plistSources = config.plistSources {
            var discoveredItems: [InspectConfig.ItemConfig] = []

            for source in plistSources where source.autoDiscover == true {
                let items = discoverItemsFromPlist(source: source, basePath: config.iconBasePath)
                discoveredItems.append(contentsOf: items)
                writeLog("ConfigurationService: Auto-discovered \(items.count) items from \(source.path)", logLevel: .info)
            }

            // Merge discovered items with existing items (existing items take precedence by ID)
            if !discoveredItems.isEmpty {
                let existingIds = Set(processedConfig.items.map { $0.id })
                let newItems = discoveredItems.filter { !existingIds.contains($0.id) }
                processedConfig.items.append(contentsOf: newItems)
                writeLog("ConfigurationService: Total items after auto-discovery: \(processedConfig.items.count)", logLevel: .info)
            }
        }

        // Sort items by guiIndex for consistent display
        processedConfig.items.sort { $0.guiIndex < $1.guiIndex }

        return processedConfig
    }

    /// Auto-discover items from a plist source
    private func discoverItemsFromPlist(source: InspectConfig.PlistSourceConfig, basePath: String?) -> [InspectConfig.ItemConfig] {
        var items: [InspectConfig.ItemConfig] = []

        // Resolve path (support relative paths)
        var plistPath = source.path
        if !plistPath.hasPrefix("/") && !plistPath.hasPrefix("~") {
            if let basePath = basePath, !basePath.isEmpty {
                plistPath = (basePath as NSString).appendingPathComponent(source.path)
            }
        }
        plistPath = (plistPath as NSString).expandingTildeInPath

        // Check if plist exists
        guard FileManager.default.fileExists(atPath: plistPath) else {
            writeLog("ConfigurationService: Auto-discover plist not found: \(plistPath)", logLevel: .error)
            return items
        }

        // Load plist
        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plistDict = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            writeLog("ConfigurationService: Failed to parse plist for auto-discovery: \(plistPath)", logLevel: .error)
            return items
        }

        // Get configuration from source
        let findingKey = source.findingKey ?? "finding"
        let expectedValue = source.expectedValue ?? "false"
        let evaluation = source.evaluation ?? "boolean"
        let excludeKeys = Set(source.excludeKeys ?? ["lastComplianceCheck", "profileIdentifier", "scanDate"])

        // Include pattern (regex)
        var includeRegex: NSRegularExpression?
        if let pattern = source.includePattern {
            includeRegex = try? NSRegularExpression(pattern: pattern, options: [])
        }

        var guiIndex = 0
        for (key, value) in plistDict.sorted(by: { $0.key < $1.key }) {
            // Skip excluded keys
            if excludeKeys.contains(key) { continue }

            // Check include pattern
            if let regex = includeRegex {
                let range = NSRange(key.startIndex..<key.endIndex, in: key)
                if regex.firstMatch(in: key, options: [], range: range) == nil { continue }
            }

            // Check if this key has the finding subkey
            guard let valueDict = value as? [String: Any],
                  valueDict[findingKey] != nil else {
                continue
            }

            // Determine category from prefix
            let category = getCategoryFromKey(key, categoryPrefix: source.categoryPrefix)

            // Format display name
            let displayName = formatDisplayName(key, categoryPrefix: source.categoryPrefix)

            // Get icon for category (uses config icons if provided, otherwise defaults)
            let icon = getIconForKey(key, category: category, sourceIcon: source.icon, categoryIcons: source.categoryIcons)

            // Check keyMappings for overrides
            var finalDisplayName = displayName
            var finalCategory = category
            if let mapping = source.keyMappings?.first(where: { $0.key == key }) {
                if let mappedName = mapping.displayName { finalDisplayName = mappedName }
                if let mappedCategory = mapping.category { finalCategory = mappedCategory }
            }

            let item = InspectConfig.ItemConfig(
                id: key,
                displayName: finalDisplayName,
                icon: icon,
                paths: [source.path],
                guiIndex: guiIndex,
                category: finalCategory,
                categoryIcon: nil,
                plistKey: "\(key).\(findingKey)",
                expectedValue: expectedValue,
                evaluation: evaluation
            )

            items.append(item)
            guiIndex += 1
        }

        return items
    }

    /// Get category from key prefix
    private func getCategoryFromKey(_ key: String, categoryPrefix: [String: String]?) -> String {
        if let prefixes = categoryPrefix {
            for (prefix, category) in prefixes where key.hasPrefix(prefix) {
                return category
            }
        }

        // Default categorization
        if key.hasPrefix("audit_") { return "Audit Controls" }
        if key.hasPrefix("auth_") { return "Authentication" }
        if key.hasPrefix("icloud_") { return "iCloud Security" }
        if key.hasPrefix("os_") { return "OS Security" }
        if key.hasPrefix("pwpolicy_") { return "Password Policy" }
        if key.hasPrefix("system_settings_") { return "System Settings" }
        if key.hasPrefix("sysprefs_") { return "System Preferences" }

        return "Other"
    }

    /// Format display name from key
    private func formatDisplayName(_ key: String, categoryPrefix: [String: String]?) -> String {
        var name = key

        // Remove known prefixes
        let prefixes = ["audit_", "auth_", "icloud_", "os_", "pwpolicy_", "system_settings_", "sysprefs_"]
        for prefix in prefixes where name.hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }

        // Replace underscores with spaces and title case
        name = name.replacingOccurrences(of: "_", with: " ")
            .capitalized
            .replacingOccurrences(of: "Ssh", with: "SSH")
            .replacingOccurrences(of: "Mdm", with: "MDM")
            .replacingOccurrences(of: "Sip", with: "SIP")
            .replacingOccurrences(of: "Airdrop", with: "AirDrop")
            .replacingOccurrences(of: "Icloud", with: "iCloud")
            .replacingOccurrences(of: "Httpd", with: "HTTP Server")
            .replacingOccurrences(of: "Nfsd", with: "NFS Server")
            .replacingOccurrences(of: "Smbd", with: "SMB Server")
            .replacingOccurrences(of: "Tftpd", with: "TFTP Server")
            .replacingOccurrences(of: "Usb", with: "USB")
            .replacingOccurrences(of: "Wifi", with: "WiFi")

        return name
    }

    /// Get icon for key/category - checks config-provided icons first, then falls back to defaults
    private func getIconForKey(_ key: String, category: String, sourceIcon: String?, categoryIcons configIcons: [String: String]?) -> String {
        // First check config-provided category icons
        if let configIcons = configIcons, let icon = configIcons[category] {
            return icon
        }

        // Fallback to default category-based icons
        let defaultCategoryIcons: [String: String] = [
            "OS Security": "sf=shield.fill,colour1=#007AFF",
            "iCloud Security": "sf=icloud.fill,colour1=#007AFF",
            "Authentication": "sf=person.badge.key.fill,colour1=#5856D6",
            "Audit Controls": "sf=doc.text.magnifyingglass,colour1=#8E8E93",
            "Password Policy": "sf=key.fill,colour1=#FF9500",
            "System Settings": "sf=gearshape.fill,colour1=#8E8E93",
            "System Preferences": "sf=gearshape.fill,colour1=#8E8E93"
        ]

        return defaultCategoryIcons[category] ?? sourceIcon ?? "sf=shield.fill,colour1=#007AFF"
    }
    
    /// TODO: better validate configuration and return warnings - 
    private func validateConfiguration(_ config: InspectConfig) -> [String] {
        var warnings: [String] = []
        
        // Check for common configuration issues
        if config.items.isEmpty && config.plistSources?.isEmpty != false {
            warnings.append("Configuration has no items or plist sources")
        }
        
        let validPresets = [
            // Full names
            "preset1", "preset2", "preset3", "preset4", "preset5", "preset6",
            // Numeric shorthand
            "1", "2", "3", "4", "5", "6",
            // Aliases
            "deployment", "cards", "compact", "toast", "compact-installer",
            "portal", "self-service", "webview-portal", "guidance", "modern-sidebar"
        ]
        if !validPresets.contains(config.preset.lowercased()) {
            warnings.append("Unknown preset '\(config.preset)' - will default to preset1")
        }
        
        // Check for missing icon files (skip SF symbols which start with "sf=" or "SF=")
        if let iconPath = config.icon,
           !iconPath.lowercased().hasPrefix("sf="),
           !FileManager.default.fileExists(atPath: iconPath) {
            warnings.append("Icon file not found: \(iconPath)")
        }
        
        // Check for missing background images
        if let backgroundImage = config.backgroundImage, !FileManager.default.fileExists(atPath: backgroundImage) {
            warnings.append("Background image not found: \(backgroundImage)")
        }
        
        // Validate color thresholds
        if let thresholds = config.colorThresholds {
            if thresholds.excellent <= thresholds.good || thresholds.good <= thresholds.warning {
                warnings.append("Color thresholds should be in descending order (excellent > good > warning)")
            }
        }

        // Validate guiIndex values for sequential ordering
        if !config.items.isEmpty {
            let guiIndexWarnings = validateGuiIndexSequence(config.items)
            warnings.append(contentsOf: guiIndexWarnings)
        }

        // Validate item-level issues (preset-aware)
        let itemWarnings = validateItems(config.items, preset: config.preset)
        warnings.append(contentsOf: itemWarnings)

        // Validate preset-specific configuration
        let presetWarnings = validatePresetSpecific(config)
        warnings.append(contentsOf: presetWarnings)

        // Log warnings
        for warning in warnings {
            writeLog("ConfigurationService: Warning - \(warning)", logLevel: .info)
        }
        
        return warnings
    }

    /// Validate individual item configurations (preset-aware)
    /// Returns warnings for: duplicate IDs, invalid stepType, invalid actions, etc.
    private func validateItems(_ items: [InspectConfig.ItemConfig], preset: String) -> [String] {
        var warnings: [String] = []
        let normalizedPreset = normalizePreset(preset)

        // Check for duplicate item IDs
        var seenIds: Set<String> = []
        for item in items {
            if seenIds.contains(item.id) {
                warnings.append("⚠️ Duplicate item ID: '\(item.id)'")
            } else {
                seenIds.insert(item.id)
            }
        }

        // Valid step types for preset6
        let validStepTypes = ["info", "confirmation", "processing", "completion"]

        // Valid button actions
        let validActions = ["url", "request", "custom"]

        // Valid overlay sizes
        let validOverlaySizes = ["small", "medium", "large"]

        for item in items {
            let itemPrefix = "Item '\(item.id)'"

            // Check empty displayName (all presets)
            if item.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                warnings.append("⚠️ \(itemPrefix): Empty displayName")
            }

            // Preset5: Items should have category for grouping
            if normalizedPreset == "5" && item.category == nil {
                warnings.append("⚠️ \(itemPrefix): Missing 'category' field (recommended for preset5 grouping)")
            }

            // Preset5: Items should have plistKey for validation
            if normalizedPreset == "5" && item.plistKey == nil && item.paths.isEmpty {
                warnings.append("⚠️ \(itemPrefix): No 'plistKey' or 'paths' for validation (preset5 compliance check)")
            }

            // Preset6: Validate stepType
            if normalizedPreset == "6" {
                if let stepType = item.stepType, !validStepTypes.contains(stepType.lowercased()) {
                    warnings.append("⚠️ \(itemPrefix): Invalid stepType '\(stepType)' - expected one of: \(validStepTypes.joined(separator: ", "))")
                }

                // Validate overlay sizes
                if let overlay = item.itemOverlay, let size = overlay.size, !validOverlaySizes.contains(size.lowercased()) {
                    warnings.append("⚠️ \(itemPrefix): Invalid itemOverlay size '\(size)' - expected one of: \(validOverlaySizes.joined(separator: ", "))")
                }

                // Validate guidance content blocks
                if let guidanceContent = item.guidanceContent {
                    // Check button actions
                    for (index, block) in guidanceContent.enumerated() where block.type == "button" {
                        if let action = block.action {
                            if !validActions.contains(action.lowercased()) {
                                warnings.append("⚠️ \(itemPrefix): guidanceContent[\(index)] has invalid button action '\(action)' - expected one of: \(validActions.joined(separator: ", "))")
                            }
                            // Check request action has requestId
                            if action.lowercased() == "request" && (block.requestId == nil || block.requestId?.isEmpty == true) {
                                warnings.append("⚠️ \(itemPrefix): guidanceContent[\(index)] button action='request' but no requestId provided")
                            }
                            // Check url action has url
                            if action.lowercased() == "url" && (block.url == nil || block.url?.isEmpty == true) {
                                warnings.append("⚠️ \(itemPrefix): guidanceContent[\(index)] button action='url' but no url provided")
                            }
                        }
                    }
                }
            }
        }

        return warnings
    }

    /// Normalize preset name to number (e.g., "preset6" -> "6", "guidance" -> "6")
    private func normalizePreset(_ preset: String) -> String {
        let lowered = preset.lowercased()

        // Direct number
        if let _ = Int(lowered) { return lowered }

        // presetN format
        if lowered.hasPrefix("preset"), let num = lowered.dropFirst(6).first {
            return String(num)
        }

        // Marketing names
        let presetMap: [String: String] = [
            "deployment": "1", "cards": "2", "compact": "3",
            "compliance": "4", "dashboard": "5",
            "guidance": "6", "guide": "6", "onboarding": "7",
            "display": "8"
        ]
        return presetMap[lowered] ?? "1"
    }

    /// Validate preset-specific configuration (root-level properties)
    private func validatePresetSpecific(_ config: InspectConfig) -> [String] {
        var warnings: [String] = []
        let preset = normalizePreset(config.preset)

        // Valid values for common properties
        let validListIndicatorStyles = ["letters", "numbers", "roman"]
        let validStepStyles = ["plain", "colored", "cards"]
        let validImageShapes = ["rectangle", "square", "circle"]

        // Validate listIndicatorStyle (all presets)
        if let style = config.listIndicatorStyle, !validListIndicatorStyles.contains(style.lowercased()) {
            warnings.append("⚠️ Invalid listIndicatorStyle '\(style)' - expected one of: \(validListIndicatorStyles.joined(separator: ", "))")
        }

        // Validate stepStyle (preset6)
        if let style = config.stepStyle, !validStepStyles.contains(style.lowercased()) {
            warnings.append("⚠️ Invalid stepStyle '\(style)' - expected one of: \(validStepStyles.joined(separator: ", "))")
        }

        // Validate imageShape (preset6)
        if let shape = config.imageShape, !validImageShapes.contains(shape.lowercased()) {
            warnings.append("⚠️ Invalid imageShape '\(shape)' - expected one of: \(validImageShapes.joined(separator: ", "))")
        }

        // Preset5 (Dashboard): Should have plistSources for compliance data
        if preset == "5" {
            if config.plistSources == nil || config.plistSources?.isEmpty == true {
                warnings.append("⚠️ Preset5: Missing 'plistSources' - required for compliance dashboard data")
            } else if let sources = config.plistSources {
                for (index, source) in sources.enumerated() {
                    // Check plist path exists (if not a URL/pattern)
                    if !source.path.hasPrefix("http") && !source.path.contains("*") {
                        let expandedPath = NSString(string: source.path).expandingTildeInPath
                        if !FileManager.default.fileExists(atPath: expandedPath) {
                            warnings.append("⚠️ Preset5: plistSources[\(index)] path not found: \(source.path)")
                        }
                    }
                }
            }
        }

        // Preset6 (Guidance): Should have items with guidanceContent
        if preset == "6" {
            let itemsWithGuidance = config.items.filter { $0.guidanceContent != nil }
            if itemsWithGuidance.isEmpty && !config.items.isEmpty {
                warnings.append("⚠️ Preset6: No items have 'guidanceContent' - recommended for workflow steps")
            }

            // Check actionPipe if using request buttons
            let hasRequestButtons = config.items.contains { item in
                item.guidanceContent?.contains { $0.action?.lowercased() == "request" } ?? false
            }
            if hasRequestButtons && config.actionPipe == nil {
                warnings.append("⚠️ Preset6: Items use 'request' button actions but no 'actionPipe' configured")
            }
        }

        // legacy presets (Picker): Should have pickerConfig
        if preset == "8" || preset == "9" {
            if config.pickerConfig == nil {
                warnings.append("⚠️ Preset\(preset): Missing 'pickerConfig' - recommended for picker mode")
            }
        }

        return warnings
    }

    /// Validate guiIndex values for sequential ordering (0, 1, 2, 3...)
    /// Returns warnings for: non-zero start, gaps, duplicates
    private func validateGuiIndexSequence(_ items: [InspectConfig.ItemConfig]) -> [String] {
        var warnings: [String] = []

        // Extract guiIndex values with item IDs for better error messages
        let indexedItems = items.map { (id: $0.id, index: $0.guiIndex) }
        let sortedByIndex = indexedItems.sorted { $0.index < $1.index }

        // Check 1: Should start at 0
        if let first = sortedByIndex.first, first.index != 0 {
            warnings.append("⚠️ guiIndex: Sequence should start at 0, but starts at \(first.index) (item: '\(first.id)')")
        }

        // Check 2: Look for duplicates
        var seenIndices: [Int: String] = [:] // index -> first item ID that used it
        for item in sortedByIndex {
            if let existingId = seenIndices[item.index] {
                warnings.append("⚠️ guiIndex: Duplicate index \(item.index) found in items '\(existingId)' and '\(item.id)'")
            } else {
                seenIndices[item.index] = item.id
            }
        }

        // Check 3: Look for gaps in sequence
        let indices = sortedByIndex.map { $0.index }
        let uniqueIndices = Set(indices).sorted()

        if uniqueIndices.count > 1 {
            for i in 0..<(uniqueIndices.count - 1) {
                let current = uniqueIndices[i]
                let next = uniqueIndices[i + 1]
                if next != current + 1 {
                    // Find which items are around the gap
                    let beforeItem = sortedByIndex.first { $0.index == current }?.id ?? "?"
                    let afterItem = sortedByIndex.first { $0.index == next }?.id ?? "?"
                    let missingIndices = (current + 1)..<next
                    warnings.append("⚠️ guiIndex: Gap in sequence - missing index(es) \(Array(missingIndices)) between '\(beforeItem)' (\(current)) and '\(afterItem)' (\(next))")
                }
            }
        }

        // Summary if issues found
        if !warnings.isEmpty {
            let actual = sortedByIndex.map { "\($0.index)" }.joined(separator: ", ")
            warnings.insert("⚠️ guiIndex: Expected sequential [0..\(items.count - 1)] but found [\(actual)]", at: 0)
        }

        return warnings
    }

    // MARK: - Brand Token Resolution (Pre-Decode)

    /// Resolve $token references in a JSON dictionary using the brandPalette
    private func resolveBrandTokens(in dict: [String: Any], palette: [String: Any]) -> [String: Any] {
        var result = dict

        for (key, value) in dict {
            if let stringValue = value as? String {
                let resolved = resolveTokenString(stringValue, palette: palette)
                if resolved != stringValue {
                    writeLog("BrandToken: Dict key '\(key)' resolved: '\(stringValue)' → '\(resolved)'", logLevel: .info)
                }
                result[key] = resolved
            } else if let arrayValue = value as? [Any] {
                writeLog("BrandToken: Processing array for key '\(key)' with \(arrayValue.count) elements", logLevel: .info)
                result[key] = resolveTokensInArray(arrayValue, palette: palette)
            } else if let dictValue = value as? [String: Any], key != "brandPalette" {
                // Skip brandPalette itself to avoid circular resolution
                result[key] = resolveBrandTokens(in: dictValue, palette: palette)
            }
        }

        return result
    }

    /// Resolve tokens in an array
    private func resolveTokensInArray(_ array: [Any], palette: [String: Any]) -> [Any] {
        return array.map { element in
            if let stringValue = element as? String {
                return resolveTokenString(stringValue, palette: palette)
            } else if let arrayValue = element as? [Any] {
                return resolveTokensInArray(arrayValue, palette: palette)
            } else if let dictValue = element as? [String: Any] {
                return resolveBrandTokens(in: dictValue, palette: palette)
            }
            return element
        }
    }

    /// Resolve $tokenName references in a string using the palette dictionary
    private func resolveTokenString(_ value: String, palette: [String: Any]) -> String {
        guard value.contains("$") else { return value }

        let pattern = #"\$([a-zA-Z_][a-zA-Z0-9_.]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return value }

        var result = value
        let matches = regex.matches(in: value, range: NSRange(value.startIndex..., in: value))

        writeLog("BrandToken: Resolving '\(value)' - found \(matches.count) token(s)", logLevel: .info)

        for match in matches.reversed() {
            guard let tokenRange = Range(match.range(at: 1), in: value),
                  let fullRange = Range(match.range, in: result) else { continue }

            let token = String(value[tokenRange])
            if let resolved = lookupPaletteToken(token, palette: palette) {
                writeLog("BrandToken: Resolved $\(token) → \(resolved)", logLevel: .info)
                result.replaceSubrange(fullRange, with: resolved)
            } else {
                writeLog("BrandToken: WARNING - Token '$\(token)' not found in palette", logLevel: .info)
            }
        }

        return result
    }

    /// Look up a token in the palette dictionary
    private func lookupPaletteToken(_ token: String, palette: [String: Any]) -> String? {
        // Handle namespaced tokens like "logos.main" or "custom.brandTeal"
        if token.contains(".") {
            let parts = token.split(separator: ".", maxSplits: 1)
            if parts.count == 2,
               let namespace = palette[String(parts[0])] as? [String: Any],
               let value = namespace[String(parts[1])] as? String {
                // Recursively resolve in case the value contains tokens
                return resolveTokenString(value, palette: palette)
            }
            return nil
        }

        // Direct token lookup
        if let value = palette[token] as? String {
            return value
        }

        return nil
    }

    // MARK: - Configuration Transformation Helpers

    func extractUIConfiguration(from config: InspectConfig) -> UIConfiguration {
        var uiConfig = UIConfiguration()

        print("Config.swift: extractUIConfiguration called")
        print("Config.swift: config.banner = \(config.banner ?? "nil")")
        print("Config.swift: config.bannerHeight = \(config.bannerHeight ?? 0)")
        print("Config.swift: config.bannerTitle = \(config.bannerTitle ?? "nil")")

        if let title = config.title {
            uiConfig.windowTitle = title
        }

        if let message = config.message {
            uiConfig.subtitleMessage = message
            uiConfig.statusMessage = message
        }

        if let icon = config.icon {
            uiConfig.iconPath = icon
        }

        if let sideMessage = config.sideMessage {
            uiConfig.sideMessages = sideMessage
        }

        if let popupButton = config.popupButton {
            uiConfig.popupButtonText = popupButton
        }

        uiConfig.preset = config.preset

        if let highlightColor = config.highlightColor {
            uiConfig.highlightColor = highlightColor
        }

        if let secondaryColor = config.secondaryColor {
            uiConfig.secondaryColor = secondaryColor
        }

        // Banner configuration
        if let banner = config.banner {
            print("Config.swift: Setting uiConfig.bannerImage = \(banner)")
            uiConfig.bannerImage = banner
        }

        if let bannerHeight = config.bannerHeight {
            print("Config.swift: Setting uiConfig.bannerHeight = \(bannerHeight)")
            uiConfig.bannerHeight = bannerHeight
        }

        if let bannerTitle = config.bannerTitle {
            print("Config.swift: Setting uiConfig.bannerTitle = \(bannerTitle)")
            uiConfig.bannerTitle = bannerTitle
        }

        print("Config.swift: After extraction - uiConfig.bannerImage = \(uiConfig.bannerImage ?? "nil")")

        if let iconsize = config.iconsize {
            uiConfig.iconSize = iconsize
        }

        // Window sizing configuration
        if let width = config.width {
            uiConfig.width = width
        }

        if let height = config.height {
            uiConfig.height = height
        }

        if let size = config.size {
            uiConfig.size = size
        }

        // Preset6 specific properties
        if let iconBasePath = config.iconBasePath {
            uiConfig.iconBasePath = iconBasePath
            ImageResolver.shared.configBasePath = iconBasePath
        }

        if let overlayicon = config.overlayicon {
            uiConfig.overlayIcon = overlayicon
        }

        if let rotatingImages = config.rotatingImages {
            uiConfig.rotatingImages = rotatingImages
        }

        if let imageRotationInterval = config.imageRotationInterval {
            uiConfig.imageRotationInterval = imageRotationInterval
        }

        if let imageShape = config.imageShape {
            uiConfig.imageFormat = imageShape  // Map to existing imageFormat property
        }

        if let imageSyncMode = config.imageSyncMode {
            uiConfig.imageSyncMode = imageSyncMode
        }

        if let stepStyle = config.stepStyle {
            uiConfig.stepStyle = stepStyle
        }

        if let listIndicatorStyle = config.listIndicatorStyle {
            uiConfig.listIndicatorStyle = listIndicatorStyle
            print("Config: Setting listIndicatorStyle to '\(listIndicatorStyle)' from JSON")
        } else {
            print("Config: No listIndicatorStyle in JSON, using default: '\(uiConfig.listIndicatorStyle)'")
        }

        return uiConfig
    }
    
    func extractBackgroundConfiguration(from config: InspectConfig) -> BackgroundConfiguration {
        var bgConfig = BackgroundConfiguration()
        
        if let backgroundColor = config.backgroundColor {
            bgConfig.backgroundColor = backgroundColor
        }
        
        if let backgroundImage = config.backgroundImage {
            bgConfig.backgroundImage = backgroundImage
        }
        
        if let backgroundOpacity = config.backgroundOpacity {
            bgConfig.backgroundOpacity = backgroundOpacity
        }
        
        if let textOverlayColor = config.textOverlayColor {
            bgConfig.textOverlayColor = textOverlayColor
        }
        
        if let gradientColors = config.gradientColors {
            bgConfig.gradientColors = gradientColors
        }
        
        return bgConfig
    }
    
    func extractButtonConfiguration(from config: InspectConfig) -> ButtonConfiguration {
        var buttonConfig = ButtonConfiguration()

        if let button1Text = config.button1Text {
            buttonConfig.button1Text = button1Text
            writeLog("Config: Extracted button1Text = '\(button1Text)'", logLevel: .info)
        } else {
            writeLog("Config: button1Text is nil in config", logLevel: .info)
        }

        if let button1Disabled = config.button1Disabled {
            buttonConfig.button1Disabled = button1Disabled
        }

        if let button2Text = config.button2Text {
            buttonConfig.button2Text = button2Text
            writeLog("Config: Extracted button2Text = '\(button2Text)'", logLevel: .info)
        } else {
            writeLog("Config: button2Text is nil in config", logLevel: .info)
        }

        // Deprecated: button2Disabled - button2 is always enabled when shown
        // if let button2Disabled = config.button2Disabled {
        //     buttonConfig.button2Disabled = button2Disabled
        // }

        if let button2Visible = config.button2Visible {
            buttonConfig.button2Visible = button2Visible
        }

        // Deprecated: buttonStyle - not used in Inspect mode
        // if let buttonStyle = config.buttonStyle {
        //     buttonConfig.buttonStyle = buttonStyle
        // }
        
        if let autoEnableButton = config.autoEnableButton {
            buttonConfig.autoEnableButton = autoEnableButton
        }
        
        return buttonConfig
    }
}
